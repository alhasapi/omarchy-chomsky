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
M.root = "/usr/share/omarchy"
M.version = "4.0.0.alpha"

-- Comparison, not binding: Hyprland resolves keysym names case-insensitively, so
-- `SUPER + j` here and `SUPER + J` in a snapshot are one key. Binding always uses
-- a source's own spelling; only the "is this key taken?" question normalises.
local keysym = require("keysym")

M.bindings = {
  { key = "SUPER + RETURN", description = "Terminal", kind = "bind", dispatch = "{ omarchy = \"terminal\" }" },
  { key = "SUPER + SHIFT + RETURN", description = "Browser", kind = "bind", dispatch = "{ omarchy = \"browser\" }" },
  { key = "SUPER + SHIFT + F", description = "File manager", kind = "bind", dispatch = "{ omarchy = \"nautilus\" }" },
  { key = "SUPER + ALT + SHIFT + F", description = "File manager (cwd)", kind = "bind", dispatch = "{ omarchy = \"nautilus-cwd\" }" },
  { key = "SUPER + SHIFT + B", description = "Browser", kind = "bind", dispatch = "{ omarchy = \"browser\" }" },
  { key = "SUPER + SHIFT + ALT + B", description = "Browser (private)", kind = "bind", dispatch = "{ omarchy = \"browser --private\" }" },
  { key = "SUPER + SHIFT + N", description = "Editor", kind = "bind", dispatch = "{ omarchy = \"editor\" }" },
  { key = "SUPER + ALT + RETURN", description = "Tmux", kind = "bind", dispatch = "{ omarchy = \"terminal-tmux\" }" },
  { key = "SUPER + CTRL + RETURN", description = "Herdr", kind = "bind", dispatch = "{ omarchy = \"terminal-herdr\" }" },
  { key = "SUPER + SHIFT + M", description = "Music", kind = "bind", dispatch = "{ omarchy = \"spotify\" }" },
  { key = "SUPER + SHIFT + ALT + M", description = "Music TUI", kind = "bind", dispatch = "{ tui = \"cliamp\", focus = true }" },
  { key = "SUPER + SHIFT + D", description = "Docker", kind = "bind", dispatch = "{ tui = \"omarchy-launch-docker-tui\" }" },
  { key = "SUPER + SHIFT + G", description = "Signal", kind = "bind", dispatch = "{ omarchy = \"signal\" }" },
  { key = "SUPER + SHIFT + O", description = "Obsidian", kind = "bind", dispatch = "{ launch = \"obsidian\", focus = \"^obsidian$\" }" },
  { key = "SUPER + SHIFT + W", description = "Omawrite", kind = "bind", dispatch = "{ launch = \"omawrite\" }" },
  { key = "SUPER + SHIFT + SLASH", description = "Passwords", kind = "bind", dispatch = "{ omarchy = \"1password\" }" },
  { key = "SUPER + SHIFT + A", description = "ChatGPT", kind = "bind", dispatch = "{ webapp = \"https://chatgpt.com\" }" },
  { key = "SUPER + SHIFT + ALT + A", description = "Grok", kind = "bind", dispatch = "{ webapp = \"https://grok.com\" }" },
  { key = "SUPER + SHIFT + C", description = "Calendar", kind = "bind", dispatch = "{ webapp = \"https://app.hey.com/calendar/weeks/\" }" },
  { key = "SUPER + SHIFT + E", description = "Email", kind = "bind", dispatch = "{ webapp = \"https://app.hey.com\" }" },
  { key = "SUPER + SHIFT + ALT + E", description = "New email", kind = "bind", dispatch = "{ webapp = \"https://app.hey.com/messages/new?display=standalone&new_window=true\" }" },
  { key = "SUPER + SHIFT + Y", description = "YouTube", kind = "bind", dispatch = "{ webapp = \"https://youtube.com/\" }" },
  { key = "SUPER + SHIFT + ALT + G", description = "WhatsApp", kind = "bind", dispatch = "{ webapp = \"https://web.whatsapp.com/\", focus = true }" },
  { key = "SUPER + SHIFT + CTRL + G", description = "Google Messages", kind = "bind", dispatch = "{ webapp = \"https://messages.google.com/web/conversations\", focus = true }" },
  { key = "SUPER + SHIFT + P", description = "Google Photos", kind = "bind", dispatch = "{ webapp = \"https://photos.google.com/\", focus = true }" },
  { key = "SUPER + SHIFT + S", description = "Google Maps", kind = "bind", dispatch = "{ webapp = \"https://maps.google.com/\", focus = true }" },
  { key = "SUPER + SHIFT + X", description = "X", kind = "bind", dispatch = "{ webapp = \"https://x.com/\" }" },
  { key = "SUPER + SHIFT + ALT + X", description = "X Post", kind = "bind", dispatch = "{ webapp = \"https://x.com/compose/post\" }" },
  { key = "SUPER + C", description = "Universal copy", kind = "bind", dispatch = "universal_clipboard_shortcut(\"CTRL\", \"C\", \"CTRL\", \"Insert\")" },
  { key = "SUPER + V", description = "Universal paste", kind = "bind", dispatch = "universal_clipboard_shortcut(\"CTRL\", \"V\", \"SHIFT\", \"Insert\")" },
  { key = "SUPER + X", description = "Universal cut", kind = "bind", dispatch = "send_shortcut_once(\"CTRL\", \"X\")" },
  { key = "SUPER + CTRL + V", description = "Clipboard manager", kind = "bind", dispatch = "\"omarchy-shell shell toggle omarchy.clipboard\"" },
  { key = "XF86AudioRaiseVolume", description = "Volume up", kind = "bind", dispatch = "\"omarchy-audio-output-volume raise\"", flags = "{ locked = true, repeating = true }" },
  { key = "XF86AudioLowerVolume", description = "Volume down", kind = "bind", dispatch = "\"omarchy-audio-output-volume lower\"", flags = "{ locked = true, repeating = true }" },
  { key = "XF86AudioMute", description = "Mute", kind = "bind", dispatch = "\"omarchy-audio-output-volume mute-toggle\"", flags = "{ locked = true }" },
  { key = "XF86AudioMicMute", description = "Mute microphone", kind = "bind", dispatch = "\"omarchy-audio-input-mute\"", flags = "{ locked = true }" },
  { key = "XF86MonBrightnessUp", description = "Brightness up", kind = "bind", dispatch = "\"omarchy-brightness-display +5%\"", flags = "{ locked = true, repeating = true }" },
  { key = "XF86MonBrightnessDown", description = "Brightness down", kind = "bind", dispatch = "\"omarchy-brightness-display 5%-\"", flags = "{ locked = true, repeating = true }" },
  { key = "SHIFT + XF86MonBrightnessUp", description = "Brightness maximum", kind = "bind", dispatch = "\"omarchy-brightness-display 100%\"", flags = "{ locked = true, repeating = true }" },
  { key = "SHIFT + XF86MonBrightnessDown", description = "Brightness minimum", kind = "bind", dispatch = "\"omarchy-brightness-display 1%\"", flags = "{ locked = true, repeating = true }" },
  { key = "XF86KbdBrightnessUp", description = "Keyboard brightness up", kind = "bind", dispatch = "\"omarchy-brightness-keyboard up\"", flags = "{ locked = true, repeating = true }" },
  { key = "XF86KbdBrightnessDown", description = "Keyboard brightness down", kind = "bind", dispatch = "\"omarchy-brightness-keyboard down\"", flags = "{ locked = true, repeating = true }" },
  { key = "XF86KbdLightOnOff", description = "Keyboard backlight cycle", kind = "bind", dispatch = "\"omarchy-brightness-keyboard cycle\"", flags = "{ locked = true }" },
  { key = "XF86TouchpadToggle", description = "Toggle touchpad", kind = "bind_toggle", dispatch = "\"touchpad\"", flags = "{ locked = true }" },
  { key = "XF86TouchpadOn", description = "Enable touchpad", kind = "bind", dispatch = "\"omarchy-toggle-touchpad on\"", flags = "{ locked = true }" },
  { key = "XF86TouchpadOff", description = "Disable touchpad", kind = "bind", dispatch = "\"omarchy-toggle-touchpad off\"", flags = "{ locked = true }" },
  { key = "ALT + XF86AudioRaiseVolume", description = "Volume up precise", kind = "bind", dispatch = "\"omarchy-audio-output-volume +1\"", flags = "{ locked = true, repeating = true }" },
  { key = "ALT + XF86AudioLowerVolume", description = "Volume down precise", kind = "bind", dispatch = "\"omarchy-audio-output-volume -1\"", flags = "{ locked = true, repeating = true }" },
  { key = "ALT + XF86MonBrightnessUp", description = "Brightness up precise", kind = "bind", dispatch = "\"omarchy-brightness-display +1%\"", flags = "{ locked = true, repeating = true }" },
  { key = "ALT + XF86MonBrightnessDown", description = "Brightness down precise", kind = "bind", dispatch = "\"omarchy-brightness-display 1%-\"", flags = "{ locked = true, repeating = true }" },
  { key = "XF86AudioNext", description = "Next track", kind = "bind", dispatch = "\"omarchy-shell media next\"", flags = "{ locked = true }" },
  { key = "ALT + XF86AudioPlay", description = "Next track", kind = "bind", dispatch = "\"omarchy-shell media next\"", flags = "{ locked = true }" },
  { key = "XF86AudioPause", description = "Pause", kind = "bind", dispatch = "\"omarchy-shell media playPause\"", flags = "{ locked = true }" },
  { key = "XF86AudioPlay", description = "Play", kind = "bind", dispatch = "\"omarchy-shell media playPause\"", flags = "{ locked = true }" },
  { key = "XF86AudioPrev", description = "Previous track", kind = "bind", dispatch = "\"omarchy-shell media previous\"", flags = "{ locked = true }" },
  { key = "ALT + SHIFT + XF86AudioPlay", description = "Previous track", kind = "bind", dispatch = "\"omarchy-shell media previous\"", flags = "{ locked = true }" },
  { key = "XF86Eject", description = "Eject media", kind = "bind", dispatch = "\"eject\"", flags = "{ locked = true }" },
  { key = "SHIFT + XF86AudioMute", description = "Switch audio output", kind = "bind", dispatch = "\"omarchy-audio-output-switch\"", flags = "{ locked = true }" },
  { key = "SHIFT + XF86AudioPause", description = "Switch media source", kind = "bind", dispatch = "\"omarchy-audio-source-switch\"", flags = "{ locked = true }" },
  { key = "SHIFT + XF86AudioPlay", description = "Switch media source", kind = "bind", dispatch = "\"omarchy-audio-source-switch\"", flags = "{ locked = true }" },
  { key = "SUPER + code:10", description = "Switch to workspace 1", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:10", description = "Move window to workspace 1", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:10", description = "Move window silently to workspace 1", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + code:11", description = "Switch to workspace 2", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:11", description = "Move window to workspace 2", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:11", description = "Move window silently to workspace 2", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + code:12", description = "Switch to workspace 3", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:12", description = "Move window to workspace 3", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:12", description = "Move window silently to workspace 3", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + code:13", description = "Switch to workspace 4", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:13", description = "Move window to workspace 4", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:13", description = "Move window silently to workspace 4", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + code:14", description = "Switch to workspace 5", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:14", description = "Move window to workspace 5", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:14", description = "Move window silently to workspace 5", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + code:15", description = "Switch to workspace 6", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:15", description = "Move window to workspace 6", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:15", description = "Move window silently to workspace 6", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + code:16", description = "Switch to workspace 7", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:16", description = "Move window to workspace 7", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:16", description = "Move window silently to workspace 7", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + code:17", description = "Switch to workspace 8", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:17", description = "Move window to workspace 8", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:17", description = "Move window silently to workspace 8", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + code:18", description = "Switch to workspace 9", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:18", description = "Move window to workspace 9", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:18", description = "Move window silently to workspace 9", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + code:19", description = "Switch to workspace 10", kind = "bind", dispatch = "hl.dsp.focus({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + code:19", description = "Move window to workspace 10", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace) })" },
  { key = "SUPER + SHIFT + ALT + code:19", description = "Move window silently to workspace 10", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = tostring(workspace), follow = false })" },
  { key = "SUPER + ALT + code:10", description = "Switch to group window 1", kind = "bind", dispatch = "hl.dsp.group.active({ index = index })" },
  { key = "SUPER + ALT + code:11", description = "Switch to group window 2", kind = "bind", dispatch = "hl.dsp.group.active({ index = index })" },
  { key = "SUPER + ALT + code:12", description = "Switch to group window 3", kind = "bind", dispatch = "hl.dsp.group.active({ index = index })" },
  { key = "SUPER + ALT + code:13", description = "Switch to group window 4", kind = "bind", dispatch = "hl.dsp.group.active({ index = index })" },
  { key = "SUPER + ALT + code:14", description = "Switch to group window 5", kind = "bind", dispatch = "hl.dsp.group.active({ index = index })" },
  { key = "SUPER + W", description = "Close window", kind = "bind", dispatch = "hl.dsp.window.close()" },
  { key = "CTRL + ALT + DELETE", description = "Close all windows", kind = "bind", dispatch = "\"omarchy-hyprland-window-close-all\"" },
  { key = "SUPER + J", description = "Toggle window split", kind = "bind", dispatch = "hl.dsp.layout(\"togglesplit\")" },
  { key = "SUPER + P", description = "Pseudo window", kind = "bind", dispatch = "hl.dsp.window.pseudo()" },
  { key = "SUPER + T", description = "Toggle window floating/tiling", kind = "bind", dispatch = "hl.dsp.window.float({ action = \"toggle\" })" },
  { key = "SUPER + F", description = "Full screen", kind = "bind", dispatch = "hl.dsp.window.fullscreen({ mode = \"fullscreen\" })" },
  { key = "SUPER + CTRL + F", description = "Tiled full screen", kind = "bind", dispatch = "\"omarchy-hyprland-window-tiled-fullscreen-toggle\"" },
  { key = "SUPER + ALT + F", description = "Full width", kind = "bind", dispatch = "hl.dsp.window.fullscreen({ mode = \"maximized\" })" },
  { key = "SUPER + O", description = "Pop window out (float & pin)", kind = "bind", dispatch = "\"omarchy-hyprland-window-pop\"" },
  { key = "SUPER + ALT + Home", description = "Save window width", kind = "bind", dispatch = "\"omarchy-hyprland-window-width save\"" },
  { key = "SUPER + Home", description = "Restore window width", kind = "bind", dispatch = "\"omarchy-hyprland-window-width restore\"" },
  { key = "SUPER + L", description = "Toggle workspace layout", kind = "bind", dispatch = "\"omarchy-hyprland-workspace-layout-toggle\"" },
  { key = "SUPER + LEFT", description = "Focus on left window", kind = "bind", dispatch = "hl.dsp.focus({ direction = \"l\" })" },
  { key = "SUPER + RIGHT", description = "Focus on right window", kind = "bind", dispatch = "hl.dsp.focus({ direction = \"r\" })" },
  { key = "SUPER + UP", description = "Focus on above window", kind = "bind", dispatch = "hl.dsp.focus({ direction = \"u\" })" },
  { key = "SUPER + DOWN", description = "Focus on below window", kind = "bind", dispatch = "hl.dsp.focus({ direction = \"d\" })" },
  { key = "SUPER + S", description = "Toggle scratchpad", kind = "bind", dispatch = "hl.dsp.workspace.toggle_special(\"scratchpad\")" },
  { key = "SUPER + ALT + S", description = "Move window to scratchpad", kind = "bind", dispatch = "hl.dsp.window.move({ workspace = \"special:scratchpad\", follow = false })" },
  { key = "SUPER + TAB", description = "Next workspace", kind = "bind", dispatch = "hl.dsp.focus({ workspace = \"e+1\" })" },
  { key = "SUPER + SHIFT + TAB", description = "Previous workspace", kind = "bind", dispatch = "hl.dsp.focus({ workspace = \"e-1\" })" },
  { key = "SUPER + CTRL + TAB", description = "Former workspace", kind = "bind", dispatch = "hl.dsp.focus({ workspace = \"previous\" })" },
  { key = "SUPER + SHIFT + ALT + LEFT", description = "Move workspace to left monitor", kind = "bind", dispatch = "hl.dsp.workspace.move({ monitor = \"l\" })" },
  { key = "SUPER + SHIFT + ALT + RIGHT", description = "Move workspace to right monitor", kind = "bind", dispatch = "hl.dsp.workspace.move({ monitor = \"r\" })" },
  { key = "SUPER + SHIFT + ALT + UP", description = "Move workspace to up monitor", kind = "bind", dispatch = "hl.dsp.workspace.move({ monitor = \"u\" })" },
  { key = "SUPER + SHIFT + ALT + DOWN", description = "Move workspace to down monitor", kind = "bind", dispatch = "hl.dsp.workspace.move({ monitor = \"d\" })" },
  { key = "SUPER + SHIFT + LEFT", description = "Swap window to the left", kind = "bind", dispatch = "hl.dsp.window.swap({ direction = \"l\" })" },
  { key = "SUPER + SHIFT + RIGHT", description = "Swap window to the right", kind = "bind", dispatch = "hl.dsp.window.swap({ direction = \"r\" })" },
  { key = "SUPER + SHIFT + UP", description = "Swap window up", kind = "bind", dispatch = "hl.dsp.window.swap({ direction = \"u\" })" },
  { key = "SUPER + SHIFT + DOWN", description = "Swap window down", kind = "bind", dispatch = "hl.dsp.window.swap({ direction = \"d\" })" },
  { key = "ALT + TAB", description = "Focus on next window", kind = "bind", dispatch = "hl.dsp.window.cycle_next()" },
  { key = "ALT + SHIFT + TAB", description = "Focus on previous window", kind = "bind", dispatch = "hl.dsp.window.cycle_next({ next = false })" },
  { key = "ALT + TAB", description = "Reveal active window on top", kind = "bind", dispatch = "hl.dsp.window.bring_to_top()" },
  { key = "ALT + SHIFT + TAB", description = "Reveal active window on top", kind = "bind", dispatch = "hl.dsp.window.bring_to_top()" },
  { key = "CTRL + ALT + TAB", description = "Focus on next monitor", kind = "bind", dispatch = "hl.dsp.focus({ monitor = \"+1\" })" },
  { key = "CTRL + ALT + SHIFT + TAB", description = "Focus on previous monitor", kind = "bind", dispatch = "hl.dsp.focus({ monitor = \"-1\" })" },
  { key = "SUPER + code:20", description = "Expand window left", kind = "bind", dispatch = "hl.dsp.window.resize({ x = -100, y = 0, relative = true })" },
  { key = "SUPER + code:21", description = "Shrink window left", kind = "bind", dispatch = "hl.dsp.window.resize({ x = 100, y = 0, relative = true })" },
  { key = "SUPER + SHIFT + code:20", description = "Shrink window up", kind = "bind", dispatch = "hl.dsp.window.resize({ x = 0, y = -100, relative = true })" },
  { key = "SUPER + SHIFT + code:21", description = "Expand window down", kind = "bind", dispatch = "hl.dsp.window.resize({ x = 0, y = 100, relative = true })" },
  { key = "SUPER + ALT + code:20", description = "Expand window left a little", kind = "bind", dispatch = "hl.dsp.window.resize({ x = -25, y = 0, relative = true })" },
  { key = "SUPER + ALT + code:21", description = "Shrink window left a little", kind = "bind", dispatch = "hl.dsp.window.resize({ x = 25, y = 0, relative = true })" },
  { key = "SUPER + SHIFT + ALT + code:20", description = "Shrink window up a little", kind = "bind", dispatch = "hl.dsp.window.resize({ x = 0, y = -25, relative = true })" },
  { key = "SUPER + SHIFT + ALT + code:21", description = "Expand window down a little", kind = "bind", dispatch = "hl.dsp.window.resize({ x = 0, y = 25, relative = true })" },
  { key = "SUPER + CTRL + code:20", description = "Expand window left a lot", kind = "bind", dispatch = "hl.dsp.window.resize({ x = -300, y = 0, relative = true })" },
  { key = "SUPER + CTRL + code:21", description = "Shrink window left a lot", kind = "bind", dispatch = "hl.dsp.window.resize({ x = 300, y = 0, relative = true })" },
  { key = "SUPER + CTRL + SHIFT + code:20", description = "Shrink window up a lot", kind = "bind", dispatch = "hl.dsp.window.resize({ x = 0, y = -300, relative = true })" },
  { key = "SUPER + CTRL + SHIFT + code:21", description = "Expand window down a lot", kind = "bind", dispatch = "hl.dsp.window.resize({ x = 0, y = 300, relative = true })" },
  { key = "SUPER + mouse_down", description = "Scroll active workspace forward", kind = "bind", dispatch = "hl.dsp.focus({ workspace = \"e+1\" })" },
  { key = "SUPER + mouse_up", description = "Scroll active workspace backward", kind = "bind", dispatch = "hl.dsp.focus({ workspace = \"e-1\" })" },
  { key = "SUPER + mouse:272", description = "Move window", kind = "bind", dispatch = "hl.dsp.window.drag()", flags = "{ mouse = true }" },
  { key = "SUPER + mouse:273", description = "Resize window", kind = "bind", dispatch = "hl.dsp.window.resize()", flags = "{ mouse = true }" },
  { key = "SUPER + G", description = "Toggle window grouping", kind = "bind", dispatch = "hl.dsp.group.toggle()" },
  { key = "SUPER + ALT + G", description = "Move active window out of group", kind = "bind", dispatch = "hl.dsp.window.move({ out_of_group = true })" },
  { key = "SUPER + ALT + LEFT", description = "Move window to group on left", kind = "bind", dispatch = "hl.dsp.window.move({ into_group = \"l\" })" },
  { key = "SUPER + ALT + RIGHT", description = "Move window to group on right", kind = "bind", dispatch = "hl.dsp.window.move({ into_group = \"r\" })" },
  { key = "SUPER + ALT + UP", description = "Move window to group on top", kind = "bind", dispatch = "hl.dsp.window.move({ into_group = \"u\" })" },
  { key = "SUPER + ALT + DOWN", description = "Move window to group on bottom", kind = "bind", dispatch = "hl.dsp.window.move({ into_group = \"d\" })" },
  { key = "SUPER + ALT + TAB", description = "Next window in group", kind = "bind", dispatch = "hl.dsp.group.next()" },
  { key = "SUPER + ALT + SHIFT + TAB", description = "Previous window in group", kind = "bind", dispatch = "hl.dsp.group.prev()" },
  { key = "SUPER + CTRL + LEFT", description = "Move grouped window focus left", kind = "bind", dispatch = "hl.dsp.group.prev()" },
  { key = "SUPER + CTRL + RIGHT", description = "Move grouped window focus right", kind = "bind", dispatch = "hl.dsp.group.next()" },
  { key = "SUPER + ALT + mouse_down", description = "Next window in group", kind = "bind", dispatch = "hl.dsp.group.next()" },
  { key = "SUPER + ALT + mouse_up", description = "Previous window in group", kind = "bind", dispatch = "hl.dsp.group.prev()" },
  { key = "SUPER + SLASH", description = "Monitor scaling up", kind = "bind", dispatch = "\"omarchy-hyprland-monitor-scaling up\"" },
  { key = "SUPER + ALT + SLASH", description = "Monitor scaling down", kind = "bind", dispatch = "\"omarchy-hyprland-monitor-scaling down\"" },
  { key = "SUPER + CTRL + code:10", description = "Bar panel 1", kind = "bind", dispatch = "\"omarchy-shell -q shell togglePanelAt right \" .. panel" },
  { key = "SUPER + CTRL + code:11", description = "Bar panel 2", kind = "bind", dispatch = "\"omarchy-shell -q shell togglePanelAt right \" .. panel" },
  { key = "SUPER + CTRL + code:12", description = "Bar panel 3", kind = "bind", dispatch = "\"omarchy-shell -q shell togglePanelAt right \" .. panel" },
  { key = "SUPER + CTRL + code:13", description = "Bar panel 4", kind = "bind", dispatch = "\"omarchy-shell -q shell togglePanelAt right \" .. panel" },
  { key = "SUPER + CTRL + code:14", description = "Bar panel 5", kind = "bind", dispatch = "\"omarchy-shell -q shell togglePanelAt right \" .. panel" },
  { key = "SUPER + CTRL + code:15", description = "Bar panel 6", kind = "bind", dispatch = "\"omarchy-shell -q shell togglePanelAt right \" .. panel" },
  { key = "SUPER + CTRL + code:16", description = "Bar panel 7", kind = "bind", dispatch = "\"omarchy-shell -q shell togglePanelAt right \" .. panel" },
  { key = "SUPER + CTRL + code:17", description = "Bar panel 8", kind = "bind", dispatch = "\"omarchy-shell -q shell togglePanelAt right \" .. panel" },
  { key = "SUPER + CTRL + code:18", description = "Bar panel 9", kind = "bind", dispatch = "\"omarchy-shell -q shell togglePanelAt right \" .. panel" },
  { key = "SUPER + SPACE", description = "Omarchy menu", kind = "bind", dispatch = "\"omarchy-menu toggle\"" },
  { key = "SUPER + ALT + SPACE", description = "Apps menu", kind = "bind", dispatch = "\"omarchy-menu toggle apps\"" },
  { key = "SUPER + CTRL + E", description = "Emojis", kind = "bind", dispatch = "\"omarchy-shell shell toggle omarchy.emojis\"" },
  { key = "SUPER + CTRL + C", description = "Capture menu", kind = "bind", dispatch = "\"omarchy-menu toggle capture\"" },
  { key = "SUPER + CTRL + O", description = "Toggle menu", kind = "bind", dispatch = "\"omarchy-menu toggle toggle\"" },
  { key = "SUPER + CTRL + H", description = "Hardware menu", kind = "bind", dispatch = "\"omarchy-menu toggle hardware\"" },
  { key = "SUPER + SHIFT + code:201", description = "Omarchy menu", kind = "bind", dispatch = "\"omarchy-menu toggle root\"" },
  { key = "SUPER + ESCAPE", description = "System menu", kind = "bind", dispatch = "\"omarchy-menu toggle system\"" },
  { key = "XF86PowerOff", description = "Power menu", kind = "bind", dispatch = "\"omarchy-menu toggle system\"", flags = "{ locked = true }" },
  { key = "SUPER + K", description = "Keybindings", kind = "bind", dispatch = "\"omarchy-menu-keybindings\"" },
  { key = "SUPER + ALT + K", description = "Tmux keybindings", kind = "bind", dispatch = "\"omarchy-menu-tmux-keybindings\"" },
  { key = "SUPER + CTRL + K", description = "Herdr keybindings", kind = "bind", dispatch = "\"omarchy-menu-herdr-keybindings\"" },
  { key = "SUPER + CTRL + Q", description = "Calculator", kind = "bind", dispatch = "\"omacalc\"" },
  { key = "XF86Calculator", description = "Calculator", kind = "bind", dispatch = "\"omacalc\"" },
  { key = "SUPER + SHIFT + SPACE", description = "Toggle top bar", kind = "bind_toggle", dispatch = "\"bar\"" },
  { key = "SUPER + CTRL + SPACE", description = "Background switcher", kind = "bind", dispatch = "\"omarchy-menu toggle background\"" },
  { key = "SUPER + SHIFT + CTRL + SPACE", description = "Theme menu", kind = "bind", dispatch = "\"omarchy-menu toggle theme\"" },
  { key = "SUPER + BACKSPACE", description = "Toggle window transparency", kind = "bind", dispatch = "\"omarchy-hyprland-window-transparency-toggle\"" },
  { key = "SUPER + SHIFT + BACKSPACE", description = "Toggle window gaps", kind = "bind", dispatch = "\"omarchy-hyprland-window-gaps-toggle\"" },
  { key = "SUPER + CTRL + BACKSPACE", description = "Toggle single-window square aspect", kind = "bind", dispatch = "\"omarchy-hyprland-window-single-square-aspect-toggle\"" },
  { key = "SUPER + comma", description = "Dismiss last notification", kind = "bind", dispatch = "\"omarchy-shell notifications dismissOne\"" },
  { key = "SUPER + SHIFT + comma", description = "Dismiss all notifications", kind = "bind", dispatch = "\"omarchy-shell notifications dismissAll\"" },
  { key = "SUPER + CTRL + comma", description = "Toggle silencing notifications", kind = "bind_toggle", dispatch = "\"notification-silencing\"" },
  { key = "SUPER + ALT + comma", description = "Invoke last notification", kind = "bind", dispatch = "\"omarchy-shell notifications invokeLast\"" },
  { key = "SUPER + SHIFT + ALT + comma", description = "Open notification history", kind = "bind", dispatch = "\"omarchy-shell notifications showHistory\"" },
  { key = "SUPER + CTRL + I", description = "Toggle locking on idle", kind = "bind_toggle", dispatch = "\"idle\"" },
  { key = "SUPER + CTRL + N", description = "Toggle nightlight", kind = "bind_toggle", dispatch = "\"nightlight\"" },
  { key = "SUPER + CTRL + Delete", description = "Toggle laptop display", kind = "bind", dispatch = "\"omarchy-hyprland-monitor-internal toggle\"" },
  { key = "SUPER + CTRL + ALT + Delete", description = "Toggle laptop display mirroring", kind = "bind", dispatch = "\"omarchy-hyprland-monitor-internal-mirror toggle\"" },
  { key = "switch:on:Lid Switch", description = "(none)", kind = "bind", dispatch = "\"omarchy-system-lid-close\"", flags = "{ locked = true }" },
  { key = "switch:off:Lid Switch", description = "(none)", kind = "bind", dispatch = "\"omarchy-hyprland-monitor-clamshell\"", flags = "{ locked = true }" },
  { key = "PRINT", description = "Screenshot", kind = "bind", dispatch = "\"omarchy-capture-screenshot\"" },
  { key = "ALT + PRINT", description = "Screenrecording", kind = "bind", dispatch = "\"omarchy-capture-screenrecording --stop-recording || omarchy-menu toggle trigger.capture.screenrecord\"" },
  { key = "SUPER + ALT + code:34", description = "Make webcam overlay smaller", kind = "bind", dispatch = "\"omarchy-capture-webcam-resize smaller\"" },
  { key = "SUPER + ALT + code:35", description = "Make webcam overlay larger", kind = "bind", dispatch = "\"omarchy-capture-webcam-resize larger\"" },
  { key = "SUPER + PRINT", description = "Color picker", kind = "bind", dispatch = "\"pkill hyprpicker || hyprpicker -a\"" },
  { key = "SUPER + CTRL + PRINT", description = "Extract text (OCR) from screenshot", kind = "bind", dispatch = "\"omarchy-capture-text\"" },
  { key = "SUPER + CTRL + S", description = "Share", kind = "bind", dispatch = "\"omarchy-menu toggle share\"" },
  { key = "SUPER + CTRL + PERIOD", description = "Transcode", kind = "bind", dispatch = "\"omarchy-transcode\"" },
  { key = "SUPER + CTRL + R", description = "Set reminder", kind = "bind", dispatch = "\"omarchy-menu toggle reminder-set\"" },
  { key = "SUPER + CTRL + ALT + R", description = "Show reminders", kind = "bind", dispatch = "\"omarchy-reminder show\"" },
  { key = "SUPER + SHIFT + CTRL + R", description = "Clear reminders", kind = "bind", dispatch = "\"omarchy-reminder clear\"" },
  { key = "SUPER + CTRL + ALT + T", description = "Show time", kind = "bind", dispatch = "\"omarchy-notification-time\"" },
  { key = "SUPER + CTRL + ALT + B", description = "Show battery remaining", kind = "bind", dispatch = "\"omarchy-notification-battery\"" },
  { key = "SUPER + CTRL + ALT + W", description = "Toggle weather", kind = "bind", dispatch = "\"omarchy-notification-weather\"" },
  { key = "SUPER + SHIFT + CTRL + A", description = "Agent", kind = "bind", dispatch = "\"omarchy-agent --pick\"" },
  { key = "SUPER + CTRL + A", description = "Audio", kind = "bind", dispatch = "\"omarchy-shell shell toggle omarchy.audio\"" },
  { key = "SUPER + CTRL + B", description = "Bluetooth", kind = "bind", dispatch = "\"omarchy-shell shell toggle omarchy.bluetooth\"" },
  { key = "SUPER + CTRL + D", description = "Display", kind = "bind", dispatch = "\"omarchy-shell shell toggle omarchy.monitor\"" },
  { key = "SUPER + CTRL + ALT + D", description = "Calendar", kind = "bind", dispatch = "\"omarchy-shell shell toggle omarchy.clock\"" },
  { key = "SUPER + CTRL + W", description = "Network", kind = "bind", dispatch = "\"omarchy-shell shell toggle omarchy.network\"" },
  { key = "SUPER + CTRL + P", description = "Power", kind = "bind", dispatch = "\"omarchy-shell shell toggle omarchy.power\"" },
  { key = "SUPER + CTRL + T", description = "Activity", kind = "bind", dispatch = "{ tui = \"btop\" }" },
  { key = "SUPER + CTRL + Z", description = "Zoom in", kind = "opaque" },
  { key = "SUPER + CTRL + ALT + Z", description = "Reset zoom", kind = "opaque" },
  { key = "SUPER + CTRL + L", description = "Lock system", kind = "bind", dispatch = "\"omarchy-system-lock\"" },
  { key = "SUPER + CTRL + X", description = "Toggle dictation", kind = "bind", dispatch = "\"voxtype record toggle\"" },
  { key = "F9", description = "Start dictation (push-to-talk)", kind = "bind", dispatch = "\"voxtype record start\"" },
  { key = "F9", description = "Stop dictation (push-to-talk)", kind = "bind", dispatch = "\"voxtype record stop\"", flags = "{ release = true }" },
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
