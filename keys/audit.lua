-- keys/audit.lua -- does the live keymap match the mode it claims?
--
-- The mode is a file on disk, and a file can be right while the session is
-- wrong: a binding that failed to take, a leftover from the other mode, another
-- plugin holding a key this port thinks it owns. So the claim is checked against
-- `hyprctl binds -j` rather than trusted, and this module holds that check.
--
-- Two things make it possible to tell the modes apart in the live keymap:
--
--   * every binding this port makes is described "Dusky: ..." (see
--     keys/chomsky_keys.lua), so provenance is readable rather than guessed;
--   * descriptions for Omarchy's own bindings come from
--     keys/omarchy-shipped.lua, so "Omarchy's binding is back" is a comparison,
--     not an assumption.
--
-- Hyprland reports a Lua binding as dispatcher "__lua" with an opaque `arg`, so
-- the dispatcher itself is not inspectable. The comparison is therefore on the
-- key, the description and the flags -- which is exactly why the description
-- carries the provenance. What it cannot prove is which *code* is behind a
-- description, so keys/chomsky_keys.lua is kept dumb: the descriptions come from
-- the tables, and the tables are audited separately.
--
--   rows    = audit.parse_tsv(text)        -- "modmask\tkey\tdescription\trepeat"
--   live    = audit.index(rows)            -- normalised key -> bindings
--   problems= audit.audit(mode, live)      -- {} when the mode is what it says
--
-- Each problem is { key, message, source }, where source is "tables" (the port's
-- own data disagrees with its pinned snapshots), "Omarchy default", "live
-- keymap", or "your own config or another plugin".

local ledger = require("dusky-ledger")
local remaps = require("remaps")
local omarchy = require("omarchy-shipped")
local extras = require("extras")
local keysym = require("keysym")
local snapshot = require("dusky-upstream")

local M = {}

-- Must match keys/chomsky_keys.lua. Kept in one place per side because this
-- module must be able to say "that is not our binding" without loading the
-- binding code (which needs a live Hyprland API).
M.PREFIX = "Dusky: "

-- The modifier bits `hyprctl binds -j` reports, highest first.
local BITS = {
  { 64, "SUPER" },
  { 8, "ALT" },
  { 4, "CTRL" },
  { 1, "SHIFT" },
}

