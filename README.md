# Chomsky

A single Omarchy bar plugin that manages a [Dusky](https://github.com/dusklinux/dusky)-derived
look & feel: 12 Hyprland animation presets, 17 screen shaders, border-resize
and inactive-window dimming, monitor rotation, DPMS, and wallpaper-driven
theme generation. Everything is bundled -- no edits to your own
`~/.config/hypr/*.lua` files required.

![Panel preview](preview.png)

## Install

```bash
omarchy plugin add https://github.com/alhasapi/omarchy-chomsky.git --enable --yes
```

Or by hand:

```bash
git clone https://github.com/alhasapi/omarchy-chomsky.git \
  ~/.config/omarchy/plugins/alhasapi.chomsky
omarchy-shell shell rescanPlugins
omarchy plugin enable alhasapi.chomsky
```

Click the portrait chip in the bar (or `omarchy-shell alhasapi.chomsky toggle`)
to open the panel.

### Wallpaper theming needs matugen

The "Theme from wallpaper" button shells out to `matugen`, an official-repo
package:

```bash
omarchy pkg add matugen
```

Everything else works with no extra packages.

## What's in the panel

| Section | What it does |
|---|---|
| **Animation** | Switch or cycle through 12 Dusky animation presets (dusky, bounce, fade, mechanical, slowmotion, disable, …) |
| **Shader** | Switch or cycle through 17 GLSL screen shaders (tints, grayscale, vignette, chromatic aberration, …), or turn them off |
| **Window behavior** | Toggle border/gap resize with the bare cursor (no modifier) plus inactive-window dimming, with a strength slider |
| **Display** | Rotate the focused monitor 90° either way; DPMS screen off |
| **Wallpaper** | Cycle to the next background in the current theme; generate + apply a new Omarchy theme from whatever wallpaper is currently set |

The bar chip's ring lights up (accent color) while a shader is active, and its
tooltip shows the current animation/shader/theme at a glance.

## How it stays out of your config

Animation presets and the window-behavior toggle are applied by writing to
Omarchy's own toggle-flag directory
(`~/.local/state/omarchy/toggles/hypr/chomsky-*.lua`), which
`default/hypr/toggles.lua` sources on every `hyprctl reload` -- after your own
`looknfeel.lua`, so it always wins, with no `require()` line needed anywhere.
Shaders and animation state are recorded in `~/.local/state/chomsky/`; the
shader restores itself on shell startup instead of needing a hook in
`~/.config/hypr/autostart.lua`.

Two things worth knowing:

- That toggle-flag directory is Omarchy-managed **state**, not user config --
  an Omarchy update or migration could in principle clear it, which would
  silently revert the animation preset and window-behavior toggle to Omarchy's
  defaults until you change them again from the panel. Nothing load-bearing
  lives there.
- `bin/chomsky-window`'s "on" state writes the *complete* Dusky-style config
  (border grab area, hover cursor, dim strength/special/around/modal, drag
  animation) rather than a diff, so it behaves the same on a machine that has
  never touched `looknfeel.lua`.

## CLIs

Each panel action is backed by a standalone script in `bin/`, usable directly
from a terminal or your own keybinds:

```
bin/chomsky-anim    {list,set <name>,current,next,prev,off,menu}
bin/chomsky-shader  {list,set <name>,off,toggle,current,next,prev,restore,menu}
bin/chomsky-window  {on [dim],off,toggle [dim],current}
bin/chomsky-monitor-rotate {cw,ccw}
bin/chomsky-theme-from-wallpaper <image> [--name NAME] [--light]
```

`bin/chomsky-link` regenerates thin `~/.local/bin/omarchy-*` wrappers onto
these (matching names from the original, pre-plugin CLIs), if you want them on
`PATH` under those names -- handy for keybinds. Safe to re-run any time.

### Optional keybinds

The plugin doesn't touch your `~/.config/hypr/bindings.lua` -- a plugin
editing your keybindings is more surprising than convenient, and it would
fight `omarchy refresh hyprland`. If you want Dusky's originals, add these
yourself (adjust to taste; every key below was free on stock Omarchy 4.0 /
Hyprland 0.56):

```lua
o.bind("SUPER + ALT + A", "Animation menu", "omarchy-anim menu")
o.bind("SUPER + ALT + X", "Shader menu", "omarchy-shader menu")
o.bind("CTRL + ALT + R", "Rotate screen CW", "omarchy-monitor-rotate cw")
o.bind("CTRL + ALT + SHIFT + R", "Rotate screen CCW", "omarchy-monitor-rotate ccw")
o.bind("ALT + F7", "Screen off (DPMS)", function()
  hl.timer(function() hl.dispatch(hl.dsp.dpms({ action = "disable" })) end, { timeout = 500, type = "oneshot" })
end, { locked = true })
o.bind("ALT + F8", "Screen on (DPMS)", function() hl.dispatch(hl.dsp.dpms({ action = "enable" })) end, { locked = true })
o.bind("SUPER + '", "Cycle background", "omarchy theme bg next")
o.bind("SUPER + SHIFT + '", "Theme from current background",
  "omarchy-theme-from-wallpaper \"$(readlink -f ~/.local/state/omarchy/current/background)\"")
```

(Requires `bin/chomsky-link` to have been run at least once, or spell out the
full `bin/chomsky-*` paths instead of the `omarchy-*` names above.)

### Menu rows

`bin/chomsky-menu-install` adds Style > Animation / Style > Shader rows to
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, reachable even when the bar
is hidden. Not run automatically -- if you want them:

```bash
~/.config/omarchy/plugins/alhasapi.chomsky/bin/chomsky-menu-install
```

`--remove` takes them back out.

## Not covered

Click-to-kill and per-app window-sizing/floating rules from the original
Dusky port are config-file territory (`hyprctl kill` bound to a key; window
rules in a `.lua` file), not something a bar plugin should own -- add them to
your own `~/.config/hypr/bindings.lua` / `windows.lua` if you want them.

## License

MIT (see `LICENSE`). Animation presets and shaders ported from Dusky (MIT);
the bundled portrait icon is CC BY-SA 2.0. See `NOTICE`.
