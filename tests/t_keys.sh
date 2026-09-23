#!/bin/bash
# Group 2: the Dusky / Omarchy keybinding switch.
#
# The switch works by clearing every key it owns and then binding the chosen
# set, from a file Hyprland sources on reload. Four invariants keep it honest,
# and all four are checked here by running the real tables under a stub of
# Hyprland's API rather than by reading the source:
#
#   1. every key a mode binds is a key that mode clears first, and both modes
#      clear the identical set -- otherwise switching back leaves an old binding
#      live, which shows up as "that key still doesn't do what it says";
#   2. dusky mode binds every selected Dusky key and every remapped Omarchy
#      action, and no excluded key;
#   3. omarchy mode restores Omarchy's own binding on every key this port owns
#      that Omarchy ships, and leaves nothing of ours behind;
#   4. the tables agree with the pinned snapshots they were built from, so a
#      Dusky key that is unclassified or an Omarchy binding that moved is caught
#      here instead of in the live session.
#
# The last section takes that further: it serves a synthetic keymap to
# `chomsky-keys check` and expects the audit to pass on a matching keymap and to
# fail on a broken one. A guard that has never been seen to fail is not a guard.

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

# --- the tables, against the snapshots they were built from -----------------
# Coverage is the claim that nothing in Dusky is unaccounted for. It only means
# something if it is recomputed, so this runs the real audit and then breaks each
# thing the audit exists to catch. A probe that cannot fail would make the
# coverage assertion above it vacuous.
if command -v lua > /dev/null 2>&1; then
  tables_harness="$TEST_TMP/tables.lua"
  cat > "$tables_harness" << 'LUA'
-- Audit the ledger and the remap table, then the same audits with one thing
-- broken each time. Prints `name=count` lines; the count is what the test
-- asserts on, so a probe that stops detecting its defect shows up as a 0.
local repo = ...
package.path = repo .. "/keys/?.lua;" .. package.path

local ledger = require("dusky-ledger")
local remaps = require("remaps")
local omarchy = require("omarchy-shipped")
local extras = require("extras")
local snapshot = require("dusky-upstream")

-- Shallow copies, deep enough to mutate a row without touching the real tables.
local function copy_rows(rows)
  local out = {}
  for i, row in ipairs(rows) do
    local copy = {}
    for key, value in pairs(row) do copy[key] = value end
    out[i] = copy
  end
  return out
end

local function with_ledger(rows, fn)
  local saved = ledger.rows
  ledger.rows = rows
  local result = fn()
  ledger.rows = saved
  return result
end

local function with_remaps(rows, fn)
  local saved = remaps.rows
  remaps.rows = rows
  local result = fn()
  remaps.rows = saved
  return result
end

local function index_of(rows, predicate)
  for i, row in ipairs(rows) do
    if predicate(row) then return i end
  end
  return nil
end

-- --- the baseline ------------------------------------------------------------
local selected, excluded = 0, 0
local kinds = {}
for _, row in ipairs(ledger.rows) do
  if row.status == "selected" then
    selected = selected + 1
    kinds[row.kind] = (kinds[row.kind] or 0) + 1
  else
    excluded = excluded + 1
  end
end

