#!/usr/bin/env bats
# bats front end for the suite in tests/run.sh.
#
# One bats test per group file. The checks inside a group are assertions rather
# than individual bats tests on purpose: a group shares one sandbox and one
# sequence (set a shader, reload, check it survived), which is exactly what the
# bugs being guarded against looked like. Splitting them into 246 independent
# `@test`s would mean rebuilding that fixture per check and writing the same
# sequence over and over, so bats is used here for what it is good at -- a
# standard protocol, `--filter`, TAP output for CI -- and the checks stay where
# they are.
#
#   bats tests/run.bats
#   bats --filter shader tests/run.bats
#   CHOMSKY_WITH_QML=1 bats tests/run.bats    # also the panel group

setup_file() {
  export SUITE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/chomsky-bats.XXXXXX")"
}

teardown_file() {
  [[ -n "${SUITE_TMP:-}" ]] && rm -rf "$SUITE_TMP"
}

run_group() {
  local group="$1"
  export TEST_TMP="$(mktemp -d "$SUITE_TMP/$group.XXXXXX")"
  run bash "$BATS_TEST_DIRNAME/$group.sh"
  if [[ "$status" -ne 0 ]]; then
    printf '%s\n' "$output"
    printf 'sandbox kept for inspection: %s\n' "$TEST_TMP" >&2
    return 1
  fi
  rm -rf "$TEST_TMP"
}

@test "safety: the tests cannot touch the real session" { run_group t_safety; }
@test "lint: shellcheck and shfmt" { run_group t_lint; }
@test "invariants: the cross-file checks" { run_group t_invariants; }
@test "shader: state matches what Hyprland has applied" { run_group t_shader; }
@test "animation: presets and the toggle file" { run_group t_anim; }
@test "window: border resize and dim strength" { run_group t_window; }
@test "keys: the Dusky/Omarchy switch clears what it binds" { run_group t_keys; }
@test "bar: the chip's on/off switch and shell.json" { run_group t_bar; }
@test "wallpaper: cycling, and the picker's two routes" { run_group t_wallpaper; }
@test "menu: install, idempotency, concurrency, removal" { run_group t_menu; }
@test "status: the JSON the panel reads" { run_group t_status; }
@test "upstream: the Omarchy interfaces this depends on" { run_group t_upstream; }
@test "clis: rotation, dpms, reload, PATH wrappers" { run_group t_clis; }

@test "qml: the panel renders (opt-in: CHOMSKY_WITH_QML=1)" {
  if [[ -z "${CHOMSKY_WITH_QML:-}" ]]; then
    skip "needs a Wayland session and shows the panel for a second: run with CHOMSKY_WITH_QML=1"
  fi
  run_group t_qml
}

@test "every group file has a test here" {
  missing=()
  for f in "$BATS_TEST_DIRNAME"/t_*.sh; do
    group="$(basename "$f" .sh)"
    grep -q "run_group $group\b" "$BATS_TEST_FILENAME" || missing+=("$group")
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'groups with no bats test: %s\n' "${missing[*]}" >&2
    return 1
  fi
}
