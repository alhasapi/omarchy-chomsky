#!/bin/bash
# Group 3: the status line.
#
# Everything the panel shows comes from one JSON line, so this is the contract
# between the CLI and the QML. Two things are checked: that it keeps emitting
# every field the QML reads (a rename on one side used to be silent), and that
# each field follows the state it describes rather than a memory of it.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

status_json() { chomsky chomsky status; }

run_capture chomsky chomsky status
assert_ran_ok "chomsky status runs"
if jq -e . <<< "$last_output" > /dev/null 2>&1; then
  pass "it prints a single parseable JSON line"
else
  fail "its output is not JSON" "$last_output"
fi

# --- the fields the QML actually reads --------------------------------------
# Taken from Service.qml rather than hardcoded, so this test fails if the QML
# starts reading a field the CLI does not emit.
qml_fields="$(grep -oE 'parsed\.[a-zA-Z]+' "$REPO_DIR/Service.qml" | sed 's/parsed\.//' | sort -u)"
missing_fields=()
for field in $qml_fields; do
  jq -e --arg f "$field" 'has($f)' <<< "$last_output" > /dev/null || missing_fields+=("$field")
done
if ((${#missing_fields[@]} == 0)); then
  pass "every field Service.qml reads is present ($(wc -w <<< "$qml_fields") of them)"
else
  fail "Service.qml reads a field the status line does not emit" "${missing_fields[*]}"
fi

# --- types ------------------------------------------------------------------
assert_eq "$(jq -r '.shaderOn | type' <<< "$last_output")" "boolean" "shaderOn is a boolean"
assert_eq "$(jq -r '.resizeOnBorder | type' <<< "$last_output")" "boolean" "resizeOnBorder is a boolean"
assert_eq "$(jq -r '.dimInactive | type' <<< "$last_output")" "boolean" "dimInactive is a boolean"
assert_eq "$(jq -r '.dimStrength | type' <<< "$last_output")" "number" "dimStrength is a number"
assert_eq "$(jq -r '.animation | type' <<< "$last_output")" "string" "animation is a string"
assert_eq "$(jq -r '.theme' <<< "$last_output")" "TestTheme" "the theme comes from Omarchy"

# --- each field follows its state -------------------------------------------
# shader
chomsky chomsky-shader set 02_green_tint > /dev/null
assert_eq "$(jq -r '.shader' <<< "$(status_json)")" "02_green_tint" "the shader field follows the applied shader"
assert_eq "$(jq -r '.shaderOn' <<< "$(status_json)")" "true" "and shaderOn follows with it"
chomsky chomsky-shader off > /dev/null
assert_eq "$(jq -r '.shaderOn' <<< "$(status_json)")" "false" "and back to false when it is turned off"

# animation
chomsky chomsky-anim set us-and-them > /dev/null 2>&1 || chomsky chomsky-anim set "$(chomsky chomsky-anim list | head -n1)" > /dev/null
preset="$(chomsky chomsky-anim current)"
assert_eq "$(jq -r '.animation' <<< "$(status_json)")" "$preset" "the animation field follows the applied preset"
rm -f "$FAKE_HOME/.local/state/omarchy/toggles/hypr/chomsky-animation.lua"
assert_eq "$(jq -r '.animation' <<< "$(status_json)")" "(none)" "and reports none once the toggle file is gone"

# keybindings
chomsky chomsky-keys dusky > /dev/null
assert_eq "$(jq -r '.keybindings' <<< "$(status_json)")" "dusky" "the keybindings field follows the mode"
chomsky chomsky-keys reset > /dev/null 2>&1
assert_eq "$(jq -r '.keybindings' <<< "$(status_json)")" "omarchy" "and returns to omarchy"

# window behaviour
chomsky chomsky-window on 0.2 > /dev/null
assert_eq "$(jq -r '.resizeOnBorder' <<< "$(status_json)")" "true" "resizeOnBorder follows the toggle"
chomsky chomsky-window off > /dev/null
assert_eq "$(jq -r '.resizeOnBorder' <<< "$(status_json)")" "false" "and follows it back"

# bar chip
write_shell_json on
assert_eq "$(jq -r '.barChip' <<< "$(status_json)")" "on" "barChip follows the bar layout"
write_shell_json off
assert_eq "$(jq -r '.barChip' <<< "$(status_json)")" "off" "and follows it off"

# background
: > "$FAKE_HOME/.local/state/omarchy/current/theme/backgrounds/bg.jpg"
chomsky chomsky-wallpaper set "$FAKE_HOME/.local/state/omarchy/current/theme/backgrounds/bg.jpg" > /dev/null
assert_eq "$(jq -r '.background' <<< "$(status_json)")" \
  "$FAKE_HOME/.local/state/omarchy/current/theme/backgrounds/bg.jpg" \
  "the background field follows what Omarchy has set"

finish_test
