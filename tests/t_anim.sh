#!/bin/bash
# Group 2: animation presets. Same mechanism as the shader -- a toggle file
# Hyprland sources -- including the rule that the plugin reports what is
# actually in force rather than what it last wrote: if the toggle file is gone,
# no preset is active, whatever a state file remembers.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

toggle="$FAKE_HOME/.local/state/omarchy/toggles/hypr/chomsky-animation.lua"

run_capture chomsky chomsky-anim list
assert_ran_ok "chomsky-anim list runs"
first="$(printf '%s\n' "$last_output" | head -n1)"
last="$(printf '%s\n' "$last_output" | tail -n1)"
list_count="$(printf '%s\n' "$last_output" | grep -c .)"
if ((list_count >= 10)); then
  pass "list reports the shipped presets ($list_count of them)"
else
  fail "list reports only $list_count presets"
fi

run_capture chomsky chomsky-anim set "$first"
assert_ran_ok "chomsky-anim set applies a preset"
assert_file "$toggle" "setting a preset writes the toggle file"
assert_eq "$(chomsky chomsky-anim current)" "$first" "current reports the preset that was set"
if command -v luac > /dev/null 2>&1; then
  if luac -p "$toggle" 2> /dev/null; then
    pass "the toggle file is valid Lua"
  else
    fail "the toggle file is not valid Lua"
  fi
fi

second="$(printf '%s\n' "$(chomsky chomsky-anim list)" | sed -n 2p)"
run_capture chomsky chomsky-anim next
assert_eq "$(chomsky chomsky-anim current)" "$second" "next moves to the following preset"
run_capture chomsky chomsky-anim prev
assert_eq "$(chomsky chomsky-anim current)" "$first" "prev moves back"
chomsky chomsky-anim set "$last" > /dev/null
chomsky chomsky-anim next > /dev/null
assert_eq "$(chomsky chomsky-anim current)" "$first" "next wraps around at the end of the list"

SHIM_PICK="$last" run_capture chomsky chomsky-anim menu
assert_ran_ok "chomsky-anim menu applies the picker's answer"
assert_eq "$(chomsky chomsky-anim current)" "$last" "the picked preset is applied"

# The honesty rule: the record alone must not be enough.
rm -f "$toggle"
assert_eq "$(chomsky chomsky-anim current)" "(none)" "with the toggle file gone, no preset is reported as active"
printf '%s\n' "$first" > "$FAKE_HOME/.local/state/chomsky/animation"
assert_eq "$(chomsky chomsky-anim current)" "(none)" "a leftover state file does not resurrect a preset"

run_capture chomsky chomsky status
assert_eq "$(printf '%s' "$last_output" | jq -r .animation)" "(none)" "status agrees"

finish_test
