#!/bin/bash
# Shared helpers for Chomsky's tests.
#
# Two rules every test here follows.
#
#   1. HOME is a throwaway directory. These scripts write into the user's own
#      config -- shell.json, the Omarchy menu extension, the Hyprland toggle
#      directory -- so a test that ran against the real HOME would be a bug in
#      itself. `setup_sandbox` installs a fake HOME and the PATH shims;
#      `check_real_home_untouched` proves afterwards that nothing escaped.
#
#   2. External commands are shims on PATH, never the real thing. Nothing here
#      may reload Hyprland, change the wallpaper, switch the user's keybindings
#      or send a notification. The shim for hyprctl models the one asymmetry
#      the shader code depends on (a reload drops runtime values and re-reads
#      the toggle directory) rather than pretending everything succeeds.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_DIR
readonly BIN_DIR="$REPO_DIR/bin"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
KEEP_TMP="${KEEP_TMP:-0}"

# --- results ----------------------------------------------------------------

TESTS_RUN=0
TESTS_FAILED=0
FAILURES=()

pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  printf '  ok    %s\n' "$1"
}

fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILURES+=("$1")
  printf '  FAIL  %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '        %s\n' "$2"
  return 0
}

# --- assertions -------------------------------------------------------------

assert_eq() { # actual expected what
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3" "expected [$2], got [$1]"; fi
}

assert_ne() {
  if [[ "$1" != "$2" ]]; then pass "$3"; else fail "$3" "expected something other than [$2]"; fi
}

assert_contains() { # haystack needle what
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3" "[$1] does not contain [$2]"; fi
}

assert_not_contains() {
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3" "[$1] unexpectedly contains [$2]"; fi
}

assert_file() {
  if [[ -f "$1" ]]; then pass "$2"; else fail "$2" "no such file: $1"; fi
}

assert_exists() { # exists what
  if [[ -e "$1" ]]; then pass "$2"; else fail "$2" "no such path: $1"; fi
}
assert_no_file() {
  if [[ ! -e "$1" ]]; then pass "$2"; else fail "$2" "file should not exist: $1"; fi
}

assert_exec() {
  if [[ -x "$1" ]]; then pass "$2"; else fail "$2" "not executable: $1"; fi
}

# Reads a file, or "<missing>" so a test can compare rather than die.
read_or() { [[ -f "$1" ]] && cat "$1" || printf '<missing>'; }

# Set by run_capture below, and declared here so that reading them before the
# first call is an empty default rather than an unbound-variable error.
last_output=""
last_status=0

# Runs a command, keeping its output and status for later assertions. Never
# aborts the test run: a failing command is the thing under test.
run_capture() {
  last_output="$("$@" 2>&1)"
  last_status=$?
  return 0
}

assert_ran_ok() { # what
  if ((last_status == 0)); then pass "$1"; else fail "$1" "exit $last_status: $last_output"; fi
}

assert_failed() { # what
  if ((last_status != 0)); then pass "$1"; else fail "$1" "expected a non-zero exit; output: $last_output"; fi
}

assert_output_contains() { # needle what
  assert_contains "$last_output" "$1" "$2"
}

# --- sandbox ----------------------------------------------------------------

