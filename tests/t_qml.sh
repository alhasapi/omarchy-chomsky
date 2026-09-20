#!/bin/bash
# Group 14: the panel, rendered by a real compositor.
#
# Opt in with `tests/run.sh --with-qml`. It is not in the default run because it
# needs a Wayland session: Panel.qml creates a layer surface, and the card takes
# its width and height from that surface, so there is nothing to measure without
# a compositor. It opens the panel on the focused monitor for about a second and
# then closes it -- if you are typing when it runs, don't be.
#
# Everything else matches the rest of the suite: a throwaway HOME, a stub
# service instead of Service.qml (so no CLI and no state file is touched), and
# the real theme from qs.Commons, which is why the checks are relative to what
# the panel reports rather than to remembered pixel values.
# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

if ! command -v quickshell > /dev/null 2>&1; then
  printf '  skip  quickshell is not installed\n'
  finish_test
fi
if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
  printf '  skip  no Wayland session to render in (the panel is a layer surface)\n'
  finish_test
fi

# --- a place for the harness to run from ---------------------------------
# `qs.Commons` and `qs.Ui` resolve against the config directory -- the directory
# holding shell.qml -- so the harness needs Omarchy's modules beside it. Copied
# rather than symlinked, so that QML resolves imports against this directory
# instead of following the link back into the repository.
harness_dir="$TEST_TMP/harness"
mkdir -p "$harness_dir"
install -m 644 "$REPO_DIR/tests/qml/shell.qml" "$harness_dir/shell.qml"
omarchy_shell="/usr/share/omarchy/shell"
for module in Commons Ui services; do
  if [[ -e "$omarchy_shell/$module" ]]; then
    ln -s "$omarchy_shell/$module" "$harness_dir/$module"
  fi
done
assert_exists "$harness_dir/Commons" "Omarchy's Commons module is where the panel expects it"
assert_file "$harness_dir/shell.qml" "the harness was copied somewhere it can import from"

# --- reading the harness ------------------------------------------------
harness_clean=""

report_line() { # $1 = marker -> the report line containing it
  printf '%s\n' "$harness_clean" | grep -m1 -- "$1" || true
}
field_value() { # $1 = report line, $2 = key
  printf '%s\n' "$1" |
    awk -v k="$2=" '{ for (i = 1; i <= NF; i++) if (index($i, k) == 1) { print substr($i, length(k) + 1); exit } }'
}
# A range line prints `x=A..B`; split it into its two numbers.
range_start() { printf '%s\n' "$1" | sed -n 's/.*[^A-Za-z]x=\(-\{0,1\}[0-9]*\)\.\..*/\1/p'; }
range_end() { printf '%s\n' "$1" | sed -n 's/.*[^A-Za-z]x=\(-\{0,1\}[0-9]*\)\.\.\(-\{0,1\}[0-9]*\).*/\2/p'; }
has() { printf '%s\n' "$harness_clean" | grep -q -- "$1"; }

status=0
run_harness() { # $1 = chip on|off, $2 = animations json, $3 = shaders json
  local chip="$1"
  local log="$TEST_TMP/qml-$chip.log"
  CHOMSKY_TEST_PANEL="$REPO_DIR/Panel.qml" \
    CHOMSKY_TEST_BARCHIP="$chip" \
    CHOMSKY_TEST_ANIMATIONS="$2" \
    CHOMSKY_TEST_SHADERS="$3" \
    timeout 40 quickshell -p "$harness_dir" > "$log" 2>&1
  status=$?
  harness_clean="$(sed 's/\x1b\[[0-9;]*m//g' "$log")"
}

# The real preset names, so the panel lays out its longest strings rather than
# something short and comfortable.
list_json() { # $1 = anim|shader
  run_capture "$BIN_DIR/chomsky-$1" list
  if ((last_status == 0)) && [[ -n "$last_output" ]]; then
    printf '%s\n' "$last_output" | jq -Rsc 'split("\n") | map(select(length > 0))'
  else
    printf '[]'
  fi
}
animations="$(list_json anim)"
shaders="$(list_json shader)"

