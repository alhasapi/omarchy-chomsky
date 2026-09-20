#!/bin/bash
# Group 2: window behaviour -- border resize and the dim strength that travels
# with it. Both live in one toggle file, and the dim strength is carried over
# from whatever is in effect rather than reset to the CLI default, so the value
# the user last chose is part of the contract.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

toggle="$FAKE_HOME/.local/state/omarchy/toggles/hypr/chomsky-window-behavior.lua"
state="$FAKE_HOME/.local/state/chomsky/window-behavior"

run_capture chomsky chomsky-window current
assert_ran_ok "chomsky-window current runs"
assert_eq "$last_output" "off" "window behaviour starts off"

run_capture chomsky chomsky-window on 0.35
assert_ran_ok "chomsky-window on applies it"
assert_file "$toggle" "turning it on writes the toggle file"
assert_eq "$(cat "$state")" "on" "the state file records it as on"
assert_contains "$(cat "$toggle")" "0.35" "the chosen dim strength is what the toggle file sets"
assert_eq "$(chomsky chomsky-window current)" "on" "current reports on"
if command -v luac > /dev/null 2>&1; then
  if luac -p "$toggle" 2> /dev/null; then
    pass "the toggle file is valid Lua"
  else
    fail "the toggle file is not valid Lua"
  fi
fi

# Hyprland's own option is what the panel reads the effective strength from.
run_capture "$SHIM_DIR/hyprctl" getoption decoration:dim_strength
assert_contains "$last_output" "0.35" "hyprctl reports the strength the toggle file set"

run_capture chomsky chomsky status
assert_eq "$(printf '%s' "$last_output" | jq -r .resizeOnBorder)" "true" "status says border resize is on"
assert_eq "$(printf '%s' "$last_output" | jq -r .dimStrength)" "0.35" "status carries the live dim strength"

run_capture chomsky chomsky-window toggle 0.5
assert_ran_ok "chomsky-window toggle flips the state"
assert_eq "$(chomsky chomsky-window current)" "off" "toggling from on lands off"
assert_contains "$(cat "$state")" "off" "the state file follows"

run_capture chomsky chomsky-window toggle 0.5
assert_eq "$(chomsky chomsky-window current)" "on" "toggling again lands back on"
assert_contains "$(cat "$toggle")" "0.5" "the strength passed to toggle is the one applied"

run_capture chomsky chomsky-window off
assert_ran_ok "chomsky-window off applies it"
assert_eq "$(cat "$state")" "off" "the state file records off"
run_capture chomsky chomsky status
assert_eq "$(printf '%s' "$last_output" | jq -r .resizeOnBorder)" "false" "status agrees that it is off"

finish_test
