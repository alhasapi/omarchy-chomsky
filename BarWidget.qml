import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Chomsky: unified manager for the Dusky-derived look & feel this plugin
// bundles -- animation presets, screen shaders, border-resize/dim window
// behavior, monitor rotation, and wallpaper-driven themes. Everything the
// panel does goes through bin/chomsky, the plugin's single integration
// surface with the standalone CLIs living alongside it in bin/.
BarWidget {
  id: root
  moduleName: "alhasapi.chomsky"

  readonly property string helperPath: Qt.resolvedUrl("bin/chomsky").toString().replace(/^file:\/\//, "")
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/chomsky"

  property string animation: "(none)"
  property string shader: "off"
  property bool shaderOn: false
  property string theme: ""
  property string background: ""
  property bool resizeOnBorder: false
  property bool dimInactive: false
  property real dimStrength: 0.15
  property string keybindings: "omarchy"

  readonly property string icon: "󰸉"
  readonly property color foreground: bar ? bar.barForeground : Color.foreground

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  // The Omarchy menu offers its "Chomsky panel" row only while a chip is on the
  // bar to open it from. The row's `when:` guard tests this marker file rather
  // than asking the shell over IPC: the menu evaluates its guards in a batch
  // that the shell itself runs, so calling back into the shell from there is a
  // way to hang the menu.
  Component.onCompleted: {
    if (root.helperPath) Quickshell.execDetached(["bash", root.helperPath, "chip", "on"])
  }

  Component.onDestruction: {
    if (root.helperPath) Quickshell.execDetached(["bash", root.helperPath, "chip", "off"])
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
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
      root.background = parsed.background || ""
      root.resizeOnBorder = parsed.resizeOnBorder === true
      root.dimInactive = parsed.dimInactive === true
      root.dimStrength = typeof parsed.dimStrength === "number" ? parsed.dimStrength : 0.15
      root.keybindings = parsed.keybindings === "dusky" ? "dusky" : "omarchy"
    } catch (e) {}
  }

  function refresh() {
    statusProbe.buffer = ""
    statusProbe.running = false
    statusProbe.running = true
  }

  function runAction(args) {
    var full = ["bash", root.helperPath].concat(args)
    Quickshell.execDetached(full)
    Qt.callLater(function() { refreshTimer.restart() })
  }

  function setAnimation(name) { root.runAction(["anim", "set", name]) }
  function animNext() { root.runAction(["anim", "next"]) }
  function animPrev() { root.runAction(["anim", "prev"]) }
  function setShader(name) { root.runAction(["shader", "set", name]) }
  function shaderOff() { root.runAction(["shader", "off"]) }
  function shaderNext() { root.runAction(["shader", "next"]) }
  function shaderPrev() { root.runAction(["shader", "prev"]) }
  function toggleWindowBehavior() {
    root.runAction(["window", "toggle", String(root.setting("dimStrength", 0.15))])
  }
  function setDimStrength(v) { root.runAction(["window", "on", String(v)]) }
  function rotate(direction) { root.runAction(["rotate", direction]) }
  function screenOff() { root.runAction(["dpms", "off"]) }
  function bgNext() { root.runAction(["bg-next"]) }
  function bgPrev() { root.runAction(["bg-prev"]) }
  function reloadHyprland() { root.runAction(["reload"]) }
  function setKeybindings(mode) { root.runAction(["keys", mode]) }
  function toggleKeybindings() { root.setKeybindings(root.keybindings === "dusky" ? "omarchy" : "dusky") }

  // The Omarchy menu rows are the plugin's main UI, so the chip is optional:
  // Service.qml owns everything that has to happen at startup. The widget only
  // turns the rows on and off, and only when the user has actually set that
  // setting -- `settings` can arrive half-populated, and the saved state file
  // (not this) is what the sync applies.
  function syncMenuRowsFromSettings() {
    if (!root.helperPath) return
    var settings = root.settings
    if (!settings || settings.menuRows === undefined) return

    var wanted = settings.menuRows
    var on = wanted === true || wanted === "true" || wanted === 1
    Quickshell.execDetached(["bash", root.helperPath, "menu-install", on ? "--enable" : "--remove"])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: {
    injectPanel()
    syncMenuRowsFromSettings()
  }

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

  // Refresh shortly after any action so the panel/chip reflect the change --
  // actions run detached (fire-and-forget), so this poll is how we notice
  // the underlying state settled.
  Timer {
    id: refreshTimer
    interval: 400
    repeat: false
    onTriggered: root.refresh()
  }

  // Also pick up changes made outside the panel entirely (a keybind, a bare
  // CLI call in a terminal) by watching the state files those write.
  FileView {
    path: root.stateDir + "/shader"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
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

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "alhasapi.chomsky"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function ping(): string { return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    active: root.shaderOn
    activeColor: Color.accent
    tooltipText: "Animation: " + root.animation + " · Shader: " + root.shader
      + (root.theme ? " · Theme: " + root.theme : "")
      + " · Keys: " + root.keybindings
    onPressed: function(b) { root.toggle() }

    // A small circular portrait instead of a glyph -- credited to Augusto
    // Starita (CC BY-SA 2.0) in NOTICE. icon.png is already circle-masked
    // with a transparent surround (baked in at build time), so no QML-side
    // masking is needed. The accent ring doubles for BarIconButton's usual
    // "active" glyph tint, which doesn't apply once iconComponent replaces
    // the glyph.
    iconComponent: Component {
      Item {
        anchors.fill: parent
        Image {
          anchors.fill: parent
          anchors.margins: root.shaderOn ? Math.max(1, Style.space(2)) : 0
          source: Qt.resolvedUrl("icon.png")
          fillMode: Image.PreserveAspectFit
          smooth: true
          asynchronous: true
        }
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: "transparent"
          border.width: root.shaderOn ? Math.max(1, Style.space(2)) : 0
          border.color: Color.accent
        }
      }
    }
  }
}
