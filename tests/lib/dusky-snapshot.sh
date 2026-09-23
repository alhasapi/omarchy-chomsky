#!/bin/bash
# dusky-snapshot: regenerate the pinned Dusky keybinding snapshot, or check a
# checkout against the one that is committed.
#
#   tests/lib/dusky-snapshot.sh --check <dusky-checkout>   # no writes; exits 1 on drift
#   tests/lib/dusky-snapshot.sh <dusky-checkout>           # rewrite keys/dusky-upstream.lua
#
# The snapshot is what makes "we cover all of Dusky" checkable: it is the list
# of keys Dusky binds, frozen at a revision, and keys/dusky-ledger.lua is
# audited against it. So when Dusky adds or renames a binding, this check fails
# until the snapshot is regenerated and the new key is classified in the ledger
# rather than quietly going missing from the port.
#
# The extraction is Lua, not awk: the bindings are multi-line calls with the
# dispatcher between the key and the description, and Lua patterns read that far
# more reliably than a line-based scanner. `lua` is already a test dependency
# (tests/t_keys.sh runs the real mode tables), and the check skips with a note
# when it is absent.
#
# What counts as a binding: `hl.bind("KEY", ...)`, `o.bind(...)` or Dusky's
# `cond_bind("KEY", ...)`, with the description on the same call. Whole-line
# `--` comments are dropped first, so the file's commented-out examples are not
# mistaken for live bindings.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_DIR
readonly SNAPSHOT="$REPO_DIR/keys/dusky-upstream.lua"
readonly UPSTREAM_REL=".config/hypr/source/keybinds.lua"

err() { echo "dusky-snapshot: $*" >&2; }

usage() {
  cat >&2 << EOF
Usage: dusky-snapshot [--check] <path-to-dusky-checkout>

  --check   Compare the checkout's key set with the committed snapshot.
            Writes nothing. Exits 1 when a key was added, removed or renamed.
  (none)    Rewrite $SNAPSHOT from the checkout.

The checkout must contain $UPSTREAM_REL.
EOF
  exit 2
}

check_only=false
if [[ "${1:-}" == "--check" ]]; then
  check_only=true
  shift
