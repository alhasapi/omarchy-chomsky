#!/bin/bash
# Group 2: the screen shader.
#
# This is the bug that started the branch: the panel showed a shader that was
# not painted, because the shader was applied at runtime (an `hl.config` through
# `hyprctl eval`) and recorded in a state file, while a config reload -- of which
# this plugin causes several -- drops runtime values. The record and reality
# disagreed, and the panel reported the record.
#
# The hyprctl shim models that asymmetry rather than stubbing it out: a reload
# re-reads the toggle directory, a runtime eval survives until the next reload.
# So these tests can reproduce the original failure and prove it is gone.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

toggle="$FAKE_HOME/.local/state/omarchy/toggles/hypr/chomsky-shader.lua"
live() { cat "$SHIM_STATE/screen_shader" 2> /dev/null || true; }
current() { chomsky chomsky-shader current; }

# --- setting a shader applies it, from a file that survives a reload --------
run_capture chomsky chomsky-shader set 01_red_tint
assert_ran_ok "chomsky-shader set applies a shader"
assert_file "$toggle" "setting a shader writes the toggle file Hyprland sources"
assert_eq "$(current)" "01_red_tint" "current reports the shader that is on"
assert_contains "$(live)" "01_red_tint.glsl" "the shader is actually applied in Hyprland"

if command -v luac > /dev/null 2>&1; then
  if luac -p "$toggle" 2> /dev/null; then
    pass "the toggle file is valid Lua (Hyprland has to be able to source it)"
  else
    fail "the toggle file is not valid Lua" "$(cat "$toggle")"
  fi
fi

# The regression itself: anything may reload the config behind the plugin's
# back -- this plugin's own keybinding switch does. The shader must come back.
chomsky hyprctl-shim-reload > /dev/null 2>&1 || true
"$SHIM_DIR/hyprctl" reload > /dev/null
assert_eq "$(current)" "01_red_tint" "the shader survives an unrelated hyprctl reload"
assert_contains "$(live)" "01_red_tint.glsl" "and is still applied afterwards"

# --- a runtime-only value is not treated as state ---------------------------
# The exact original scenario: something applied a shader at runtime and wrote
# no durable file. Hyprland reports it until the next reload, so `current` says
# so; after a reload the truth is "off", and the plugin must say that rather
# than report a remembered name.
run_capture chomsky chomsky-shader off
assert_ran_ok "chomsky-shader off turns it off"
assert_no_file "$toggle" "turning the shader off removes the toggle file"
assert_eq "$(live)" "" "turning the shader off clears the live value"
assert_eq "$(current)" "off" "current reports off once it is off"

"$SHIM_DIR/hyprctl" eval 'hl.config({ decoration = { screen_shader = "/tmp/stale.glsl" } })' > /dev/null
assert_eq "$(current)" "stale" "a runtime value is reported while it really is applied"
"$SHIM_DIR/hyprctl" reload > /dev/null
assert_eq "$(current)" "off" "after a reload, the plugin reports off rather than a remembered name"

# --- restore reconciles in both directions ----------------------------------
chomsky chomsky-shader set 10_grayscale > /dev/null
"$SHIM_DIR/hyprctl" eval 'hl.config({ decoration = { screen_shader = "" } })' > /dev/null
assert_eq "$(live)" "" "simulated drift: applied then cleared at runtime"

run_capture chomsky chomsky-shader restore
assert_ran_ok "chomsky-shader restore runs"
assert_contains "$(live)" "10_grayscale.glsl" "restore puts back what the toggle file says should be on"
assert_eq "$(current)" "10_grayscale" "and current agrees"

chomsky chomsky-shader off > /dev/null
"$SHIM_DIR/hyprctl" eval 'hl.config({ decoration = { screen_shader = "/tmp/stray.glsl" } })' > /dev/null
assert_ne "$(live)" "" "simulated stray runtime value with no toggle file"
chomsky chomsky-shader restore > /dev/null
assert_eq "$(live)" "" "restore clears a stray value when the toggle file is gone"
assert_eq "$(current)" "off" "and the report follows reality, not the stray"

# --- cycling reads live state, not a remembered one -------------------------
chomsky chomsky-shader set 10_grayscale > /dev/null
"$SHIM_DIR/hyprctl" eval 'hl.config({ decoration = { screen_shader = "" } })' > /dev/null
chomsky chomsky-shader next > /dev/null
assert_eq "$(current)" "01_red_tint" "with nothing applied, next starts from the top of the list"

# --- the picker applies what it returns -------------------------------------
SHIM_PICK=12_posterization run_capture chomsky chomsky-shader menu
assert_ran_ok "chomsky-shader menu applies the picker's answer"
assert_eq "$(current)" "12_posterization" "the picked shader is the one that ends up applied"

# --- the panel's JSON agrees with reality -----------------------------------
run_capture chomsky chomsky status
assert_ran_ok "chomsky status runs"
assert_eq "$(printf '%s' "$last_output" | jq -r .shader)" "12_posterization" "status reports the live shader"
assert_eq "$(printf '%s' "$last_output" | jq -r .shaderOn)" "true" "status says a shader is on when one is"

chomsky chomsky-shader off > /dev/null
run_capture chomsky chomsky status
assert_eq "$(printf '%s' "$last_output" | jq -r .shader)" "off" "status reports off"
assert_eq "$(printf '%s' "$last_output" | jq -r .shaderOn)" "false" "and shaderOn false"

finish_test
