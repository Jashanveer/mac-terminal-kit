#!/usr/bin/env bash

set -u
set -o pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MACTERM_BIN=${MACTERM_BIN:-"$ROOT_DIR/bin/macterm"}
BEGIN_MARKER='# >>> mac-terminal-kit managed >>>'
END_MARKER='# <<< mac-terminal-kit managed <<<'

PASS_COUNT=0
FAIL_COUNT=0
TEST_ROOT=''
TEST_NAME=''
TEST_DIR=''
TEST_HOME=''
COMMAND_COUNT=0
RUN_LOG=''
RUN_OUTPUT=''

cleanup() {
  if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then
    rm -rf -- "$TEST_ROOT"
  fi
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

fail() {
  printf '    %s\n' "$*" >&2
  return 1
}

assert_path_exists() {
  [ -e "$1" ] || [ -L "$1" ] || fail "expected path to exist: $1"
}

assert_path_absent() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    fail "expected path to be absent: $1"
  fi
}

assert_file_contains() {
  local file=$1
  local text=$2

  [ -f "$file" ] || {
    fail "expected file to exist: $file"
    return 1
  }
  grep -Fq -- "$text" "$file" || fail "expected $file to contain: $text"
}

assert_line_count() {
  local expected=$1
  local text=$2
  local file=$3
  local actual

  [ -f "$file" ] || {
    fail "expected file to exist: $file"
    return 1
  }
  actual=$(grep -Fxc -- "$text" "$file" 2>/dev/null || true)
  [ "$actual" -eq "$expected" ] ||
    fail "expected $expected exact occurrence(s) of '$text' in $file, found $actual"
}

assert_files_equal() {
  cmp -s -- "$1" "$2" || fail "expected files to match: $1 and $2"
}

snapshot_path() {
  local path=$1
  local destination=$2

  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    printf 'missing\n' >"$destination"
    return
  fi

  find "$path" -print | LC_ALL=C sort | while IFS= read -r entry; do
    if [ -L "$entry" ]; then
      printf 'link\t%s\t%s\n' "$entry" "$(readlink "$entry")"
    elif [ -d "$entry" ]; then
      printf 'dir\t%s\n' "$entry"
    elif [ -f "$entry" ]; then
      cksum "$entry"
    else
      printf 'other\t%s\n' "$entry"
    fi
  done >"$destination"
}

list_backup_ids() {
  local backup_dir="$TEST_HOME/.local/state/mac-terminal-kit/backups"
  local entry

  [ -d "$backup_dir" ] || return 0
  for entry in "$backup_dir"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    basename -- "$entry"
  done | LC_ALL=C sort
}

run_macterm() {
  COMMAND_COUNT=$((COMMAND_COUNT + 1))
  RUN_LOG="$TEST_DIR/command-$COMMAND_COUNT.log"

  if HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_HOME/.config" \
    XDG_STATE_HOME="$TEST_HOME/.local/state" \
    ZDOTDIR="$TEST_HOME" \
    MACTERM_REPO_ROOT="$ROOT_DIR" \
    "$MACTERM_BIN" "$@" >"$RUN_LOG" 2>&1; then
    RUN_OUTPUT=$(cat "$RUN_LOG")
    return 0
  else
    local status=$?
    RUN_OUTPUT=$(cat "$RUN_LOG")
    return "$status"
  fi
}

setup_case() {
  TEST_DIR="$TEST_ROOT/$TEST_NAME"
  TEST_HOME="$TEST_DIR/home"
  COMMAND_COUNT=0
  RUN_LOG=''
  RUN_OUTPUT=''
  mkdir -p "$TEST_HOME"
}

test_first_install() {
  run_macterm install --no-packages

  assert_path_exists "$TEST_HOME/.zshrc"
  assert_path_exists "$TEST_HOME/.config/mac-terminal-kit"
  assert_path_exists "$TEST_HOME/.local/state/mac-terminal-kit"
  assert_line_count 1 "$BEGIN_MARKER" "$TEST_HOME/.zshrc"
  assert_line_count 1 "$END_MARKER" "$TEST_HOME/.zshrc"

  if run_macterm doctor; then
    :
  fi
  printf '%s\n' "$RUN_OUTPUT" | grep -Fq 'managed configuration' ||
    fail "doctor did not inspect the managed configuration"
}