fi
[[ $# -eq 1 ]] || usage

checkout="$(cd "$1" 2> /dev/null && pwd)" || {
  err "not a directory: $1"
  exit 2
}
source_file="$checkout/$UPSTREAM_REL"
[[ -f "$source_file" ]] || {
  err "no $UPSTREAM_REL under $checkout -- is that a Dusky checkout?"
  exit 2
}

if ! command -v lua > /dev/null 2>&1; then
  echo "dusky-snapshot: lua is not installed, cannot read the bindings" >&2
  exit 3
fi

rev="$(git -C "$checkout" rev-parse HEAD 2> /dev/null || echo unknown)"

work="$(mktemp -d "${TMPDIR:-/tmp}/dusky-snapshot.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# --- extract (key, kind, description) tuples, in file order -----------------
SOURCE_FILE="$source_file" lua - > "$work/keys.tsv" << 'LUA'
-- Read Dusky's keybinds.lua and print one `key<TAB>kind<TAB>description` line
-- per live binding, first occurrence of a key winning, in file order.
local path = assert(os.getenv("SOURCE_FILE"), "SOURCE_FILE is not set")
local file = assert(io.open(path, "r"))
local source = file:read("a")
file:close()

-- Drop whole-line comments, the way the ledger's provenance does: the file
-- keeps commented-out example bindings and they must not be read as live.
source = source:gsub("[\n][ \t]*%-%-[^\n]*", "\n")
source = source:gsub("^[ \t]*%-%-[^\n]*", "")

-- `hl.bind(` / `o.bind(` / `cond_bind(` are the three call forms. A prefix
-- that is not one of those (as in `hl.unbind(` or a helper named `mybind(`) is
-- skipped rather than read as a binding. The prefix also names the kind:
-- `cond_bind` is Dusky's pass-through helper, the rest are plain bindings.
local function next_call(pos)
  local s, e, prefix, key = source:find('([%a_%.]*)bind%s*%(%s*"([^"]+)"', pos)
  while s do
    if prefix == "hl." or prefix == "o." or prefix == "cond_" then
      return s, e, prefix, key
    end
    s, e, prefix, key = source:find('([%a_%.]*)bind%s*%(%s*"([^"]+)"', e)
  end
  return nil
end

local seen, order, count = {}, {}, 0
local pos = 1
while true do
  local call_start, key_end, prefix, key = next_call(pos)
  if not call_start then break end
  count = count + 1

  local kind = (prefix == "cond_") and "cond" or "bind"

  -- The description belongs to this call, so only look as far as the next call.
  local next_start = next_call(key_end)
  local window = source:sub(key_end, (next_start or (#source + 1)) - 1)
  local desc = window:match('description%s*=%s*"([^"]*)"') or "(no description)"

  if not seen[key] then
    seen[key] = true
    order[#order + 1] = { key = key, kind = kind, desc = desc }
  end
  pos = key_end
end

for _, entry in ipairs(order) do
  io.write(entry.key, "\t", entry.kind, "\t", entry.desc, "\n")
end
io.stderr:write(string.format("dusky-snapshot: read %d binds, %d distinct keys\n", count, #order))
LUA

if [[ ! -s "$work/keys.tsv" ]]; then
  err "read no bindings out of $source_file"
  exit 1
fi

# --- render the snapshot ----------------------------------------------------
{
  cat << EOF
-- keys/dusky-upstream.lua -- the pinned snapshot of Dusky's keybinding set.
--
-- Dusky binds these keys in $UPSTREAM_REL. This file is data only: no
-- functions, no Hyprland API. keys/dusky-ledger.lua is checked against it,
-- so a key that appears or changes upstream is caught instead of quietly
-- missing from the port.
--
-- Regenerate after refreshing the checkout:
--   tests/lib/dusky-snapshot.sh <path-to-dusky-checkout>
--
--   repo  https://github.com/dusklinux/dusky
--   rev   $rev
--
-- Keys are kept in upstream file order. \`kind\` records how Dusky bound them:
-- "bind" for hl.bind, "cond" for cond_bind (Dusky's pass-through helper).

local M = {}

M.repo = "https://github.com/dusklinux/dusky"
M.rev = "$rev"
M.source = "$UPSTREAM_REL"

M.keys = {
EOF
  awk -F'\t' '{
    gsub(/\\/, "\\\\", $1); gsub(/"/, "\\\"", $1)
    gsub(/\\/, "\\\\", $3); gsub(/"/, "\\\"", $3)
    printf "  { key = \"%s\", action = \"%s\", kind = \"%s\" },\n", $1, $3, $2
  }' "$work/keys.tsv"
  cat << 'EOF'
}

return M
EOF
} > "$work/dusky-upstream.lua"

# --- compare or install ----------------------------------------------------
if [[ "$check_only" == true ]]; then
  # Only the key rows are compared. A different revision changes the header by
  # design; a different key set is the drift this check exists to catch.
  strip() { sed '/^M\.rev = /d; s/^--   rev   .*/--   rev   (ignored)/' "$1"; }
  if diff -u <(strip "$SNAPSHOT") <(strip "$work/dusky-upstream.lua") > "$work/diff"; then
    echo "dusky-snapshot: checkout matches the committed snapshot ($rev)"
    exit 0
  fi
  err "the checkout's bindings differ from $SNAPSHOT"
  cat "$work/diff" >&2
  echo >&2
  err "regenerate with: tests/lib/dusky-snapshot.sh $checkout"
  err "then classify any new key in keys/dusky-ledger.lua -- the ledger audit fails until you do"
  exit 1
fi

cp "$work/dusky-upstream.lua" "$SNAPSHOT"
echo "dusky-snapshot: wrote $SNAPSHOT ($(wc -l < "$work/keys.tsv") keys at $rev)"