# A fake HOME laid out the way the plugin expects to find Omarchy's state, plus
# shims first on PATH. $SANDBOX holds everything this test may write to.
# Put the shims on PATH. run.sh does this for a whole run; doing it here as well
# means a single test file can be run on its own -- through bats, or by hand --
# without the risk of reaching the real hyprctl, and so the real wallpaper.
ensure_shims() {
  SHIM_DIR="$TEST_TMP/shims"
  if [[ ! -x "$SHIM_DIR/hyprctl" ]]; then
    mkdir -p "$SHIM_DIR"
    cp "$REPO_DIR"/tests/lib/shims/* "$SHIM_DIR/"
    chmod +x "$SHIM_DIR"/*
  fi
  case ":$PATH:" in
    *":$SHIM_DIR:"*) ;;
    *) PATH="$SHIM_DIR:$PATH" ;;
  esac
  export PATH SHIM_DIR
}

setup_sandbox() {
  ensure_shims
  SANDBOX="$(mktemp -d "$TEST_TMP/sandbox.XXXXXX")"
  export FAKE_HOME="$SANDBOX/home"
  export SHIM_STATE="$SANDBOX/shim"

  mkdir -p "$FAKE_HOME/.config/omarchy/extensions" \
    "$FAKE_HOME/.local/state/chomsky" \
    "$FAKE_HOME/.local/state/omarchy/current/theme/backgrounds" \
    "$FAKE_HOME/.local/state/omarchy/toggles/hypr" \
    "$FAKE_HOME/.local/bin" \
    "$FAKE_HOME/Pictures" \
    "$SHIM_STATE"

  printf 'TestTheme\n' > "$FAKE_HOME/.local/state/omarchy/current/theme.name"
  : > "$SHIM_STATE/notify.log"
  : > "$SHIM_STATE/bg-set.log"
  : > "$SHIM_STATE/frontend.log"
  : > "$SHIM_STATE/omarchy-shell.calls"
  : > "$SHIM_STATE/shell.log"

  # A chip that is off the bar but enabled, which is the state this branch is
  # written for.
  write_shell_json off

  export HOME="$FAKE_HOME"
  export PATH="$SHIM_DIR:$PATH"

  local tool
  for tool in hyprctl omarchy omarchy-theme-bg-set omarchy-shell omarchy-menu-images; do
    if [[ "$(command -v "$tool" 2> /dev/null)" != "$SHIM_DIR/$tool" ]]; then
      printf '  FAIL  the %s on PATH is not the test shim (%s)\n' \
        "$tool" "$(command -v "$tool" 2> /dev/null)"
      printf '        refusing to run: a test without its shims could reload the real\n'
      printf '        compositor or change the real wallpaper. Run tests/run.sh.\n' >&2
      exit 1
    fi
  done
}

# $1 = on|off: where the chip's entry lives in the fake shell.json.
write_shell_json() {
  local where="${1:-off}"
  jq -n --arg where "$where" '
    {
      version: 1,
      bar: { layout: {
        left: ["omarchy.workspaces"],
        center: ["omarchy.clock"],
        right: ["omarchy.tray", {id: "omarchy.power"}]
      }},
      plugins: []
    }
    | if $where == "on"
      then .bar.layout.right += [{"id": "alhasapi.chomsky"}]
      else .plugins = [{"id": "alhasapi.chomsky"}]
      end
  ' > "$FAKE_HOME/.config/omarchy/shell.json"
}

# A plugin script, run with the sandbox's HOME and shims.
chomsky() { "$BIN_DIR/$1" "${@:2}"; }

# --- real-home guard --------------------------------------------------------

# Everything the plugin is allowed to touch in the user's real config. Hashed
# before and after the run: a difference means a test leaked out of the
# sandbox, which would be worse than the bug it was looking for.
REAL_HOME_PATHS=(
  ".config/omarchy/shell.json"
  ".config/omarchy/extensions/omarchy-menu.jsonc"
  ".config/omarchy/extensions/chomsky-menu-entry"
  ".local/state/chomsky"
  ".local/state/omarchy/toggles/hypr"
)

hash_real_home() {
  # "hash path" per file, so that editing a file changes the line. (Taking the
  # path from find's -printf and the hash with awk's $1 put the path in both
  # columns, which made the guard blind to modifications -- only additions and
  # deletions changed it.)
  local p
  for p in "${REAL_HOME_PATHS[@]}"; do
    if [[ -d "$REAL_HOME/$p" ]]; then
      find "$REAL_HOME/$p" -type f -exec sha256sum {} \; 2> /dev/null
    elif [[ -e "$REAL_HOME/$p" ]]; then
      sha256sum "$REAL_HOME/$p"
    else
      echo "absent $p"
    fi
  done | sort -k2
}

real_home_baseline() {
  REAL_HOME="${REAL_HOME:-$HOME}"
  # The guard must measure the user's home, not the sandbox, so capture the
  # real one before any test swaps HOME out.
  if [[ -z "${REAL_HOME_SAVED:-}" ]]; then
    REAL_HOME_SAVED="$HOME"
    REAL_HOME="$HOME"
  fi
  hash_real_home > "$TEST_TMP/real-home.before"
}

check_real_home_untouched() {
  local now="$TEST_TMP/real-home.after"
  hash_real_home > "$now"
  if diff -q "$TEST_TMP/real-home.before" "$now" > /dev/null 2>&1; then
    TESTS_RUN=$((TESTS_RUN + 1))
    printf '  ok    the real home directory was not touched\n'
  else
    fail "the real home directory was modified by the test run" \
      "changed: $(diff "$TEST_TMP/real-home.before" "$now" | grep '^[<>]' | head -4 | tr '\n' ' ')"
  fi
}

# --- test lifecycle ---------------------------------------------------------

start_test() { printf '\n%s\n' "$(basename "$0")"; }

finish_test() {
  if ((TESTS_FAILED == 0)); then
    printf '  %d checks passed\n' "$TESTS_RUN"
    exit 0
  fi
  printf '  %d of %d checks failed\n' "$TESTS_FAILED" "$TESTS_RUN"
  exit 1
}

# Keep the sandbox on failure (or always, with CHOMSKY_TEST_KEEP=1) so a
# failing run can be inspected instead of guessed at.
trap 'if (( TESTS_FAILED > 0 )) || [[ "$KEEP_TMP" == "1" ]]; then printf "  (sandbox kept: %s)\n" "$TEST_TMP"; fi' EXIT
