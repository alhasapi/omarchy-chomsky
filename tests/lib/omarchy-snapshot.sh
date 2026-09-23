#!/bin/bash
# omarchy-snapshot: regenerate the pinned snapshot of Omarchy's shipped
# keybindings, or check the installed Omarchy against the one committed.
#
#   tests/lib/omarchy-snapshot.sh --check            # no writes; exits 1 on drift
#   tests/lib/omarchy-snapshot.sh [omarchy-root]     # rewrite keys/omarchy-shipped.lua
#
# The toggle has to know two things about Omarchy that only Omarchy can tell it:
# which keys are *taken* (so a remap target is never parked on top of a shipped
# binding) and, for the keys the port displaces, what Omarchy's own binding was
# (so omarchy mode can put it back). Both come from this snapshot.
#
# It is a snapshot rather than a runtime read because a plugin must not parse
# another config on every reload. The cost is drift, and the cure is --check:
# t_upstream.sh runs it, so an Omarchy update that adds, moves, renames or
# re-dispatches a binding fails the suite until the snapshot is regenerated.
#
# Extraction is Lua: the bindings are multi-line calls, three of them generated
# by loops, and the third argument is an arbitrary Lua expression that has to be
# kept verbatim for omarchy mode to restore. A line-based grep cannot do that;
# a small parser can. Loop expressions are reduced to literals and then
# evaluated, so `"SUPER + " .. key` with `key = "code:" .. tostring(n + 9)`
# becomes `SUPER + code:10` exactly, without a second, guessed copy of the loop.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_DIR
readonly SNAPSHOT="$REPO_DIR/keys/omarchy-shipped.lua"

err() { echo "omarchy-snapshot: $*" >&2; }

usage() {
  cat >&2 << EOF
Usage: omarchy-snapshot [--check] [omarchy-root]

  --check        Compare the installed Omarchy with the committed snapshot.
                 Writes nothing. Exits 1 when a binding was added, removed,
                 renamed, moved or given a different dispatcher.
  (none)         Rewrite $SNAPSHOT from the installed Omarchy.

omarchy-root defaults to \$OMARCHY_PATH, then /usr/share/omarchy.
EOF
  exit 2
}

check_only=false
if [[ "${1:-}" == "--check" ]]; then
  check_only=true
  shift