test_install_is_idempotent() {
  local zshrc_before="$TEST_DIR/zshrc.before"
  local config_before="$TEST_DIR/config.before"
  local zshrc_after="$TEST_DIR/zshrc.after"
  local config_after="$TEST_DIR/config.after"

  run_macterm install --no-packages
  snapshot_path "$TEST_HOME/.zshrc" "$zshrc_before"
  snapshot_path "$TEST_HOME/.config/mac-terminal-kit" "$config_before"

  run_macterm install --no-packages
  snapshot_path "$TEST_HOME/.zshrc" "$zshrc_after"
  snapshot_path "$TEST_HOME/.config/mac-terminal-kit" "$config_after"

  assert_files_equal "$zshrc_before" "$zshrc_after"
  assert_files_equal "$config_before" "$config_after"
  assert_line_count 1 "$BEGIN_MARKER" "$TEST_HOME/.zshrc"
  assert_line_count 1 "$END_MARKER" "$TEST_HOME/.zshrc"
}

test_preserves_surrounding_zshrc() {
  cat >"$TEST_HOME/.zshrc" <<'EOF'
# user prelude
export USER_SENTINEL='before managed content'

# user epilogue
alias user-sentinel='printf preserved'
EOF

  run_macterm install --no-packages

  assert_line_count 1 "# user prelude" "$TEST_HOME/.zshrc"
  assert_line_count 1 "export USER_SENTINEL='before managed content'" "$TEST_HOME/.zshrc"
  assert_line_count 1 "# user epilogue" "$TEST_HOME/.zshrc"
  assert_line_count 1 "alias user-sentinel='printf preserved'" "$TEST_HOME/.zshrc"
  assert_line_count 1 "$BEGIN_MARKER" "$TEST_HOME/.zshrc"
  assert_line_count 1 "$END_MARKER" "$TEST_HOME/.zshrc"
}

test_refuses_malformed_markers() {
  local before="$TEST_DIR/zshrc.before"

  cat >"$TEST_HOME/.zshrc" <<EOF
# user content
$BEGIN_MARKER
# missing closing marker
EOF
  cp "$TEST_HOME/.zshrc" "$before"

  if run_macterm install --no-packages; then
    fail "install unexpectedly accepted an unmatched managed marker"
  fi

  assert_files_equal "$before" "$TEST_HOME/.zshrc"
  assert_path_absent "$TEST_HOME/.config/mac-terminal-kit"
  assert_path_absent "$TEST_HOME/.local/state/mac-terminal-kit"
}

test_refuses_reversed_markers() {
  local before="$TEST_DIR/zshrc.before"

  cat >"$TEST_HOME/.zshrc" <<EOF
# user content
$END_MARKER
# content that must remain
$BEGIN_MARKER
EOF
  cp "$TEST_HOME/.zshrc" "$before"

  if run_macterm install --no-packages; then
    fail "install unexpectedly accepted reversed managed markers"
  fi

  assert_files_equal "$before" "$TEST_HOME/.zshrc"
  assert_path_absent "$TEST_HOME/.config/mac-terminal-kit"
}

test_refuses_symlinked_managed_root() {
  mkdir -p "$TEST_HOME/external-config"
  printf '%s\n' 'must remain untouched' >"$TEST_HOME/external-config/sentinel"
  mkdir -p "$TEST_HOME/.config"
  ln -s "$TEST_HOME/external-config" "$TEST_HOME/.config/mac-terminal-kit"

  if run_macterm install --no-packages; then
    fail "install unexpectedly accepted a symlinked managed root"
  fi

  assert_file_contains "$TEST_HOME/external-config/sentinel" 'must remain untouched'
  [ -L "$TEST_HOME/.config/mac-terminal-kit" ] || fail "managed root symlink was changed"
}

