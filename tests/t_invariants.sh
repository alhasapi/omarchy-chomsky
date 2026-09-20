#!/bin/bash
# Group 1: invariants that must hold across files.
#
# These are the cheap checks with the best track record here -- an unexecutable
# script, a menu row pointing at a script that no longer exists, a watched state
# file whose name changed. Each of those fails silently at runtime and looks
# like "the feature just doesn't work".

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test

# The verbs a script dispatches on, from its first `case "..."` block onwards.
script_verbs() { # $1 = script
  # Only the outermost case block: bin/chomsky and chomsky-menu-entry nest a
  # second one, whose labels are not subcommands of the script. Labels may be
  # written `a|b)` or `a | b)`, depending on the formatter.
  awk '/^[[:space:]]*case "/{depth++; if (depth == 1) inside = 1; next}
       /^[[:space:]]*esac/{if (depth > 0) depth--; if (depth == 0) inside = 0; next}
       inside && depth == 1' "$1" |
    grep -oE '^[[:space:]]*[A-Za-z0-9_.*|-]+([[:space:]]*\|[[:space:]]*[A-Za-z0-9_.*|-]+)*\)' |
    sed 's/^[[:space:]]*//; s/)$//' | tr '|' '\n' | tr -d ' ' | grep -vE '^$|^\*' | sort -u
}

