#!/bin/bash
# Group 0: the safety properties this suite rests on.
#
# These tests are only trustworthy if they cannot damage the machine they run
# on, and that rests on two things: every external command being a shim on PATH,
# and the check that the user's real config came out untouched actually working.
# A guard that has never been seen to fail is not a guard, so the second test
# here deliberately breaks a throwaway directory and expects it to be noticed.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

# --- nothing on PATH is the real thing --------------------------------------
# setup_sandbox already refuses to run when this is not true; asserting it as a
# test as well means a broken shim set is reported as a failure with a name.
for tool in hyprctl omarchy omarchy-theme-bg-set omarchy-shell omarchy-menu-images \
  omarchy-menu-select omarchy-menu-keybindings omarchy-notification-send \
  omarchy-hyprland-monitor-focused; do
  resolved="$(command -v "$tool" 2> /dev/null || true)"
  assert_eq "$resolved" "$SHIM_DIR/$tool" "$tool resolves to the test shim, not the real one"
done

# A shim that is asked for something it does not model must fail loudly: a
# silently-successful stub would let a test pass on a call that does nothing.
run_capture "$SHIM_DIR/hyprctl" getoption something:unknown
assert_failed "the hyprctl shim fails on an invocation it does not model"

# --- the real-home guard notices changes ------------------------------------
# Run against a throwaway "home" so the real one is never involved, and cover
# both shapes the guard has to handle: a path that is a file, and a path that is
# a directory. The guard hashes the two differently (`sha256sum` vs `find`), and
# the bug it had -- taking the path where the hash should be -- was only visible
# in the directory case. Probing just a file made this test blind to it.
probe_home="$(mktemp -d "$TEST_TMP/probe.XXXXXX")"
mkdir -p "$probe_home/.config/omarchy" "$probe_home/.local/state/omarchy/toggles/hypr"
echo '{}' > "$probe_home/.config/omarchy/shell.json"
echo 'hl.config({})' > "$probe_home/.local/state/omarchy/toggles/hypr/chomsky-shader.lua"

# Deliberately not silencing stderr: a probe that fails to source the helpers
# returns empty strings, which would compare equal and read as "the guard is
# broken" instead of "the probe is broken".
probe_hash() {
  # The path goes in as an argument, not as `REPO_DIR=... cmd`: REPO_DIR is
  # readonly in this shell, so that assignment fails and never reaches the
  # child. Without this the probe silently returned nothing.
  REAL_HOME="$probe_home" bash -c 'source "$1"; hash_real_home' _ \
    "$REPO_DIR/tests/lib/common.sh"
}

before="$(probe_hash)"
if [[ -z "$before" ]]; then
  fail "the real-home probe produced no output" \
    "the probe is broken, so the guard's result would prove nothing either way"
fi

echo '{"changed": true}' > "$probe_home/.config/omarchy/shell.json"
after_file_edit="$(probe_hash)"
assert_ne "$after_file_edit" "$before" "the guard notices an edited file"

echo 'hl.config({decoration = {screen_shader = "x"}})' \
  > "$probe_home/.local/state/omarchy/toggles/hypr/chomsky-shader.lua"
after_dir_edit="$(probe_hash)"
assert_ne "$after_dir_edit" "$after_file_edit" \
  "and an edited file inside a watched directory"

rm -f "$probe_home/.config/omarchy/shell.json"
after_delete="$(probe_hash)"
assert_ne "$after_delete" "$after_dir_edit" "and a deleted one"

mkdir -p "$probe_home/.config/omarchy/extensions"
echo 'x' > "$probe_home/.config/omarchy/extensions/omarchy-menu.jsonc"
after_add="$(probe_hash)"
assert_ne "$after_add" "$after_delete" "and a new file where there was none"

# --- the sandbox is where writes land ---------------------------------------
# A script that ignores HOME is the failure this catches: the guard would
# notice it at the end of a run, but not which test did it.
run_capture chomsky chomsky-bar on
assert_ran_ok "a command that rewrites shell.json succeeds"
assert_file "$FAKE_HOME/.config/omarchy/shell.json" "its write landed in the sandbox home"
assert_not_contains "$(cat "$FAKE_HOME/.config/omarchy/shell.json")" "$HOME" "and nowhere else"

finish_test
