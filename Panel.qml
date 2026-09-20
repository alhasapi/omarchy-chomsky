import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "alhasapi.chomsky"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property string helperPath: hostWidget && hostWidget.helperPath ? hostWidget.helperPath : ""
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string animation: hostWidget && hostWidget.animation ? hostWidget.animation : "(none)"
  readonly property string shaderName: hostWidget && hostWidget.shader ? hostWidget.shader : "off"
  readonly property bool shaderOn: hostWidget && hostWidget.shaderOn === true
  readonly property string themeName: hostWidget && hostWidget.theme ? hostWidget.theme : ""
  readonly property bool resizeOnBorder: hostWidget && hostWidget.resizeOnBorder === true
  readonly property real dimStrength: hostWidget && typeof hostWidget.dimStrength === "number" ? hostWidget.dimStrength : 0.15
  readonly property string keybindings: hostWidget && hostWidget.keybindings === "dusky" ? "dusky" : "omarchy"

  property var animationList: []
  property var shaderList: []

  // Flat keyboard-cursor index over every interactive control below, in
  // visual (top-to-bottom) order. The dim-strength slider is reachable by
  // mouse/wheel only -- dragging a slider by discrete keyboard steps isn't
  // worth the extra index bookkeeping for a single control.
  property int cursorIndex: 0
  property bool cursorActive: false
  readonly property int cursorCount: 14

  function open() {
    root.controller.show()
    root.reloadLists()
    root.cursorActive = false
    root.cursorIndex = 0
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
  }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(hostWidget || root, direction)
    return false
  }

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
      case 13: root.reloadHyprland(); break
    }
  }

  function setAnimation(name) {
    if (hostWidget && hostWidget.setAnimation) hostWidget.setAnimation(name)
    Qt.callLater(root.reloadLists)
  }
  function animNext() {
    if (hostWidget && hostWidget.animNext) hostWidget.animNext()
    Qt.callLater(root.reloadLists)
  }
  function animPrev() {
    if (hostWidget && hostWidget.animPrev) hostWidget.animPrev()
    Qt.callLater(root.reloadLists)
  }
  function setShader(name) {
    if (hostWidget && hostWidget.setShader) hostWidget.setShader(name)
    Qt.callLater(root.reloadLists)
  }
  function shaderOff() {
    if (hostWidget && hostWidget.shaderOff) hostWidget.shaderOff()
    Qt.callLater(root.reloadLists)
  }
  function shaderNext() {
    if (hostWidget && hostWidget.shaderNext) hostWidget.shaderNext()
    Qt.callLater(root.reloadLists)
  }
  function shaderPrev() {
    if (hostWidget && hostWidget.shaderPrev) hostWidget.shaderPrev()
    Qt.callLater(root.reloadLists)
  }
  function toggleWindowBehavior() {
    if (hostWidget && hostWidget.toggleWindowBehavior) hostWidget.toggleWindowBehavior()
  }
  function toggleKeybindings() {
    if (hostWidget && hostWidget.toggleKeybindings) hostWidget.toggleKeybindings()
  }
  function setDimStrength(v) {
    if (hostWidget && hostWidget.setDimStrength) hostWidget.setDimStrength(v)
  }
  function rotate(direction) {
    if (hostWidget && hostWidget.rotate) hostWidget.rotate(direction)
  }
  function screenOff() {
    if (hostWidget && hostWidget.screenOff) hostWidget.screenOff()
  }
  function bgPrev() {
    if (hostWidget && hostWidget.bgPrev) hostWidget.bgPrev()
  }
  function bgNext() {
    if (hostWidget && hostWidget.bgNext) hostWidget.bgNext()
  }
  function reloadHyprland() {
    if (hostWidget && hostWidget.reloadHyprland) hostWidget.reloadHyprland()
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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(Math.min(content.implicitHeight, Style.space(560)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // Suspend cursor-driven nav while a dropdown owns its own popup keys
      // (search field, result list, Esc-to-close) -- otherwise j/k here
      // would double-drive both the popup and the panel cursor underneath it.
      blocked: animDropdown.popupOpen || shaderDropdown.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { root.moveCursor(dy !== 0 ? dy : dx) }
      onActivateRequested: root.activateCursor()

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Chomsky"
          meta: root.animation + " · " + (root.shaderOn ? root.shaderName : "no shader")
            + (root.themeName ? " · " + root.themeName : "")
            + " · " + (root.keybindings === "dusky" ? "Dusky keys" : "Omarchy keys")
          foreground: root.foreground
          fontFamily: root.fontFamily
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

          PanelSectionHeader { text: "ANIMATION"; foreground: root.foreground; fontFamily: root.fontFamily }

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
              fontFamily: root.fontFamily
              hasCursor: root.cursorActive && root.cursorIndex === 0
              onChanged: function(v) { root.setAnimation(v) }
            }
            PanelActionButton {
              id: prevBtn
              anchors.verticalCenter: animDropdown.verticalCenter
              iconText: "󰒮"
              tooltipText: "Previous animation"
              foreground: root.foreground
              fontFamily: root.fontFamily
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
              fontFamily: root.fontFamily
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

          PanelSectionHeader { text: "SHADER"; foreground: root.foreground; fontFamily: root.fontFamily }

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
              fontFamily: root.fontFamily
              hasCursor: root.cursorActive && root.cursorIndex === 3
              onChanged: function(v) { v === "off" ? root.shaderOff() : root.setShader(v) }
            }
            PanelActionButton {
              id: shaderPrevBtn
              anchors.verticalCenter: shaderDropdown.verticalCenter
              iconText: "󰒮"
              tooltipText: "Previous shader"
              foreground: root.foreground
              fontFamily: root.fontFamily
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
              fontFamily: root.fontFamily
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

          PanelSectionHeader { text: "WINDOW BEHAVIOR"; foreground: root.foreground; fontFamily: root.fontFamily }

          Toggle {
            width: parent.width
            label: "Resize by border / dim inactive"
            description: root.resizeOnBorder
              ? "Drag any edge to resize; unfocused windows dim"
              : "Omarchy defaults: SUPER-drag only, no dimming"
            checked: root.resizeOnBorder
            foreground: root.foreground
            accent: Color.accent
            fontFamily: root.fontFamily
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
              font.family: root.fontFamily
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

          PanelSectionHeader { text: "KEYBINDINGS"; foreground: root.foreground; fontFamily: root.fontFamily }

          Toggle {
            width: parent.width
            label: "Dusky keybindings"
            description: root.keybindings === "dusky"
              ? "Vim H/J/K/L focus, arrows resize, SUPER + ALT pickers"
              : "Omarchy's shipped bindings: SUPER + J/K/L and the arrows"
            checked: root.keybindings === "dusky"
            foreground: root.foreground
            accent: Color.accent
            fontFamily: root.fontFamily
            hasCursor: root.cursorActive && root.cursorIndex === 7
            onClicked: root.toggleKeybindings()
          }
        }

        PanelSeparator { foreground: root.foreground }

        // ---- Display ----
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader { text: "DISPLAY"; foreground: root.foreground; fontFamily: root.fontFamily }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              text: "↺ Rotate"
              tooltipText: "Rotate focused monitor counter-clockwise"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              hasCursor: root.cursorActive && root.cursorIndex === 8
              onClicked: root.rotate("ccw")
            }
            Button {
              text: "↻ Rotate"
              tooltipText: "Rotate focused monitor clockwise"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              hasCursor: root.cursorActive && root.cursorIndex === 9
              onClicked: root.rotate("cw")
            }
            Button {
              text: "⏻ Screen off"
              tooltipText: "DPMS off (any key wakes it)"
              foreground: root.foreground
              fontFamily: root.fontFamily
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

          PanelSectionHeader { text: "WALLPAPER"; foreground: root.foreground; fontFamily: root.fontFamily }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "󰒮 Previous"
              tooltipText: "Previous background (including ~/Pictures)"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              hasCursor: root.cursorActive && root.cursorIndex === 11
              onClicked: root.bgPrev()
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Next 󰒭"
              tooltipText: "Next background (including ~/Pictures)"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              hasCursor: root.cursorActive && root.cursorIndex === 12
              onClicked: root.bgNext()
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        // ---- Footer ----
        Button {
          width: parent.width
          text: "Reload Hyprland"
          leftAlign: false
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          hasCursor: root.cursorActive && root.cursorIndex === 13
          onClicked: root.reloadHyprland()
        }
      }
    }
  }
}