test_backup_and_restore() {
  local expected="$TEST_DIR/zshrc.expected"
  local backups_before="$TEST_DIR/backups.before"
  local backups_after="$TEST_DIR/backups.after"
  local new_ids="$TEST_DIR/backups.new"
  local backup_id
  local id_count

  cat >"$TEST_HOME/.zshrc" <<'EOF'
# content that must survive a restore
export RESTORE_SENTINEL=original
EOF
  run_macterm install --no-packages
  cp "$TEST_HOME/.zshrc" "$expected"

  list_backup_ids >"$backups_before"
  run_macterm backup
  list_backup_ids >"$backups_after"
  comm -13 "$backups_before" "$backups_after" >"$new_ids"

  id_count=$(wc -l <"$new_ids" | tr -d ' ')
  [ "$id_count" -eq 1 ] ||
    fail "expected backup to create one entry under state/backups, found $id_count"
  backup_id=$(sed -n '1p' "$new_ids")
  [ -n "$backup_id" ] || fail "backup did not produce a usable backup id"

  cat >"$TEST_HOME/.zshrc" <<'EOF'
# destructive local change
export RESTORE_SENTINEL=mutated
EOF
  run_macterm restore "$backup_id"

  assert_files_equal "$expected" "$TEST_HOME/.zshrc"
  assert_file_contains "$TEST_HOME/.zshrc" 'export RESTORE_SENTINEL=original'
}

test_refuses_corrupt_backup_without_deleting_live_file() {
  local backup_id

  printf '%s\n' 'original' >"$TEST_HOME/.zshrc"
  run_macterm backup
  backup_id=$(list_backup_ids | tail -1)
  rm "$TEST_HOME/.local/state/mac-terminal-kit/backups/$backup_id/items/zshrc"
  printf '%s\n' 'live content' >"$TEST_HOME/.zshrc"

  if run_macterm restore "$backup_id"; then
    fail "restore unexpectedly accepted a corrupt backup"
  fi
  assert_file_contains "$TEST_HOME/.zshrc" 'live content'
}

test_refuses_manifest_path_injection() {
  local backup_id manifest external="$TEST_DIR/external-sentinel"

  printf '%s\n' 'protected' >"$external"
  run_macterm backup
  backup_id=$(list_backup_ids | tail -1)
  manifest="$TEST_HOME/.local/state/mac-terminal-kit/backups/$backup_id/manifest.tsv"
  awk -F '\t' -v OFS='\t' -v target="$external" '$1 == "zshrc" {$2 = target; $3 = "missing"; $4 = "-"} {print}' "$manifest" >"$manifest.tmp"
  mv "$manifest.tmp" "$manifest"

  if run_macterm restore "$backup_id"; then
    fail "restore unexpectedly accepted a manifest path injection"
  fi
  assert_file_contains "$external" 'protected'
}

test_refuses_corrupt_symlink_metadata() {
  local backup_id manifest

  run_macterm install --no-packages
  run_macterm backup
  backup_id=$(list_backup_ids | tail -1)
  manifest="$TEST_HOME/.local/state/mac-terminal-kit/backups/$backup_id/manifest.tsv"
  awk -F '\t' -v OFS='\t' '$1 == "wezterm" {$4 = "/tmp/untrusted.lua"} {print}' "$manifest" >"$manifest.tmp"
  mv "$manifest.tmp" "$manifest"

  if run_macterm restore "$backup_id"; then
    fail "restore unexpectedly accepted corrupt symlink metadata"
  fi
  [ "$(readlink "$TEST_HOME/.wezterm.lua")" = "$TEST_HOME/.config/mac-terminal-kit/wezterm.lua" ] ||
    fail "restore changed the live WezTerm symlink"
}

test_doctor_rejects_modified_managed_payload() {
  run_macterm install --no-packages
  awk -v start="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == start { print; print "echo altered"; inside = 1; next }
    $0 == end { inside = 0; print; next }
    !inside { print }
  ' "$TEST_HOME/.zshrc" >"$TEST_HOME/.zshrc.tmp"
  mv "$TEST_HOME/.zshrc.tmp" "$TEST_HOME/.zshrc"

  if run_macterm doctor; then
    fail "doctor unexpectedly accepted a modified managed payload"
  fi
  printf '%s\n' "$RUN_OUTPUT" | grep -Fq 'invalid zsh integration' ||
    fail "doctor did not identify the invalid zsh integration"
}