print("rows=" .. #ledger.rows)
print("selected=" .. selected)
print("excluded=" .. excluded)
for _, kind in ipairs(ledger.kinds) do print("kind_" .. kind .. "=" .. (kinds[kind] or 0)) end
print("remaps=" .. #remaps.rows)
print("extras=" .. #extras.rows)
print("owned=" .. (#remaps.owned(ledger) + #extras.keys()))
print("baseline=" .. (#ledger.audit(snapshot) + #remaps.audit(ledger, omarchy) + #extras.audit(ledger, omarchy, remaps)))

-- --- ledger probes -----------------------------------------------------------
local drop_row = copy_rows(ledger.rows)
table.remove(drop_row, assert(index_of(drop_row, function(row) return row.status == "selected" end)))
print("probe_drop_row=" .. #with_ledger(drop_row, function() return ledger.audit(snapshot) end))

local drift = copy_rows(ledger.rows)
local drift_i = assert(index_of(drift, function(row) return row.key == "SUPER + h" end))
drift[drift_i].key = "SUPER + H"
print("probe_key_spelling=" .. #with_ledger(drift, function() return ledger.audit(snapshot) end))

local no_reason = copy_rows(ledger.rows)
local no_reason_i = assert(index_of(no_reason, function(row) return row.status == "excluded" end))
no_reason[no_reason_i].reason = ""
print("probe_missing_reason=" .. #with_ledger(no_reason, function() return ledger.audit(snapshot) end))

local no_bind = copy_rows(ledger.rows)
local no_bind_i = assert(index_of(no_bind, function(row) return row.status == "selected" end))
no_bind[no_bind_i].cmd = nil
no_bind[no_bind_i].dsp = nil
print("probe_selected_without_binding=" .. #with_ledger(no_bind, function() return ledger.audit(snapshot) end))

local bad_status = copy_rows(ledger.rows)
local bad_status_i = assert(index_of(bad_status, function(row) return row.status == "selected" end))
bad_status[bad_status_i].status = "maybe"
print("probe_unknown_status=" .. #with_ledger(bad_status, function() return ledger.audit(snapshot) end))

-- An equivalent row has to say which Omarchy implementation it reuses, so the
-- reason requirement covers more than the deviations.
local eq_no_reason = copy_rows(ledger.rows)
local eq_i = assert(index_of(eq_no_reason, function(row) return row.kind == "equivalent" end))
eq_no_reason[eq_i].reason = ""
print("probe_equivalent_without_reason=" .. #with_ledger(eq_no_reason, function() return ledger.audit(snapshot) end))

-- --- remap probes ------------------------------------------------------------
local taken = copy_rows(remaps.rows)
local taken_i = assert(index_of(taken, function(row) return row.kind == "moved" end))
taken[taken_i].to = "SUPER + F"
print("probe_remap_target_taken=" .. #with_remaps(taken, function() return remaps.audit(ledger, omarchy) end))

local dusky_key = copy_rows(remaps.rows)
local dusky_key_i = assert(index_of(dusky_key, function(row) return row.kind == "moved" end))
dusky_key[dusky_key_i].to = "SUPER + Z"
print("probe_remap_target_on_dusky_key=" .. #with_remaps(dusky_key, function() return remaps.audit(ledger, omarchy) end))

local deleted = copy_rows(remaps.rows)
table.remove(deleted, 1)
print("probe_remap_row_deleted=" .. #with_remaps(deleted, function() return remaps.audit(ledger, omarchy) end))

local duplicated = copy_rows(remaps.rows)
duplicated[#duplicated].to = duplicated[1].to
print("probe_remap_duplicate_target=" .. #with_remaps(duplicated, function() return remaps.audit(ledger, omarchy) end))
LUA

  run_capture lua "$tables_harness" "$REPO_DIR"
  assert_ran_ok "the table audit runs"
  read_count() { printf '%s\n' "$last_output" | sed -n "s/^$1=//p"; }

  assert_eq "$(read_count rows)" "167" "the ledger has a row for every key Dusky binds"
  assert_eq "$(read_count excluded)" "124" "and the rest are excluded"
  assert_eq "$(read_count remaps)" "13" "every displaced Omarchy action has a landing place"
  assert_eq "$(read_count extras)" "1" "the port's own binding is counted apart from Dusky's"
  assert_eq "$(read_count owned)" "50" "the port owns the selected keys, where remaps landed, and its own extra"
  assert_eq "$(read_count baseline)" "0" "the tables agree with both pinned snapshots"

  selected_n="$(read_count selected)"
  kind_total=$(($(read_count kind_ported) + $(read_count kind_equivalent) + $(read_count kind_deviation)))
  assert_eq "$kind_total" "$selected_n" "every selected key has one of the three kinds"
  if ((selected_n > 0 && selected_n < 167)); then
    pass "the selection is curated, not everything ($selected_n of 167)"
  else
    fail "the selected set is $selected_n of 167" "a curated port should be a real subset"
  fi

  for probe in drop_row key_spelling missing_reason equivalent_without_reason selected_without_binding \
    unknown_status remap_target_taken remap_target_on_dusky_key remap_row_deleted remap_duplicate_target; do
    count="$(read_count "probe_$probe")"
    if [[ "$count" =~ ^[0-9]+$ ]] && ((count > 0)); then
      pass "the audit catches $probe"
    else
      fail "the audit does not catch $probe" "identity: ${count:-no output}"
    fi
  done
else
  printf '  skip  lua not installed, the tables were not audited\n'
fi

# --- the mode tables, run for real -----------------------------------------
if command -v lua > /dev/null 2>&1; then
  harness="$TEST_TMP/keys.lua"
  cat > "$harness" << 'LUA'
-- Record what each mode binds and clears, by standing in for Hyprland's API, and
-- check the result against the tables the mode was built from.
local dir, mode = ...
package.path = dir .. "/keys/?.lua;" .. package.path

local bound, cleared = {}, {}

-- Anything Hyprland's API offers that we do not model: callable and indexable to
-- any depth, so `hl.dsp.window.resize(...)` works without this stub having to
-- know the API. bind and unbind are recorded, which is what is under test.
local function any()
  return setmetatable({}, {
    __call = function() return any() end,
    __index = function() return any() end,
  })
end

o = {
  bind = function(key, description) bound[#bound + 1] = { key = key, description = description or "" } end,
  bind_toggle = function(key, description) bound[#bound + 1] = { key = key, description = description or "" } end,
}
hl = { unbind = function(key) cleared[#cleared + 1] = key end, dispatch = any(), timer = any(), dsp = any() }

local module = require("chomsky_keys")
module.apply(mode, dir)

local ledger = require("dusky-ledger")
local remaps = require("remaps")
local omarchy = require("omarchy-shipped")
local extras = require("extras")
local keysym = require("keysym")

print("MODE " .. mode)
for _, binding in ipairs(bound) do print("BOUND\t" .. binding.key .. "\t" .. binding.description) end
for _, key in ipairs(cleared) do print("CLEARED\t" .. key) end

local owned = module.keys()
local bound_set, cleared_set = {}, {}
for _, binding in ipairs(bound) do bound_set[keysym.normalise(binding.key)] = binding end
for _, key in ipairs(cleared) do cleared_set[keysym.normalise(key)] = true end

local problems = {}
local function problem(text) problems[#problems + 1] = text end

for _, key in ipairs(owned) do
  if not cleared_set[keysym.normalise(key)] then problem("owned key never cleared: " .. key) end
end
for normalised, binding in pairs(bound_set) do
  if not cleared_set[normalised] then problem("bound without being cleared: " .. binding.key) end
end

if mode == "dusky" then
  for _, row in ipairs(ledger.selected()) do
    local binding = bound_set[keysym.normalise(row.key)]
    if not binding then
      problem("selected key not bound: " .. row.key)
    elseif binding.description ~= "Dusky: " .. (row.dusky or row.key) then
      problem("selected key bound as " .. binding.description .. ": " .. row.key)
    end
  end
  for _, remap in ipairs(remaps.rows) do
    if remap.kind == "moved" and not bound_set[keysym.normalise(remap.to)] then
      problem("remap not bound: " .. remap.to)
    end
  end
  for _, row in ipairs(ledger.rows) do
    if row.status == "excluded" and bound_set[keysym.normalise(row.key)] then
      problem("excluded key bound: " .. row.key)
    end
  end
  for _, row in ipairs(extras.rows) do
    local binding = bound_set[keysym.normalise(row.key)]
    if not binding then
      problem("extra not bound: " .. row.key)
    elseif binding.description ~= "Dusky: " .. row.description then
      problem("extra bound as " .. binding.description .. ": " .. row.key)
    end
  end
else
  for normalised, binding in pairs(bound_set) do
    if binding.description:find("^Dusky: ") then
      problem("a Dusky binding survived into omarchy mode: " .. binding.key)
    end
  end
  for _, remap in ipairs(remaps.rows) do
    if remap.kind == "moved" and bound_set[keysym.normalise(remap.to)] then
      problem("a remap survived into omarchy mode: " .. remap.to)
    end
  end
  for _, row in ipairs(extras.rows) do
    if bound_set[keysym.normalise(row.key)] then
      problem("an extra survived into omarchy mode: " .. row.key)
    end
  end
  for _, key in ipairs(owned) do
    if omarchy.occupied(key) and not bound_set[keysym.normalise(key)] then
      problem("Omarchy binding not restored: " .. key)
    end
  end
end

local distinct_bound, distinct_cleared = 0, 0
for _ in pairs(bound_set) do distinct_bound = distinct_bound + 1 end
for _ in pairs(cleared_set) do distinct_cleared = distinct_cleared + 1 end

print(string.format("VERDICT\t%d\t%d\t%d\t%d", #problems, distinct_bound, distinct_cleared, #owned))
for _, text in ipairs(problems) do print("PROBLEM\t" .. text) end
LUA
  for mode in dusky omarchy; do
    if ! out="$(lua "$harness" "$REPO_DIR" "$mode" 2>&1)"; then
      fail "the keybinding module runs for $mode mode" "$out"
      continue
    fi
    printf '%s\n' "$out" > "$TEST_TMP/keys.$mode.out"
    printf '%s\n' "$out" | awk -F'\t' '$1 == "BOUND" { print $2 }' | sort -u > "$TEST_TMP/keys.$mode.bound"
    printf '%s\n' "$out" | awk -F'\t' '$1 == "CLEARED" { print $2 }' | sort -u > "$TEST_TMP/keys.$mode.cleared"

    verdict="$(printf '%s\n' "$out" | awk -F'\t' '$1 == "VERDICT" { print $2, $3, $4, $5 }')"
    read -r problems bound_n cleared_n owned_n <<< "$verdict"
    if [[ "${problems:-}" == "0" ]]; then
      pass "$mode mode matches the tables ($bound_n bound, $cleared_n cleared, $owned_n owned)"
    else
      fail "$mode mode does not match the tables" \
        "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "PROBLEM" { print $2 }' | head -4 | tr '\n' ' ')"
    fi
    assert_eq "$cleared_n" "$owned_n" "$mode mode clears the whole owned set"
  done

  if [[ ! -s "$TEST_TMP/keys.dusky.cleared" || ! -s "$TEST_TMP/keys.omarchy.cleared" ]]; then
    fail "both modes clear exactly the same set of keys" "the mode tables did not run, so there is nothing to compare"
  elif diff -q "$TEST_TMP/keys.dusky.cleared" "$TEST_TMP/keys.omarchy.cleared" > /dev/null 2>&1; then
    pass "both modes clear exactly the same set of keys ($(wc -l < "$TEST_TMP/keys.dusky.cleared") keys)"
  else
    fail "the two modes clear different sets" \
      "only in dusky: $(comm -23 "$TEST_TMP/keys.dusky.cleared" "$TEST_TMP/keys.omarchy.cleared" | tr '\n' ' ')"
  fi

  # Every key dusky mode binds, it must have cleared first: the old failure mode
  # was a binding surviving the switch back.
  leaked="$(comm -23 "$TEST_TMP/keys.dusky.bound" "$TEST_TMP/keys.dusky.cleared" | tr '\n' ',')"
  if [[ -z "${leaked//,/}" ]]; then
    pass "nothing is bound that was not cleared first"
  else
    fail "keys bound without being cleared survive a switch to the other mode" "$leaked"
  fi

  # And the two modes disagree by design: dusky binds Dusky's set, omarchy mode
  # restores Omarchy's, so the counts differ in a way the tables predict.
  if [[ "$(wc -l < "$TEST_TMP/keys.omarchy.bound")" -lt "$(wc -l < "$TEST_TMP/keys.dusky.bound")" ]]; then
    pass "omarchy mode binds fewer keys, because free keys are left alone"
  else
    fail "omarchy mode binds at least as many keys as dusky mode" "the modes may be sharing a table"
  fi
else
  printf '  skip  lua not installed, the mode tables were not executed\n'
fi

# --- the keys verb lists what the switch touches ----------------------------
if command -v lua > /dev/null 2>&1; then
  run_capture chomsky chomsky-keys keys
  assert_ran_ok "chomsky-keys keys runs"
  listed="$(printf '%s\n' "$last_output" | grep -c .)"
  assert_eq "$listed" "50" "it lists the whole owned set"
  assert_output_contains "SUPER + h" "including Dusky's vim focus key"
  assert_output_contains "SUPER + CTRL + ALT + S" "including a key an Omarchy action moved onto"
  assert_output_contains "SUPER + SHIFT + ESCAPE" "including this port's own click-to-kill, which Dusky has no key for"
else
  printf '  skip  lua not installed, the key list was not checked\n'
fi

# --- the live audit, against a fixture keymap -------------------------------
# `check` reads the live keymap, so the keymap is served from a fixture and the
# audit is made to pass on a matching one and fail on a broken one. Both
# directions matter: a check that only ever passes is decoration.
if command -v lua > /dev/null 2>&1 && command -v jq > /dev/null 2>&1; then
  fixture_harness="$TEST_TMP/fixture.lua"
  cat > "$fixture_harness" << 'LUA'
-- Print the live keymap a mode should produce, as TSV for jq to shape into
-- hyprctl's JSON. `mutation` breaks one thing on purpose.
local repo, mode, mutation = ...
package.path = repo .. "/keys/?.lua;" .. package.path

local audit = require("audit")
local ledger = require("dusky-ledger")
local remaps = require("remaps")
local omarchy = require("omarchy-shipped")
local keysym = require("keysym")

local BITS = { { "SUPER", 64 }, { "CTRL", 4 }, { "ALT", 8 }, { "SHIFT", 1 } }

local function split_key(key)
  local modmask, name = 0, ""
  for part in key:gmatch("[^+]+") do
    local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
    local isModifier = false
    for _, bit in ipairs(BITS) do
      if trimmed:upper() == bit[1] then
        modmask = modmask + bit[2]
        isModifier = true
      end
    end
    if not isModifier then name = trimmed end
  end
  return modmask, name
end

local rows = {}
if mode == "dusky" then
  for _, want in pairs(audit.expected("dusky")) do
    -- `repeat` is a Lua keyword, so the field cannot be called that.
    rows[#rows + 1] = { key = want.key, description = want.description, repeat_flag = want.repeating }
  end
  if mutation == "omarchy-action-on-selected-key" then
    for _, row in ipairs(rows) do
      if keysym.normalise(row.key) == keysym.normalise("SUPER + M") then
        row.description = "Universal copy"
      end
    end
  end
else
  for _, key in ipairs(remaps.owned(ledger)) do
    for _, binding in ipairs(omarchy.for_key(key)) do
      rows[#rows + 1] = { key = binding.key, description = binding.description, repeat_flag = false }
    end
  end
end

for _, row in ipairs(rows) do
  local modmask, name = split_key(row.key)
  print(table.concat({ modmask, name, row.description, row.repeat_flag and "true" or "false" }, "\t"))
end
LUA

  keymap_from_fixture() { # mode [mutation]
    lua "$fixture_harness" "$REPO_DIR" "$1" "${2:-}" |
      jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {modmask: (.[0]|tonumber), key: .[1], description: .[2], repeat: (.[3] == "true")})' \
        > "$SHIM_STATE/binds.json"
  }

  run_capture chomsky chomsky-keys dusky
  keymap_from_fixture dusky
  run_capture chomsky chomsky-keys check
  assert_ran_ok "check passes on a keymap that matches dusky mode"
  assert_output_contains "mode: dusky" "it reports the mode it audited"
  assert_output_contains "problems: 0" "with no problems"

  # The original failure mode: dusky mode selected, an Omarchy action still live.
  keymap_from_fixture dusky omarchy-action-on-selected-key
  run_capture chomsky chomsky-keys check
  assert_failed "check fails when an Omarchy action is live on a selected key"
  assert_output_contains "SUPER + M" "and names the key"
  assert_output_contains "Omarchy default" "and attributes it to Omarchy"

  # Switching back: Omarchy's own bindings, and nothing of ours.
  run_capture chomsky chomsky-keys omarchy
  keymap_from_fixture omarchy
  run_capture chomsky chomsky-keys check
  assert_ran_ok "check passes on a keymap that matches omarchy mode"

  keymap_from_fixture dusky
  run_capture chomsky chomsky-keys check
  assert_failed "check fails when Dusky bindings survive into omarchy mode"
  assert_output_contains "survived into omarchy mode" "and says which way it is wrong"

  rm -f "$SHIM_STATE/binds.json"
  run_capture chomsky chomsky-keys check
  assert_failed "check fails when the live keymap has none of these bindings"
else
  printf '  skip  lua or jq missing, the live audit was not exercised\n'
fi

# --- what the panel reads ---------------------------------------------------
chomsky chomsky-keys reset > /dev/null 2>&1
assert_eq "$(chomsky chomsky-keys current)" "omarchy" "reset returns to Omarchy's own bindings"
run_capture chomsky chomsky status
assert_eq "$(printf '%s' "$last_output" | jq -r .keybindings)" "omarchy" "status reports the mode the toggle file describes"

finish_test
