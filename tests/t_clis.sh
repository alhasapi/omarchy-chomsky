#!/bin/bash
# Group 2: the small CLIs that only pass a command along -- monitor rotation,
# screen off, reload, and the PATH wrappers chomsky-link writes.
#
# These exist because the alternative is relying on them by hand: a rotation
# that silently dispatches to the wrong monitor, or a wrapper pointing at a
# script that was renamed, is invisible until someone needs it mid-presentation.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

effects() { cat "$SHIM_STATE/effects.log" 2> /dev/null || true; }
: > "$SHIM_STATE/effects.log"

# --- monitor rotation -------------------------------------------------------
# Rotation reissues the full monitor spec through hyprctl eval (a `keyword
# monitor` is refused on Lua-parser builds), reading the live mode first. The
# shim models the transform, so stepping it is observable.
for direction in cw ccw; do
  : > "$SHIM_STATE/effects.log"
  run_capture chomsky chomsky-monitor-rotate "$direction"
  assert_ran_ok "chomsky-monitor-rotate $direction runs"
done
: > "$SHIM_STATE/effects.log"
chomsky chomsky-monitor-rotate cw > /dev/null
assert_contains "$(effects)" "transform = 1" "cw advances the monitor's transform by one"
assert_contains "$(effects)" "HDMI-A-2" "and names the focused monitor"
chomsky chomsky-monitor-rotate cw > /dev/null
assert_contains "$(effects)" "transform = 2" "a second cw advances it again"
: > "$SHIM_STATE/effects.log"
chomsky chomsky-monitor-rotate ccw > /dev/null
assert_contains "$(effects)" "transform = 1" "ccw steps it back"
assert_contains "$(cat "$SHIM_STATE/hyprctl.calls")" "monitors" "the live monitor values are read before reissuing the spec"

# --- screen off / reload ----------------------------------------------------
: > "$SHIM_STATE/hyprctl.calls"
run_capture chomsky chomsky dpms off
assert_ran_ok "chomsky dpms off runs"
assert_contains "$(cat "$SHIM_STATE/hyprctl.calls")" "dispatch" "screen off goes through a hyprctl dispatch"

: > "$SHIM_STATE/hyprctl.calls"
run_capture chomsky chomsky reload
assert_ran_ok "chomsky reload runs"
assert_contains "$(cat "$SHIM_STATE/hyprctl.calls")" "reload" "and reloads Hyprland"

# --- the PATH wrappers ------------------------------------------------------
run_capture chomsky chomsky-link
assert_ran_ok "chomsky-link runs"
wrappers=0
for name in omarchy-anim omarchy-shader omarchy-monitor-rotate omarchy-wallpaper; do
  wrapper="$FAKE_HOME/.local/bin/$name"
  if [[ -x "$wrapper" ]]; then
    wrappers=$((wrappers + 1))
  else
    fail "$name was not linked into ~/.local/bin"
  fi
done
if ((wrappers == 4)); then
  pass "all four wrappers are written and executable"
fi
if grep -q "$BIN_DIR/chomsky-shader" "$FAKE_HOME/.local/bin/omarchy-shader" 2> /dev/null; then
  pass "a wrapper points at the plugin's own script"
else
  fail "the wrapper does not point at the plugin" "$(cat "$FAKE_HOME/.local/bin/omarchy-shader" 2> /dev/null)"
fi
# And it works, which is the only reason it exists.
run_capture "$FAKE_HOME/.local/bin/omarchy-shader" current
assert_ran_ok "a wrapper runs"
assert_eq "$last_output" "off" "and reports the shader state"

finish_test
