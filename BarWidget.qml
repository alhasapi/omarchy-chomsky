import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Chomsky's optional bar chip.
//
// The plugin does not need it. The Omarchy menu rows under Style cover
// everything the plugin does, and the panel behind them is summoned from the
// menu -- or with `omarchy-shell shell toggle alhasapi.chomsky` -- and is
// centered on screen rather than anchored to a bar icon. So the chip is a
// status-at-a-glance and a second way in, for anyone who wants one:
// `bin/chomsky-bar off` takes it off the bar and leaves the plugin, its menu
// rows and its service running.
//
// State comes from the plugin's service, which the shell exposes to every
// plugin entry point through the injected facade, so the chip shows what the
// panel shows without polling anything itself.
BarWidget {
  id: root
  moduleName: "alhasapi.chomsky"

  readonly property string helperPath: Qt.resolvedUrl("bin/chomsky").toString().replace(/^file:\/\//, "")

  // A third-party bar widget is handed a PluginBarApi facade as its `bar`
  // (Ui/BarWidget.qml documents bar/moduleName/settings as the injected set),
  // and the plugin shell facade lives on it, at bar.shell. That is what can
  // reach this plugin's own service. A replacement bar hands over a
  // service-less facade instead, in which case `service` stays null and the
  // chip falls back to showing no live state -- the host's rule, not ours to
  // work around.
  readonly property var shellFacade: bar && bar.shell ? bar.shell : null

  readonly property var service: shellFacade && typeof shellFacade.serviceFor === "function"
    ? shellFacade.serviceFor("alhasapi.chomsky") : null
  readonly property string animation: service && service.animation ? service.animation : "(none)"
  readonly property string shader: service && service.shader ? service.shader : "off"
  readonly property bool shaderOn: service && service.shaderOn === true
  readonly property string theme: service && service.theme ? service.theme : ""
  readonly property string keybindings: service && service.keybindings === "dusky" ? "dusky" : "omarchy"

  readonly property string icon: "󰸉"
  readonly property color foreground: bar ? bar.barForeground : Color.foreground

  // Opens the panel the same way the menu row does -- through the host, since
  // the panel is the plugin's own `panel` entry point rather than a popup this
  // widget owns.
  function toggle() {
    if (shellFacade && typeof shellFacade.toggle === "function")
      shellFacade.toggle("alhasapi.chomsky", "{}")
  }

  // The rows' durable state is the plugin's own state file;
  // chomsky-menu-install owns it and chomsky-menu-install --enable/--remove
  // write it. This mirrors an explicit widget setting onto that file.
  // `settings` can arrive half-populated, so only an explicit value counts.
  function syncMenuRowsFromSettings() {
    var settings = root.settings
    if (!settings || settings.menuRows === undefined) return
    var wanted = settings.menuRows
    var on = wanted === true || wanted === "true" || wanted === 1
    Quickshell.execDetached(["bash", root.helperPath, "menu-install", on ? "--enable" : "--remove"])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onSettingsChanged: syncMenuRowsFromSettings()

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
