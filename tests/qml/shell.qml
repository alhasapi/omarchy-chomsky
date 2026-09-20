import QtQuick
import Quickshell
import qs.Commons

// A harness for Panel.qml, used by tests/t_qml.sh.
//
// It loads the real panel with a stub service standing in for Service.qml, so
// nothing here talks to a CLI or a state file. It then measures the card and
// prints one line per fact, because the checks are made on the output rather
// than in QML: a test that can only pass or fail inside a language nobody else
// reads is a test nobody can fix.
//
// Three things it cannot fake, and why the suite is opt-in:
//
//   * Panel.qml creates a PanelWindow. A layer surface takes its width and
//     height from the compositor, and the card is sized from the window, so
//     there has to be a compositor. The panel is opened, measured and closed
//     inside a second, so it appears briefly on the focused monitor.
//   * The lists it feeds the dropdowns come from CHOMSKY_TEST_ANIMATIONS and
//     CHOMSKY_TEST_SHADERS, which the test fills with the real names -- the
//     longest thing the panel ever has to lay out, which is what makes the
//     truncation check mean something.
//   * Style, Color and Border come from qs.Commons, so the real theme is in
//     play: the numbers move when Omarchy's theme changes, and the assertions
//     are relative for that reason.
ShellRoot {
  id: harness

  // Where Panel.qml is. The group copies this file next to Omarchy's modules
  // (a `qs.Commons` import resolves against the config directory) and passes
  // the path; the relative fallback is for running it by hand from here.
  readonly property string panelPath: (Quickshell.env("CHOMSKY_TEST_PANEL") || "../../Panel.qml")
  readonly property string barChipOn: (Quickshell.env("CHOMSKY_TEST_BARCHIP") || "off")
  readonly property var animationNames: parseList("CHOMSKY_TEST_ANIMATIONS",
    ["ethereal-dusky-slowmotion", "vertical_air", "slide", "fade"])
  readonly property var shaderNames: parseList("CHOMSKY_TEST_SHADERS",
    ["chromatic-aberration-strong", "off", "crt-easymode"])

  function parseList(name, fallback) {
    var raw = Quickshell.env(name) || ""
    if (raw === "") return fallback
    try {
      var list = JSON.parse(raw)
      return (list && list.length) ? list : fallback
    } catch (e) {
      console.log("HARNESS bad " + name + ": " + e)
      return fallback
    }
  }

  // --- the stub service ----------------------------------------------------
  // Every property Panel.qml reads and every action it can call. Actions are
  // no-ops that record their name, so a report can say what the panel tried to
  // do without anything happening.
  property var calls: []
  readonly property string helperPath: ""
  readonly property string animation: animationNames.length ? animationNames[0] : "(none)"
  readonly property string shader: shaderNames.length ? shaderNames[0] : "off"
  readonly property bool shaderOn: true
  readonly property string theme: "tokyo-night"
  readonly property bool resizeOnBorder: true
  readonly property real dimStrength: 0.35
  readonly property string keybindings: "dusky"
  readonly property string barChip: barChipOn
  function note(name) { calls = calls.concat([name]) }
  function refresh() { note("refresh") }
  function setAnimation(v) { note("setAnimation") }
  function animNext() { note("animNext") }
  function animPrev() { note("animPrev") }
  function setShader(v) { note("setShader") }
  function shaderOff() { note("shaderOff") }
  function shaderNext() { note("shaderNext") }
  function shaderPrev() { note("shaderPrev") }
  function toggleWindowBehavior() { note("toggleWindowBehavior") }
  function toggleKeybindings() { note("toggleKeybindings") }
  function setDimStrength(v) { note("setDimStrength") }
  function rotate(d) { note("rotate") }
  function screenOff() { note("screenOff") }
  function bgPrev() { note("bgPrev") }
  function bgNext() { note("bgNext") }
  function bgMenu() { note("bgMenu") }
  function reloadHyprland() { note("reloadHyprland") }

  // --- walking the tree ----------------------------------------------------
  function childrenOf(item) {
    var out = ((item.children || []).length ? item.children.slice() : (item.data || []).slice())
    if (item.contentItem) out.push(item.contentItem)
    if (item.item) out.push(item.item)
    return out
  }

  // `seen` matters: childrenOf() reports an object through more than one route
  // (children, data, contentItem, item), and without it every control is
  // visited -- and counted -- several times over.
  function walk(item, visit, depth, seen) {
    if (!item || (depth || 0) > 60) return
    if (!seen) seen = []
    var kids = childrenOf(item)
    for (var i = 0; i < kids.length; i++) {
      if (seen.indexOf(kids[i]) >= 0) continue
      seen.push(kids[i])
      visit(kids[i])
      walk(kids[i], visit, (depth || 0) + 1, seen)
    }
  }

  function find(item, match, depth) {
    if (!item || (depth || 0) > 60) return null
    var kids = childrenOf(item)
    for (var i = 0; i < kids.length; i++) {
      var hit = null
      try { if (match(kids[i])) hit = kids[i] } catch (e) {}
      if (hit) return hit
      hit = find(kids[i], match, (depth || 0) + 1)
      if (hit) return hit
    }
    return null
  }

  function hasProperty(item, name) {
    try { return item[name] !== undefined } catch (e) { return false }
  }

  // --- the panel -----------------------------------------------------------
  Loader {
    id: panelLoader
    source: harness.panelPath
    onLoaded: {
      item.service = harness
      item.animationList = harness.animationNames
      item.shaderList = harness.shaderNames
      item.open("{}")
    }
  }

  Timer {
    // Long enough for the compositor to configure the surface and for the
    // card to be laid out against it, short enough not to be in the way.
    interval: 900
    running: true
    onTriggered: {
      var report = harness.measure(panelLoader.item)
      var panel = panelLoader.item
      panel.close()
      console.log(report)
      console.log("REPORT-END")
      Qt.quit()
    }
  }

  function measure(panel) {
    if (!panel) return "HARNESS panel did not load"
    var lines = []
    function say(s) { lines.push(s) }

    say("HARNESS helperPath=[" + panel.helperPath + "] calls=" + JSON.stringify(calls))

    var card = find(panel, function (i) {
      return i.contentTopInset !== undefined && i.radius !== undefined
    })
    if (!card) return lines.concat(["CARD not found"]).join("\n")

    var flick = find(panel, function (i) {
      return i.flickableDirection !== undefined && i.contentHeight !== undefined
    })
    var content = flick && flick.contentItem && flick.contentItem.children.length
      ? flick.contentItem.children[0] : null
    var needed = panel.neededHeight
    var innerBottom = card.height - card.contentBottomInset
    var contentBottom = content ? content.mapToItem(card, 0, 0).y + content.height : -1

    var win = find(panel, function (i) { return i.exclusionMode !== undefined })
    if (!win) return lines.concat(["WINDOW not found"]).join("\n")
    say("GEOM windowW=" + Math.round(win.width) + " windowH=" + Math.round(win.height)
      + " cardW=" + Math.round(card.width) + " cardH=" + Math.round(card.height)
      + " needed=" + Math.round(needed) + " space340=" + Style.space(340)
      + " gapsOut=" + Style.gapsOut)
    say("CARD insets T=" + card.contentTopInset + " B=" + card.contentBottomInset
      + " L=" + card.contentLeftInset + " R=" + card.contentRightInset)
    say("CONTENT implicit=" + Math.round(content ? content.implicitHeight : -1)
      + " bottom=" + Math.round(contentBottom) + " cardInnerBottom=" + Math.round(innerBottom)
      + " slack=" + Math.round(innerBottom - contentBottom))

    // Text: nothing may be elided, and every piece of it has to sit inside the
    // card's content box.
    var nil = { x: 1e9, y: 1e9, r: -1e9, b: -1e9, n: 0, truncated: [] }
    var box = nil
    walk(panel, function (i) {
      if (!hasProperty(i, "truncated") || !hasProperty(i, "text")) return
      if (!String(i.text).length) return
      if (i.truncated === true)
        box.truncated.push(String(i.text).substring(0, 60) + " (elide=" + i.elide + ", w=" + Math.round(i.width) + ")")
      var p = i.mapToItem(panel, 0, 0)
      box.x = Math.min(box.x, p.x)
      box.y = Math.min(box.y, p.y)
      box.r = Math.max(box.r, p.x + i.width)
      box.b = Math.max(box.b, p.y + i.height)
      box.n++
    })
    say("TEXTBOX n=" + box.n + " x=" + Math.round(box.x) + ".." + Math.round(box.r)
      + " y=" + Math.round(box.y) + ".." + Math.round(box.b))
    // Left and right are the panel's own outer edges, so compare against the
    // card instead: text outside the card would be clipped by it visually.
    var cardBox = card.mapToItem(panel, 0, 0)
    say("CARDBOX x=" + Math.round(cardBox.x) + ".." + Math.round(cardBox.x + card.width)
      + " y=" + Math.round(cardBox.y) + ".." + Math.round(cardBox.y + card.height))
    for (var t = 0; t < box.truncated.length; t++) say("TRUNCATED " + box.truncated[t])
    say("TRUNCATED-COUNT " + box.truncated.length)

    // The chip switch: it should be the first keyboard stop.
    var sw = find(panel, function (i) {
      return i.checked !== undefined && i.cursorRing !== undefined
    })
    if (sw) {
      var wasActive = panel.cursorActive
      var wasIndex = panel.cursorIndex
      panel.cursorActive = true
      panel.cursorIndex = 0
      var first = sw.hasCursor === true
      panel.cursorActive = wasActive
      panel.cursorIndex = wasIndex
      say("SWITCH found checked=" + sw.checked + " visible=" + sw.visible + " isFirstStop=" + first
        + " w=" + Math.round(sw.width) + " h=" + Math.round(sw.height))
    } else {
      say("SWITCH not found")
    }

    // The cursor: every index the panel claims to have must light exactly one
    // control. This is what a stale index after removing a row looks like from
    // the outside -- the count says 15 and one of them does nothing.
    var controls = 0
    walk(panel, function (i) { if (hasProperty(i, "hasCursor")) controls++ })
    var wasActive2 = panel.cursorActive
    var wasIndex2 = panel.cursorIndex
    panel.cursorActive = true
    var strays = []
    var perIndex = []
    for (var i = 0; i < panel.cursorCount; i++) {
      panel.cursorIndex = i
      var hit = 0
      walk(panel, function (c) { if (c.hasCursor === true) hit++ })
      perIndex.push(hit)
      if (hit !== 1) strays.push(i + "->" + hit)
    }
    panel.cursorActive = wasActive2
    panel.cursorIndex = wasIndex2
    say("CURSORS count=" + panel.cursorCount + " controls=" + controls
      + " perIndex=" + perIndex.join(","))
    say("CURSOR-STRAYS " + (strays.length ? strays.join(" ") : "none"))

    return lines.join("\n")
  }
}
