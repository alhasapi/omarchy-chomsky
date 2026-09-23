-- keys/extras.lua -- the bindings this port adds on its own account.
--
-- The ledger accounts for every key Dusky binds; the remap table says where each
-- displaced Omarchy action goes. This is the third, deliberately tiny list: keys
-- that are neither.
--
-- There is one, and it is here rather than dropped. Dusky has no click-to-kill
-- key -- its kill bindings are Kill Process on `SUPER + semicolon` and Kill
-- Focused Process Completely on `SUPER + SHIFT + C`, both left out of the
-- selection, and no other file in Dusky's config binds one. But this port has
-- shipped click-to-kill on `SUPER + SHIFT + ESCAPE` since its first port and the
-- README advertises it, so tidying the tables must not quietly delete it. An
-- extra is the honest place for it: it is visibly not Dusky's, it is cleared by
-- both modes like everything else the port owns, and `chomsky-keys keys` and
-- `chomsky-keys check` treat it exactly like the rest.
--
-- The audit keeps this list from becoming a back door: an extra may not be a key
-- Dusky binds (that belongs in the ledger), may not be a key Omarchy binds (that
-- needs a remap row, not a quiet override), and may not be a key an Omarchy
-- action is already being moved onto.

local M = {}

M.rows = {
  {
    key = "SUPER + SHIFT + ESCAPE",
    description = "Kill window (click)",
    command = "hyprctl kill",
    locked = true,
    reason = "Kept from this port's first release; Dusky has no click-to-kill binding.",
  },
}

function M.keys()
  local keys = {}
  for _, row in ipairs(M.rows) do keys[#keys + 1] = row.key end
  return keys
end

-- Returns a list of problems, empty when every extra is the port's own to bind.
function M.audit(ledger, omarchy, remaps)
  local problems = {}
  local dusky, targets, seen = {}, {}, {}

  for _, row in ipairs(ledger.rows) do dusky[row.key] = row.status end
  for _, target in ipairs(remaps.targets()) do targets[target] = true end

  for _, row in ipairs(M.rows) do
    if type(row.key) ~= "string" or row.key == "" then
      problems[#problems + 1] = "an extra has no key"
    elseif seen[row.key] then
      problems[#problems + 1] = "two extras on the same key: " .. row.key
    else
      seen[row.key] = true
      if dusky[row.key] then
        problems[#problems + 1] = row.key .. ": Dusky binds this key, so it belongs in the ledger, not here"
      end
      if omarchy.occupied(row.key) then
        problems[#problems + 1] = row.key .. ": Omarchy binds this key, so it needs a remap row, not an extra"
      end
      if targets[row.key] then
        problems[#problems + 1] = row.key .. ": an Omarchy action is already moved onto this key"
      end
      if type(row.description) ~= "string" or row.description == "" then
        problems[#problems + 1] = row.key .. ": an extra needs a description"
      end
      if not row.command and not row.dsp then
        problems[#problems + 1] = row.key .. ": an extra needs a command or a dispatcher"
      end
      if type(row.reason) ~= "string" or row.reason == "" then
        problems[#problems + 1] = row.key .. ": an extra needs a reason"
      end
    end
  end

  return problems
end

return M
