#!/bin/bash
# Group 2: the Dusky / Omarchy keybinding switch.
#
# The switch works by clearing every key it knows about and then binding the
# chosen set, from a file Hyprland sources on reload. The invariant that keeps
# it honest is therefore: **every key a mode binds must be a key that mode
# clears first**, and both modes must clear the same set -- otherwise switching
# back leaves an old binding live, which shows up as "that key still doesn't do
# what it says". That is checked by running the real Lua under a stub of
# Hyprland's `hl` API, not by reading it.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

toggle="$FAKE_HOME/.local/state/omarchy/toggles/hypr/chomsky-keys.lua"

# --- the generated toggle file ----------------------------------------------
run_capture chomsky chomsky-keys current
assert_ran_ok "chomsky-keys current runs"
assert_eq "$last_output" "omarchy" "with no toggle file the mode is Omarchy's own bindings"

run_capture chomsky chomsky-keys dusky
assert_ran_ok "chomsky-keys dusky switches to the Dusky set"
assert_file "$toggle" "switching writes the toggle file Hyprland sources"
assert_eq "$(chomsky chomsky-keys current)" "dusky" "current reports the mode that was set"
assert_contains "$(cat "$toggle")" 'chomsky_keys.lua' "the toggle file points at the plugin's Lua module"
if command -v luac > /dev/null 2>&1; then
  if luac -p "$toggle" 2> /dev/null; then
    pass "the generated toggle file is valid Lua"
  else
    fail "the generated toggle file is not valid Lua" "$(cat "$toggle")"
  fi
fi

run_capture chomsky chomsky-keys toggle
assert_ran_ok "chomsky-keys toggle flips the mode"
assert_eq "$(chomsky chomsky-keys current)" "omarchy" "toggling from Dusky lands on Omarchy"
chomsky chomsky-keys reset > /dev/null 2>&1
assert_eq "$(chomsky chomsky-keys current)" "omarchy" "reset returns to Omarchy's own bindings"

# --- the mode tables, run for real -----------------------------------------
if command -v lua > /dev/null 2>&1; then
  harness="$(mktemp "$TEST_TMP/keys.XXXXXX.lua")"
  cat > "$harness" << 'LUA'
-- Record what each mode binds and clears, by standing in for Hyprland's API.
local bound, cleared = {}, {}
-- Anything Hyprland's API offers that we do not model: callable and indexable
-- to any depth, so `hl.dsp.window.resize(...)` works without this stub having
-- to know the API. bind and unbind are recorded, which is what is under test.
local function any()
  return setmetatable({}, {
    __call = function() return any() end,
    __index = function() return any() end,
  })
end
o = { bind = function(key) bound[#bound + 1] = key end }
hl = {
  unbind = function(key) cleared[#cleared + 1] = key end,
  dispatch = any(),
  timer = any(),
  dsp = any(),
}
local path, mode, dir = ...
-- loadfile, not require: this is a path, not a module name.
local chunk, err = loadfile(path)
if not chunk then error(err) end
chunk().apply(mode, dir)
print(table.concat(bound, "\n") .. "\n--\n" .. table.concat(cleared, "\n"))
LUA
  module_name="$REPO_DIR/keys/chomsky_keys.lua"
  for mode in dusky omarchy; do
    if ! out="$(lua "$harness" "$module_name" "$mode" "$REPO_DIR" 2>&1)"; then
      fail "the keybinding module runs for $mode mode" "$out"
      continue
    fi
    # The harness prints the bound keys, a "--" separator, then the cleared ones.
    printf '%s\n' "$out" | awk -v m="$mode" -v tmp="$TEST_TMP" '
      BEGIN { part = 1 }
      /^--$/ { part = 2; next }
      { print > (tmp "/keys." m (part == 1 ? ".bound" : ".cleared")) }'
    bound_n=$(grep -c . "$TEST_TMP/keys.$mode.bound" 2> /dev/null || echo 0)
    cleared_n=$(grep -c . "$TEST_TMP/keys.$mode.cleared" 2> /dev/null || echo 0)
    if ((cleared_n >= 20)); then
      pass "$mode mode clears every key it knows about ($cleared_n keys)"
    else
      fail "$mode mode clears only $cleared_n keys" "expected the full key list"
    fi
    if ((bound_n >= 5)); then
      pass "$mode mode binds $bound_n keys"
    else
      fail "$mode mode binds only $bound_n keys"
    fi
    # The invariant: nothing may be bound that is not cleared first.
    leaked="$(comm -23 <(sort -u "$TEST_TMP/keys.$mode.bound") <(sort -u "$TEST_TMP/keys.$mode.cleared") | tr '\n' ',')"
    if [[ -z "${leaked//,/}" ]]; then
      pass "$mode mode binds nothing it does not clear first"
    else
      fail "$mode mode binds keys that survive a switch to the other mode" "$leaked"
    fi
  done
  if [[ ! -s "$TEST_TMP/keys.dusky.cleared" || ! -s "$TEST_TMP/keys.omarchy.cleared" ]]; then
    fail "both modes clear exactly the same set of keys" "the mode tables did not run, so there is nothing to compare"
  elif diff -q <(sort -u "$TEST_TMP/keys.dusky.cleared") <(sort -u "$TEST_TMP/keys.omarchy.cleared") > /dev/null 2>&1; then
    pass "both modes clear exactly the same set of keys"
  else
    fail "the two modes clear different sets" \
      "only in dusky: $(comm -23 <(sort -u "$TEST_TMP/keys.dusky.cleared") <(sort -u "$TEST_TMP/keys.omarchy.cleared") | tr '\n' ' ')"
  fi
else
  printf '  skip  lua not installed, the mode tables were not executed\n'
fi

# --- what the panel reads ---------------------------------------------------
run_capture chomsky chomsky status
assert_eq "$(printf '%s' "$last_output" | jq -r .keybindings)" "omarchy" "status reports the mode the toggle file describes"

finish_test
