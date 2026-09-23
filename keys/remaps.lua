-- keys/remaps.lua -- the Omarchy actions this port displaces, and where they go.
--
-- The toggle offers a curated set of Dusky bindings. Some of those keys already
-- carried an Omarchy binding, and the rule is that Omarchy's action moves rather
-- than disappears: "you switched to Dusky keys and lost the keybindings menu" is
-- not an acceptable outcome, and neither is the old failure of parking that menu
-- on a key Dusky owns.
--
--   Two kinds of row:
--
--   kind = "selected"  Omarchy's action is already available on the target,
--                      because the target is Dusky's own key for that same
--                      action (Dusky binds window split on SUPER + Y, so
--                      Omarchy's split needs no new key). `shared` records the
--                      token that has to appear on both sides to call them the
--                      same action.
--   kind = "moved"     The port binds Omarchy's action on the target itself in
--                      dusky mode, with Omarchy's own dispatcher, taken from
--                      keys/omarchy-shipped.lua. Nothing is copied by hand, so
--                      an Omarchy update moves the dispatcher here too.
--
-- Every target was chosen to stay close to the key it replaces, and remaps exist
-- only in dusky mode: omarchy mode is stock Omarchy with every action back on its
-- original key.
--
-- M.audit() is the gate. It fails on a collided selected key with no remap, a
-- remap whose source is not a collided selected key, a target that is already
-- taken, two remaps landing on one key, an Omarchy action moved onto a key Dusky
-- binds, or a "selected" row whose target does not actually share the action.

local keysym = require("keysym")

local M = {}

M.rows = {
  {
    omarchy = "Toggle window split",
    from = "SUPER + J",
    to = "SUPER + Y",
    kind = "selected",
    shared = "togglesplit",
    reason = "Dusky binds window split on SUPER + Y, so both modes agree on where split lives and no key is taken.",
  },
  {
    omarchy = "Keybindings",
    from = "SUPER + K",
    to = "CTRL + SHIFT + SPACE",
    kind = "selected",
    shared = "omarchy-menu-keybindings",
    reason = "Dusky's own key for showing keybinds, and free in Omarchy.",
  },
  {
    omarchy = "Toggle workspace layout",
    from = "SUPER + L",
    to = "SUPER + SHIFT + CTRL + L",
    kind = "moved",
    reason = "Keeps the L, one modifier step further out, and free in Omarchy.",
  },
  {
    omarchy = "Focus on left window",
    from = "SUPER + LEFT",
    to = "SUPER + h",
    kind = "selected",
    shared = "focus",
    reason = "Dusky's focus key for that direction.",
  },
  {
    omarchy = "Focus on right window",
    from = "SUPER + RIGHT",
    to = "SUPER + l",
    kind = "selected",
    shared = "focus",
    reason = "Dusky's focus key for that direction.",
  },
  {
    omarchy = "Focus on above window",
    from = "SUPER + UP",
    to = "SUPER + k",
    kind = "selected",
    shared = "focus",
    reason = "Dusky's focus key for that direction.",
  },
  {
    omarchy = "Focus on below window",
    from = "SUPER + DOWN",
    to = "SUPER + j",
    kind = "selected",
    shared = "focus",
    reason = "Dusky's focus key for that direction.",
  },
  {
    omarchy = "Tmux keybindings",
    from = "SUPER + ALT + K",
    to = "SUPER + CTRL + ALT + K",
    kind = "moved",
    reason = "Stays in the keybindings family around K, and free in Omarchy.",
  },
  {
    omarchy = "Next workspace",
    from = "SUPER + TAB",
    to = "SUPER + SHIFT + TAB",
    kind = "selected",
    shared = "e+1",
    reason = "Dusky binds next workspace on SUPER + SHIFT + TAB, so the action keeps a key that already means it.",
  },
  {
    omarchy = "Previous workspace",
    from = "SUPER + SHIFT + TAB",
    to = "SUPER + CTRL + SHIFT + TAB",
    kind = "moved",
    reason = "Dusky's previous-workspace key is SUPER + TAB, which now means the last-used workspace, so Omarchy's relative previous step keeps its TAB at one more modifier.",
  },
  {
    omarchy = "Toggle scratchpad",
    from = "SUPER + S",
    to = "SUPER + CTRL + ALT + S",
    kind = "moved",
    reason = "Stays in the S family with the scratchpad moves, and free in Omarchy.",
  },
  {
    omarchy = "Move window to scratchpad",
    from = "SUPER + ALT + S",
    to = "SUPER + ALT + SHIFT + S",
    kind = "moved",
    reason = "Keeps the S family together next to the scratchpad toggle, and free in Omarchy.",
  },
  {
    omarchy = "Toggle window floating/tiling",
    from = "SUPER + T",
    to = "SUPER + ALT + T",
    kind = "moved",
    reason = "Keeps the T, one modifier step further out, and free in Omarchy.",
  },
}

-- The keys the port binds in dusky mode beyond the selected Dusky set: the
-- targets it moves an Omarchy action onto. This union is the set either mode has
-- to clear, so switching back cannot leave a remap behind.
function M.targets()
  local keys = {}
  for _, remap in ipairs(M.rows) do
    if remap.kind == "moved" then keys[#keys + 1] = remap.to end
  end
  return keys
end

-- Every key this port owns: the selected Dusky set plus the moved-onto keys.
function M.owned(ledger)
  local keys, seen = {}, {}
  local function add(key)
    if not seen[key] then
      seen[key] = true
      keys[#keys + 1] = key
    end
  end
  for _, row in ipairs(ledger.selected()) do add(row.key) end
  for _, key in ipairs(M.targets()) do add(key) end
  return keys
end

-- Compare the remap table against the ledger and Omarchy's shipped bindings.
-- Returns a list of problems, empty when every displaced action has exactly one
-- landing place that is genuinely free and genuinely the same action.
function M.audit(ledger, omarchy)
  local problems = {}

  local selected = {}
  for _, row in ipairs(ledger.selected()) do selected[keysym.normalise(row.key)] = row end
  local in_ledger = {}
  for _, row in ipairs(ledger.rows) do in_ledger[keysym.normalise(row.key)] = row end

  local by_from, by_to = {}, {}
  for _, remap in ipairs(M.rows) do
    local from, to = keysym.normalise(remap.from), keysym.normalise(remap.to)
    if by_from[from] then
      problems[#problems + 1] = "two remaps move the same Omarchy binding: " .. remap.from
    else
      by_from[from] = remap
    end
    if by_to[to] then
      problems[#problems + 1] = "two remaps land on the same key: " .. remap.to
    else
      by_to[to] = remap
    end
  end

  -- Every collided selected key has a landing place, and every remap row moves
  -- something that is really there.
  for key, row in pairs(selected) do
    if omarchy.occupied(key) and not by_from[key] then
      problems[#problems + 1] = "selected key collides with an Omarchy binding but has no remap: " .. row.key
    end
  end

  for _, remap in ipairs(M.rows) do
    local from = keysym.normalise(remap.from)
    if not selected[from] then
      problems[#problems + 1] = remap.from .. ": remap source is not a selected Dusky key"
    elseif not omarchy.occupied(from) then
      problems[#problems + 1] = remap.from .. ": remap source is not bound by Omarchy"
    else
      local named = false
      for _, binding in ipairs(omarchy.for_key(from)) do
        if binding.description == remap.omarchy then named = true end
      end
      if not named then
        problems[#problems + 1] = string.format(
          "%s: Omarchy no longer describes that binding as %q", remap.from, remap.omarchy)
      end
    end

    local to = keysym.normalise(remap.to)
    if remap.kind == "selected" then
      local target = selected[to]
      if not target then
        problems[#problems + 1] = remap.to .. ": kind=selected, but that key is not in the selected Dusky set"
      elseif not remap.shared then
        problems[#problems + 1] = remap.to .. ": kind=selected needs a shared token to prove it is the same action"
      else
        local spec = target.cmd or target.dsp or ""
        if not spec:find(remap.shared, 1, true) then
          problems[#problems + 1] = string.format(
            "%s: the selected binding (%s) does not contain %q, so it is not the same action",
            remap.to, spec, remap.shared)
        end
        local in_omarchy = false
        for _, binding in ipairs(omarchy.for_key(from)) do
          if binding.dispatch and binding.dispatch:find(remap.shared, 1, true) then in_omarchy = true end
        end
        if not in_omarchy then
          problems[#problems + 1] = string.format(
            "%s: Omarchy's dispatcher for that action no longer contains %q", remap.from, remap.shared)
        end
      end
    elseif remap.kind == "moved" then
      if in_ledger[to] then
        problems[#problems + 1] = remap.to .. ": an Omarchy action must never be moved onto a key Dusky binds"
      end
      -- Free, outright. Another remap's source counts as taken here: it is
      -- occupied by Omarchy until this port vacates it, and stacking two moves
      -- on one key is how a landing place stops being one.
      if omarchy.occupied(to) then
        problems[#problems + 1] = remap.to .. ": the remap target is already bound by Omarchy"
      end
      if by_from[to] then
        problems[#problems + 1] = remap.to .. ": the remap target is another remap's source"
      end
      if type(remap.reason) ~= "string" or remap.reason == "" then
        problems[#problems + 1] = remap.to .. ": a moved remap needs a reason"
      end
    else
      problems[#problems + 1] = remap.to .. ": unknown remap kind " .. tostring(remap.kind)
    end
  end

  return problems
end

return M
