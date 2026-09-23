-- keys/dusky-ledger.lua -- every key Dusky binds, and what this port does with it.
--
-- The toggle offers a curated set of Dusky bindings, not all of them. This
-- ledger is the whole decision, one row per key, so the selection is explicit:
--
--   status = "selected"  the port binds this key in dusky mode
--     kind = "ported"      Dusky's action, implemented here
--     kind = "equivalent"  the same action, reusing Omarchy's implementation
--     kind = "deviation"   deliberately different, with a reason
--     cmd / dsp / flags    the binding, resolved by chomsky_keys.lua
--   status = "excluded"  the port leaves this key alone, with a reason
--
-- The selection rule, stated so it can be checked rather than guessed: a Dusky
-- binding is selected when all three hold --
--
--   1. it differs from what Omarchy does *on that key*, so taking it is not a
--      no-op;
--   2. it is implementable here, with an Omarchy command, a Hyprland dispatcher,
--      or one of this plugin's own commands;
--   3. Omarchy does not already provide the same action on another key, so the
--      port adds muscle memory instead of a second binding for something that
--      already has one.
--
-- Everything that fails the rule is excluded for one of four reasons, and every
-- excluded row names its own: Omarchy already does exactly this on this key;
-- Omarchy already does this same action on another key; it is Dusky-only tooling
-- with no Omarchy equivalent; or taking the key would displace an Omarchy binding
-- that matters more than the Dusky one (the cursor-zoom and cursor-size families,
-- for instance, sit on Omarchy's window-resizing keys).
--
-- Where a selected key collides with an Omarchy binding, the Omarchy action is
-- moved rather than dropped: see keys/remaps.lua. Bindings this port adds that
-- are neither Dusky's nor a displaced Omarchy action are in keys/extras.lua.
--
-- Checked against the pinned snapshot by M.audit(), tests/t_keys.sh and
-- `chomsky-keys check`.

local M = {}

M.rev = "47e7a113a87136b7de8f30965560d1b692e56788"
M.kinds = { "ported", "equivalent", "deviation" }

M.rows = {
  { key = "ALT + SPACE", dusky = "Launch Menu for Apps", status = "excluded", reason = "Omarchy binds SUPER + ALT + SPACE to the apps menu." },
  { key = "CTRL + SHIFT + SPACE", dusky = "Show Keybinds", status = "selected", kind = "equivalent", cmd = "omarchy-menu-keybindings", reason = "reuses Omarchy's keybindings menu" },
  { key = "SUPER + CTRL + SPACE", dusky = "Search Emojis", status = "excluded", reason = "Omarchy binds SUPER + CTRL + E to emojis." },
  { key = "SUPER + CTRL + SHIFT + SPACE", dusky = "Calculator", status = "excluded", reason = "Omarchy binds SUPER + CTRL + Q and XF86Calculator to the calculator." },
  { key = "SUPER + SHIFT + SPACE", dusky = "Matugen Theme Config", status = "excluded", reason = "Omarchy binds SUPER + SHIFT + CTRL + SPACE to the theme menu." },
  { key = "CTRL + SPACE", dusky = "Rofi Wallpaper Selector", status = "selected", kind = "ported", cmd = "chomsky wallpaper menu" },
  { key = "SUPER + SPACE", dusky = "System Menu", status = "excluded", reason = "Omarchy binds SUPER + SPACE to the Omarchy menu, which fills the same role as Dusky's control centre." },
  { key = "CTRL + ALT + SPACE", dusky = "Dusky Glance", status = "excluded", reason = "Dusky-only system-overview panel; Omarchy has no equivalent." },
  { key = "ALT + SHIFT + SPACE", dusky = "Power Menu", status = "excluded", reason = "Omarchy binds SUPER + ESCAPE and XF86PowerOff to the system menu." },
  { key = "CTRL + SHIFT + escape", dusky = "System Monitor", status = "excluded", reason = "Omarchy binds SUPER + CTRL + T to the activity monitor." },
  { key = "ALT + 1", dusky = "Wi-Fi Manager", status = "excluded", reason = "Omarchy binds SUPER + CTRL + W to the network panel." },
  { key = "ALT + 2", dusky = "Bluetooth Manager", status = "excluded", reason = "Omarchy binds SUPER + CTRL + B to the Bluetooth panel." },
  { key = "ALT + 3", dusky = "Audio Mixer", status = "excluded", reason = "Omarchy binds SUPER + CTRL + A to the audio panel." },
  { key = "ALT + 4", dusky = "Dusky Wallpaper Selector", status = "excluded", reason = "Part of Dusky's ALT + N quick-tool group; the wallpaper picker is selected on CTRL + SPACE." },
  { key = "SUPER + apostrophe", dusky = "Cycle Next Wallpaper", status = "selected", kind = "ported", cmd = "chomsky bg-next" },
  { key = "SUPER + SHIFT + apostrophe", dusky = "Cycle Fav Wallpaper", status = "selected", kind = "deviation", cmd = "chomsky bg-prev", reason = "Dusky cycles through favourite wallpapers here; the port steps to the previous wallpaper instead, because favourites are a Dusky-only concept." },
  { key = "ALT + 5", dusky = "Unlock Browser", status = "excluded", reason = "Dusky-only drive manager (browser volume lock)." },
  { key = "ALT + SHIFT + 5", dusky = "Lock Browser", status = "excluded", reason = "Dusky-only drive manager (browser volume lock)." },
  { key = "ALT + 6", dusky = "Enable Game Mode (Disable Keybinds)", status = "excluded", reason = "Dusky-only game-mode submap that suspends keybindings." },
  { key = "CTRL + ALT + R", dusky = "Rotate Screen Clockwise", status = "selected", kind = "ported", cmd = "chomsky rotate cw" },
  { key = "CTRL + ALT + SHIFT + R", dusky = "Rotate Screen Anti-Clockwise", status = "selected", kind = "ported", cmd = "chomsky rotate ccw" },
  { key = "ALT + F7", dusky = "Screen Off DPMS", status = "selected", kind = "ported", dsp = "dpms:off", flags = "locked" },
  { key = "ALT + F8", dusky = "Screen On DPMS", status = "selected", kind = "ported", dsp = "dpms:on", flags = "locked" },
  { key = "ALT + 9", dusky = "Start Waybar for 1 Min", status = "excluded", reason = "Dusky-only Waybar toggle." },
  { key = "ALT + 0", dusky = "system Tray TUI", status = "excluded", reason = "Dusky-only system-tray TUI." },
  { key = "SUPER + ALT + W", dusky = "Waybar Swap Configs", status = "excluded", reason = "Dusky-only Waybar config swap." },
  { key = "SUPER + ALT + SHIFT + W", dusky = "Waybar Swap Configs", status = "excluded", reason = "Dusky-only Waybar config swap." },
  { key = "ALT + F4", dusky = "Logout Menu", status = "excluded", reason = "Omarchy binds SUPER + ESCAPE and XF86PowerOff to the system menu." },
  { key = "SUPER + SHIFT + R", dusky = "Reload Hyprland", status = "selected", kind = "ported", cmd = "chomsky reload" },
  { key = "ALT + V", dusky = "Dusky QuickPanal", status = "excluded", reason = "Dusky-only quick panel." },
  { key = "SUPER + F", dusky = "Scale Up", status = "excluded", reason = "Omarchy binds SUPER + SLASH to monitor scaling." },
  { key = "SUPER + SHIFT + F", dusky = "Scale Down", status = "excluded", reason = "Omarchy binds SUPER + ALT + SLASH to scaling down." },
  { key = "SUPER + semicolon", dusky = "Kill Process", status = "excluded", reason = "Dusky-only process killer." },
  { key = "SUPER + U", dusky = "Key Press Sound", status = "excluded", reason = "Dusky-only Wayclick key-press sounds." },
  { key = "SUPER + SHIFT + U", dusky = "OSD KEY Presses", status = "excluded", reason = "Dusky-only key-press OSD." },
  { key = "SUPER + ALT + S", dusky = "Shader Menu", status = "selected", kind = "ported", cmd = "chomsky shader menu" },
  { key = "SUPER + ALT + X", dusky = "Disable Shader", status = "selected", kind = "ported", cmd = "chomsky shader off" },
  { key = "SUPER + ALT + V", dusky = "Vibrant Shader", status = "selected", kind = "ported", cmd = "chomsky shader set 14_vibrance" },
  { key = "SUPER + ALT + A", dusky = "Hyprland Animation Rofi Menu", status = "selected", kind = "ported", cmd = "chomsky anim menu" },
  { key = "SUPER + SHIFT + M", dusky = "Special Workspace for Spotify", status = "excluded", reason = "Omarchy binds SUPER + SHIFT + M to launching and focusing Music; Dusky's special workspace is a Dusky-only construct." },
  { key = "SUPER + ALT + period", dusky = "Toggle Blur/Opacity", status = "excluded", reason = "Global blur/opacity/shadow combo; the per-window toggle is selected on SUPER + period instead." },
  { key = "SUPER + period", dusky = "Toggle Opacity", status = "selected", kind = "ported", dsp = "wprop:opaque", flags = "locked" },
  { key = "SUPER + comma", dusky = "Toggle Per-Window Blur", status = "excluded", reason = "Omarchy uses the SUPER + comma family for notifications." },
  { key = "SUPER + equal", dusky = "Zoom In", status = "excluded", reason = "Omarchy resizes windows with the SUPER + minus/equal family." },
  { key = "SUPER + minus", dusky = "Zoom Out", status = "excluded", reason = "Omarchy resizes windows with the SUPER + minus/equal family." },
  { key = "SUPER + BACKSPACE", dusky = "Reset Zoom", status = "excluded", reason = "Omarchy binds SUPER + BACKSPACE to window transparency." },
  { key = "SUPER + SHIFT + equal", dusky = "Cursor Size Up", status = "excluded", reason = "Part of Omarchy's SHIFT + minus/equal window-resizing family." },
  { key = "SUPER + SHIFT + minus", dusky = "Cursor Size Down", status = "excluded", reason = "Part of Omarchy's SHIFT + minus/equal window-resizing family." },
  { key = "SUPER + SHIFT + mouse_up", dusky = "Cursor Size Up (Scroll)", status = "excluded", reason = "Part of Dusky's cursor-size family, which collides with Omarchy's window resizing." },
  { key = "SUPER + SHIFT + mouse_down", dusky = "Cursor Size Down (Scroll)", status = "excluded", reason = "Part of Dusky's cursor-size family, which collides with Omarchy's window resizing." },
  { key = "SUPER + SHIFT + BACKSPACE", dusky = "Cursor Size Reset", status = "excluded", reason = "Omarchy binds SUPER + SHIFT + BACKSPACE to window gaps." },
  { key = "SUPER + V", dusky = "Clipboard History (Terminal)", status = "excluded", reason = "Dusky-only terminal clipboard tool; Omarchy binds SUPER + V to universal paste." },
  { key = "SUPER + B", dusky = "Color Picker", status = "selected", kind = "equivalent", cmd = "pkill hyprpicker || hyprpicker -a", reason = "reuses Omarchy's colour picker" },
  { key = "SUPER + S", dusky = "Quick Screenshot", status = "selected", kind = "equivalent", cmd = "omarchy-capture-region", reason = "reuses Omarchy's region capture" },
  { key = "SHIFT + Print", dusky = "Full Screen Quick Screenshot", status = "excluded", reason = "Omarchy binds PRINT to a full screenshot already." },
  { key = "SUPER + SHIFT + S", dusky = "Screenshot and Annotation", status = "excluded", reason = "Same action as SUPER + S, which is selected." },
  { key = "Print", dusky = "Fullscreen Screenshot and Annotation", status = "excluded", reason = "Omarchy binds PRINT to a screenshot already." },
  { key = "SHIFT + CTRL + ALT + space", dusky = "Dusky Screenshoter", status = "excluded", reason = "Omarchy binds SUPER + CTRL + C to the capture menu." },
  { key = "ALT + R", dusky = "Screen Recorder", status = "excluded", reason = "Omarchy binds ALT + PRINT to screen recording." },
  { key = "SUPER + SHIFT + G", dusky = "Image Search (Select and search)", status = "excluded", reason = "Dusky-only image search." },
  { key = "SUPER + ALT + G", dusky = "Game Launcher", status = "excluded", reason = "Dusky-only game launcher." },
  { key = "SUPER + ALT + SHIFT + G", dusky = "Dusky Games TUI", status = "excluded", reason = "Dusky-only games TUI." },
  { key = "SUPER + T", dusky = "OCR Selection", status = "selected", kind = "equivalent", cmd = "omarchy-capture-text", reason = "reuses Omarchy's OCR capture" },
  { key = "SUPER + SHIFT + T", dusky = "OCR Fullscreen", status = "excluded", reason = "Same action as SUPER + T, which is selected." },
  { key = "SUPER + ALT + O", dusky = "Dusky AI LLM Side Panel", status = "excluded", reason = "Dusky-only LLM side panel." },
  { key = "SUPER + ALT + M", dusky = "Music Recognition aka Shazam", status = "excluded", reason = "Dusky-only music recognition." },
  { key = "SUPER + O", dusky = "TTS Kokoro GPU", status = "excluded", reason = "Dusky-only text-to-speech." },
  { key = "SUPER + SHIFT + O", dusky = "TTS VC", status = "excluded", reason = "Dusky-only text-to-speech voice conversion." },
  { key = "SUPER + I", dusky = "STT Parakeet GPU", status = "excluded", reason = "Dusky-only Parakeet speech-to-text; Omarchy binds SUPER + CTRL + X and F9 to dictation." },
  { key = "SUPER + N", dusky = "Notification History", status = "selected", kind = "equivalent", cmd = "omarchy-shell notifications showHistory", reason = "reuses Omarchy's notification history" },
  { key = "SUPER + ALT + D", dusky = "Clear Screen Notifications", status = "selected", kind = "equivalent", cmd = "omarchy-shell notifications dismissAll", reason = "reuses Omarchy's dismiss-all" },
  { key = "SUPER + ALT + F", dusky = "Interact with the current notification (answer Yes/No prompts)", status = "excluded", reason = "Omarchy binds SUPER + ALT + F to full width, and SUPER + ALT + comma already invokes the last notification." },
  { key = "SUPER + M", dusky = "Lock Screen", status = "selected", kind = "equivalent", cmd = "omarchy-system-lock", reason = "reuses Omarchy's lock" },
  { key = "SUPER + C", dusky = "Close Window", status = "excluded", reason = "Omarchy binds SUPER + W to close window; SUPER + C is universal copy, paired with SUPER + V and SUPER + X." },
  { key = "SUPER + SHIFT + C", dusky = "Kill Focused Process Completely", status = "excluded", reason = "Dusky-only focused-process killer." },
  { key = "SUPER + A", dusky = "Window Fullscreen", status = "excluded", reason = "Omarchy binds SUPER + F to full screen." },
  { key = "SUPER + SHIFT + A", dusky = "Window Maximize", status = "excluded", reason = "Omarchy binds SUPER + ALT + F to full width (maximized)." },
  { key = "SUPER + X", dusky = "Pin Window", status = "excluded", reason = "Omarchy binds SUPER + O to pop a window out (float and pin); SUPER + X is universal cut." },
  { key = "SUPER + Y", dusky = "Toggle Window Split", status = "selected", kind = "ported", dsp = "layout:togglesplit" },
  { key = "SUPER + D", dusky = "Smart Float", status = "excluded", reason = "Omarchy binds SUPER + T to the float/tile toggle." },
  { key = "SUPER + SHIFT + D", dusky = "Toggle Pseudo", status = "excluded", reason = "Omarchy binds SUPER + P to pseudo window." },
  { key = "SUPER + G", dusky = "Group Toggle (tabbed)", status = "excluded", reason = "Omarchy binds SUPER + G to the same group toggle." },
  { key = "SUPER + ALT + H", dusky = "Group Prev Tab", status = "selected", kind = "ported", dsp = "group:prev" },
  { key = "SUPER + ALT + L", dusky = "Group Next Tab", status = "selected", kind = "ported", dsp = "group:next" },
  { key = "SUPER + ALT + SHIFT + H", dusky = "Group Merge Left (create if none)", status = "selected", kind = "ported", dsp = "winto:l" },
  { key = "SUPER + ALT + SHIFT + L", dusky = "Group Merge Right (create if none)", status = "selected", kind = "ported", dsp = "winto:r" },
  { key = "SUPER + ALT + SHIFT + K", dusky = "Group Merge Up (create if none)", status = "selected", kind = "ported", dsp = "winto:u" },
  { key = "SUPER + ALT + SHIFT + J", dusky = "Group Merge Down (create if none)", status = "selected", kind = "ported", dsp = "winto:d" },
  { key = "SUPER + ALT + U", dusky = "Group Move Out (ungroup)", status = "selected", kind = "ported", dsp = "wout" },
  { key = "SUPER + ALT + K", dusky = "Group Lock Toggle", status = "selected", kind = "ported", dsp = "group:lock" },
  { key = "SUPER + h", dusky = "Focus Left", status = "selected", kind = "ported", dsp = "focus:l" },
  { key = "SUPER + l", dusky = "Focus Right", status = "selected", kind = "ported", dsp = "focus:r" },
  { key = "SUPER + k", dusky = "Focus Up", status = "selected", kind = "ported", dsp = "focus:u" },
  { key = "SUPER + j", dusky = "Focus Down", status = "selected", kind = "ported", dsp = "focus:d" },
  { key = "SUPER + SHIFT + h", dusky = "Move Left", status = "selected", kind = "ported", dsp = "wmove:l", flags = "repeating" },
  { key = "SUPER + SHIFT + l", dusky = "Move Right", status = "selected", kind = "ported", dsp = "wmove:r", flags = "repeating" },
  { key = "SUPER + SHIFT + k", dusky = "Move Up", status = "selected", kind = "ported", dsp = "wmove:u", flags = "repeating" },
  { key = "SUPER + SHIFT + j", dusky = "Move Down", status = "selected", kind = "ported", dsp = "wmove:d", flags = "repeating" },
  { key = "SUPER + right", dusky = "Resize Width +", status = "selected", kind = "ported", dsp = "resize:30:0", flags = "repeating" },
  { key = "SUPER + left", dusky = "Resize Width -", status = "selected", kind = "ported", dsp = "resize:-30:0", flags = "repeating" },
  { key = "SUPER + up", dusky = "Resize Height -", status = "selected", kind = "ported", dsp = "resize:0:-30", flags = "repeating" },
  { key = "SUPER + down", dusky = "Resize Height +", status = "selected", kind = "ported", dsp = "resize:0:30", flags = "repeating" },
  { key = "SUPER + TAB", dusky = "Last Workspace", status = "selected", kind = "ported", dsp = "ws:previous", flags = "repeating" },
  { key = "ALT + SHIFT + TAB", dusky = "Cycle Backward", status = "excluded", reason = "Omarchy binds ALT + SHIFT + TAB to focusing the previous window; Dusky's previous workspace also lives on SUPER + TAB." },
  { key = "SUPER + SHIFT + TAB", dusky = "Cycle Next WS", status = "selected", kind = "ported", dsp = "ws:e+1", flags = "repeating" },
  { key = "SUPER + mouse_down", dusky = "Cycle Next Workspace", status = "excluded", reason = "Omarchy binds SUPER + scroll to the same workspace cycling." },
  { key = "SUPER + mouse_up", dusky = "Cycle Previous Workspace", status = "excluded", reason = "Omarchy binds SUPER + scroll to the same workspace cycling." },
  { key = "SUPER + Z", dusky = "Toggle Scratchpad", status = "excluded", reason = "Omarchy already binds toggle-scratchpad, remapped off SUPER + S by this port." },
  { key = "SUPER + SHIFT + Z", dusky = "Move to Scratchpad", status = "excluded", reason = "Omarchy already binds move-to-scratchpad, remapped off SUPER + ALT + S by this port." },
  { key = "SUPER + 1", dusky = "Switch To Context 1", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + 2", dusky = "Switch To Context 2", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + 3", dusky = "Switch To Context 3", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + 4", dusky = "Switch To Context 4", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + 5", dusky = "Switch To Context 5", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + 6", dusky = "Switch To Context 6", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + 7", dusky = "Switch To Context 7", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + 8", dusky = "Switch To Context 8", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + 9", dusky = "Switch To Context 9", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + 0", dusky = "Switch To Context 10", status = "excluded", reason = "Omarchy already binds this key to the equivalent workspace switch." },
  { key = "SUPER + SHIFT + 1", dusky = "Move To Context 1", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + SHIFT + 2", dusky = "Move To Context 2", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + SHIFT + 3", dusky = "Move To Context 3", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + SHIFT + 4", dusky = "Move To Context 4", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + SHIFT + 5", dusky = "Move To Context 5", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + SHIFT + 6", dusky = "Move To Context 6", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + SHIFT + 7", dusky = "Move To Context 7", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + SHIFT + 8", dusky = "Move To Context 8", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + SHIFT + 9", dusky = "Move To Context 9", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + SHIFT + 0", dusky = "Move To Context 10", status = "excluded", reason = "Omarchy already binds this key to the equivalent window-to-workspace move." },
  { key = "SUPER + ALT + 1", dusky = "Silent Move To Context 1", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + ALT + 2", dusky = "Silent Move To Context 2", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + ALT + 3", dusky = "Silent Move To Context 3", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + ALT + 4", dusky = "Silent Move To Context 4", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + ALT + 5", dusky = "Silent Move To Context 5", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + ALT + 6", dusky = "Silent Move To Context 6", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + ALT + 7", dusky = "Silent Move To Context 7", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + ALT + 8", dusky = "Silent Move To Context 8", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + ALT + 9", dusky = "Silent Move To Context 9", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + ALT + 0", dusky = "Silent Move To Context 10", status = "excluded", reason = "Omarchy binds SUPER + ALT + N to grouped window N, and its silent workspace move is SUPER + SHIFT + ALT + N." },
  { key = "SUPER + mouse:272", dusky = "Move Window", status = "excluded", reason = "Omarchy binds SUPER + mouse drag to moving a window." },
  { key = "SUPER + mouse:273", dusky = "Resize Window", status = "excluded", reason = "Omarchy binds SUPER + mouse drag to resizing a window." },
  { key = "XF86AudioRaiseVolume", dusky = "Volume up", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86AudioLowerVolume", dusky = "Volume down", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86AudioMute", dusky = "Mute", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86AudioMicMute", dusky = "Mute microphone", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86MonBrightnessUp", dusky = "Brightness up", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86MonBrightnessDown", dusky = "Brightness down", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "ALT + XF86AudioRaiseVolume", dusky = "Volume up precise", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "ALT + XF86AudioLowerVolume", dusky = "Volume down precise", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "ALT + XF86MonBrightnessUp", dusky = "Brightness up precise", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "ALT + XF86MonBrightnessDown", dusky = "Brightness down precise", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86KbdBrightnessUp", dusky = "Keyboard Brightness up", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86KbdBrightnessDown", dusky = "Keyboard Brightness down", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "SUPER + SHIFT + B", dusky = "Live Radio Menu", status = "excluded", reason = "Dusky-only live-radio menu." },
  { key = "XF86AudioNext", dusky = "Next track", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86AudioPrev", dusky = "Previous track", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86AudioPlay", dusky = "Play", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86AudioPause", dusky = "Pause", status = "excluded", reason = "Omarchy binds the same key to the same action." },
  { key = "XF86AudioStop", dusky = "Stop", status = "excluded", reason = "Omarchy has no media-stop action; play/pause is on the other media keys." },
  { key = "SUPER + P", dusky = "Toggle Pause", status = "excluded", reason = "Omarchy binds SUPER + P to pseudo window; media play/pause is on the XF86 keys." },
  { key = "SUPER + SHIFT + P", dusky = "Toggle Audio Active Stream", status = "excluded", reason = "Omarchy binds SHIFT + XF86AudioPause to switching media source." },
  { key = "ALT + P", dusky = "Mute Audio", status = "excluded", reason = "Omarchy binds XF86AudioMute to muting." },
  { key = "ALT + M", dusky = "Mono Audio Toggle", status = "excluded", reason = "Dusky-only mono-audio toggle." },
  { key = "ALT + O", dusky = "Switch Audio Output", status = "excluded", reason = "Omarchy binds SHIFT + XF86AudioMute to switching audio output." },
  { key = "ALT + I", dusky = "Switch Mic Input", status = "excluded", reason = "Dusky-only input-source switcher." },
  { key = "ALT + N", dusky = "Dusky Audio Studio & Voice DSP", status = "excluded", reason = "Dusky-only audio studio and voice DSP." },
  { key = "XF86Calculator", dusky = "Calculator", status = "excluded", reason = "Omarchy binds the same key to the calculator." },
}

-- Compare the ledger against the pinned snapshot. Returns a list of problems,
-- empty when the ledger covers the snapshot exactly. This is the check that
-- keeps "we cover all of Dusky" honest: it fails on a key we never classified, a
-- key classified twice, an excluded row with no reason, a selected row with no
-- binding, a deviation or an equivalent with no reason, and any drift in a key's
-- spelling from upstream.
function M.audit(snapshot)
  local problems = {}
  local seen, selected, excluded = {}, 0, 0

  for _, row in ipairs(M.rows) do
    if type(row.key) ~= "string" or row.key == "" then
      problems[#problems + 1] = "a ledger row has no key"
    elseif seen[row.key] then
      problems[#problems + 1] = "duplicate ledger row: " .. row.key
    else
      seen[row.key] = true
    end

    if row.status == "selected" then
      selected = selected + 1
      local known = false
      for _, kind in ipairs(M.kinds) do
        if row.kind == kind then known = true end
      end
      if not known then
        problems[#problems + 1] = row.key .. ": selected with an unknown kind " .. tostring(row.kind)
      end
      if not row.cmd and not row.dsp then
        problems[#problems + 1] = row.key .. ": selected with no cmd or dsp"
      end
      -- An equivalent row says which Omarchy implementation it reuses; a
      -- deviation says why it differs. Only a plain port needs no note.
      -- Tested against "" as well as nil: the probe that guards this sets an
      -- empty string, and an empty string is truthy in Lua.
      if (row.kind == "deviation" or row.kind == "equivalent")
        and (row.reason == nil or row.reason == "") then
        problems[#problems + 1] = row.key .. ": a " .. row.kind .. " must carry a reason"
      end
    elseif row.status == "excluded" then
      excluded = excluded + 1
      if not row.reason or row.reason == "" then
        problems[#problems + 1] = row.key .. ": excluded with no reason"
      end
    else
      problems[#problems + 1] = row.key .. ": unknown status " .. tostring(row.status)
    end
  end

  for _, entry in ipairs(snapshot.keys) do
    local row = nil
    for _, candidate in ipairs(M.rows) do
      if candidate.key == entry.key then row = candidate end
    end
    if not row then
      problems[#problems + 1] = "no ledger row for the key Dusky binds: " .. entry.key
    elseif row.dusky ~= entry.action then
      problems[#problems + 1] = entry.key .. ": downstream action changed, snapshot says \"" .. entry.action .. "\", ledger says \"" .. tostring(row.dusky) .. "\""
    end
  end

  return problems, selected, excluded
end

-- The keys either mode must clear: everything the port binds or deliberately
-- drops, plus (from keys/remaps.lua) the keys Omarchy actions are moved to.
function M.keys()
  local keys = {}
  for _, row in ipairs(M.rows) do
    keys[#keys + 1] = row.key
  end
  return keys
end

-- The ledger rows the port actually binds in dusky mode.
function M.selected()
  local rows = {}
  for _, row in ipairs(M.rows) do
    if row.status == "selected" then rows[#rows + 1] = row end
  end
  return rows
end

return M
