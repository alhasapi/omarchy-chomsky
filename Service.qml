import QtQuick
import Quickshell
import Quickshell.Io

// Chomsky's startup surface, kept out of BarWidget.qml on purpose.
//
// The Omarchy menu rows are meant to be the plugin's main UI, so the bar chip
// is optional -- and a widget's own component is only instantiated where it is
// placed in the bar. Anything that has to happen once per shell start (the
// saved shader going back on, the menu rows being in place) therefore cannot
// live in the widget: take the chip off the bar and it would stop running.
//
// A plugin that declares the "service" kind is mounted for as long as the
// plugin is enabled, however its widget is placed -- including not at all. See
// `bin/chomsky-bar off` for taking the chip off the bar while keeping the
// plugin enabled.
Item {
  id: root

  readonly property string helperPath: Qt.resolvedUrl("bin/chomsky").toString().replace(/^file:\/\//, "")

  Component.onCompleted: {
    if (!root.helperPath) return

    // Re-apply whatever shader is on record. Replaces a hook that used to live
    // in ~/.config/hypr/autostart.lua -- keeping it here means a fresh plugin
    // install needs no edits to anyone's hyprland config.
    Quickshell.execDetached(["bash", root.helperPath, "shader", "restore"])

    // Make the Omarchy menu rows match the saved setting. Safe to run more
    // than once; chomsky-menu-install serialises concurrent runs itself.
    Quickshell.execDetached(["bash", root.helperPath, "menu-install"])
  }
}
