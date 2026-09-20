import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Chomsky's panel.
//
// A centered overlay card, the same shape as Omarchy's own menu: one
// full-screen layer surface with a scrim over it and the card centered
// inside. Two things follow from that shape.
//
// The bar chip is optional. A panel anchored to a bar widget needs a widget
// to anchor to, so it can only exist where the chip does; this one is
// summoned by the host (`omarchy-shell shell toggle alhasapi.chomsky`, which
// is what the menu's "Chomsky panel" row runs) and is centered on the focused
// monitor instead.
//
// And the card has room to grow. A popup hanging off a bar icon is capped by
// the space between the bar and the screen edge, so content past that was
// simply cut off with no way to reach it. Here the card is as tall as its
// content and the leftover space is the bottom margin -- when the screen is
// too short for that, the content scrolls.
//
// State and actions live in Service.qml, which the host injects as `service`.
// This file is a view: it never touches a CLI or a state file directly.
Item {
  id: root

  // Injected by omarchy-shell through the `panel` entry point.
  property var shell: null
  property var service: null
  property var manifest: null

  // Plugin lifecycle. The host calls open(payloadJson) when this panel is
  // summoned and close() when it is hidden; `opened` is what the host reads
  // back (via isPluginOpen) so that closing from in here -- Escape, a click
  // on the scrim -- still toggles correctly next time.
  property bool opened: false

  readonly property string helperPath: service && service.helperPath ? service.helperPath : ""
  readonly property string animation: service && service.animation ? service.animation : "(none)"
  readonly property string shaderName: service && service.shader ? service.shader : "off"
  readonly property bool shaderOn: service && service.shaderOn === true
  readonly property string themeName: service && service.theme ? service.theme : ""
  readonly property bool resizeOnBorder: service && service.resizeOnBorder === true
  readonly property real dimStrength: service && typeof service.dimStrength === "number" ? service.dimStrength : 0.15
  readonly property string keybindings: service && service.keybindings === "dusky" ? "dusky" : "omarchy"
  readonly property bool barChip: !service || service.barChip !== "off"

  property var animationList: []
  property var shaderList: []

  // Menu styling, so the card reads as part of Omarchy rather than as a
  // plugin's own thing. Same colors, radius, padding and border spec the
  // Omarchy menu itself uses.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color borderColor: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", borderColor, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  // A little more than Omarchy's own panels use: the last row here is a
  // bordered button, whose border would otherwise sit as close to the card's
  // edge as bare text does, which reads as cramped.
  property int contentMargin: Style.space(22)
  property int contentSpacing: Style.space(8)

  // Height is fitted to the content, with the rest of the screen as margin --
  // a taller panel than its content reads as a form, not a menu. Width is
  // fixed: a menu that reflows as you move between sections looks jumpy, and
  // this is a touch wider than the Omarchy menu's own card because the
  // animation and shader rows put two buttons beside a search field.
  //
  // Measured against the card's own insets rather than against contentMargin:
  // the border adds to them, and the few pixels that left unaccounted for were
  // exactly enough to clip the bottom row, leaving the last button's border
  // sitting on the card's edge instead of inside it.
  readonly property int neededHeight: card.contentTopInset + card.contentBottomInset + content.implicitHeight
  readonly property int cardWidth: Math.min(Style.space(340), panel.width - Style.gapsOut * 2)
  readonly property int cardHeight: Math.min(root.neededHeight, Math.max(Style.space(160), panel.height - Style.gapsOut * 2))

  // Where a keyboard-summoned panel belongs. Falls back to the default screen
  // until Hyprland reports a focused monitor, rather than guessing an output.
  readonly property var targetScreen: {
    var focused = Hyprland.focusedMonitor
    if (!focused) return null
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name) === String(focused.name)) return screens[i]
    }
    return null
  }

  // Flat keyboard-cursor index over every interactive control below, in
  // visual (top-to-bottom) order. The dim-strength slider is reachable by
  // mouse/wheel only -- dragging a slider by discrete keyboard steps isn't
  // worth the extra index bookkeeping for a single control.
  property int cursorIndex: 0
  property bool cursorActive: false
  readonly property int cursorCount: 15

  function open(payloadJson) {
    root.opened = true
    root.reloadLists()
    root.cursorActive = false
    root.cursorIndex = 0
    flick.contentY = 0
    if (root.service && root.service.refresh) root.service.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    root.opened ? root.close() : root.open()
  }

  function ping() { return "ok" }

  function reloadLists() {
    if (!root.helperPath) return
    animProc.buffer = ""
    animProc.running = false
    animProc.running = true
    shaderProc.buffer = ""
    shaderProc.running = false
    shaderProc.running = true
  }

  function moveCursor(delta) {
    root.cursorActive = true
    root.cursorIndex = Math.max(0, Math.min(root.cursorCount - 1, root.cursorIndex + delta))
    root.revealCursor()
  }

  // Only does anything when the card had to be capped and the content
  // scrolls: keeps the cursor's rough position in the view rather than
  // walking the focus off the bottom of a short screen.
  function revealCursor() {
    if (!flick || flick.contentHeight <= flick.height) return
    var span = flick.contentHeight - flick.height
    var ratio = root.cursorCount > 1 ? root.cursorIndex / (root.cursorCount - 1) : 0
    flick.contentY = Math.round(ratio * span)
  }

  function activateCursor() {
    switch (root.cursorIndex) {
      case 0: animDropdown.open(); break
      case 1: root.animPrev(); break
      case 2: root.animNext(); break
      case 3: shaderDropdown.open(); break
      case 4: root.shaderPrev(); break
      case 5: root.shaderNext(); break
      case 6: root.toggleWindowBehavior(); break
      case 7: root.toggleKeybindings(); break
      case 8: root.rotate("ccw"); break
      case 9: root.rotate("cw"); break
      case 10: root.screenOff(); break
      case 11: root.bgPrev(); break
      case 12: root.bgNext(); break
      case 13: root.pickWallpaper(); break
      case 14: root.toggleBarChip(); break
    }
  }

  // Every action goes through the service, which owns the CLI calls and the
  // state the panel displays.
  function setAnimation(name) {
    if (service && service.setAnimation) service.setAnimation(name)
    Qt.callLater(root.reloadLists)
  }
  function animNext() {
    if (service && service.animNext) service.animNext()
    Qt.callLater(root.reloadLists)
  }
  function animPrev() {
    if (service && service.animPrev) service.animPrev()
    Qt.callLater(root.reloadLists)
  }
  function setShader(name) {
    if (service && service.setShader) service.setShader(name)
    Qt.callLater(root.reloadLists)
  }
  function shaderOff() {
    if (service && service.shaderOff) service.shaderOff()
    Qt.callLater(root.reloadLists)
  }
  function shaderNext() {
    if (service && service.shaderNext) service.shaderNext()
    Qt.callLater(root.reloadLists)
  }
  function shaderPrev() {
    if (service && service.shaderPrev) service.shaderPrev()
    Qt.callLater(root.reloadLists)
  }
  function toggleWindowBehavior() {
    if (service && service.toggleWindowBehavior) service.toggleWindowBehavior()
  }
  function toggleKeybindings() {
    if (service && service.toggleKeybindings) service.toggleKeybindings()
  }

  function toggleBarChip() {
    if (service && service.setBarChip) service.setBarChip(!root.barChip)
  }
  function setDimStrength(v) {
    if (service && service.setDimStrength) service.setDimStrength(v)
  }
  function rotate(direction) {
    if (service && service.rotate) service.rotate(direction)
  }
  function screenOff() {
    if (service && service.screenOff) service.screenOff()
  }
  function bgPrev() {
    if (service && service.bgPrev) service.bgPrev()
  }
  function bgNext() {
    if (service && service.bgNext) service.bgNext()
  }
  // The picker is its own overlay (Omarchy's image picker), so get out of its
  // way first: two overlay surfaces fighting over keyboard focus is not a
  // thing worth debugging twice.
  function pickWallpaper() {
    root.close()
    if (service && service.bgMenu) Qt.callLater(function() { service.bgMenu() })
  }
  Process {
    id: animProc
    property string buffer: ""
    command: root.helperPath ? ["bash", root.helperPath, "animations"] : ["true"]
    stdout: SplitParser {
      onRead: function(line) { animProc.buffer += line }
    }
    onExited: {
      try { root.animationList = JSON.parse(animProc.buffer) } catch (e) { root.animationList = [] }
    }
  }

  Process {
    id: shaderProc
    property string buffer: ""
    command: root.helperPath ? ["bash", root.helperPath, "shaders"] : ["true"]
    stdout: SplitParser {
      onRead: function(line) { shaderProc.buffer += line }
    }
    onExited: {
      try { root.shaderList = JSON.parse(shaderProc.buffer) } catch (e) { root.shaderList = [] }
    }
  }

  PanelWindow {
    id: panel
    screen: root.targetScreen
    visible: root.opened
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "chomsky-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.max(Style.gapsOut, Math.round((panel.height - root.cardHeight) / 2))
      radius: root.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      // Clicks inside the card land here and stop, so they never reach the
      // dismissal MouseArea underneath.
      MouseArea { anchors.fill: parent; onClicked: {} }

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        // BorderSurface's `padding` is a set of insets for children to use,
        // not something it applies itself -- without this the content sits
        // flush against the card's border.
        anchors.topMargin: card.contentTopInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        // Suspend cursor-driven nav while a dropdown owns its own popup keys
        // (search field, result list, Esc-to-close) -- otherwise j/k here
        // would double-drive both the popup and the panel cursor underneath it.
        blocked: animDropdown.popupOpen || shaderDropdown.popupOpen
        onCloseRequested: root.close()
        onMoveRequested: function(dx, dy) { root.moveCursor(dy !== 0 ? dy : dx) }
        onActivateRequested: root.activateCursor()

        Flickable {
          id: flick
          anchors.fill: parent
          contentWidth: width
          contentHeight: content.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          clip: true
          interactive: contentHeight > height

          Column {
            id: content
            width: flick.width
            spacing: root.contentSpacing

            PanelHero {
              width: parent.width
              title: "Chomsky"
              // The animation and shader are the two dropdowns immediately
              // below, so repeating them here only made this line long enough
              // to be cut off. The keybinding mode is the one piece of state
              // with no control of its own in view, and it is short enough to
              // never elide.
              detail: root.keybindings === "dusky" ? "Dusky" : "Omarchy"
              foreground: root.foreground
              fontFamily: Style.font.family
              iconComponent: Component {
                Item {
                  width: Style.font.display
                  height: Style.font.display
                  Image {
                    anchors.fill: parent
                    source: Qt.resolvedUrl("icon.png")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                  }
                }
              }
            }

            PanelSeparator { foreground: root.foreground }

            // ---- Animation ----
            Column {
              width: parent.width
              spacing: Style.space(6)

              PanelSectionHeader { text: "ANIMATION"; foreground: root.foreground; fontFamily: Style.font.family }

              Row {
                width: parent.width
                spacing: Style.space(8)

                SearchableDropdown {
                  id: animDropdown
                  width: parent.width - prevBtn.width - nextBtn.width - parent.spacing * 2
                  showLabel: false
                  value: root.animation
                  placeholderText: "Search presets…"
                  options: root.animationList.map(function(a) { return a.name })
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  hasCursor: root.cursorActive && root.cursorIndex === 0
                  onChanged: function(v) { root.setAnimation(v) }
                }
                PanelActionButton {
                  id: prevBtn
                  anchors.verticalCenter: animDropdown.verticalCenter
                  iconText: "󰒮"
                  tooltipText: "Previous animation"
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === 1
                  onClicked: root.animPrev()
                }
                PanelActionButton {
                  id: nextBtn
                  anchors.verticalCenter: animDropdown.verticalCenter
                  iconText: "󰒭"
                  tooltipText: "Next animation"
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === 2
                  onClicked: root.animNext()
                }
              }
            }

            PanelSeparator { foreground: root.foreground }

            // ---- Shader ----
            Column {
              width: parent.width
              spacing: Style.space(6)

              PanelSectionHeader { text: "SHADER"; foreground: root.foreground; fontFamily: Style.font.family }

              Row {
                width: parent.width
                spacing: Style.space(8)

                SearchableDropdown {
                  id: shaderDropdown
                  width: parent.width - shaderPrevBtn.width - shaderNextBtn.width - parent.spacing * 2
                  showLabel: false
                  value: root.shaderOn ? root.shaderName : "off"
                  placeholderText: "Search shaders…"
                  options: [{ value: "off", label: "Off" }].concat(
                    root.shaderList.map(function(s) { return { value: s.name, label: s.name } }))
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  hasCursor: root.cursorActive && root.cursorIndex === 3
                  onChanged: function(v) { v === "off" ? root.shaderOff() : root.setShader(v) }
                }
                PanelActionButton {
                  id: shaderPrevBtn
                  anchors.verticalCenter: shaderDropdown.verticalCenter
                  iconText: "󰒮"
                  tooltipText: "Previous shader"
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === 4
                  onClicked: root.shaderPrev()
                }
                PanelActionButton {
                  id: shaderNextBtn
                  anchors.verticalCenter: shaderDropdown.verticalCenter
                  iconText: "󰒭"
                  tooltipText: "Next shader"
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === 5
                  onClicked: root.shaderNext()
                }
              }
            }

            PanelSeparator { foreground: root.foreground }

            // ---- Window behavior ----
            Column {
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader { text: "WINDOW BEHAVIOR"; foreground: root.foreground; fontFamily: Style.font.family }

              Toggle {
                width: parent.width
                label: "Border resize & dim"
                description: root.resizeOnBorder
                  ? "Drag any edge to resize; unfocused windows dim"
                  : "Omarchy defaults: SUPER-drag only, no dimming"
                checked: root.resizeOnBorder
                foreground: root.foreground
                accent: Color.accent
                fontFamily: Style.font.family
                hasCursor: root.cursorActive && root.cursorIndex === 6
                onClicked: root.toggleWindowBehavior()
              }

              Row {
                width: parent.width
                spacing: Style.space(10)
                visible: root.resizeOnBorder

                Text {
                  text: "Dim strength"
                  color: root.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
                PanelSlider {
                  width: content.width - Style.space(110)
                  minimum: 0
                  maximum: 0.7
                  step: 0.05
                  value: root.dimStrength
                  onReleased: function(v) { root.setDimStrength(v) }
                }
              }
            }

            PanelSeparator { foreground: root.foreground }

            // ---- Keybindings ----
            Column {
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader { text: "KEYBINDINGS"; foreground: root.foreground; fontFamily: Style.font.family }

              Toggle {
                width: parent.width
                label: "Dusky keybindings"
                description: root.keybindings === "dusky"
                  ? "Vim H/J/K/L focus, arrows resize, SUPER + ALT pickers"
                  : "Omarchy's shipped bindings: SUPER + J/K/L and the arrows"
                checked: root.keybindings === "dusky"
                foreground: root.foreground
                accent: Color.accent
                fontFamily: Style.font.family
                hasCursor: root.cursorActive && root.cursorIndex === 7
                onClicked: root.toggleKeybindings()
              }
            }

            PanelSeparator { foreground: root.foreground }

            // ---- Display ----
            Column {
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader { text: "DISPLAY"; foreground: root.foreground; fontFamily: Style.font.family }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Button {
                  text: "↺ Rotate"
                  tooltipText: "Rotate focused monitor counter-clockwise"
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === 8
                  onClicked: root.rotate("ccw")
                }
                Button {
                  text: "↻ Rotate"
                  tooltipText: "Rotate focused monitor clockwise"
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === 9
                  onClicked: root.rotate("cw")
                }
                Button {
                  text: "⏻ Screen off"
                  tooltipText: "DPMS off (any key wakes it)"
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === 10
                  onClicked: root.screenOff()
                }
              }
            }

            PanelSeparator { foreground: root.foreground }

            // ---- Wallpaper ----
            Column {
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader { text: "WALLPAPER"; foreground: root.foreground; fontFamily: Style.font.family }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Button {
                  width: (parent.width - parent.spacing) / 2
                  text: "󰒮 Previous"
                  tooltipText: "Previous background (including ~/Pictures)"
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === 11
                  onClicked: root.bgPrev()
                }

                Button {
                  width: (parent.width - parent.spacing) / 2
                  text: "Next 󰒭"
                  tooltipText: "Next background (including ~/Pictures)"
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  bordered: true
                  hasCursor: root.cursorActive && root.cursorIndex === 12
                  onClicked: root.bgNext()
                }
              }

              Button {
                width: parent.width
                text: "Pick wallpaper…"
                tooltipText: "Choose a background from a thumbnail grid"
                foreground: root.foreground
                fontFamily: Style.font.family
                bordered: true
                hasCursor: root.cursorActive && root.cursorIndex === 13
                onClicked: root.pickWallpaper()
              }
            }

            PanelSeparator { foreground: root.foreground }

            // The chip is the only part of the plugin that takes bar space,
            // and it is off by default -- so the way back on belongs here,
            // next to everything else the panel controls.
            Column {
              width: parent.width
              spacing: root.contentSpacing

              PanelSectionHeader { text: "BAR CHIP"; foreground: root.foreground; fontFamily: Style.font.family }

              Toggle {
                width: parent.width
                label: "Show the bar chip"
                description: root.barChip
                  ? "On the bar. Everything works without it too"
                  : "Off. This panel and the Omarchy menu work without it"
                checked: root.barChip
                foreground: root.foreground
                accent: Color.accent
                fontFamily: Style.font.family
                hasCursor: root.cursorActive && root.cursorIndex === 14
                onClicked: root.toggleBarChip()
              }
            }
          }
        }
      }
    }
  }
}