# --- every script is executable, with a shebang -----------------------------
missing_exec=()
missing_shebang=()
for f in "$BIN_DIR"/*; do
  [[ -x "$f" ]] || missing_exec+=("$(basename "$f")")
  head -n1 "$f" | grep -q '^#!' || missing_shebang+=("$(basename "$f")")
done
if ((${#missing_exec[@]} == 0)); then
  pass "every bin/ script is executable"
else
  fail "some bin/ scripts are not executable" \
    "${missing_exec[*]} -- the menu rows and QML run these directly, so a missing +x breaks them at runtime"
fi
if ((${#missing_shebang[@]} == 0)); then
  pass "every bin/ script has a shebang"
else
  fail "some bin/ scripts have no shebang" "${missing_shebang[*]}"
fi

# The same rule for the suite itself: these are run, not sourced, and a missing
# bit here fails the way a missing bit on bin/chomsky-bar did.
not_exec=()
for f in "$REPO_DIR"/tests/run.sh "$REPO_DIR"/tests/t_*.sh "$REPO_DIR"/tests/lib/shims/*; do
  [[ -x "$f" ]] || not_exec+=("$(basename "$f")")
done
if ((${#not_exec[@]} == 0)); then
  pass "every test script and shim is executable"
else
  fail "a test script or shim is not executable" "${not_exec[*]}"
fi

# --- nothing bakes in a developer's home ------------------------------------
baked="$(grep -rl --exclude-dir=.git -E '/home/[a-z]+/' "$REPO_DIR/bin" "$REPO_DIR/tests" \
  "$REPO_DIR"/*.qml "$REPO_DIR/keys" "$REPO_DIR/animations" "$REPO_DIR/manifest.json" 2> /dev/null || true)"
if [[ -z "$baked" ]]; then
  pass "no absolute home paths in the sources"
else
  fail "an absolute home path is baked into a source file" "$(printf '%s ' "$baked")"
fi

# --- manifest ---------------------------------------------------------------
manifest="$REPO_DIR/manifest.json"
if jq -e . "$manifest" > /dev/null 2>&1; then
  pass "manifest.json is valid JSON"
else
  fail "manifest.json is valid JSON" "$(jq . "$manifest" 2>&1 | head -2 | tr '\n' ' ')"
fi

assert_eq "$(jq -r '.id' "$manifest")" "alhasapi.chomsky" "manifest id is the plugin id"
for kind in bar-widget service panel; do
  if jq -e --arg k "$kind" '.kinds | index($k)' "$manifest" > /dev/null; then
    pass "manifest declares the $kind kind"
  else
    fail "manifest declares the $kind kind" "kinds: $(jq -c .kinds "$manifest")"
  fi
done
for entry in $(jq -r '.entryPoints | to_entries[] | .value' "$manifest"); do
  assert_file "$REPO_DIR/$entry" "manifest entryPoint $entry exists"
done
assert_file "$REPO_DIR/icon.png" "icon.png exists (referenced by the panel and bar widget)"

# --- lua files compile ------------------------------------------------------
if command -v luac > /dev/null 2>&1; then
  bad_lua=()
  for f in "$REPO_DIR"/keys/*.lua "$REPO_DIR"/animations/*.lua; do
    luac -p "$f" 2> /dev/null || bad_lua+=("$(basename "$f")")
  done
  if ((${#bad_lua[@]} == 0)); then
    pass "every .lua file compiles (luac -p)"
  else
    fail "some .lua files do not compile" "${bad_lua[*]}"
  fi
else
  printf '  skip  luac not installed, Lua syntax unchecked\n'
fi

# --- shaders are present and non-empty --------------------------------------
empty_shaders=()
for f in "$REPO_DIR"/shaders/*.glsl; do
  [[ -s "$f" ]] || empty_shaders+=("$(basename "$f")")
done
if ((${#empty_shaders[@]} == 0)); then
  pass "every shader file is non-empty"
else
  fail "some shader files are empty" "${empty_shaders[*]}"
fi

# --- bin/chomsky's usage line matches what it dispatches --------------------
usage="$(grep -oE 'Usage: chomsky <[^>]*>' "$BIN_DIR/chomsky" | sed 's/.*<//;s/>//')"
usage_verbs="$(printf '%s' "$usage" | tr '|' '\n' | sort -u)"
dispatch_verbs="$(script_verbs "$BIN_DIR/chomsky")"
if diff <(printf '%s\n' "$usage_verbs") <(printf '%s\n' "$dispatch_verbs") > /dev/null; then
  pass "chomsky's usage line lists exactly the subcommands it handles"
else
  fail "chomsky's usage line and its dispatch disagree" \
    "in usage only: $(comm -23 <(printf '%s\n' "$usage_verbs") <(printf '%s\n' "$dispatch_verbs") | tr '\n' ' ') | dispatched only: $(comm -13 <(printf '%s\n' "$usage_verbs") <(printf '%s\n' "$dispatch_verbs") | tr '\n' ' ')"
fi

# --- the QML only calls subcommands that exist ------------------------------
# Where the target is known, the verb is checked against that script too: the
# dispatcher passing an argument through to a script that no longer accepts it
# is the same class of failure.
declare -A VERB_TARGET=(
  [anim]=chomsky-anim [shader]=chomsky-shader [window]=chomsky-window
  [keys]=chomsky-keys [bar]=chomsky-bar [wallpaper]=chomsky-wallpaper
  [rotate]=chomsky-monitor-rotate
)

# First element of each call is the dispatcher subcommand. Rebuild that list
# from the raw matches rather than from the flattened one above.
mapfile -t call_lines < <(grep -ohE 'runAction\(\[[^]]*\]|execDetached\(\["bash", root\.helperPath[^]]*\]' \
  "$REPO_DIR"/Service.qml "$REPO_DIR"/Panel.qml "$REPO_DIR"/BarWidget.qml 2> /dev/null | sort -u)

unknown_sub=()
for line in "${call_lines[@]}"; do
  mapfile -t tokens < <(printf '%s' "$line" | grep -oE '"[a-z-]+"' | tr -d '"')
  # execDetached(["bash", root.helperPath, "menu-install"]) -- the interpreter
  # comes first, and the helper path is not a literal.
  [[ "${tokens[0]:-}" == "bash" ]] && tokens=("${tokens[@]:1}")
  sub="${tokens[0]:-}"
  [[ -z "$sub" ]] && continue
  grep -qx "$sub" <<< "$dispatch_verbs" || unknown_sub+=("$sub")
done
if ((${#unknown_sub[@]} == 0)); then
  pass "every subcommand the QML calls exists in bin/chomsky"
else
  fail "the QML calls a subcommand bin/chomsky does not handle" "${unknown_sub[*]}"
fi

bad_verbs=()
for line in "${call_lines[@]}"; do
  mapfile -t parts < <(printf '%s' "$line" | grep -oE '"[a-z-]+"' | tr -d '"')
  [[ "${parts[0]:-}" == "bash" ]] && parts=("${parts[@]:1}")
  sub="${parts[0]:-}"
  verb="${parts[1]:-}"
  [[ -z "$sub" || -z "$verb" ]] && continue
  target="${VERB_TARGET[$sub]:-}"
  [[ -z "$target" ]] && continue
  script_verbs "$BIN_DIR/$target" | grep -qx "$verb" || bad_verbs+=("$sub $verb -> $target")
done
if ((${#bad_verbs[@]} == 0)); then
  pass "every literal verb the QML passes is handled by the script it reaches"
else
  fail "the QML passes a verb its target script does not handle" "${bad_verbs[*]}"
fi

# --- Service.qml watches files the scripts actually own ---------------------
# The panel refreshes by watching state files. If a script renames its file and
# the watch is not updated, the panel silently stops noticing changes -- which
# is how the shader came to display a state it did not have.
watched_states="$(grep -ohE 'stateDir \+ "/[a-z-]+"' "$REPO_DIR/Service.qml" | grep -oE '/[a-z-]+"$' | tr -d '/"' | sort -u)"
owned_states="$(grep -ohE 'STATE_DIR/[a-z-]+"' "$BIN_DIR"/* | grep -oE '/[a-z-]+"$' | tr -d '/"' | sort -u)"
missing_states="$(comm -23 <(printf '%s\n' "$watched_states") <(printf '%s\n' "$owned_states") | tr '\n' ' ')"
if [[ -z "${missing_states// /}" ]]; then
  pass "every state file Service.qml watches is one a script writes"
else
  fail "Service.qml watches a state file no script writes" "$missing_states"
fi

watched_toggles="$(grep -ohE 'chomsky-[a-z-]+\.lua' "$REPO_DIR/Service.qml" | sort -u)"
owned_toggles="$(grep -ohE 'chomsky-[a-z-]+\.lua' "$BIN_DIR"/* | sort -u)"
missing_toggles="$(comm -23 <(printf '%s\n' "$watched_toggles") <(printf '%s\n' "$owned_toggles") | tr '\n' ' ')"
if [[ -z "${missing_toggles// /}" ]]; then
  pass "every toggle file Service.qml watches is one a script writes"
else
  fail "Service.qml watches a toggle file no script writes" "$missing_toggles"
fi

# --- the menu rows only point at scripts that exist -------------------------
emit="$BIN_DIR/chomsky-menu-install"
# shellcheck disable=SC2016  # the pattern is the literal text $SCRIPT_DIR
referenced="$(grep -ohE '\$SCRIPT_DIR/chomsky-[a-z-]+' "$emit" | sed 's|\$SCRIPT_DIR/||' | sort -u)"
bad_refs=()
for name in $referenced; do
  [[ -x "$BIN_DIR/$name" ]] || bad_refs+=("$name")
done
if ((${#bad_refs[@]} == 0)); then
  pass "every script the menu rows reference exists and is executable ($(wc -w <<< "$referenced") of them)"
else
  fail "a menu row points at a script that is missing or not executable" "${bad_refs[*]}"
fi

# --- the helper dispatches every mode the rows use --------------------------
entry="$BIN_DIR/chomsky-menu-entry"
# Only the row *actions* are modes of the helper; the `checked` guards also use
# `%s <verb>` but name a verb of the script they quote, not of the helper.
modes_in_rows="$(grep -ohE '"action":"%s [a-z-]+"' "$emit" | grep -oE '[a-z-]+"$' | tr -d '"' | sort -u)"
entry_verbs="$(script_verbs "$entry")"
unhandled=()
for mode in $modes_in_rows; do
  grep -qx "$mode" <<< "$entry_verbs" || unhandled+=("$mode")
done
if ((${#unhandled[@]} == 0)); then
  pass "chomsky-menu-entry handles every row action the installer emits"
else
  fail "the installer emits a row action the helper does not handle" "${unhandled[*]}"
fi

finish_test