# --- everything that can be said about one run --------------------------
check_report() { # $1 = which run ("chip off" / "chip on")
  local which="$1"
  if ((status != 0)) || ! has "REPORT-END"; then
    fail "the harness rendered the panel ($which)" \
      "quickshell exited $status: $(printf '%s\n' "$harness_clean" | grep -viE 'portal|^\s*$' | tail -3 | tr '\n' ' ')"
    return
  fi
  pass "the harness rendered the panel and reported ($which)"

  # A binding error inside the panel is invisible in a screenshot and is exactly
  # what a harness should surface.
  local pattern
  for pattern in TypeError "is not a function" "Unable to assign"; do
    assert_not_contains "$harness_clean" "$pattern" "no QML runtime error: $pattern ($which)"
  done

  # The stub must be the only service in play: a real helperPath means the panel
  # ran the real CLIs.
  assert_contains "$harness_clean" "HARNESS helperPath=[] calls=" \
    "the panel used the stub service, not the real one ($which)"

  local geom card content textbox cardbox
  geom="$(report_line GEOM)"
  card="$(report_line CARD)"
  content="$(report_line CONTENT)"
  textbox="$(report_line TEXTBOX)"
  cardbox="$(report_line CARDBOX)"
  assert_contains "$card" "CARD insets" "the card was found ($which)"
  if [[ -z "$card" || -z "$content" || -z "$textbox" || -z "$cardbox" ]]; then
    fail "the harness reported its geometry ($which)" "one of GEOM/CARD/CONTENT/TEXTBOX/CARDBOX was missing: $harness_clean"
    return
  fi

  # Padding: real space on all four sides, not a flush border.
  local t b l r
  t="$(field_value "$card" T)"
  b="$(field_value "$card" B)"
  l="$(field_value "$card" L)"
  r="$(field_value "$card" R)"
  if [[ -n "$t" && -n "$b" && -n "$l" && -n "$r" ]] &&
    ((t > 0)) && ((b > 0)) && ((l > 0)) && ((r > 0)); then
    pass "the card has real padding on all four sides ($t/$b/$l/$r) ($which)"
  else
    fail "the card has real padding on all four sides" "insets T=$t B=$b L=$l R=$r ($which)"
  fi

  # Height: as tall as its content and no taller. Shorter means the last row is
  # clipped -- the bug this check exists for -- and taller makes the card look
  # like a form rather than a menu.
  local needed card_h slack
  needed="$(field_value "$geom" needed)"
  card_h="$(field_value "$geom" cardH)"
  slack="$(field_value "$content" slack)"
  assert_eq "$card_h" "$needed" "the card is exactly as tall as its content ($which)"
  if [[ -n "$slack" ]] && ((slack >= 0)) && ((slack <= 2)); then
    pass "the content ends inside the card, with ${slack}px to spare ($which)"
  else
    fail "the content ends inside the card" \
      "content bottom=$(field_value "$content" bottom), card inner bottom=$(field_value "$content" cardInnerBottom), slack=$slack ($which)"
  fi

  # Width: the small card. If Style.space(340) ever exceeds the screen this
  # catches the clamp as well.
  local card_w space340 window_h gaps
  card_w="$(field_value "$geom" cardW)"
  space340="$(field_value "$geom" space340)"
  window_h="$(field_value "$geom" windowH)"
  gaps="$(field_value "$geom" gapsOut)"
  assert_eq "$card_w" "$space340" "the card is Style.space(340) wide, and fits the screen ($which)"
  if [[ -n "$window_h" && -n "$gaps" ]] && ((window_h - gaps * 2 >= needed)); then
    pass "the screen is tall enough for the whole card, so nothing scrolls ($which)"
  else
    fail "the screen is tall enough for the whole card" "panelH=$window_h needed=$needed ($which)"
  fi

  # Text: nothing elided, and nothing laid out past the card's own edges.
  local truncated_n
  truncated_n="$(printf '%s\n' "$harness_clean" | awk '/TRUNCATED-COUNT/ { print $NF; exit }')"
  assert_eq "$truncated_n" "0" "no text is truncated ($which)"
  local n
  n="$(field_value "$textbox" n)"
  if [[ -n "$n" ]] && ((n >= 10)); then
    pass "the text walker found $n pieces of text ($which)"
  else
    fail "the text walker found text" \
      "n=$n -- a walker that finds nothing would pass every check about text ($which)"
  fi
  local tx tr cx cw
  tx="$(range_start "$textbox")"
  tr="$(range_end "$textbox")"
  cx="$(range_start "$cardbox")"
  cw="$(range_end "$cardbox")"
  if [[ -n "$tx" && -n "$tr" && -n "$cx" && -n "$cw" ]] &&
    ((tx >= cx - 1)) && ((tr <= cw + 1)); then
    pass "all text is inside the card's width ($tx..$tr within $cx..$cw) ($which)"
  else
    fail "all text is inside the card's width" "text $tx..$tr, card $cx..$cw ($which)"
  fi

  # The cursor: every index the panel claims lights exactly one control, and the
  # chip switch is the first of them. A stale index after removing a row is
  # exactly what this looks like from outside.
  local count controls strays
  count="$(field_value "$(report_line CURSORS)" count)"
  controls="$(field_value "$(report_line CURSORS)" controls)"
  strays="$(printf '%s\n' "$harness_clean" | awk '/CURSOR-STRAYS/ { print $NF; exit }')"
  # Not an equality: a couple of Omarchy's reusable pieces carry a hasCursor
  # property of their own. What has to hold is that every index lights exactly
  # one control, which the strays check below covers.
  if [[ -n "$controls" && -n "$count" ]] && ((controls >= count)); then
    pass "the panel reports $controls cursor-capable controls for $count indexes ($which)"
  else
    fail "the panel has a control for every cursor index" "controls=$controls count=$count ($which)"
  fi
  assert_eq "$strays" "none" "no cursor index is a dead stop ($which)"
  assert_contains "$harness_clean" "SWITCH found" "the chip switch is in the card ($which)"
  assert_contains "$harness_clean" "isFirstStop=true" "the chip switch is the first keyboard stop ($which)"
}

run_harness off "$animations" "$shaders"
check_report "chip off"
assert_contains "$harness_clean" "SWITCH found checked=false" "the switch reads off when the chip is off"

run_harness on "$animations" "$shaders"
check_report "chip on"
assert_contains "$harness_clean" "SWITCH found checked=true" "and on when it is on"

finish_test
