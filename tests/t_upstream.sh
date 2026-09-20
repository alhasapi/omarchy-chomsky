#!/bin/bash
# Group 3: the contracts this plugin does not own.
#
# Every mechanism here leans on something in /usr/share/omarchy: the toggle
# directory being sourced on reload, the image grid's IPC signature, the panel
# hero having a trailing slot, the style tokens the card is built from. None of
# that is ours, all of it can change when Omarchy updates, and every one of
# those changes arrives as the same symptom: the feature quietly stops working.
#
# So: assert the interfaces we depend on, and skip with a note when Omarchy is
# not there at all (the suite is still useful on a machine without it).

# shellcheck source=tests/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
start_test

OMARCHY="${OMARCHY_PATH:-/usr/share/omarchy}"
if [[ ! -d "$OMARCHY" ]]; then
  printf '  skip  Omarchy is not installed at %s\n' "$OMARCHY"
  finish_test
fi

# --- the toggle directory is sourced on every reload -------------------------
# The durability fix for the shader rests on this: the file is re-read after a
# reload, which is exactly what a runtime `hl.config` through `hyprctl eval`
# does not survive.
toggles="$OMARCHY/default/hypr/toggles.lua"
assert_file "$toggles" "Omarchy sources a toggle directory (default/hypr/toggles.lua)"
if [[ -f "$toggles" ]]; then
  if grep -q 'omarchy/toggles/hypr' "$toggles"; then
    pass "it reads the directory these scripts write to"
  else
    fail "the toggle loader no longer points at ~/.local/state/omarchy/toggles/hypr" "$(grep -v '^--' "$toggles" | head -n6 | tr '\n' ' ')"
  fi
  if grep -q 'require_all.files(toggles_dir' "$toggles"; then
    pass "it loads every .lua file in that directory by name (no allow-list to join)"
  else
    fail "the toggle loader no longer loads the directory wholesale" "a differently named toggle file might stop being applied"
  fi
  # The one exclusion is for two legacy generated files that could carry an
  # injected device name. Nothing of ours may be on that list.
  excluded="$(grep -oE '\["[a-z-]+"\] = true' "$toggles" | sed 's/\["//;s/"\] = true//' || true)"
  if [[ -z "$excluded" ]]; then
    pass "nothing is excluded from the toggle directory"
  elif grep -q chomsky <<< "$excluded"; then
    fail "a Chomsky toggle file is excluded from being loaded" "$excluded"
  else
    pass "the only exclusions are the known legacy files ($(tr '\n' ' ' <<< "$excluded"))"
  fi
fi

# And the ordering that makes one file able to win in both directions: the
# toggles are required *after* Omarchy's defaults and after the user's own
# bindings/looknfeel, so a toggle overrides either without editing either.
user_cfg="$OMARCHY/config/hypr/hyprland.lua"
if [[ -f "$user_cfg" ]]; then
  toggles_line="$(grep -n 'default\.hypr\.toggles' "$user_cfg" | cut -d: -f1 | head -n1)"
  bindings_line="$(grep -n 'require("hypr\.bindings")' "$user_cfg" | cut -d: -f1 | head -n1)"
  looknfeel_line="$(grep -n 'require("hypr\.looknfeel")' "$user_cfg" | cut -d: -f1 | head -n1)"
  if [[ -n "$toggles_line" && -n "$bindings_line" && "$toggles_line" -gt "$bindings_line" ]]; then
    pass "the toggles are loaded after the user's own bindings (line $toggles_line vs $bindings_line)"
  else
    fail "the toggles may no longer be loaded last" "toggles=$toggles_line bindings=$bindings_line -- the keybinding switch relies on winning here"
  fi
  if [[ -n "$looknfeel_line" && -n "$toggles_line" && "$toggles_line" -gt "$looknfeel_line" ]]; then
    pass "and after the user's look and feel (line $toggles_line vs $looknfeel_line)"
  else
    fail "the toggles may no longer override looknfeel" "toggles=$toggles_line looknfeel=$looknfeel_line"
  fi