fi
[[ $# -le 1 ]] || usage

root="${1:-${OMARCHY_PATH:-/usr/share/omarchy}}"
bindings_dir="$root/default/hypr/bindings"
[[ -d "$bindings_dir" ]] || {
  err "no $bindings_dir -- Omarchy is not installed there"
  exit 2
}

if ! command -v lua > /dev/null 2>&1; then
  echo "omarchy-snapshot: lua is not installed, cannot read the bindings" >&2
  exit 3
fi

version="$(cat "$root/version" 2> /dev/null || echo unknown)"

work="$(mktemp -d "${TMPDIR:-/tmp}/omarchy-snapshot.XXXXXX")"
trap 'rm -rf "$work"' EXIT

BINDINGS_DIR="$bindings_dir" lua - > "$work/shipped.tsv" << 'LUA'
-- Read Omarchy's binding modules and print one tab-separated row per binding:
--   key <TAB> description <TAB> kind <TAB> dispatch <TAB> flags
-- `dispatch` and `flags` are the source text of the call's third and fourth
-- arguments, empty when they cannot be re-evaluated as an expression (a
-- multi-statement function body), in which case kind is "opaque".
--
-- Rows keep file order, which keeps the generated file diffable: regenerating
-- after an Omarchy update shows exactly what moved.

local dir = assert(os.getenv("BINDINGS_DIR"), "BINDINGS_DIR is not set")

local function read(path)
  local file = assert(io.open(path, "r"))
  local text = file:read("a")
  file:close()
  return text
end

local function files()
  local names = {}
  local pipe = assert(io.popen("ls -1 " .. dir))
  for name in pipe:lines() do
    if name:match("%.lua$") then names[#names + 1] = dir .. "/" .. name end
  end
  pipe:close()
  table.sort(names)
  return names
end

-- Whole-line comments only: a `--` inside an expression is not a comment. The
-- commented-out examples in these files must not be read as live bindings.
local function strip_comments(text)
  text = text:gsub("[\n][ \t]*%-%-[^\n]*", "\n")
  return (text:gsub("^[ \t]*%-%-[^\n]*", ""))
end

-- Split a call's arguments on top-level commas, ignoring commas inside strings
-- and brackets. Needed because the third argument is arbitrary Lua.
local function split_args(text)
  local args, depth, start = {}, 0, 1
  local i, n = 1, #text
  local quote = nil
  while i <= n do
    local c = text:sub(i, i)
    if quote then
      if c == "\\" then i = i + 1
      elseif c == quote then quote = nil end
    elseif c == '"' or c == "'" then
      quote = c
    elseif c == "(" or c == "{" or c == "[" then
      depth = depth + 1
    elseif c == ")" or c == "}" or c == "]" then
      depth = depth - 1
    elseif c == "," and depth == 0 then
      args[#args + 1] = text:sub(start, i - 1)
      start = i + 1
    end
    i = i + 1
  end
  args[#args + 1] = text:sub(start)
  for index, value in ipairs(args) do args[index] = value:gsub("^%s+", ""):gsub("%s+$", "") end
  return args
end

-- Find `o.bind(...)` / `o.bind_toggle(...)` calls and hand back their argument
-- text, by scanning to the matching close paren.
local function find_calls(text)
  local calls = {}
  local pos = 1
  while true do
    local s, e, name = text:find("o%.(bind_toggle)%s*%(", pos)
    local s2, e2 = text:find("o%.bind%s*%(", pos)
    if s2 and (not s or s2 < s) then s, e, name = s2, e2, "bind" end
    if not s then break end
    -- e is the index of the opening paren itself, so the arguments start after
    -- it, at a depth of 1: the call's own close paren is the one that returns to 0.
    local depth, i, quote = 1, e + 1, nil
    while i <= #text do
      local c = text:sub(i, i)
      if quote then
        if c == "\\" then i = i + 1
        elseif c == quote then quote = nil end
      elseif c == '"' or c == "'" then
        quote = c
      elseif c == "(" then
        depth = depth + 1
      elseif c == ")" then
        depth = depth - 1
        if depth == 0 then break end
      end
      i = i + 1
    end
    calls[#calls + 1] = { kind = name, args = split_args(text:sub(e + 1, i - 1)), span = { s, i } }
    pos = i
  end
  return calls
end

-- Evaluate an expression that is expected to be pure literals. Inside a loop
-- the loop variable and the body's own locals are declared first, so the key is
-- evaluated exactly as Lua would evaluate it: `"SUPER + " .. key` with
-- `local key = "code:" .. tostring(n + 9)` becomes `SUPER + code:10`, with no
-- second, guessed copy of the loop arithmetic. Anything that is not evaluable
-- (a free variable, a function call) is an error rather than a wrong key.
local function eval_expr(text, what, loop)
  local prefix = ""
  if loop then
    prefix = "local " .. loop.name .. " = " .. loop.value .. "\n" .. loop.decls .. "\n"
  end
  local chunk, load_err = load(prefix .. "return " .. text)
  if not chunk then
    error(string.format("cannot evaluate %s %q: %s", what, text, tostring(load_err)), 0)
  end
  local ok, value = pcall(chunk)
  if not ok then
    error(string.format("cannot evaluate %s %q: %s", what, text, tostring(value)), 0)
  end
  return value
end

local function row(key, desc, kind, dispatch, flags)
  if key == nil then return end
  local out = { key = tostring(key), desc = desc and tostring(desc) or "(none)", kind = kind }
  local body = dispatch and dispatch:gsub("%s+", " ")
  if body and body ~= "" and not body:match("^function") then
    -- flags are only meaningful for a real dispatcher; keep them verbatim.
    local flagtext = (flags and flags ~= "" and flags ~= "nil") and flags or nil
    if flagtext and flagtext:match("^%s*{.*}%s*$") then
      out.dispatch, out.flags = body, flagtext:gsub("%s+", " ")
    else
      out.dispatch = body
    end
  else
    out.kind = "opaque"
  end
  return out
end

local rows, seen_loops = {}, {}

-- The `local` declarations a loop body makes before its first bind call, kept
-- verbatim for eval_expr's prefix so a key built from a local resolves exactly
-- the way it does in the config.
local function loop_decls(body)
  local decls = ""
  for line in (body .. "\n"):gmatch("[^\n]*\n") do
    if line:find("o%%.bind") then break end
    if line:match("^%s*local%s+") then decls = decls .. line end
  end
  return decls
end

local function parse(text, into, loop)
  for _, call in ipairs(find_calls(text)) do
    local args = call.args
    local key = args[1] and eval_expr(args[1], "key", loop)
    local desc = args[2] and args[2] ~= "nil" and eval_expr(args[2], "description", loop) or nil
    local row_out = row(key, desc, call.kind, args[3], args[4])
    if row_out then into[#into + 1] = row_out end
  end
end

for _, path in ipairs(files()) do
  local text = strip_comments(read(path))

  -- Loops first, and remember their spans so the plain pass does not read them
  -- a second time with an unsubstituted variable in the key.
  local cursor = 1
  while true do
    local s, e, name, from, to = text:find("for%s+([%w_]+)%s*=%s*(%d+)%s*,%s*(%d+)%s+do", cursor)
    if not s then break end
    local body_end = text:find("\nend", e)
    local body = text:sub(e + 1, (body_end or #text) - 1)
    local decls = loop_decls(body)
    seen_loops[#seen_loops + 1] = { path = path, name = name, from = tonumber(from), to = tonumber(to) }
    for value = tonumber(from), tonumber(to) do
      local ok, err = pcall(parse, body, rows, { name = name, value = value, decls = decls })
      if not ok then error(string.format("%s: loop %s=%d: %s", path, name, value, tostring(err)), 0) end
    end
    text = text:sub(1, s - 1) .. string.rep(" ", e - s + 1) .. text:sub((body_end or #text) + 4)
    cursor = 1
  end

  parse(text, rows)
end

for _, entry in ipairs(rows) do
  -- One escape point, and it covers everything a Lua string literal needs.
  -- Tab and newline have to go too: the row has to survive a TSV line.
  local function escape(s)
    return (s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\t", "\\t"):gsub("\n", "\\n"))
  end
  io.write(table.concat({
    escape(entry.key), escape(entry.desc), entry.kind,
    escape(entry.dispatch or ""), escape(entry.flags or ""),
  }, "\t"), "\n")
end
LUA

if [[ ! -s "$work/shipped.tsv" ]]; then
  err "read no bindings out of $bindings_dir"
  exit 1
fi

# --- render the snapshot ----------------------------------------------------
# --- render the snapshot ----------------------------------------------------
# A path can hold a quote or a backslash, and it is about to go inside a Lua
# string literal: escape it rather than assume the shape of the directory.
lua_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

{
  # Quoted, so a backtick or a $ in the prose below is never read as shell.
  cat << 'EOF'
-- keys/omarchy-shipped.lua -- the pinned snapshot of Omarchy's keybindings.
--
-- Two questions the toggle cannot answer without Omarchy: which keys are
-- already taken (a remap target must never land on one) and what Omarchy's own
-- binding was on a key the port displaces (omarchy mode must put it back
-- exactly). Both are answered here, as data.
--
-- Regenerate after an Omarchy update:
--   tests/lib/omarchy-snapshot.sh
-- Check the installed Omarchy against it:
--   tests/lib/omarchy-snapshot.sh --check
--
-- `dispatch` and `flags` are the source text of the binding's third and fourth
-- arguments, kept verbatim so chomsky_keys.lua can rebuild exactly that
-- dispatcher with load() in omarchy mode. kind = "opaque" means the argument was
-- a multi-statement function and is kept for the key-occupancy check only.

local M = {}
EOF
  printf 'M.root = "%s"\n' "$(lua_string "$root")"
  printf 'M.version = "%s"\n' "$(lua_string "$version")"
  cat << 'EOF'

-- Comparison, not binding: Hyprland resolves keysym names case-insensitively, so
-- `SUPER + j` here and `SUPER + J` in a snapshot are one key. Binding always uses
-- a source's own spelling; only the "is this key taken?" question normalises.
local keysym = require("keysym")

M.bindings = {
EOF
  awk -F'\t' '{
    printf "  { key = \"%s\", description = \"%s\", kind = \"%s\"", $1, $2, $3
    if ($4 != "") {
      printf ", dispatch = \"%s\"", $4
      if ($5 != "") printf ", flags = \"%s\"", $5
    }
    printf " },\n"
  }' "$work/shipped.tsv"
  cat << 'EOF'
}

-- The set of keys Omarchy ships, for "is this key free?" questions. Built once
-- on load: a key bound twice (Omarchy does that for swap-and-raise pairs) is
-- still one entry. Keys are normalised, so a caller can ask about `SUPER + j`
-- and get the truth about Omarchy's `SUPER + J`.
local occupied = {}
for _, binding in ipairs(M.bindings) do occupied[keysym.normalise(binding.key)] = true end

function M.occupied(key)
  return occupied[keysym.normalise(key)] == true
end

-- Every binding Omarchy ships on a key, in file order. A list, not a lookup:
-- the port has to restore all of them, not assume there is one.
function M.for_key(key)
  local out = {}
  for _, binding in ipairs(M.bindings) do
    if keysym.equal(binding.key, key) then out[#out + 1] = binding end
  end
  return out
end

-- The shipped binding for a key, as a value chomsky_keys.lua can hand straight
-- to o.bind(): { key, description, dispatch, flags }, one entry per shipped bind.
-- Returns nil when Omarchy ships nothing there, and raises when the binding
-- cannot be rebuilt -- which the suite treats as drift, because omarchy mode
-- would then silently fail to put Omarchy's binding back.
--
-- `env` is what the dispatcher source is evaluated against; it defaults to the
-- globals, which is where `hl` lives when the toggle runs. Tests pass a stub.
function M.restore(key, env)
  local bindings = M.for_key(key)
  if #bindings == 0 then return nil end
  env = env or _G
  local out = {}
  for _, binding in ipairs(bindings) do
    if not binding.dispatch then
      error(string.format("omarchy-shipped: %s is a %s binding and cannot be restored", key, binding.kind), 0)
    end
    local chunk, load_err = load("return " .. binding.dispatch, "restore:" .. key, "t", env)
    if not chunk then
      error(string.format("omarchy-shipped: %s has an unloadable dispatcher: %s", key, tostring(load_err)), 0)
    end
    local ok, value = pcall(chunk)
    if not ok then
      error(string.format("omarchy-shipped: %s dispatcher failed: %s", key, tostring(value)), 0)
    end
    local flags
    if binding.flags then
      local flag_chunk = assert(load("return " .. binding.flags, "flags:" .. key, "t", env))
      flags = flag_chunk()
    end
    out[#out + 1] = { key = binding.key, description = binding.description, dispatch = value, flags = flags }
  end
  return out
end

return M
EOF
} > "$work/omarchy-shipped.lua"

# --- compare or install ----------------------------------------------------
if [[ "$check_only" == true ]]; then
  # The root and version lines are environment, not contract: a different
  # install path or version is expected. A different binding is not.
  strip() { sed -e 's/^M\.root = .*/M.root = (ignored)/' -e 's/^M\.version = .*/M.version = (ignored)/' "$1"; }
  if diff -u <(strip "$SNAPSHOT") <(strip "$work/omarchy-shipped.lua") > "$work/diff"; then
    echo "omarchy-snapshot: installed Omarchy matches the committed snapshot ($version)"
    exit 0
  fi
  err "the installed Omarchy bindings differ from $SNAPSHOT"
  cat "$work/diff" >&2
  echo >&2
  err "regenerate with: tests/lib/omarchy-snapshot.sh"
  err "then re-check keys/remaps.lua targets and any restored binding in keys/chomsky_keys.lua"
  exit 1
fi

cp "$work/omarchy-shipped.lua" "$SNAPSHOT"
echo "omarchy-snapshot: wrote $SNAPSHOT ($(wc -l < "$work/shipped.tsv") bindings at $version)"
