# Chomsky

A single Omarchy plugin that manages a [Dusky](https://github.com/dusklinux/dusky)-derived
look & feel: 12 Hyprland animation presets, 17 screen shaders, border-resize
and inactive-window dimming, monitor rotation, DPMS, wallpaper cycling across
the active theme and your own `~/Pictures`, and a switch between Omarchy's
keybindings and Dusky's. Everything is bundled -- no edits to your own
`~/.config/hypr/*.lua` files required.

It is built to be driven from the **Omarchy menu** rather than from the bar.
Every action has a row under **Style**, and the panel behind them is a centered
overlay in the same shape as Omarchy's own menu -- so nothing has to sit on the
bar for the plugin to be usable. The chip is opt-in:
`bin/chomsky-bar on` puts it on, `off` takes it off again.

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

Enabling a plugin with a bar widget puts that widget on the bar -- Omarchy's
choice, not the plugin's. If you would rather have the plugin without the chip,
take it off:

```bash
~/.config/omarchy/plugins/alhasapi.chomsky/bin/chomsky-bar off
```

## What it does

| Section | What it does |
|---|---|
| **Animation** | Switch or cycle through 12 Dusky animation presets (dusky, bounce, fade, mechanical, slowmotion, disable, …) |
| **Shader** | Switch or cycle through 17 GLSL screen shaders (tints, grayscale, vignette, chromatic aberration, …), or turn them off |
| **Window behavior** | Toggle border/gap resize with the bare cursor (no modifier) plus inactive-window dimming, with a strength slider |
| **Keybindings** | Switch between Omarchy's shipped bindings and a curated 43-key Dusky set, with every displaced Omarchy binding moved to a documented key (see below) |
| **Display** | Rotate the focused monitor 90° either way; DPMS screen off |
| **Wallpaper** | Cycle to the previous/next background across the active theme and `~/Pictures`, or pick one from a thumbnail grid |

Every one of those is available three ways: from the Omarchy menu (each gets its
own row under **Style**), from the panel (Style > **Chomsky panel**, or
`omarchy-shell shell toggle alhasapi.chomsky`), and from the CLIs in `bin/`.
The panel is the mouse-friendly view -- animation/shader dropdowns, the
dim-strength slider, the keybinding toggle, the wallpaper picker -- and it opens
centered on the focused monitor with a scrim over everything else, the way the
Omarchy menu does.

If you also want the chip on the bar, it shows the animation and shader at a
glance: its ring lights up (accent color) while a shader is active, its tooltip
lists the current animation, shader, theme and keybinding mode, and clicking it
opens the same panel.

## The panel

The panel is a full-screen overlay with the card centered in it: one layer
surface, a scrim, and the same colors, radius, padding and border spec the
Omarchy menu uses. It is summoned from the menu, or directly:

```bash
omarchy-shell shell toggle alhasapi.chomsky
```

Because the card is centered rather than hanging off a bar icon, it is as tall
as its content -- with the leftover space as its margin -- and scrolls only if
the screen is too short for that. (A popup anchored to a bar widget is capped by
the distance from the bar to the screen edge instead, which silently cut off
whatever did not fit.)

The card's rows are Animations, Shader, Window Behavior, Keybindings, Display
and Wallpaper. The switch for the bar chip sits at the top of the card, on the
trailing edge of the header, where Omarchy's own panels (bluetooth, network,
dropbox) put their power switches.

Keyboard: `j`/`k` or the arrows move the cursor, `Enter` activates, `Esc`
closes, and a click on the scrim closes. The animation and shader pickers are
type-to-search dropdowns.

There is no "reload Hyprland" row: everything here applies itself, and the
manual reload is one key away in the Dusky set (`SUPER + SHIFT + R`) and one
command away anywhere else (`hyprctl reload`).

## The bar chip

The chip is optional, and nothing else depends on it:

From the panel, the switch at the top right of the card; or from a terminal:

```bash
~/.config/omarchy/plugins/alhasapi.chomsky/bin/chomsky-bar on      # put it on the bar
~/.config/omarchy/plugins/alhasapi.chomsky/bin/chomsky-bar off     # take it off
~/.config/omarchy/plugins/alhasapi.chomsky/bin/chomsky-bar toggle  # whichever applies
```

`off` moves the widget's entry out of `bar.layout` and into shell.json's
top-level `plugins` array, which is what keeps the plugin enabled. Deleting the
entry from the bar by hand instead switches the whole plugin off: a third-party
bar widget counts as enabled only while it is either placed in the bar or listed
in `plugins` (see `PluginRegistry.findEntryLocation`). `off` writes the file
atomically, validates it first, and leaves a timestamped
`shell.json.bak.<epoch>` beside it. `chomsky-bar status` says which mode you are
in.

With no chip on the bar everything still works: the menu rows, the panel, the
keybinding switch, the wallpaper cycling, and the saved shader being restored at
login -- that last one lives in a service, not in the widget, precisely so it
survives the chip going away.

