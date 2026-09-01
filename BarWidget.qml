import QtQuick
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "ksxx.liftoff"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root).
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

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

  // Soft accent tint behind the pill while the tracked launch is imminent
  // (Model.isImminent's window, exposed as Panel.qml's `imminent`) — a
  // "this one's close" cue at a glance, not an error/warning state, so it
  // uses the accent color rather than the default urgent/warning tint.
  Rectangle {
    anchors.fill: button
    radius: Style.cornerRadius
    color: (panelLoader.item && panelLoader.item.imminent === true)
           ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.13)
           : "transparent"
    Behavior on color { ColorAnimation { duration: 300 } }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: panelLoader.item ? panelLoader.item.label : "󱓞"
    horizontalMargin: 8.75
    active: panelLoader.item ? panelLoader.item.imminent === true : false
    activeColor: Color.accent
    // Suppressed, not just left off: the panel opened by a click is the
    // detail view, and (per omarchy.weather, the reference for this exact
    // BarWidget+Panel pattern) a hover tooltip on top of that gets stuck
    // showing after the click instead of being dismissed.
    tooltipText: ""

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
