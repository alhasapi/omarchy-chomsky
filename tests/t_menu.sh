#!/bin/bash
# Group 3: the Omarchy menu rows.
#
# The rows are one generated block inside a file the user also owns, written by
# a script that may run concurrently from several shell starts. The properties
# that matter are therefore: the user's own rows survive, installing twice is
# the same as installing once, a concurrent pair does not leave two blocks, the
# block is valid JSONC with commands that exist, and -- the one that actually
# bit -- a row with a missing escape is refused rather than written, because it
# would break the whole menu rather than just our part of it.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

ext="$FAKE_HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
helper="$FAKE_HOME/.config/omarchy/extensions/chomsky-menu-entry"

# A menu extension with the user's own rows around where ours will land.
cat > "$ext" << 'JSONC'
{
  // the user's own row
  "user.row": {"label": "Mine"},
  "user.other": {"label": "Also mine"}
}
JSONC

# `grep -c` already prints 0 when it finds nothing; `|| echo 0` added a second.
blocks() { grep -c '>>> chomsky-menu >>>' "$ext" 2> /dev/null || true; }
# Our rows are the `style.*` keys; the user's rows in the fixture are `user.*`.
rows_json() { grep -v '^[[:space:]]*//' "$ext" | jq -c '[to_entries[] | select(.key | startswith("style.")) | .value]'; }
# The generated block is plain JSON once the marker comments are dropped; if it
# is not, the shell cannot read the menu at all.
jsonc_valid() { grep -v '^[[:space:]]*//' "$ext" | jq -e . > /dev/null 2>&1; }

run_capture chomsky chomsky-menu-install --enable
assert_ran_ok "chomsky-menu-install --enable installs the rows"
assert_eq "$(blocks)" "1" "exactly one managed block is written"
if jsonc_valid; then
  pass "the menu file is still valid JSONC after installing"
else
  fail "the menu file no longer parses after installing" "$(grep -v '^[[:space:]]*//' "$ext" | jq . 2>&1 | head -2 | tr '\n' ' ')"
fi
assert_contains "$(cat "$ext")" '"user.row"' "the user's own rows are kept"
assert_file "$helper" "the row-action helper is copied into the extensions directory"
assert_exec "$helper" "and is executable"

# --- idempotent -------------------------------------------------------------
first_sum="$(sha256sum "$ext" | cut -d' ' -f1)"
run_capture chomsky chomsky-menu-install --enable
assert_ran_ok "installing again succeeds"
assert_eq "$(blocks)" "1" "and does not add a second block"
assert_eq "$(sha256sum "$ext" | cut -d' ' -f1)" "$first_sum" "and writes a byte-identical file"

# --- concurrent -------------------------------------------------------------
for _ in 1 2 3 4 5 6 7 8 9 10; do chomsky chomsky-menu-install --enable > /dev/null 2>&1 & done
wait
assert_eq "$(blocks)" "1" "ten concurrent installs still leave one block"
if jsonc_valid; then
  pass "and the file is valid afterwards"
else
  fail "the file was corrupted by concurrent installs"
fi

# --- the rows point at things that exist -------------------------------------
mapfile -t actions < <(rows_json | jq -r '.[] | .action // empty')
bad_cmds=()
for line in "${actions[@]}"; do
  cmd="${line%% *}"
  # A row may run a bare command from PATH (omarchy-shell) or a script by path.
  if [[ "$cmd" == /* ]]; then
    [[ -x "$cmd" ]] || bad_cmds+=("$cmd")
  else
    command -v "$cmd" > /dev/null 2>&1 || bad_cmds+=("$cmd")
  fi
done
if ((${#bad_cmds[@]} == 0)); then
  pass "every row action is a runnable command (${#actions[@]} actions)"
else
  fail "a row action is not runnable" "${bad_cmds[*]}"
fi

# The guards are shell commands the menu runs before showing a row; they must
# run without a syntax or command-not-found error (exit 0 or 1, never 126/127).
mapfile -t guards < <(rows_json | jq -r '.[] | (.checked // empty), (.when // empty)' | sort -u)
bad_guards=()
for guard in "${guards[@]}"; do
  [[ -z "$guard" ]] && continue
  bash -c "$guard" > /dev/null 2>&1
  rc=$?
  ((rc > 1)) && bad_guards+=("rc=$rc: $guard")
done
if ((${#bad_guards[@]} == 0)); then
  pass "every row guard runs (exit 0 or 1, no missing command or syntax error)"
else
  fail "a row guard fails to run at all" "${bad_guards[*]}"
fi

# --- removing ---------------------------------------------------------------
run_capture chomsky chomsky-menu-install --remove
assert_ran_ok "chomsky-menu-install --remove removes the rows"
assert_eq "$(blocks)" "0" "the managed block is gone"
assert_no_file "$helper" "the helper is removed with it"
assert_contains "$(cat "$ext")" '"user.other"' "the user's own rows are still there"
if jsonc_valid; then
  pass "and the file is valid after removal"
else
  fail "the file no longer parses after removal"
fi

# --- a row left behind after the plugin is deleted ---------------------------
chomsky chomsky-menu-install --enable > /dev/null
stale_home="$(mktemp -d "$TEST_TMP/stale.XXXXXX")"
: > "$SHIM_STATE/notify.log"
run_capture env HOME="$stale_home" OMARCHY_MENU_EXTENSION="$ext" PATH="$SHIM_DIR:$PATH" \
  SHIM_STATE="$SHIM_STATE" "$helper" animation
assert_ran_ok "clicking a row whose plugin is gone does not fail"
assert_eq "$(blocks)" "0" "the block it can no longer run is cleaned up"
if grep -q "Plugin is gone" "$SHIM_STATE/notify.log"; then
  pass "and the user is told why the rows disappeared"
else
  fail "nothing was said about the removed rows" "$(cat "$SHIM_STATE/notify.log")"
fi

# --- a block that would not parse is refused ---------------------------------
# The guard added after a missing escape shipped: the same mutation must now be
# caught here instead of in the user's menu.
mutant_dir="$(mktemp -d "$TEST_TMP/mutant.XXXXXX")"
cp "$BIN_DIR"/* "$mutant_dir/"
python3 - "$mutant_dir/chomsky-menu-install" << 'PY'
import sys
p = sys.argv[1]
s = open(p).read()
# One escape too few in a generated row: the file text `\\"` becomes `\"`,
# which is what shipped once and broke the whole menu file.
if '\\\\"' not in s:
    sys.exit("mutation pattern not found (has the emitter changed?)")
open(p, "w").write(s.replace('\\\\"', '\\"'))
PY
cat > "$ext" << 'JSONC'
{
  "user.row": {"label": "Mine"}
}
JSONC
sum_before="$(sha256sum "$ext" | cut -d' ' -f1)"
if ! grep -q '\\\\"' "$mutant_dir/chomsky-menu-install"; then
  pass "the mutation applied (the mutant emitter has one escape too few)"
else
  fail "the mutation did not apply" "the escaping guard was therefore not exercised"
fi
run_capture env HOME="$FAKE_HOME" OMARCHY_MENU_EXTENSION="$ext" PATH="$SHIM_DIR:$PATH" \
  SHIM_STATE="$SHIM_STATE" "$mutant_dir/chomsky-menu-install" --enable
assert_failed "an emitter that produces unparseable rows is refused"
assert_eq "$(sha256sum "$ext" | cut -d' ' -f1)" "$sum_before" "and the user's menu file is left untouched"
assert_eq "$(blocks)" "0" "with no half-written block left behind"

finish_test
