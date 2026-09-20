import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Chomsky's always-on half: state, actions, and the things that have to happen
// once per shell start.
//
// This is a `service` entry point, which means the host mounts it for as long
// as the plugin is enabled -- whether or not the bar chip is placed, and
// whether or not the panel has ever been opened. Two consequences, both
// deliberate:
//
//   * The plugin's state and its CLI calls live here, not in the widget or the
//     panel. Both of those come and go (the chip is optional, and the panel is
//     unloaded or hidden while closed); this does not.
//   * The saved shader goes back on at login from here. A widget's own
//     component only exists where it is placed in the bar, so hanging the
//     restore off the widget would silently stop restoring the moment the chip
//     came off the bar.
//
// The panel reads everything below through the `service` property the host
// injects into the `panel` entry point; the chip reads it through
// shell.serviceFor(). Neither talks to a CLI directly.
Item {
  id: root

  property var shell: null
  property string omarchyPath: ""

  readonly property string helperPath: Qt.resolvedUrl("bin/chomsky").toString().replace(/^file:\/\//, "")
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/chomsky"

  property string animation: "(none)"
  property string shader: "off"
  property bool shaderOn: false
  property string theme: ""
  property bool resizeOnBorder: false
  property real dimStrength: 0.15
  property string keybindings: "omarchy"

  Component.onCompleted: {
    if (!root.helperPath) return

    // Re-apply whatever shader is on record. Replaces a hook that used to live
    // in ~/.config/hypr/autostart.lua -- keeping it here means a fresh plugin
    // install needs no edits to anyone's hyprland config.
    Quickshell.execDetached(["bash", root.helperPath, "shader", "restore"])

    // Make the Omarchy menu rows match the saved choice. Safe to run more than
    // once; chomsky-menu-install serialises concurrent runs itself.
    Quickshell.execDetached(["bash", root.helperPath, "menu-install"])
  }

  function ingestStatus(line) {
    var raw = String(line || "").trim()
    if (!raw) return
    try {
      var parsed = JSON.parse(raw)
      root.animation = parsed.animation || "(none)"
      root.shader = parsed.shader || "off"
      root.shaderOn = parsed.shaderOn === true
      root.theme = parsed.theme || ""
      root.resizeOnBorder = parsed.resizeOnBorder === true
      root.dimStrength = typeof parsed.dimStrength === "number" ? parsed.dimStrength : 0.15
      root.keybindings = parsed.keybindings === "dusky" ? "dusky" : "omarchy"
    } catch (e) {}
  }

  function refresh() {
    statusProbe.buffer = ""
    statusProbe.running = false
    statusProbe.running = true
  }

  // Actions run detached (fire-and-forget), so the refresh timer below is how
  // the panel and the chip notice the underlying state settled.
  function runAction(args) {
    if (!root.helperPath) return
    Quickshell.execDetached(["bash", root.helperPath].concat(args))
    Qt.callLater(function() { refreshTimer.restart() })
  }

  function setAnimation(name) { root.runAction(["anim", "set", name]) }
  function animNext() { root.runAction(["anim", "next"]) }
  function animPrev() { root.runAction(["anim", "prev"]) }
  function setShader(name) { root.runAction(["shader", "set", name]) }
  function shaderOff() { root.runAction(["shader", "off"]) }
  function shaderNext() { root.runAction(["shader", "next"]) }
  function shaderPrev() { root.runAction(["shader", "prev"]) }

  // Dim strength carries over from whatever is in effect, so toggling back on
  // returns the strength the slider was last left at rather than the CLI's
  // built-in default.
  function toggleWindowBehavior() { root.runAction(["window", "toggle", String(root.dimStrength)]) }
  function setDimStrength(v) { root.runAction(["window", "on", String(v)]) }

  function rotate(direction) { root.runAction(["rotate", direction]) }
  function screenOff() { root.runAction(["dpms", "off"]) }
  function bgNext() { root.runAction(["bg-next"]) }
  function bgPrev() { root.runAction(["bg-prev"]) }
  function bgMenu() { root.runAction(["wallpaper", "menu"]) }

  function setKeybindings(mode) { root.runAction(["keys", mode]) }
  function toggleKeybindings() { root.setKeybindings(root.keybindings === "dusky" ? "omarchy" : "dusky") }

  Process {
    id: statusProbe
    property string buffer: ""
    running: true
    command: ["bash", root.helperPath, "status"]
    stdout: SplitParser {
      onRead: function(line) { statusProbe.buffer += line }
    }
    onExited: root.ingestStatus(statusProbe.buffer)
  }

  Timer {
    id: refreshTimer
    interval: 400
    repeat: false
    onTriggered: root.refresh()
  }

  // Pick up changes made outside the plugin entirely -- a keybind, a bare CLI
  // call in a terminal -- by watching the state files those write.
  // A shader is applied by writing this toggle file (Hyprland sources it on
  // every reload), so this -- not a state file -- is what changes when a shader
  // is switched from anywhere. It is removed when the shader is turned off,
  // hence the load-failed path as well.
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr/chomsky-shader.lua"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
    onLoaded: root.refresh()
    onLoadFailed: root.refresh()
  }
  FileView {
    path: root.stateDir + "/animation"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }
  FileView {
    path: root.stateDir + "/window-behavior"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }
  // The keybinding mode is owned by chomsky-keys, which writes this toggle
  // file -- watching it is how a switch made from the menu or a terminal shows
  // up in the panel and the chip's tooltip.
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr/chomsky-keys.lua"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }
}
