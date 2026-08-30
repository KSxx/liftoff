import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Backing state + popup for the Rocket Launches widget. Always loaded (via
// BarWidget.qml's Loader) so the bar pill can show a live countdown even
// while the popup itself is closed.
//
// Polls the free RocketLaunch.Live `launches/next/5` endpoint over curl —
// no API key needed for that endpoint, and the plugin never asks for one.
// See docs/RESEARCH.md and docs/DECISIONS.md for why.
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

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 300, 60, 3600)

  property var launches: []
  property var selected: null
  property bool loading: false
  property string lastError: ""
  property real lastFetchMs: 0
  property real nowMs: Date.now()

  readonly property bool offline: lastError !== ""
  readonly property var nextLaunch: launches.length > 0 ? launches[0] : null

  // Bar pill text: rocket + compact countdown/date/TBD, or a clear "can't
  // reach the API" marker when there's no cached data to fall back to.
  readonly property string label: {
    if (root.offline && root.launches.length === 0) return "🚀 !"
    return Model.barLabel(root.nextLaunch, root.nowMs)
  }

  // launches[] projected onto {lat, lon, isNext, label, launch} for the map,
  // skipping anything whose site isn't in LaunchSites.js.
  readonly property var mapModel: {
    var out = []
    for (var i = 0; i < root.launches.length; i++) {
      var l = root.launches[i]
      if (l.lat === null || l.lon === null) continue
      var countdown = Model.countdownLabel(l.t0, root.nowMs)
      var tail = countdown ? (" · " + countdown) : (l.dateLabel ? (" · ~" + l.dateLabel) : "")
      out.push({ key: l.id, lat: l.lat, lon: l.lon, isNext: l.isNext, label: l.name + tail, launch: l })
    }
    return out
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

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
    if (fetchProcess.running) return
    root.loading = true
    fetchProcess.command = ["curl", "-fsS", "--max-time", "10", "https://fdo.rocketlaunch.live/json/launches/next/5"]
    fetchProcess.running = true
  }

  function applyLaunches(list) {
    root.launches = list
    var keepId = root.selected ? root.selected.id : null
    var found = null
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === keepId) { found = list[i]; break }
    }
    root.selected = found || (list.length > 0 ? list[0] : null)
  }

  function selectLaunch(launch) {
    root.selected = launch
  }

  Process {
    id: fetchProcess
    running: false
    command: []
    stdout: StdioCollector { id: fetchStdout; waitForEnd: true }
    stderr: StdioCollector { id: fetchStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode === 0) {
        root.applyLaunches(Model.parseLaunches(String(fetchStdout.text || "")))
        root.lastError = ""
        root.lastFetchMs = Date.now()
      } else {
        root.lastError = String(fetchStderr.text || "").trim() || "RocketLaunch.Live unreachable"
        retryTimer.restart()
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Back off to a short fixed retry after a failure, independent of the
  // configured (possibly much longer) normal interval.
  Timer {
    id: retryTimer
    interval: 30000
    repeat: false
    onTriggered: root.refresh()
  }

  // Ticks the countdown display. Faster while the popup is open or a launch
  // is imminent, otherwise slow enough to cost nothing.
  Timer {
    id: clockTimer
    interval: (root.opened || Model.isImminent(root.nextLaunch ? root.nextLaunch.t0 : null, root.nowMs)) ? 1000 : 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.nowMs = Date.now()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(column.implicitHeight + Style.space(32))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: scroll.width
          spacing: Style.space(14)

          Rectangle {
            visible: root.offline
            width: parent.width
            height: offlineText.implicitHeight + Style.space(12)
            radius: Style.cornerRadius > 0 ? Style.space(4) : 0
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
            border.color: Color.urgent
            border.width: 1

            Text {
              id: offlineText
              anchors.centerIn: parent
              width: parent.width - Style.space(16)
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              color: Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              text: root.launches.length > 0
                    ? "Can't reach RocketLaunch.Live — showing the last data from "
                      + Model.localTimeLabel(new Date(root.lastFetchMs).toISOString())
                    : "Can't reach RocketLaunch.Live: " + root.lastError
            }
          }

          WorldMap {
            width: parent.width
            launches: root.mapModel
            foreground: root.foreground
            fontFamily: root.fontFamily
            onLaunchClicked: function(item) { root.selectLaunch(item.launch) }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: root.selected !== null

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              text: root.selected ? root.selected.name : ""
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              text: root.selected ? [root.selected.provider, root.selected.vehicle].filter(function(s) { return s }).join(" · ") : ""
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              text: {
                if (!root.selected) return ""
                var loc = [root.selected.padName, root.selected.locationName, root.selected.country].filter(function(s) { return s }).join(", ")
                return loc
              }
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              text: {
                if (!root.selected) return ""
                if (root.selected.precision === "exact") {
                  var local = Model.localTimeLabel(root.selected.t0)
                  var cd = Model.countdownLabel(root.selected.t0, root.nowMs)
                  return (local || "") + (cd ? "  ·  T−" + cd : "")
                }
                if (root.selected.precision === "date") return "Estimated: " + root.selected.dateLabel
                return "Launch date: TBD"
              }
            }

            Text {
              visible: root.selected && root.selected.missionDescription !== ""
              width: parent.width
              wrapMode: Text.WordWrap
              color: root.foreground
              opacity: 0.85
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              text: root.selected ? root.selected.missionDescription : ""
            }

            Row {
              spacing: Style.space(12)

              Text {
                visible: root.selected && root.selected.detailUrl !== null
                text: "Launch page ↗"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.selected && root.selected.detailUrl) Qt.openUrlExternally(root.selected.detailUrl)
                }
              }

              Text {
                visible: root.selected && root.selected.livestreamUrl !== null
                text: "Livestream ↗"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.selected && root.selected.livestreamUrl) Qt.openUrlExternally(root.selected.livestreamUrl)
                }
              }
            }
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignRight
            color: root.foreground
            opacity: 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            text: "Data by RocketLaunch.Live"

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Qt.openUrlExternally("https://rocketlaunch.live/")
            }
          }
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
