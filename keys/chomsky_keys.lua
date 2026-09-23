-- chomsky_keys: the switch between stock Omarchy and a curated set of Dusky
-- keybindings.
--
-- Loaded from ~/.local/state/omarchy/toggles/hypr/chomsky-keys.lua, which
-- default/hypr/toggles.lua sources last on every `hyprctl reload` -- after
-- Omarchy's defaults and after the user's own ~/.config/hypr/bindings.lua.
-- Loading last is what lets this file settle the disagreement without editing
-- anyone's config, and what makes the switch a reload rather than a logout.
--
-- Nothing here is a decision. The decisions live next to the data:
--
--   keys/dusky-ledger.lua     which of Dusky's keys the port selects, and why
--                             the rest are left alone
--   keys/remaps.lua           where each displaced Omarchy action moves to
--   keys/omarchy-shipped.lua  Omarchy's own bindings, so omarchy mode can put
--                             them back exactly and remap targets can be checked
--                             for being genuinely free
--   keys/keysym.lua           when two key spellings mean the same binding
--
-- Both modes clear the *identical* set of keys -- everything this port owns,
-- which is the selected Dusky keys plus the keys an Omarchy action was moved
-- onto (`remaps.owned`). That is what makes switching reversible: no key can
-- survive from one mode into the other, so nothing has to be discovered by
-- pressing it.
--
-- The direction of the port is deliberate: Dusky owns the navigation keys
-- (vim focus and moves, arrows for resizing) while Omarchy keeps its own
-- binding everywhere the two agree, and every Omarchy binding the port displaces
-- is re-homed rather than dropped. Omarchy mode is stock Omarchy, including on
-- the keys this port takes in dusky mode.
--
-- `dir` is the plugin directory, passed in by the generated toggle file, so
-- plugin-owned bindings call this plugin's own bin/ scripts and do not depend on
-- chomsky-link having been run.

local ledger = require("dusky-ledger")
local remaps = require("remaps")
local omarchy = require("omarchy-shipped")
local extras = require("extras")

local M = {}

-- The prefix on every binding this port makes. It is what tells the two modes
-- apart in `hyprctl binds -j` without guessing: in dusky mode an owned key reads
-- "Dusky: ...", in omarchy mode it reads exactly what Omarchy calls it. So the
-- audit in bin/chomsky-keys can prove the mode from the live keymap instead of
-- trusting this file.
local PREFIX = "Dusky: "

-- --- the action vocabulary the ledger's `dsp` field names -------------------
-- Anything the ledger cannot express as a shell command is named here and built
-- against Hyprland's own API, so the ledger stays data.
local function resolve(dsp)
  local direction = dsp:match("^focus:(%a)$")
  if direction then return hl.dsp.focus({ direction = direction }) end

  direction = dsp:match("^wmove:(%a)$")
  if direction then return hl.dsp.window.move({ direction = direction }) end

  local x, y = dsp:match("^resize:(-?%d+):(-?%d+)$")
  if x then
    return hl.dsp.window.resize({ x = tonumber(x), y = tonumber(y), relative = true })
  end

  if dsp == "layout:togglesplit" then return hl.dsp.layout("togglesplit") end

  if dsp == "wprop:opaque" then
    return hl.dsp.window.set_prop({ prop = "opaque", value = "toggle", window = "activewindow" })
  end

  if dsp == "group:prev" then return hl.dsp.group.prev() end
  if dsp == "group:next" then return hl.dsp.group.next() end
  if dsp == "group:lock" then return hl.dsp.group.lock_active({ action = "toggle" }) end

  direction = dsp:match("^winto:(%a)$")
  if direction then return hl.dsp.window.move({ into_or_create_group = direction }) end
  if dsp == "wout" then return hl.dsp.window.move({ out_of_group = true }) end

  local workspace = dsp:match("^ws:(.+)$")
  if workspace then return hl.dsp.focus({ workspace = workspace }) end

  if dsp == "dpms:off" then
    -- The 500ms delay is Dusky's own trick: without it, releasing the keys
    -- immediately re-wakes the screen.
    return function()
      hl.timer(function()
        hl.dispatch(hl.dsp.dpms({ action = "disable" }))
      end, { timeout = 500, type = "oneshot" })
    end
  end
  if dsp == "dpms:on" then return hl.dsp.dpms({ action = "enable" }) end

  error("chomsky_keys: the ledger names an unknown dispatcher: " .. tostring(dsp), 0)
