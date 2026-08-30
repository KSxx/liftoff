import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Backing state + popup for the Rocket Launches widget. Always loaded (via
// BarWidget.qml's Loader) so the bar pill can show a live countdown even
// while the popup itself is closed. Live data fetching lands in a later
// iteration; for now this just establishes the panel shell.
Panel {
  id: root
  moduleName: "ksxx.liftoff"
  ipcTarget: "ksxx.liftoff"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Bar pill text. Placeholder until live data lands.
  property string label: "🚀"
  property string tooltipText: "Rocket Launches"

  function open() {
    root.controller.show()
    refresh()
  }

  function openFromHotkey() {
    open()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) close()
    else open()
  }

  function refresh() {
    // TODO: poll RocketLaunch.Live and update label/content.
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(placeholder.implicitHeight + Style.space(32))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: placeholder
        anchors.centerIn: parent
        spacing: Style.space(8)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "🚀"
          font.pixelSize: 32
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "No launch data yet"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }
}