## Keybindings: Dusky or Omarchy

Style > **Keybindings** in the menu (or the panel's toggle) switches Hyprland
between Omarchy's stock bindings and a curated set of Dusky's:

| | |
|---|---|
| **Dusky** | 43 of Dusky's keys: vim navigation (`SUPER + H/J/K/L` focus, `SUPER + SHIFT + H/J/K/L` moves), arrows for resizing, group and workspace keys, this plugin's own menus (animations, shaders, rotation, DPMS, wallpapers, screenshots) and a handful of Dusky habits Omarchy has no key for |
| **Omarchy** | Stock Omarchy on every key -- including the 13 keys this port takes in dusky mode, which get Omarchy's own binding back |

Two rules make the switch predictable.

**The port is curated, not exhaustive.** Dusky binds 167 keys. Porting all of
them would drag in Dusky's own tooling -- Waybar, wayclick, its rofi menus,
control centre, TTS/STT, drive and snapshot managers -- and would displace most
of Omarchy's window management for no gain. So the port selects a binding when
all three hold: it **differs from what Omarchy does on that key**, it is
**implementable** here (an Omarchy command, a Hyprland dispatcher, or one of this
plugin's own commands), and **Omarchy does not already provide the same action on
another key**, so the port adds muscle memory rather than a second binding for
something that already has one. The selection is data, in
`keys/dusky-ledger.lua`: **43 selected, 124 left alone, each with its reason**,
and all 167 of Dusky's keys have a row. The audit fails if a Dusky key has no
row, so the boundary is a decision rather than an omission.

**Nothing Omarchy had is dropped.** Where a selected key already carries an
Omarchy binding, that action moves to a nearby key:

| Omarchy's action | Was on | Now on | How |
|---|---|---|---|
| Toggle window split | `SUPER + J` | `SUPER + Y` | Dusky already binds this action on `SUPER + Y` |
| Keybindings | `SUPER + K` | `CTRL + SHIFT + SPACE` | Dusky already binds this action on `CTRL + SHIFT + SPACE` |
| Toggle workspace layout | `SUPER + L` | `SUPER + SHIFT + CTRL + L` | Bound by this port on the new key, with Omarchy's own dispatcher |
| Focus on left window | `SUPER + LEFT` | `SUPER + h` | Dusky already binds this action on `SUPER + h` |
| Focus on right window | `SUPER + RIGHT` | `SUPER + l` | Dusky already binds this action on `SUPER + l` |
| Focus on above window | `SUPER + UP` | `SUPER + k` | Dusky already binds this action on `SUPER + k` |
| Focus on below window | `SUPER + DOWN` | `SUPER + j` | Dusky already binds this action on `SUPER + j` |
| Tmux keybindings | `SUPER + ALT + K` | `SUPER + CTRL + ALT + K` | Bound by this port on the new key, with Omarchy's own dispatcher |
| Next workspace | `SUPER + TAB` | `SUPER + SHIFT + TAB` | Dusky already binds this action on `SUPER + SHIFT + TAB` |
| Previous workspace | `SUPER + SHIFT + TAB` | `SUPER + CTRL + SHIFT + TAB` | Bound by this port on the new key, with Omarchy's own dispatcher |
| Toggle scratchpad | `SUPER + S` | `SUPER + CTRL + ALT + S` | Bound by this port on the new key, with Omarchy's own dispatcher |
| Move window to scratchpad | `SUPER + ALT + S` | `SUPER + ALT + SHIFT + S` | Bound by this port on the new key, with Omarchy's own dispatcher |
| Toggle window floating/tiling | `SUPER + T` | `SUPER + ALT + T` | Bound by this port on the new key, with Omarchy's own dispatcher |

Where the moved action is one Dusky already binds elsewhere, no new binding is
needed: Dusky binds window split on `SUPER + Y` and the keybindings menu on
`CTRL + SHIFT + SPACE`, so Omarchy's split and keybindings menu live there in
dusky mode. Where it is not, the port binds Omarchy's action on the new key with
**Omarchy's own dispatcher**, read out of `keys/omarchy-shipped.lua` rather than
copied by hand -- so when Omarchy changes a dispatcher, it changes here too.

Remaps exist only in dusky mode. "Omarchy" mode is stock Omarchy: every binding
back on its original key, and nothing of this port's left anywhere.

### The keys that are selected

| Key | Dusky's binding | Status | Bound to |
|---|---|---|---|
| `CTRL + SHIFT + SPACE` | Show Keybinds | equivalent | `omarchy-menu-keybindings` |
| `CTRL + SPACE` | Rofi Wallpaper Selector | ported | `chomsky wallpaper menu` |
| `SUPER + apostrophe` | Cycle Next Wallpaper | ported | `chomsky bg-next` |
| `SUPER + SHIFT + apostrophe` | Cycle Fav Wallpaper | deviation | `chomsky bg-prev` |
| `CTRL + ALT + R` | Rotate Screen Clockwise | ported | `chomsky rotate cw` |
| `CTRL + ALT + SHIFT + R` | Rotate Screen Anti-Clockwise | ported | `chomsky rotate ccw` |
| `ALT + F7` | Screen Off DPMS | ported | `dpms:off` *(locked)* |
| `ALT + F8` | Screen On DPMS | ported | `dpms:on` *(locked)* |
| `SUPER + SHIFT + R` | Reload Hyprland | ported | `chomsky reload` |
| `SUPER + ALT + S` | Shader Menu | ported | `chomsky shader menu` |
| `SUPER + ALT + X` | Disable Shader | ported | `chomsky shader off` |
| `SUPER + ALT + V` | Vibrant Shader | ported | `chomsky shader set 14_vibrance` |
| `SUPER + ALT + A` | Hyprland Animation Rofi Menu | ported | `chomsky anim menu` |
| `SUPER + period` | Toggle Opacity | ported | `wprop:opaque` *(locked)* |
| `SUPER + B` | Color Picker | equivalent | `pkill hyprpicker || hyprpicker -a` |
| `SUPER + S` | Quick Screenshot | equivalent | `omarchy-capture-region` |
| `SUPER + T` | OCR Selection | equivalent | `omarchy-capture-text` |
| `SUPER + N` | Notification History | equivalent | `omarchy-shell notifications showHistory` |
| `SUPER + ALT + D` | Clear Screen Notifications | equivalent | `omarchy-shell notifications dismissAll` |
| `SUPER + M` | Lock Screen | equivalent | `omarchy-system-lock` |
| `SUPER + Y` | Toggle Window Split | ported | `layout:togglesplit` |
| `SUPER + ALT + H` | Group Prev Tab | ported | `group:prev` |
| `SUPER + ALT + L` | Group Next Tab | ported | `group:next` |
| `SUPER + ALT + SHIFT + H` | Group Merge Left (create if none) | ported | `winto:l` |
| `SUPER + ALT + SHIFT + L` | Group Merge Right (create if none) | ported | `winto:r` |
| `SUPER + ALT + SHIFT + K` | Group Merge Up (create if none) | ported | `winto:u` |
| `SUPER + ALT + SHIFT + J` | Group Merge Down (create if none) | ported | `winto:d` |
| `SUPER + ALT + U` | Group Move Out (ungroup) | ported | `wout` |
| `SUPER + ALT + K` | Group Lock Toggle | ported | `group:lock` |
| `SUPER + h` | Focus Left | ported | `focus:l` |
| `SUPER + l` | Focus Right | ported | `focus:r` |
| `SUPER + k` | Focus Up | ported | `focus:u` |
| `SUPER + j` | Focus Down | ported | `focus:d` |
| `SUPER + SHIFT + h` | Move Left | ported | `wmove:l` *(repeating)* |
| `SUPER + SHIFT + l` | Move Right | ported | `wmove:r` *(repeating)* |
| `SUPER + SHIFT + k` | Move Up | ported | `wmove:u` *(repeating)* |
| `SUPER + SHIFT + j` | Move Down | ported | `wmove:d` *(repeating)* |
| `SUPER + right` | Resize Width + | ported | `resize:30:0` *(repeating)* |
| `SUPER + left` | Resize Width - | ported | `resize:-30:0` *(repeating)* |
| `SUPER + up` | Resize Height - | ported | `resize:0:-30` *(repeating)* |
| `SUPER + down` | Resize Height + | ported | `resize:0:30` *(repeating)* |
| `SUPER + TAB` | Last Workspace | ported | `ws:previous` *(repeating)* |
| `SUPER + SHIFT + TAB` | Cycle Next WS | ported | `ws:e+1` *(repeating)* |

### The keys that are left alone, and why

Every remaining Dusky binding, with the reason it is not ported. Each excluded
row names its own reason, and they fall into four kinds: Omarchy already does
exactly this on this key; Omarchy already does this same action on another key;
it is Dusky-only tooling with no Omarchy equivalent; or taking the key would
displace an Omarchy binding that matters more than the Dusky one -- the
cursor-zoom and cursor-size families, for instance, sit on Omarchy's
window-resizing keys.

| Why it is not ported | Keys |
|---|---|
| Omarchy binds SUPER + ALT + SPACE to the apps menu. | `ALT + SPACE` |
| Omarchy binds SUPER + CTRL + E to emojis. | `SUPER + CTRL + SPACE` |
| Omarchy binds SUPER + CTRL + Q and XF86Calculator to the calculator. | `SUPER + CTRL + SHIFT + SPACE` |
| Omarchy binds SUPER + SHIFT + CTRL + SPACE to the theme menu. | `SUPER + SHIFT + SPACE` |
| Omarchy binds SUPER + SPACE to the Omarchy menu, which fills the same role as Dusky's control centre. | `SUPER + SPACE` |
| Dusky-only system-overview panel; Omarchy has no equivalent. | `CTRL + ALT + SPACE` |
| Omarchy binds SUPER + ESCAPE and XF86PowerOff to the system menu. | `ALT + SHIFT + SPACE`, `ALT + F4` |
| Omarchy binds SUPER + CTRL + T to the activity monitor. | `CTRL + SHIFT + escape` |
| Omarchy binds SUPER + CTRL + W to the network panel. | `ALT + 1` |
| Omarchy binds SUPER + CTRL + B to the Bluetooth panel. | `ALT + 2` |
| Omarchy binds SUPER + CTRL + A to the audio panel. | `ALT + 3` |
| Part of Dusky's ALT + N quick-tool group; the wallpaper picker is selected on CTRL + SPACE. | `ALT + 4` |
| Dusky-only drive manager (browser volume lock). | `ALT + 5`, `ALT + SHIFT + 5` |
| Dusky-only game-mode submap that suspends keybindings. | `ALT + 6` |
| Dusky-only Waybar toggle. | `ALT + 9` |
| Dusky-only system-tray TUI. | `ALT + 0` |
| Dusky-only Waybar config swap. | `SUPER + ALT + W`, `SUPER + ALT + SHIFT + W` |
| Dusky-only quick panel. | `ALT + V` |
| Omarchy binds SUPER + SLASH to monitor scaling. | `SUPER + F` |
| Omarchy binds SUPER + ALT + SLASH to scaling down. | `SUPER + SHIFT + F` |
| Dusky-only process killer. | `SUPER + semicolon` |
| Dusky-only Wayclick key-press sounds. | `SUPER + U` |
| Dusky-only key-press OSD. | `SUPER + SHIFT + U` |
| Omarchy binds SUPER + SHIFT + M to launching and focusing Music; Dusky's special workspace is a Dusky-only construct. | `SUPER + SHIFT + M` |
| Global blur/opacity/shadow combo; the per-window toggle is selected on SUPER + period instead. | `SUPER + ALT + period` |
| Omarchy uses the SUPER + comma family for notifications. | `SUPER + comma` |
| Omarchy resizes windows with the SUPER + minus/equal family. | `SUPER + equal`, `SUPER + minus` |
| Omarchy binds SUPER + BACKSPACE to window transparency. | `SUPER + BACKSPACE` |
| Part of Omarchy's SHIFT + minus/equal window-resizing family. | `SUPER + SHIFT + equal`, `SUPER + SHIFT + minus` |
| Part of Dusky's cursor-size family, which collides with Omarchy's window resizing. | `SUPER + SHIFT + mouse_up`, `SUPER + SHIFT + mouse_down` |
| Omarchy binds SUPER + SHIFT + BACKSPACE to window gaps. | `SUPER + SHIFT + BACKSPACE` |
| Dusky-only terminal clipboard tool; Omarchy binds SUPER + V to universal paste. | `SUPER + V` |
| Omarchy binds PRINT to a full screenshot already. | `SHIFT + Print` |
| Same action as SUPER + S, which is selected. | `SUPER + SHIFT + S` |
| Omarchy binds PRINT to a screenshot already. | `Print` |
| Omarchy binds SUPER + CTRL + C to the capture menu. | `SHIFT + CTRL + ALT + space` |
| Omarchy binds ALT + PRINT to screen recording. | `ALT + R` |
| Dusky-only image search. | `SUPER + SHIFT + G` |
| Dusky-only game launcher. | `SUPER + ALT + G` |
| Dusky-only games TUI. | `SUPER + ALT + SHIFT + G` |
| Same action as SUPER + T, which is selected. | `SUPER + SHIFT + T` |
| Dusky-only LLM side panel. | `SUPER + ALT + O` |
| Dusky-only music recognition. | `SUPER + ALT + M` |
| Dusky-only text-to-speech. | `SUPER + O` |
| Dusky-only text-to-speech voice conversion. | `SUPER + SHIFT + O` |
| Dusky-only Parakeet speech-to-text; Omarchy binds SUPER + CTRL + X and F9 to dictation. | `SUPER + I` |
| Omarchy binds SUPER + ALT + F to full width, and SUPER + ALT + comma already invokes the last notification. | `SUPER + ALT + F` |
| Omarchy binds SUPER + W to close window; SUPER + C is universal copy, paired with SUPER + V and SUPER + X. | `SUPER + C` |
| Dusky-only focused-process killer. | `SUPER + SHIFT + C` |
| Omarchy binds SUPER + F to full screen. | `SUPER + A` |
| Omarchy binds SUPER + ALT + F to full width (maximized). | `SUPER + SHIFT + A` |
| Omarchy binds SUPER + O to pop a window out (float and pin); SUPER + X is universal cut. | `SUPER + X` |
| Omarchy binds SUPER + T to the float/tile toggle. | `SUPER + D` |
| Omarchy binds SUPER + P to pseudo window. | `SUPER + SHIFT + D` |
| Omarchy binds SUPER + G to the same group toggle. | `SUPER + G` |
| Omarchy binds ALT + SHIFT + TAB to focusing the previous window; Dusky's previous workspace also lives on SUPER + TAB. | `ALT + SHIFT + TAB` |
| Omarchy binds SUPER + scroll to the same workspace cycling. | `SUPER + mouse_down`, `SUPER + mouse_up` |
| Omarchy already binds toggle-scratchpad, remapped off SUPER + S by this port. | `SUPER + Z` |
| Omarchy already binds move-to-scratchpad, remapped off SUPER + ALT + S by this port. | `SUPER + SHIFT + Z` |
| Omarchy already binds this key to the equivalent workspace switch. | `SUPER + 1`, `SUPER + 2`, `SUPER + 3`, `SUPER + 4`, `SUPER + 5`, `SUPER + 6`, `SUPER + 7`, `SUPER + 8`, `SUPER + 9`, `SUPER + 0` |
| Omarchy already binds this key to the equivalent window-to-workspace move. | `SUPER + SHIFT + 1`, `SUPER + SHIFT + 2`, `SUPER + SHIFT + 3`, `SUPER + SHIFT + 4`, `SUPER + SHIFT + 5`, `SUPER + SHIFT + 6`, `SUPER + SHIFT + 7`, `SUPER + SHIFT + 8`, `SUPER + SHIFT + 9`, `SUPER + SHIFT + 0` |
| Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N. | `SUPER + ALT + 1`, `SUPER + ALT + 2`, `SUPER + ALT + 3`, `SUPER + ALT + 4`, `SUPER + ALT + 5`, `SUPER + ALT + 6`, `SUPER + ALT + 7`, `SUPER + ALT + 8`, `SUPER + ALT + 9`, `SUPER + ALT + 0` |
| Omarchy binds SUPER + mouse drag to moving a window. | `SUPER + mouse:272` |
| Omarchy binds SUPER + mouse drag to resizing a window. | `SUPER + mouse:273` |
| Omarchy binds the same key to the same action. | `XF86AudioRaiseVolume`, `XF86AudioLowerVolume`, `XF86AudioMute`, `XF86AudioMicMute`, `XF86MonBrightnessUp`, `XF86MonBrightnessDown`, `ALT + XF86AudioRaiseVolume`, `ALT + XF86AudioLowerVolume`, `ALT + XF86MonBrightnessUp`, `ALT + XF86MonBrightnessDown`, `XF86KbdBrightnessUp`, `XF86KbdBrightnessDown`, `XF86AudioNext`, `XF86AudioPrev`, `XF86AudioPlay`, `XF86AudioPause` |
| Dusky-only live-radio menu. | `SUPER + SHIFT + B` |
| Omarchy has no media-stop action; play/pause is on the other media keys. | `XF86AudioStop` |
| Omarchy binds SUPER + P to pseudo window; media play/pause is on the XF86 keys. | `SUPER + P` |
| Omarchy binds SHIFT + XF86AudioPause to switching media source. | `SUPER + SHIFT + P` |
| Omarchy binds XF86AudioMute to muting. | `ALT + P` |
| Dusky-only mono-audio toggle. | `ALT + M` |
| Omarchy binds SHIFT + XF86AudioMute to switching audio output. | `ALT + O` |
| Dusky-only input-source switcher. | `ALT + I` |
| Dusky-only audio studio and voice DSP. | `ALT + N` |
| Omarchy binds the same key to the calculator. | `XF86Calculator` |

### One binding that is not Dusky's at all

Click-to-kill is this port's own, not Dusky's: Dusky kills a process with
`SUPER + SHIFT + C` and has no click-to-kill key. It has shipped here since the
first port, so it lives in `keys/extras.lua` rather than disappearing in a
tidy-up, and `check` audits it like everything else.

| Key | What it does | Why it is here |
|---|---|---|
| `SUPER + SHIFT + ESCAPE` | Kill window (click) | Kept from this port's first release; Dusky has no click-to-kill binding. |

### The two keys that used to hold Omarchy's menus

An earlier version of this port parked Omarchy's keybindings menu and
workspace-layout toggle on `SUPER + SHIFT + K` and `SUPER + SHIFT + L`. Those are
Dusky's own keys -- Move Up and Move Right -- so that was taking them. The menus
now move out of Dusky's way instead (`SUPER + CTRL + ALT + K` and
`SUPER + SHIFT + CTRL + L`), and `SUPER + SHIFT + K` / `SUPER + SHIFT + L` are
Dusky's moves again.

### Checking the live keymap

```bash
bin/chomsky-keys            # the mode in force
bin/chomsky-keys dusky
bin/chomsky-keys omarchy
bin/chomsky-keys toggle
bin/chomsky-keys keys       # every key the switch touches (50 of them)
bin/chomsky-keys check      # compare the live keymap with the mode in force
bin/chomsky-keys reset      # drop the switch; leave your config in charge
```

`check` is the honest one. The mode is a file on disk, and a file can be right
while the session is wrong: a binding that failed to take, a leftover from the
other mode, another plugin holding a key this port thinks it owns. So `check`
reads `hyprctl binds -j` and compares. In dusky mode every selected key must
carry its Dusky binding, every remapped action must be live on its new key, and
no key this port owns may still be answering with an Omarchy action. In omarchy
mode Omarchy's own binding must be back on every key this port owns, and nothing
of this port's may remain. It exits non-zero and names each problem together
with what it thinks the cause is: an Omarchy default, your own config, or this
port. Every binding the port makes is described `Dusky: ...`, which is what
makes that readable rather than guessed.

### How the switch works

The switch is one generated file in Omarchy's own toggle directory
(`~/.local/state/omarchy/toggles/hypr/chomsky-keys.lua`), which
`default/hypr/toggles.lua` sources last on every `hyprctl reload` -- after
Omarchy's defaults *and* after your own `~/.config/hypr/bindings.lua`. Loading
last is what lets the mode settle the disagreement without editing either, and
what makes switching a reload rather than a logout. Both modes clear the same 50
keys first, so nothing can survive a switch in either direction.

`keys/chomsky_keys.lua` holds no decisions; it is a consumer of four data files:
`keys/dusky-ledger.lua` (what Dusky binds, and what is selected),
`keys/remaps.lua` (where displaced Omarchy actions go), `keys/extras.lua` (this
port's own binding) and `keys/omarchy-shipped.lua` (Omarchy's bindings, pinned
from `$OMARCHY_PATH/default/hypr/bindings/`).
`tests/lib/dusky-snapshot.sh` and `tests/lib/omarchy-snapshot.sh` regenerate the
two pinned snapshots, and their `--check` modes are what the test suite runs --
so an upstream move fails the suite instead of drifting quietly.

Nothing is touched until you switch for the first time: with no toggle file there
are no Chomsky bindings at all. If you had already ported some Dusky bindings into
your own `~/.config/hypr/bindings.lua`, **that section is obsolete now** -- this
plugin owns those keys, and `check` reports anything a hand-port leaves behind.
Delete it, or leave it and let the toggle win: it loads last either way.

## Omarchy menu rows

The plugin adds its own rows under **Style**, so everything above is reachable
from the keyboard-driven menu even when the bar is hidden or the chip is off:

```
Style
├── Chomsky panel                 the panel below (alias: `chomsky`)
├── Animation                     animation picker; ✓ unless the preset is `disable`
├── Shader
│   ├── Pick shader...            (alias: `shader`)
│   ├── Next shader / Previous shader
│   └── Turn off shader           hidden when no shader is active
├── Window Behavior               ✓ when border resize & dimming is on
│   ├── Toggle border resize & dim
│   └── Set dim strength...
├── Keybindings                  ✓ when the Dusky set is on
│   ├── Dusky keybindings        ✓ when active
│   ├── Omarchy keybindings      ✓ when active
│   └── Show current keybindings
├── Display Controls
│   ├── Rotate 90° Clockwise / Counter-Clockwise
│   └── Turn screen off (DPMS)
├── Wallpaper
│   ├── Previous background / Next background
│   └── Pick wallpaper...         thumbnail grid, active one highlighted
```

They are installed on shell start, as one marker-delimited block in
`~/.config/omarchy/extensions/omarchy-menu.jsonc` -- the file Omarchy provides
for exactly this. Turn them off (and keep them off) with either:

```bash
bin/chomsky-menu-install --remove                 # from a terminal
omarchy bar set alhasapi.chomsky menuRows false --json   # the widget setting
```

`bin/chomsky-menu-install --enable` brings them back; `--help` explains the
rest. The choice is saved in `~/.local/state/chomsky/menu-rows`, so it survives
plugin updates and restarts. With the chip on the bar, the `menuRows` widget
setting writes the same state.

The rows keep working while the plugin is disabled or the chip is off the bar;
they only stop once the plugin directory is deleted, at which point clicking one
cleans the stale block out of the menu and says so.

### Picking a wallpaper

`Pick wallpaper...` opens Omarchy's own thumbnail grid, with the active
wallpaper highlighted and a search field. It goes through Omarchy's
`omarchy-menu-images` front-end when the image list fits, and otherwise drives
the image-picker overlay with the *directories* and lets it enumerate them:

`omarchy-menu-images` hands the picker its whole image list base64-encoded in a
single command-line argument, and Linux caps one argument at 128 KiB. A
`~/Pictures` with a thousand photos in it reaches that, and the picker then
fails with `Argument list too long` instead of opening -- which is exactly what
happened here. Given directories, the overlay runs its own `list.sh` with no
size limit, at the cost of a few seconds of enumeration (one lookup per image)
before the grid appears. Both paths end the same way: the picker writes the
chosen path to a file and this plugin applies it with `omarchy-theme-bg-set`.

## How it stays out of your config

Animation presets, the window-behavior toggle, the keybinding switch and the
screen shader are all applied by writing to Omarchy's own toggle-flag directory
(`~/.local/state/omarchy/toggles/hypr/chomsky-*.lua`), which
`default/hypr/toggles.lua` sources on every `hyprctl reload` -- after your own
`looknfeel.lua`, so it always wins, with no `require()` line needed anywhere.

The shader belongs in that directory for a reason worth spelling out:
`decoration:screen_shader` set at runtime (with `hyprctl keyword`, or an
`hl.config` through `hyprctl eval`) is forgotten by the next reload -- and
plenty of things reload the config. Applied from a toggle file it survives
them, and `chomsky-shader current` reports what Hyprland actually has on rather
than what was last asked for, so the panel cannot claim a shader is running
while nothing is painted.

The menu-rows choice and the wallpaper/keybinding mode are recorded in
`~/.local/state/chomsky/`.

Two files outside the plugin directory, both reversible:

- `~/.config/omarchy/extensions/omarchy-menu.jsonc` -- the plugin's rows, in
  their own marker-delimited block, only while they are switched on.
- `~/.config/omarchy/shell.json` -- only if you use `chomsky-bar off|on`, which
  moves the chip's entry between `bar.layout` and `plugins`.

Worth knowing:

- That toggle-flag directory is Omarchy-managed **state**, not user config --
  an Omarchy update or migration could in principle clear it, which would
  silently revert the animation preset, window-behavior toggle and keybinding
  mode to Omarchy's defaults until you change them again. Nothing load-bearing
  lives there.
- `bin/chomsky-window`'s "on" state writes the *complete* Dusky-style config
  (border grab area, hover cursor, dim strength/special/around/modal, drag
  animation) rather than a diff, so it behaves the same on a machine that has
  never touched `looknfeel.lua`.

## CLIs

Each action is backed by a standalone script in `bin/`, usable from a terminal
or your own keybinds:

```
bin/chomsky-anim    {list,set <name>,current,next,prev,off,menu}
bin/chomsky-shader  {list,set <name>,off,toggle,current,next,prev,restore,menu}
bin/chomsky-window  {on [dim],off,toggle [dim],current}
bin/chomsky-keys    {dusky,omarchy,toggle,current,keys,check,reset}
bin/chomsky-monitor-rotate {cw,ccw}
bin/chomsky-wallpaper {list,current,next,prev,set <path>,menu}
bin/chomsky-bar     {on,off,toggle,status}
bin/chomsky-menu-install [--enable|--remove]
```

`bin/chomsky` is the single entry point the QML calls, so the plugin's QML
depends on that one script rather than on a dozen argv conventions.
`bin/chomsky-menu-entry` is the row-action dispatcher that
`chomsky-menu-install` copies into `~/.config/omarchy/extensions/` for the menu
rows to call.

`bin/chomsky-link` regenerates thin `~/.local/bin/omarchy-*` wrappers onto the
animation, shader, rotation and wallpaper CLIs, if you want them on `PATH` under
those names -- handy for keybinds. Safe to re-run any time.

## How it is put together

The plugin declares three entry points, and the split is what makes the chip
optional:

| | |
|---|---|
| `Service.qml` | `service` kind. Mounted whenever the plugin is enabled, placed or not. Owns the state the panel and the chip display, every CLI call, the shader restore at login, and the menu-row sync. |
| `Panel.qml` | `panel` kind. The centered overlay. A view only: it reads state from the service the host injects and calls its actions. Summoned and hidden by the host. |
| `BarWidget.qml` | `bar-widget` kind. The optional chip. Reads the same service, and asks the host to toggle the panel -- it does not own the panel. |

## Backgrounds and themes

Omarchy does not regenerate theme colors when the background changes. Its own
background switcher (`omarchy theme bg next`) symlinks the image and tells the
shell to show it -- no color path at all; colors change when you switch
*themes* (`omarchy theme set`), which also happens to pick a background for the
new theme. Chomsky's wallpaper cycling goes through the same
`omarchy-theme-bg-set`, so it behaves exactly like Style > Background, and
changing a background deliberately leaves your colors alone.

`aether` (a desktop theme generator, `aether --generate <wallpaper>`) is
installed but nothing in Omarchy calls it, so "generate a theme from this
wallpaper" is not an Omarchy behaviour this plugin could match. If you want it
as an explicit extra action, say so -- it belongs behind its own menu row rather
than on the wallpaper keys, since it renders every app's template.

Nothing announces a background change: Omarchy notifies when a *theme* switch
found no background (`No background was found for theme`), which is a different
path, and the plugin stays quiet.

## Tests

```bash
tests/run.sh                 # the whole suite, a few seconds, no session needed
tests/run.sh shader menu     # only groups whose name matches
tests/run.sh --with-qml      # also render the panel (needs a Wayland session)
tests/run.sh --list          # what would run
tests/run.sh --keep          # keep the sandboxes for inspection
bats tests/run.bats          # the same groups through bats (TAP, --filter)
```

Two rules keep the suite safe to run in a live session:

**Every test gets a throwaway `HOME`.** These scripts write into the user's own
config -- `shell.json`, the Omarchy menu extension, the Hyprland toggle
directory -- so a test using the real one would be a bug in itself. At the end
of a run the real files are hashed against a baseline taken at the start, and a
difference fails the run. That guard is itself tested (`t_safety.sh` breaks a
throwaway home and requires it to be noticed): a guard that has never been seen
to fail is not a guard.

**Every external command is a shim on `PATH`.** Nothing here may reload the real
Hyprland, change the real wallpaper or switch the real keybindings. The shims do
more than stub: `hyprctl` models the asymmetry the shader code depends on (a
reload re-reads the toggle directory and drops runtime values), so the original
"panel shows a shader that is not painted" bug can be reproduced in a test. A
shim asked for something it does not model fails loudly rather than quietly
succeeding. The `hyprctl` shim also serves a keymap, so the keybinding audit can
be run against a keymap the test writes -- a matching one and a broken one.

The keybinding tables are checked against their sources, not read. `t_keys.sh`
runs the real `keys/chomsky_keys.lua` under the stub and asserts what each mode
binds and clears; audits the ledger, remap and extras tables against both pinned
snapshots; and then breaks each thing those audits exist to catch (a key
dropped, a spelling drifted, a reason missing, a remap target taken or parked on
a Dusky key, a remap row deleted), because an assertion nobody has seen fail is
decoration. `t_upstream.sh` regenerates the Omarchy snapshot in a throwaway tree
with one binding renamed and another moved, and requires the check to notice
both.

| Group | What it holds |
| --- | --- |
| `t_safety.sh` | the shims shadow the real commands, and the real-home guard works |
| `t_lint.sh` | `shellcheck` and `shfmt` over every script (skipped if not installed) |
| `t_invariants.sh` | executable bits, manifest, Lua compiles, and the cross-file contracts: QML subcommands exist, watched state files are ones a script writes, menu rows point at scripts that exist |
| `t_shader.sh` | applied shader survives a reload, `current` reads Hyprland rather than a record, `restore` converges both ways |
| `t_anim.sh`, `t_window.sh` | presets and window behaviour, including "no toggle file means nothing is active" |
| `t_keys.sh` | runs the real tables under a stub `hl` API: no mode may bind a key it does not clear first, dusky mode must match the ledger and the remaps, omarchy mode must restore Omarchy's own bindings, and the tables must still catch nine deliberately broken variants |
| `t_bar.sh` | moving the chip preserves every other bar entry and the widget's own settings, and refuses a `shell.json` it cannot parse |
| `t_wallpaper.sh` | cycling, plus the picker's two routes and the 128 KiB argument it must never build |
| `t_menu.sh` | install is idempotent, ten concurrent installs leave one block, removal is clean, an unparseable row is refused |
| `t_status.sh` | every field the panel reads, each following its state rather than a memory of it |
| `t_upstream.sh` | the Omarchy interfaces this leans on, so an update that moves one fails here instead of quietly breaking a feature, plus the pinned Omarchy binding snapshot |
| `t_clis.sh` | rotation, DPMS, reload, and the `~/.local/bin` wrappers |
| `t_qml.sh` | the panel, rendered: the card fits its content, nothing is truncated, and every cursor index lights a control. Opt-in (`--with-qml`) |

One group is opt-in. `--with-qml` renders the real panel through quickshell, so
it needs a Wayland session -- a layer surface takes its size from the compositor,
which is where the card's height comes from. It shows the panel on the focused
monitor for about a second each run. The assertions are relative for that reason:
the theme is live, so what it checks is that the content ends where the card
does, not that it is 613 pixels tall.

Adding one: create `tests/t_<name>.sh`, source `tests/lib/common.sh`, call
`start_test`, use the `assert_*` helpers, call `finish_test`, and add a
`run_group t_<name>` line to `tests/run.bats` (a test there checks you did).

Not automated, deliberately: how the panel *looks*. Its geometry is checked (the
content fits the card, nothing is truncated), but optical alignment and visual
weight are not something a test can judge -- see *Not covered* below.

## Not covered

Per-app window-sizing and floating rules from the original Dusky port are
config-file territory (window rules in a `.lua` file), not something a plugin
should own -- add them to your own `~/.config/hypr/windows.lua` if you want
them. Click-to-kill is covered, but it is this port's own binding rather than
Dusky's -- see `keys/extras.lua`.

The pre-2.0 `theme-from-wallpaper` feature (generate a whole Omarchy theme from
an image with `matugen`) was dropped: Omarchy's own `Style > Theme` covers theme
switching, and this plugin now only cycles and picks backgrounds. It is still in
git history if you want it back. See *Backgrounds and themes* above for why a
background change does not regenerate colors on its own.

## License

MIT (see `LICENSE`). Animation presets and shaders ported from Dusky (MIT);
the bundled portrait icon is CC BY-SA 2.0. See `NOTICE`.