end

-- `flags` is a comma-separated list in the ledger ("repeating", "locked"), so the
-- data file stays readable. Hyprland wants a table.
local function parse_flags(text)
  if type(text) ~= "string" or text == "" then return nil end
  local flags = {}
  for piece in text:gmatch("[^,]+") do
    local flag = piece:gsub("%s+", "")
    if flag ~= "" then flags[flag] = true end
  end
  if next(flags) == nil then return nil end
  return flags
end

-- Plugin-owned commands are rewritten to this plugin's own bin/ directory, so a
-- binding works whether or not chomsky-link has put the CLIs on PATH.
local function resolve_command(command, dir)
  if command:match("^chomsky%f[%s]") then
    if type(dir) ~= "string" or dir == "" then
      error("chomsky_keys: a ledger command needs the plugin directory: " .. command, 0)
    end
    return dir .. "/bin/" .. command
  end
  return command
end

local function bind_selected(row, dir)
  local flags = parse_flags(row.flags)
  local description = PREFIX .. (row.dusky or row.key)

  if row.cmd then
    o.bind(row.key, description, resolve_command(row.cmd, dir), flags)
  elseif row.dsp then
    o.bind(row.key, description, resolve(row.dsp), flags)
  else
    error("chomsky_keys: a selected ledger row has no cmd or dsp: " .. row.key, 0)
  end
end

-- A displaced Omarchy action, bound on the key it moved to, with Omarchy's own
-- dispatcher and its description. `kind = "selected"` rows need nothing here:
-- their target is a Dusky key that already performs the same action.
local function bind_remaps()
  for _, remap in ipairs(remaps.rows) do
    if remap.kind == "moved" then
      local shipped = omarchy.restore(remap.from)
      if not shipped then
        error("chomsky_keys: nothing to move from " .. remap.from, 0)
      end
      for _, binding in ipairs(shipped) do
        o.bind(remap.to, PREFIX .. binding.description, binding.dispatch, binding.flags)
      end
    end
  end
end

-- Bindings this port adds on its own account, neither Dusky's nor a displaced
-- Omarchy action. See keys/extras.lua for why there is exactly one.
local function bind_extras(dir)
  for _, row in ipairs(extras.rows) do
    local flags
    if row.locked then flags = { locked = true } end
    o.bind(row.key, PREFIX .. row.description, resolve_command(row.command, dir), flags)
  end
end

-- Omarchy's own bindings, back on their own keys, for every owned key Omarchy
-- ships. Keys Omarchy has nothing on are simply left unbound: "Omarchy" here
-- means Omarchy, not "Omarchy plus whatever this port knows".
local function bind_omarchy()
  for _, key in ipairs(M.keys()) do
    local shipped = omarchy.restore(key)
    if shipped then
      for _, binding in ipairs(shipped) do
        o.bind(binding.key, binding.description, binding.dispatch, binding.flags)
      end
    end
  end
end

-- Every key either mode clears: the selected Dusky set, the keys an Omarchy
-- action moved onto, and this port's own extras. Also what `chomsky-keys keys`
-- prints.
function M.keys()
  local keys = remaps.owned(ledger)
  for _, key in ipairs(extras.keys()) do keys[#keys + 1] = key end
  return keys
end

-- mode is "dusky" or "omarchy"; dir is the plugin directory.
function M.apply(mode, dir)
  if mode ~= "dusky" then mode = "omarchy" end

  local owned = M.keys()
  for _, key in ipairs(owned) do
    hl.unbind(key)
  end

  if mode == "dusky" then
    for _, row in ipairs(ledger.selected()) do
      bind_selected(row, dir)
    end
    bind_remaps()
    bind_extras(dir)
  else
    bind_omarchy()
  end
end

return M