fi

# --- the image grid's IPC signature -----------------------------------------
# Called as: image-selector open <dirs> <rows> <selected> <selection> <done> <labels> <filterable>
shell_qml="$OMARCHY/shell/shell.qml"
assert_file "$shell_qml" "the shell defines the image-selector target"
if [[ -f "$shell_qml" ]]; then
  if grep -q '"image-selector"' "$shell_qml"; then
    pass "the image-selector target still exists"
  else
    fail "the image-selector target is gone from the shell" "the wallpaper picker would stop opening"
  fi
  sig="$(grep -A14 '"image-selector"' "$shell_qml" | head -n16)"
  if grep -q 'function open(imageDirs' <<< "$sig"; then
    pass "its open() still takes the directories first"
  else
    fail "the open() signature changed" "$(printf '%s' "$sig" | tr '\n' ' ' | head -c 200)"
  fi
  if grep -q 'imageRowsB64' <<< "$sig" && grep -q 'decodeBase64(imageRowsB64)' <<< "$sig"; then
    pass "and still passes a row list base64-encoded in one argument (the 128 KiB limit that shapes the picker)"
  else
    fail "the row argument changed shape" "$(printf '%s' "$sig" | tr '\n' ' ' | head -c 200)"
  fi
fi

front_end="$(command -v omarchy-menu-images || true)"
assert_file "$front_end" "Omarchy's image front-end is on PATH"
if [[ -f "$front_end" ]]; then
  for flag in --selected --filterable; do
    if grep -q -- "$flag" "$front_end"; then
      pass "the front-end still accepts $flag"
    else
      fail "the front-end no longer accepts $flag" "the picker call in chomsky-wallpaper would fail"
    fi
  done
fi

# --- the panel building blocks ----------------------------------------------
for component in Ui/PanelHero.qml Ui/ToggleSwitch.qml Ui/BorderSurface.qml Ui/PanelToolTip.qml Ui/PanelKeyCatcher.qml Commons/Style.qml; do
  assert_file "$OMARCHY/shell/$component" "the shell still ships $component"
done
if [[ -f "$OMARCHY/shell/Ui/PanelHero.qml" ]] && grep -q 'trailingControl' "$OMARCHY/shell/Ui/PanelHero.qml"; then
  pass "PanelHero still has the trailingControl slot the chip switch sits in"
else
  fail "PanelHero lost trailingControl" "the bar chip switch would stop appearing"
fi
if [[ -f "$OMARCHY/shell/Commons/Style.qml" ]]; then
  for token in 'panelPadding' 'function space' 'cornerRadius'; do
    if grep -q "$token" "$OMARCHY/shell/Commons/Style.qml"; then
      pass "Style still provides $token"
    else
      fail "Style no longer provides $token" "the panel's sizing would break"
    fi
  done
fi

# --- the menu model ---------------------------------------------------------
assert_file "$OMARCHY/shell/plugins/menu/MenuModel.js" "the menu model is where the rows are parsed"
if [[ -f "$OMARCHY/shell/plugins/menu/MenuModel.js" ]]; then
  for kind in action checked when; do
    if grep -q "$kind" "$OMARCHY/shell/plugins/menu/MenuModel.js"; then
      pass "the menu model still understands '$kind'"
    else
      fail "the menu model no longer mentions '$kind'" "the generated rows rely on it"
    fi
  done
fi

# --- the plugin registry treats a plugins[] entry as enabled -----------------
plugin_registry="$(find "$OMARCHY/shell" -name 'PluginRegistry.qml' 2> /dev/null | head -n1)"
if [[ -n "$plugin_registry" ]]; then
  if grep -q 'findEntryLocation' "$plugin_registry"; then
    pass "PluginRegistry still has findEntryLocation (what makes plugins[] count as enabled)"
  else
    fail "PluginRegistry.findEntryLocation is gone" "chomsky-bar's off must be re-checked"
  fi
else
  fail "PluginRegistry.qml was not found" "the chip-off mechanism rests on it"
fi

finish_test
