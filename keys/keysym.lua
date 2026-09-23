-- keys/keysym.lua -- deciding when two key strings are the same binding.
--
-- Hyprland resolves modifier names and keysym names case-insensitively, and the
-- order the modifiers are written in does not matter. So Dusky's `SUPER + j`,
-- Omarchy's `SUPER + J` and a hand-written `SUPER + j` are one binding, and a
-- comparison that treats them as three different keys is how a collision hides:
-- the port would think a key was free while Omarchy already had something on it.
--
-- This module is for *comparison only*. Bindings are always written out in the
-- spelling the source of truth uses (Dusky's spelling in the ledger, Omarchy's
-- in its snapshot), because that is what gets passed to `hl.bind`/`hl.unbind`,
-- and normalising for the wire would change keysym names into something
-- Hyprland may not accept.
--
--   keysym.normalise("SUPER + SHIFT + h")  == keysym.normalise("shift + super + H")
--   keysym.equal("SUPER + left", "SUPER + LEFT")  == true

local M = {}

-- Modifiers Hyprland accepts, in the order it prints them back from
-- `hyprctl binds -j`. Normalising to this order makes the written order
-- irrelevant.
local MODIFIER_ORDER = { "SUPER", "CTRL", "ALT", "SHIFT" }
local MODIFIERS = {}
for _, name in ipairs(MODIFIER_ORDER) do MODIFIERS[name] = true end

-- `MOD` is Hyprland's alias for SUPER. The rest are the keysym names Hyprland
-- accepts for one key, so that a port does not read as "free" against a
-- differently-spelled equivalent.
local ALIASES = {
  MOD = "SUPER",
  ESC = "ESCAPE",
  RETURN = "ENTER",
}

-- Normalise a key string into a comparable form. Returns the input unchanged
-- for anything that is not a string, so callers can pass a table row's field
-- without a guard.
function M.normalise(key)
  if type(key) ~= "string" then return key end

  local modifiers, keysym = {}, nil
  for part in key:gmatch("[^+]+") do
    local name = part:gsub("^%s+", ""):gsub("%s+$", ""):upper()
    if name ~= "" then
      if MODIFIERS[name] then
        modifiers[#modifiers + 1] = name
      elseif keysym == nil then
        keysym = name
      else
        -- A second non-modifier token: not a key string this module understands
        -- (a `switch:on:...` name, for instance). Keep the original spelling so
        -- two identical strings still compare equal and nothing is guessed.
        return key
      end
    end
  end

  local ordered = {}
  for _, name in ipairs(MODIFIER_ORDER) do
    for _, present in ipairs(modifiers) do
      if present == name then ordered[#ordered + 1] = name end
    end
  end

  keysym = ALIASES[keysym] or keysym
  if keysym == nil then return table.concat(ordered, " + ") end
  if #ordered == 0 then return keysym end
  return table.concat(ordered, " + ") .. " + " .. keysym
end

function M.equal(a, b)
  return M.normalise(a) == M.normalise(b)
end

return M
