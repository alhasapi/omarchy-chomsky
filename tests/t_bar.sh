#!/bin/bash
# Group 2: the bar chip's on/off switch.
#
# This is the one script that rewrites Omarchy's own shell.json, so the tests
# are mostly about what it must *not* do: lose the user's other bar entries,
# lose a widget's own settings, or replace a file it could not parse.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

shell_json="$FAKE_HOME/.config/omarchy/shell.json"

in_layout() { jq -r '[.bar.layout[] | .[] | if type == "object" then .id else . end] | index("alhasapi.chomsky") != null' "$shell_json"; }
in_plugins() { jq -r '[.plugins[] | if type == "object" then .id else . end] | index("alhasapi.chomsky") != null' "$shell_json"; }
others() { jq -c '[.bar.layout[] | .[] | if type == "object" then .id else . end] | map(select(. != "alhasapi.chomsky")) | sort' "$shell_json"; }

run_capture chomsky chomsky-bar status
assert_ran_ok "chomsky-bar status runs"
assert_eq "$last_output" "off" "with the chip in plugins[] the state is off"
before_others="$(others)"

run_capture chomsky chomsky-bar on
assert_ran_ok "chomsky-bar on puts the chip back on the bar"
assert_eq "$(in_layout)" "true" "the entry is in a bar section"
assert_eq "$(in_plugins)" "false" "and no longer in plugins[]"
assert_eq "$(others)" "$before_others" "every other bar entry is left where it was"
assert_eq "$(chomsky chomsky-bar status)" "on" "status reports on"
if compgen -G "$shell_json.bak.*" > /dev/null; then
  pass "a timestamped backup was kept beside shell.json"
else
  fail "no backup was left beside shell.json"
fi

# The chip can carry settings of its own; moving it must not drop them.
jq '.bar.layout.right = (.bar.layout.right | map(if (type == "object" and .id == "alhasapi.chomsky") then . + {settings: {menuRows: false}} else . end))' \
  "$shell_json" > "$shell_json.tmp" && mv "$shell_json.tmp" "$shell_json"
chomsky chomsky-bar off > /dev/null
if jq -e '.plugins[] | select((type == "object") and (.id == "alhasapi.chomsky") and (.settings.menuRows == false))' "$shell_json" > /dev/null; then
  pass "the widget's own settings survive being moved off the bar"
else
  fail "the widget's own settings were dropped moving it off the bar" "$(jq -c .plugins "$shell_json")"
fi

run_capture chomsky chomsky-bar toggle
assert_ran_ok "chomsky-bar toggle flips it"
assert_eq "$(chomsky chomsky-bar status)" "on" "toggle from off lands on"
run_capture chomsky chomsky-bar toggle
assert_eq "$(chomsky chomsky-bar status)" "off" "toggle from on lands off"

# Doing nothing must not rewrite the file.
sum_before="$(sha256sum "$shell_json" | cut -d' ' -f1)"
run_capture chomsky chomsky-bar off
assert_ran_ok "asking for the state it is already in is not an error"
assert_contains "$last_output" "already" "and says so"
assert_eq "$(sha256sum "$shell_json" | cut -d' ' -f1)" "$sum_before" "and leaves shell.json untouched"

# --- refusing to break the user's config ------------------------------------
printf '{ this is not json\n' > "$shell_json"
broken_sum="$(sha256sum "$shell_json" | cut -d' ' -f1)"
run_capture chomsky chomsky-bar on
assert_failed "an unparseable shell.json is refused rather than replaced"
assert_eq "$(sha256sum "$shell_json" | cut -d' ' -f1)" "$broken_sum" "and the broken file is left exactly as it was"

jq -n '{version: 1, plugins: []}' > "$shell_json"
no_bar_sum="$(sha256sum "$shell_json" | cut -d' ' -f1)"
run_capture chomsky chomsky-bar on
assert_failed "a shell.json with no bar layout is refused"
assert_eq "$(sha256sum "$shell_json" | cut -d' ' -f1)" "$no_bar_sum" "and that file is left as it was"

# --- what the panel's JSON reports ------------------------------------------
write_shell_json on
run_capture chomsky chomsky status
assert_eq "$(printf '%s' "$last_output" | jq -r .barChip)" "on" "status reports on when the entry is on the bar"
write_shell_json off
run_capture chomsky chomsky status
assert_eq "$(printf '%s' "$last_output" | jq -r .barChip)" "off" "and off when it is in plugins[]"

finish_test
