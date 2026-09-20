#!/bin/bash
# Chomsky's test suite.
#
#   tests/run.sh              every test
#   tests/run.sh shader menu  only tests whose name matches
#   tests/run.sh --list       what would run
#   --keep                    keep the sandboxes (or CHOMSKY_TEST_KEEP=1)
#
# Everything runs headless, with a throwaway HOME and shims for every external
# command, so the suite cannot disturb the session it is run from. The one
# exception is checked and reported at the end: the user's real config files are
# hashed before and after, and any difference fails the run.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TESTS_DIR

# shellcheck source=tests/lib/common.sh
source "$TESTS_DIR/lib/common.sh"

PATTERNS=()
LIST_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --keep) KEEP_TMP=1 ;;
    --list) LIST_ONLY=1 ;;
    -h | --help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) PATTERNS+=("$arg") ;;
  esac
done
export KEEP_TMP

# One temp tree for the whole run: the shims live in it, plus a sandbox per test.
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/chomsky-tests.XXXXXX")"
export TEST_TMP
mkdir -p "$TEST_TMP/shims"
cp "$TESTS_DIR"/lib/shims/* "$TEST_TMP/shims/"
chmod +x "$TEST_TMP"/shims/*
# A guaranteed-noop HOSTNAME-ish guard: HL_INSTANCE_SIGNATURE would let a real
# hyprctl through, so make one up and let the shim answer everything.
export HYPRLAND_INSTANCE_SIGNATURE="chomsky-tests"

mapfile -t ALL_TESTS < <(find "$TESTS_DIR" -maxdepth 1 -name 't_*.sh' -printf '%f\n' | sort)

if ((LIST_ONLY)); then
  printf '%s\n' "${ALL_TESTS[@]}"
  exit 0
fi

selected=()
for t in "${ALL_TESTS[@]}"; do
  if ((${#PATTERNS[@]} == 0)); then
    selected+=("$t")
    continue
  fi
  for p in "${PATTERNS[@]}"; do
    [[ "$t" == *"$p"* ]] && {
      selected+=("$t")
      break
    }
  done
done

if ((${#selected[@]} == 0)); then
  printf 'no tests match: %s\n' "${PATTERNS[*]}" >&2
  exit 1
fi

real_home_baseline

printf 'Chomsky tests: %d file(s), repo %s\n' "${#selected[@]}" "$REPO_DIR"

total_run=0
total_failed=0
failed_files=()
overall_start=$(date +%s)

for t in "${selected[@]}"; do
  start=$(date +%s)
  output="$(TEST_TMP="$TEST_TMP" bash "$TESTS_DIR/$t" 2>&1)"
  status=$?
  elapsed=$(($(date +%s) - start))
  printf '%s' "$output"
  printf '  -- %s: %s (%ss)\n' "$t" "$([[ $status -eq 0 ]] && echo pass || echo FAIL)" "$elapsed"

  # Each test file prints its own counts; collect them for the summary.
  run_n=$(printf '%s' "$output" | grep -cE '^  (ok|FAIL) ')
  fail_n=$(printf '%s' "$output" | grep -cE '^  FAIL ')
  total_run=$((total_run + run_n))
  total_failed=$((total_failed + fail_n))
  [[ $status -ne 0 ]] && failed_files+=("$t")
done

printf '\n%s\n' "------------------------------------------------------------"
check_real_home_untouched
printf '%d checks, %d failed, %ss\n' "$total_run" "$total_failed" "$(($(date +%s) - overall_start))"

if ((total_failed > 0)); then
  printf 'failing: %s\n' "${failed_files[*]}"
  printf 'sandbox: %s\n' "$TEST_TMP"
  exit 1
fi

printf 'sandbox: %s (removing; use --keep to keep it)\n' "$TEST_TMP"
rm -rf "$TEST_TMP"
exit 0
