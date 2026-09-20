-- chomsky_keys: the keybinding sets that Chomsky's "Dusky keybindings" toggle
-- switches between.
--
-- Loaded from ~/.local/state/omarchy/toggles/hypr/chomsky-keys.lua, which
-- default/hypr/toggles.lua sources last on every `hyprctl reload` -- after
-- Omarchy's defaults and after the user's own ~/.config/hypr/bindings.lua.
-- Loading last is what lets one mode win over the other without editing
-- anybody's config, and what makes the switch a reload instead of a logout.
--
-- Both modes unbind every key in KEYS before binding anything. That is what
-- makes the switch complete and repeatable:
--
--   dusky   -- the Dusky port: vim navigation, arrows for resizing, the
--              animation and shader pickers, monitor rotation, DPMS, and
--              click-to-kill.
--   omarchy -- Omarchy's shipped bindings on the keys Dusky displaced
--              (SUPER + J/K/L, SUPER + arrows). The keys Omarchy has nothing
--              on are left unbound, so this really is "Omarchy's keybindings"
--              and not "Omarchy's plus extras".
--
-- Omarchy has no "restore the shipped default" primitive, so omarchy mode
-- re-binds those seven defaults explicitly. They are copied from
-- $OMARCHY_PATH/default/hypr/bindings/{tiling,utilities}.lua -- if Omarchy
-- ever changes one, change it here too (hyprctl binds -j shows the live set).
--
-- `dir` is the plugin directory, passed in by the generated toggle file, so
-- the bindings call the plugin's own bin/ scripts and do not depend on
-- chomsky-link having been run.

local M = {}

-- Every key either mode touches. Omarchy mode unbinds all of them and re-binds
-- only what Omarchy ships, so this list is the whole blast radius of the
-- toggle -- the seven in the second block are the only ones that displace an
-- Omarchy binding.
local KEYS = {
  -- Dusky only: nothing is bound here in Omarchy's defaults.
  "SUPER + ALT + A", -- animation picker
  "SUPER + ALT + X", -- shader picker
  "CTRL + ALT + R", -- rotate monitor
  "CTRL + ALT + SHIFT + R",
  "ALT + F7", -- DPMS
  "ALT + F8",
  "SUPER + SHIFT + R", -- reload Hyprland
  "SUPER + SHIFT + ESCAPE", -- click-to-kill
  "SUPER + H", -- vim focus
  "SUPER + SHIFT + H", -- vim swap
  "SUPER + SHIFT + J",
  "SUPER + SHIFT + K", -- Omarchy's keybindings menu, moved off SUPER + K
  "SUPER + SHIFT + L", -- workspace layout, moved off SUPER + L
  "SUPER + Y", -- window split, moved off SUPER + J
  "SUPER + apostrophe", -- wallpapers
  "SUPER + SHIFT + apostrophe",

  -- Displaced Omarchy defaults.
  "SUPER + J",
  "SUPER + K",
  "SUPER + L",
  "SUPER + LEFT",
  "SUPER + RIGHT",
  "SUPER + UP",
  "SUPER + DOWN",
}

local function unbind_all()
  -- Unbinding a key nothing is bound to is harmless, so this needs no checks.
  for _, key in ipairs(KEYS) do
    hl.unbind(key)
  end
end

local function dusky(dir)
  local chomsky = dir .. "/bin/chomsky"

  o.bind("SUPER + ALT + A", "Animation menu", chomsky .. " anim menu")
  o.bind("SUPER + ALT + X", "Shader menu", chomsky .. " shader menu")

  o.bind("CTRL + ALT + R", "Rotate screen clockwise", chomsky .. " rotate cw")
  o.bind("CTRL + ALT + SHIFT + R", "Rotate screen anti-clockwise", chomsky .. " rotate ccw")

  -- The 500ms delay matches Dusky's own trick: without it, releasing the keys
  -- immediately re-wakes the screen.
  o.bind("ALT + F7", "Screen off (DPMS)", function()
    hl.timer(function()
      hl.dispatch(hl.dsp.dpms({ action = "disable" }))
    end, { timeout = 500, type = "oneshot" })
  end, { locked = true })

  o.bind("ALT + F8", "Screen on (DPMS)", function()
    hl.dispatch(hl.dsp.dpms({ action = "enable" }))
  end, { locked = true })

  o.bind("SUPER + SHIFT + R", "Reload Hyprland", "hyprctl reload")

  -- `hyprctl kill` (not a Lua dispatcher -- there is no hl.dsp.kill) enters a
  -- mode where the next click kills that window.
  o.bind("SUPER + SHIFT + ESCAPE", "Kill window (click)", "hyprctl kill")

  -- Vim navigation, using the four keys Omarchy leaves free for exactly this.
  o.bind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "l" }))
  o.bind("SUPER + J", "Focus down", hl.dsp.focus({ direction = "d" }))
  o.bind("SUPER + K", "Focus up", hl.dsp.focus({ direction = "u" }))
  o.bind("SUPER + L", "Focus right", hl.dsp.focus({ direction = "r" }))

  o.bind("SUPER + SHIFT + H", "Swap window left", hl.dsp.window.swap({ direction = "l" }))
  o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))

  -- The three Omarchy bindings the vim keys displaced, moved rather than
  -- dropped.
  o.bind("SUPER + Y", "Toggle window split", hl.dsp.layout("togglesplit"))
  o.bind("SUPER + SHIFT + K", "Keybindings", "omarchy-menu-keybindings")
  o.bind("SUPER + SHIFT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

  -- Wallpapers: Dusky's "next background" (now across the theme and
  -- ~/Pictures) and, where it used to generate a theme from the wallpaper,
  -- picking one from the thumbnail grid.
  o.bind("SUPER + apostrophe", "Next background", chomsky .. " bg-next")
  o.bind("SUPER + SHIFT + apostrophe", "Pick wallpaper", chomsky .. " wallpaper menu")

  -- Arrows resize rather than focus, the way Dusky has them. Works on tiled
  -- windows (adjusts the split ratio) and floating ones (moves the edge).
  o.bind("SUPER + RIGHT", "Grow window width", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true })
  o.bind("SUPER + LEFT", "Shrink window width", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
  o.bind("SUPER + DOWN", "Grow window height", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })
  o.bind("SUPER + UP", "Shrink window height", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
end

local function omarchy()
  o.bind("SUPER + J", "Toggle window split", hl.dsp.layout("togglesplit"))
  o.bind("SUPER + K", "Keybindings", "omarchy-menu-keybindings")
  o.bind("SUPER + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

  o.bind("SUPER + LEFT", "Focus on left window", hl.dsp.focus({ direction = "l" }))
  o.bind("SUPER + RIGHT", "Focus on right window", hl.dsp.focus({ direction = "r" }))
  o.bind("SUPER + UP", "Focus on above window", hl.dsp.focus({ direction = "u" }))
  o.bind("SUPER + DOWN", "Focus on below window", hl.dsp.focus({ direction = "d" }))
end

-- mode is "dusky" or "omarchy"; dir is the plugin directory.
function M.apply(mode, dir)
  if mode == "dusky" and (type(dir) ~= "string" or dir == "") then
    error("chomsky_keys: dusky mode needs the plugin directory")
  end

  unbind_all()

  if mode == "dusky" then
    dusky(dir)
  else
    omarchy()
  end
end

M.keys = KEYS

return M