test_uninstall() {
  mkdir -p "$TEST_HOME/.config/mac-terminal-kit-test"
  git config --file "$TEST_HOME/.gitconfig" --add include.path "$TEST_HOME/.config/mac-terminal-kit-test/neighbor.gitconfig"
  cat >"$TEST_HOME/.zshrc" <<'EOF'
# keep before uninstall
export UNINSTALL_SENTINEL=preserve
EOF
  run_macterm install --no-packages
  run_macterm uninstall

  assert_line_count 1 "# keep before uninstall" "$TEST_HOME/.zshrc"
  assert_line_count 1 "export UNINSTALL_SENTINEL=preserve" "$TEST_HOME/.zshrc"
  assert_line_count 0 "$BEGIN_MARKER" "$TEST_HOME/.zshrc"
  assert_line_count 0 "$END_MARKER" "$TEST_HOME/.zshrc"
  assert_path_absent "$TEST_HOME/.config/mac-terminal-kit"
  if grep -Fq 'mac-terminal-kit/delta.gitconfig' "$TEST_HOME/.gitconfig" 2>/dev/null; then
    fail "uninstall left the Git Delta include behind"
  fi
  assert_file_contains "$TEST_HOME/.gitconfig" "$TEST_HOME/.config/mac-terminal-kit-test/neighbor.gitconfig"
}

test_preserves_symlinked_zshrc() {
  mkdir -p "$TEST_HOME/dotfiles"
  printf '%s\n' '# linked user config' >"$TEST_HOME/dotfiles/zshrc"
  ln -s dotfiles/zshrc "$TEST_HOME/.zshrc"

  run_macterm install --no-packages
  [ -L "$TEST_HOME/.zshrc" ] || fail "install replaced the .zshrc symlink"
  assert_line_count 1 "$BEGIN_MARKER" "$TEST_HOME/dotfiles/zshrc"

  run_macterm uninstall
  [ -L "$TEST_HOME/.zshrc" ] || fail "uninstall replaced the .zshrc symlink"
  assert_line_count 1 "# linked user config" "$TEST_HOME/dotfiles/zshrc"
  assert_line_count 0 "$BEGIN_MARKER" "$TEST_HOME/dotfiles/zshrc"
}

run_test() {
  local name=$1
  local function_name=$2
  local status

  TEST_NAME=$name
  setup_case
  printf 'TEST %-34s ' "$name"

  set +e
  (set -e; "$function_name")
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS\n'
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL\n'
    if ls "$TEST_DIR"/command-*.log >/dev/null 2>&1; then
      for RUN_LOG in "$TEST_DIR"/command-*.log; do
        printf '%s\n' "--- ${RUN_LOG#"$TEST_ROOT"/} ---"
        sed 's/^/    /' "$RUN_LOG"
      done
    fi
  fi
}

main() {
  [ -x "$MACTERM_BIN" ] || die "installer is not executable: $MACTERM_BIN"
  TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/mac-terminal-kit-tests.XXXXXX")
  trap cleanup EXIT HUP INT TERM

  run_test first_install test_first_install
  run_test install_is_idempotent test_install_is_idempotent
  run_test preserves_surrounding_zshrc test_preserves_surrounding_zshrc
  run_test refuses_malformed_markers test_refuses_malformed_markers
  run_test refuses_reversed_markers test_refuses_reversed_markers
  run_test refuses_symlinked_managed_root test_refuses_symlinked_managed_root
  run_test backup_and_restore test_backup_and_restore
  run_test refuses_corrupt_backup test_refuses_corrupt_backup_without_deleting_live_file
  run_test refuses_manifest_path_injection test_refuses_manifest_path_injection
  run_test refuses_corrupt_symlink_metadata test_refuses_corrupt_symlink_metadata
  run_test uninstall test_uninstall
  run_test preserves_symlinked_zshrc test_preserves_symlinked_zshrc
  run_test doctor_rejects_modified_payload test_doctor_rejects_modified_managed_payload

  printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
  [ "$FAIL_COUNT" -eq 0 ]
}

main "$@"
