#!/bin/bash
# Group 2/3: wallpapers, and the picker.
#
# The picker has two ways in, and both are tested because the choice between
# them is the fix for the bug this branch started from: Omarchy's front-end
# hands the image grid its whole list base64-encoded in a single command-line
# argument, and the kernel caps one argument at 128 KiB, so with a large enough
# ~/Pictures it failed with `Argument list too long` and the picker never
# opened. Past that size the plugin drives the grid with the *directories*
# instead and lets it enumerate them.
#
# So: the front-end is used while the list fits, the directory route is used
# when it does not, a failure of either is reported rather than swallowed, and
# no path ever builds a payload anywhere near the kernel's limit.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test
setup_sandbox

theme_dir="$FAKE_HOME/.local/state/omarchy/current/theme/backgrounds"
pictures="$FAKE_HOME/Pictures"
for n in a b; do : > "$theme_dir/$n.jpg"; done
: > "$pictures/c.jpg"
: > "$theme_dir/not-an-image.txt"

bg_calls() { grep -c . "$SHIM_STATE/bg-set.log" 2> /dev/null || true; }
current() { chomsky chomsky-wallpaper current; }
frontend_calls() { grep -c . "$SHIM_STATE/frontend.calls" 2> /dev/null || true; }
shell_calls() { grep -c . "$SHIM_STATE/omarchy-shell.calls" 2> /dev/null || true; }

# --- listing and cycling ----------------------------------------------------
run_capture chomsky chomsky-wallpaper list
assert_ran_ok "chomsky-wallpaper list runs"
assert_eq "$(printf '%s\n' "$last_output" | grep -c .)" "3" "list finds the images and ignores the .txt file"
assert_not_contains "$last_output" "not-an-image" "non-images are not offered"

mapfile -t walls < <(printf '%s\n' "$last_output")
run_capture chomsky chomsky-wallpaper next
assert_ran_ok "chomsky-wallpaper next applies a wallpaper"
assert_eq "$(current)" "${walls[0]}" "with nothing set, next starts at the top of the list"
run_capture chomsky chomsky-wallpaper next
assert_eq "$(current)" "${walls[1]}" "next advances by one"
chomsky chomsky-wallpaper prev > /dev/null
assert_eq "$(current)" "${walls[0]}" "prev goes back"
chomsky chomsky-wallpaper prev > /dev/null
assert_eq "$(current)" "${walls[2]}" "prev wraps around at the top"

run_capture chomsky chomsky-wallpaper set "${walls[1]}"
assert_ran_ok "chomsky-wallpaper set applies a path"
assert_eq "$(current)" "${walls[1]}" "the path that was set is the one in effect"
applied="$(tail -n1 "$SHIM_STATE/bg-set.log")"
assert_eq "$applied" "${walls[1]}" "and it was applied through Omarchy's own background setter"

run_capture chomsky chomsky-wallpaper set "$pictures/nope.jpg"
assert_failed "setting a file that does not exist fails"
assert_contains "$last_output" "does not exist" "with a message that says so"

# --- the front-end path, while the list fits --------------------------------
: > "$SHIM_STATE/frontend.calls"
CHOMSKY_TEST_FRONTEND=pick CHOMSKY_TEST_PICK="${walls[0]}" run_capture chomsky chomsky-wallpaper menu
assert_ran_ok "the picker applies the front-end's answer"
assert_eq "$(current)" "${walls[0]}" "the picked wallpaper is applied"
assert_eq "$(frontend_calls)" "1" "the thumbnail front-end was the way in"
assert_eq "$(shell_calls)" "0" "without driving the image grid directly"

# --- dismissed without choosing ---------------------------------------------
CHOMSKY_TEST_FRONTEND=cancel run_capture chomsky chomsky-wallpaper menu
assert_ran_ok "dismissing the picker without choosing is not an error"
assert_eq "$(current)" "${walls[0]}" "and leaves the wallpaper alone"

# --- the front-end fails, as it did for real --------------------------------
: > "$SHIM_STATE/bg-set.log"
CHOMSKY_TEST_FRONTEND=fail CHOMSKY_TEST_PICK="${walls[1]}" run_capture chomsky chomsky-wallpaper menu
assert_ran_ok "a failing front-end falls back to the directory route"
assert_eq "$(current)" "${walls[1]}" "and the pick still gets applied"
if (($(shell_calls) >= 1)); then
  pass "the image grid was driven directly instead"
else
  fail "the image grid was never opened" "front-end failed and nothing took over"
fi

# What the grid is handed: the directories, an empty row list, and nowhere near
# the per-argument limit that broke the original.
largest="$(jq -r '.largest' "$SHIM_STATE/omarchy-shell.sizes" | tail -n1)"
rows_arg="$(jq -r '.[3]' "$SHIM_STATE/omarchy-shell.calls" | tail -n1)"
dirs_arg="$(jq -r '.[2]' "$SHIM_STATE/omarchy-shell.calls" | tail -n1)"
method="$(jq -rc '.[0:2]' "$SHIM_STATE/omarchy-shell.calls" | tail -n1)"
assert_eq "$method" '["image-selector","open"]' "the grid is opened through the shell's image-selector target"
assert_eq "$rows_arg" "" "no image list is passed as an argument"
assert_contains "$dirs_arg" "$pictures" "the directories are passed instead"
if ((largest < 4096)); then
  pass "the largest argument is ${largest} bytes, far below the 128 KiB limit"
else
  fail "an argument of ${largest} bytes is approaching the kernel's 131072-byte limit"
fi

# --- dismissed on the directory route ---------------------------------------
: > "$SHIM_STATE/bg-set.log"
CHOMSKY_TEST_FRONTEND=fail run_capture chomsky chomsky-wallpaper menu
assert_ran_ok "dismissing the grid without choosing is not an error"
assert_eq "$(bg_calls)" "0" "and nothing is applied"

# --- the grid refuses to open -----------------------------------------------
CHOMSKY_TEST_FRONTEND=fail CHOMSKY_TEST_PICKER_FAIL=1 run_capture chomsky chomsky-wallpaper menu
assert_failed "a grid that will not open is a failure, not a silent success"
assert_contains "$last_output" "did not open" "with a message that says why"

# --- a library too large for the front-end's single argument ----------------
# 1500 images is past the size where the base64 row list no longer fits in one
# argv entry, which is exactly the case that used to fail.
for i in $(seq 1 1500); do : > "$pictures/bulk-$i.jpg"; done
: > "$SHIM_STATE/frontend.calls"
: > "$SHIM_STATE/omarchy-shell.calls"
CHOMSKY_TEST_PICK="${walls[2]}" run_capture chomsky chomsky-wallpaper menu
assert_ran_ok "a library too large for the front-end still opens a picker"
assert_eq "$(current)" "${walls[2]}" "and the pick is applied"
assert_eq "$(frontend_calls)" "0" "the front-end was skipped rather than left to fail"
if (($(shell_calls) >= 1)); then
  pass "the directory route took over"
else
  fail "with 1500 images no picker was opened at all"
fi
largest="$(jq -r '.largest' "$SHIM_STATE/omarchy-shell.sizes" | tail -n1)"
if ((largest < 4096)); then
  pass "and its payload stays small (${largest} bytes) however many images there are"
else
  fail "the payload grew to ${largest} bytes with the size of the library"
fi

finish_test
