#!/bin/bash
# Group 1: the static gates -- shellcheck and shfmt.
#
# Both are optional: the suite is useful without them and skips with a note
# rather than failing, so a machine that has not installed them still runs
# everything else. When they are present they run over every script in the repo,
# including any added later, because the file lists are globs.

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test

# A `source=` directive is resolved relative to the working directory, so the
# lint runs from the repository root.
cd "$REPO_DIR" || exit 1

scripts=()
while IFS= read -r f; do scripts+=("$f"); done < <(
  printf '%s\n' bin/* tests/*.sh tests/lib/*.sh tests/lib/shims/* | sort
)
if ((${#scripts[@]} >= 20)); then
  pass "linting ${#scripts[@]} scripts"
else
  fail "the script list looks wrong (${#scripts[@]} files)" "the globs may have stopped matching"
fi

# --- shellcheck -------------------------------------------------------------
if command -v shellcheck > /dev/null 2>&1; then
  # -x follows the `source=` directives, so the test files see the assertion
  # helpers and the variables they set.
  run_capture shellcheck -x -f gcc "${scripts[@]}"
  if ((last_status == 0)); then
    pass "shellcheck is clean"
  else
    findings="$(printf '%s\n' "$last_output" | grep -cE ':[0-9]+:[0-9]+: (error|warning)' || true)"
    fail "shellcheck reports $findings error(s)/warning(s)" "$(printf '%s\n' "$last_output" | grep -E ':[0-9]+:[0-9]+: (error|warning)' | head -6 | tr '\n' ' ')"
  fi
else
  printf '  skip  shellcheck not installed\n'
fi

# --- shfmt ------------------------------------------------------------------
if command -v shfmt > /dev/null 2>&1; then
  # Flags come from .editorconfig, so this is exactly what a contributor's
  # editor and the test agree on.
  run_capture shfmt -d "${scripts[@]}"
  if ((last_status == 0)) && [[ -z "$last_output" ]]; then
    pass "shfmt reports no formatting differences"
  else
    files="$(printf '%s\n' "$last_output" | grep -c '^diff ' || true)"
    fail "shfmt would reformat $files file(s)" "run: shfmt -w ${scripts[*]:0:3} ... (see .editorconfig for the style)"
  fi
else
  printf '  skip  shfmt not installed\n'
fi

# --- the formatting is pinned in one place ----------------------------------
assert_file "$REPO_DIR/.editorconfig" "the shell style is pinned in .editorconfig"
if [[ -f "$REPO_DIR/.editorconfig" ]]; then
  for key in indent_style indent_size switch_case_indent; do
    if grep -q "^$key" "$REPO_DIR/.editorconfig"; then
      pass ".editorconfig sets $key"
    else
      fail ".editorconfig does not set $key" "shfmt's output would depend on the machine"
    fi
  done
fi

finish_test