-- Turn hyprctl's modmask + key back into a key string, so it can be compared
-- with the tables through keysym.normalise (which is where case and modifier
-- order stop mattering).
function M.key_string(modmask, key)
  local parts, left = {}, modmask or 0
  for _, bit in ipairs(BITS) do
    if left >= bit[1] then
      left = left - bit[1]
      parts[#parts + 1] = bit[2]
    end
  end
  parts[#parts + 1] = key or ""
  return table.concat(parts, " + ")
end

-- Parse the TSV the CLI produces with jq. A description can contain anything, so
-- the key is the only field allowed to be empty (hyprctl reports code:NN binds
-- with an empty key).
function M.parse_tsv(text)
  local rows = {}
  for line in (text or ""):gmatch("[^\n]+") do
    local modmask, key, description, repeat_flag = line:match("^(%d+)\t(.-)\t(.-)\t(.*)$")
    if modmask then
      rows[#rows + 1] = {
        modmask = tonumber(modmask),
        key = key,
        description = description,
        repeat_flag = repeat_flag == "true",
      }
    end
  end
  return rows
end

-- Group bindings by normalised key. A key can carry more than one binding
-- (Omarchy binds several swap-and-raise pairs), so each entry is a list.
function M.index(rows)
  local live = {}
  for _, row in ipairs(rows) do
    local normalised = keysym.normalise(M.key_string(row.modmask, row.key))
    live[normalised] = live[normalised] or {}
    table.insert(live[normalised], row)
  end
  return live
end

-- Omarchy's own descriptions, for attributing a binding that is not ours.
local shipped_descriptions = {}
for _, binding in ipairs(omarchy.bindings) do
  shipped_descriptions[binding.description] = true
end

local function attribute(description)
  if description:find("^" .. M.PREFIX, 1) then return "this port" end
  if shipped_descriptions[description] then return "Omarchy default" end
  return "your own config or another plugin"
end

-- What the live keymap should contain, as normalised key -> expected binding.
-- In omarchy mode nothing is expected from this port: the check there is that
-- Omarchy's own bindings are back, which M.audit reads straight from the
-- snapshot.
function M.expected(mode)
  local expected = {}
  if mode ~= "dusky" then return expected end

  for _, row in ipairs(ledger.selected()) do
    expected[keysym.normalise(row.key)] = {
      key = row.key,
      description = M.PREFIX .. (row.dusky or row.key),
      repeating = type(row.flags) == "string" and row.flags:find("repeating", 1, true) ~= nil,
    }
  end

  for _, remap in ipairs(remaps.rows) do
    if remap.kind == "moved" then
      -- The description Omarchy itself uses, so the moved action still reads as
      -- what it is wherever it lands.
      local shipped = omarchy.for_key(remap.from)
      local description = shipped[1] and shipped[1].description or remap.omarchy
      expected[keysym.normalise(remap.to)] = {
        key = remap.to,
        description = M.PREFIX .. description,
        repeating = false,
      }
    end
  end

  -- This port's own bindings, which are dusky-mode only like the rest.
  for _, row in ipairs(extras.rows) do
    expected[keysym.normalise(row.key)] = {
      key = row.key,
      description = M.PREFIX .. row.description,
      repeating = false,
    }
  end

  return expected
end

function M.audit(mode, live)
  local problems = {}
  local function problem(key, message, source)
    problems[#problems + 1] = { key = key, message = message, source = source }
  end

  -- The tables first: if the ledger no longer covers Dusky's snapshot, or a
  -- remap target is no longer free, the live check is measuring the wrong thing.
  for _, entry in ipairs(ledger.audit(snapshot)) do problem("-", entry, "tables") end
  for _, entry in ipairs(remaps.audit(ledger, omarchy)) do problem("-", entry, "tables") end
  for _, entry in ipairs(extras.audit(ledger, omarchy, remaps)) do problem("-", entry, "tables") end

  local owned = {}
  for _, key in ipairs(remaps.owned(ledger)) do owned[keysym.normalise(key)] = key end
  for _, key in ipairs(extras.keys()) do owned[keysym.normalise(key)] = key end

  if mode == "dusky" then
    for normalised, want in pairs(M.expected(mode)) do
      local bindings = live[normalised] or {}
      local found = false
      for _, binding in ipairs(bindings) do
        if binding.description == want.description then found = true end
        if not binding.description:find("^" .. M.PREFIX, 1) then
          problem(
            want.key,
            string.format("live binding is %q, not the Dusky binding (%q)", binding.description, want.description),
            attribute(binding.description)
          )
        end
      end
      if not found then
        problem(want.key, string.format("nothing in the live keymap does this (expected %q)", want.description), "live keymap")
      end
      if want.repeating then
        local repeats = false
        for _, binding in ipairs(bindings) do
          if binding.repeat_flag then repeats = true end
        end
        if not repeats then
          problem(want.key, "expected a repeating binding (hold the key to keep resizing)", "live keymap")
        end
      end
    end

    -- A Dusky binding anywhere else is a leak: dusky mode only owns its own keys.
    -- Reported by its normalised key, because hyprctl hands back the keysym alone
    -- (`T`, `SPACE`) and a problem that names half a key is not actionable.
    for normalised, bindings in pairs(live) do
      for _, binding in ipairs(bindings) do
        if binding.description:find("^" .. M.PREFIX, 1) and not owned[normalised] then
          problem(normalised, "this port binds a key it does not own", "this port")
        end
      end
    end
  else
    for normalised, key in pairs(owned) do
      local shipped = omarchy.for_key(key)
      if #shipped > 0 then
        local want, seen = {}, {}
        for _, binding in ipairs(shipped) do want[binding.description] = true end
        for _, binding in ipairs(live[normalised] or {}) do
          if want[binding.description] then
            seen[binding.description] = true
          else
            problem(
              key,
              string.format("live binding is %q, which is not Omarchy's binding for this key", binding.description),
              attribute(binding.description)
            )
          end
        end
        for description in pairs(want) do
          if not seen[description] then
            problem(key, string.format("Omarchy's %q was not restored", description), "live keymap")
          end
        end
      end
    end

    -- Nothing of this port's may survive a switch back. Only bindings of ours
    -- are reported here: a binding someone else put on a key Omarchy does not
    -- use is their business, not a failure of this switch.
    for normalised, bindings in pairs(live) do
      for _, binding in ipairs(bindings) do
        if binding.description:find("^" .. M.PREFIX, 1) then
          problem(normalised, "a Dusky binding survived into omarchy mode", "this port")
        end
      end
    end
  end

  return problems
end

return M
