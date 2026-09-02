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

  // One row in the launch list. Built on CursorSurface (qs.Ui) so hover/
  // selection visuals follow the shared panel-row contract: never read
  // containsMouse directly for color, only hasCursor (transient, set by the
  // caller from a centralized hover key) and current (persistent selection).
  // Doesn't bind into `root` directly (nested components don't inherit the
  // outer id scope) — every input comes in as an explicit property.
  // One PROVIDER/VEHICLE/SITE/LOCAL cell in the detail strip below. Same
  // "explicit properties, not outer id scope" shape as LaunchRow above —
  // labelColor/valueColor/fontFamily come in per instance rather than
  // reading root.* directly.
  component DetailCell: Column {
    property string label: ""
    property string value: ""
    property real widthRatio: 1
    property color labelColor: Color.foreground
    property color valueColor: Color.foreground
    property string fontFamily: Style.font.family

    width: (parent.width - parent.spacing * 3) / 4 * widthRatio
    spacing: Style.space(3)

    Text {
      text: label
      color: labelColor
      font.family: fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1.5
    }
    Text {
      width: parent.width
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: value
      color: valueColor
      font.family: fontFamily
      font.pixelSize: Style.font.body
    }
  }

  component LaunchRow: CursorSurface {
  id: row

  property var launch: null
  property string fontFamily: Style.font.family
  property bool watched: false
  property real nowMs: Date.now()

  signal entered()
  signal exited()
  signal rowClicked()
  signal watchToggled()

  implicitHeight: body.implicitHeight + Style.space(6)
  height: implicitHeight
  // Selection gets the rail+wash below instead of CursorSurface's default
  // flat box+border for the `current` state. The hover-cursor border stays
  // exactly as CursorSurface defines it — only the (non-hover) selected
  // state's border is suppressed.
  currentFill: "transparent"
  borderSpec: hasCursor ? Border.controlSpec("hover-cursor", foreground, accent) : Border.none()

  readonly property color textPrimary: foreground
  readonly property color textSecondary: Qt.darker(foreground, 1.1)

  // Countdown badge color ramps from a dim neutral tone up to the accent
  // color as a launch gets closer (Model.urgencyRatio — shared with the
  // hero header and map rings, not recomputed here). The selected row's
  // countdown goes fully accent regardless of urgency, matching the rail.
  readonly property color dimColor: Qt.darker(foreground, 1.7)
  readonly property real urgency: launch ? Model.urgencyRatio(launch.t0, nowMs) : 0
  readonly property color countdownColor: current ? accent : Model.blendColor(dimColor, accent, urgency)

  // Selected-row treatment: a left accent rail + a quiet accent-to-transparent
  // wash, instead of a flat highlight box — keeps the row itself uncluttered.
  Rectangle {
    visible: row.current
    anchors.fill: parent
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.09) }
      GradientStop { position: 0.92; color: "transparent" }
    }
  }
  Rectangle {
    visible: row.current
    width: 2
    color: row.accent
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: row.entered()
    onExited: row.exited()
    onClicked: row.rowClicked()
  }

  Row {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    spacing: Style.space(6)

    Column {
      width: parent.width - star.width - parent.spacing
      spacing: Style.space(2)

      Text {
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: row.launch ? row.launch.name : ""
        color: (row.hasCursor || row.current) ? row.textPrimary : row.textSecondary
        font.family: row.fontFamily
        font.pixelSize: 11
        font.bold: row.watched
      }

      Row {
        width: parent.width
        spacing: Style.space(5)

        Rectangle {
          id: urgencyDot
          width: 3; height: 3; radius: 1.5
          anchors.verticalCenter: parent.verticalCenter
          color: row.countdownColor
        }

        Text {
          width: parent.width - urgencyDot.width - parent.spacing
          elide: Text.ElideRight
          textFormat: Text.PlainText
          color: row.countdownColor
          font.family: row.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: row.urgency >= 1
          text: {
            if (!row.launch) return ""
            var c = Model.countdownLabel(row.launch.t0, row.nowMs)
            var when = c ? ("T−" + c) : (row.launch.precision === "date" && row.launch.dateLabel ? "~" + row.launch.dateLabel : "TBD")
            return row.launch.provider ? (when + " · " + row.launch.provider) : when
          }
        }
      }
    }

    Text {
      id: star
      text: row.watched ? "" : ""
      color: row.watched ? Color.accent : Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.55)
      font.family: row.fontFamily
      font.pixelSize: Style.font.body

      MouseArea {
        anchors.fill: parent
        anchors.margins: -Style.space(4)
        cursorShape: Qt.PointingHandCursor
        onClicked: row.watchToggled()
      }
    }
  }
  }

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Redesign palette: four gray steps derived off the theme's own foreground
  // (never hardcoded hex, so it keeps following the active Omarchy theme).
  // Qt.darker() rather than alpha transparency — alpha blends toward
  // whatever's behind it (here, a near-black panel), which compounds with
  // a foreground that's already not pure white and reads notably dimmer
  // than intended; darkening the opaque color instead stays predictable
  // regardless of background. textPrimary is reserved for the one
  // "brightest" element at a time (the hero name); everything else steps
  // down from there.
  readonly property color textPrimary: root.foreground
  readonly property color textSecondary: Qt.darker(root.foreground, 1.1)
  readonly property color textLabel: Qt.darker(root.foreground, 1.7)
  readonly property color textMeta: Qt.darker(root.foreground, 2.8)

  // Border roles, per the Claude Design handoff spec (section 01): thin
  // alpha-blended lines, not darkened opaque text tones — a line is meant
  // to read as subtle against whatever's behind it, unlike body text.
  readonly property color borderLine: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
  readonly property color borderLineSoft: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 300, 60, 3600)

  property var launches: []
  property var selected: null
  property bool loading: false
  property string lastError: ""
  property real lastFetchMs: 0
  property real nowMs: Date.now()

  readonly property bool offline: lastError !== ""
  readonly property var nextLaunch: launches.length > 0 ? launches[0] : null

  // The user's pinned launch, persisted (see persistSettings below). Empty
  // string means nothing is pinned.
  readonly property string watchedLaunchId: setting("watchedLaunchId", "")

  // Drives the bar pill and the map's highlighted marker: the pinned launch
  // if it's still among the (at most 5) fetched launches, else the
  // chronologically next one — same id-lookup-with-fallback shape as
  // applyLaunches() uses for `selected` below.
  readonly property var trackedLaunch: {
    if (root.watchedLaunchId !== "") {
      for (var i = 0; i < root.launches.length; i++) {
        // watchedLaunchId is a persisted string; launch ids come from the API
        // as numbers — String() both sides so the comparison isn't a silent
        // always-false type mismatch.
        if (String(root.launches[i].id) === root.watchedLaunchId) return root.launches[i]
      }
    }
    return root.nextLaunch
  }

  // Whether the tracked launch is close enough for the bar pill to draw
  // attention — same condition clockTimer already uses for its fast tick.
  readonly property bool imminent: Model.isImminent(root.trackedLaunch ? root.trackedLaunch.t0 : null, root.nowMs)

  // Single source of hover truth shared by the launch list and the map, so
  // hovering either one highlights/zooms in sync with the other.
  property string hoveredKey: ""

  // Bar pill text: rocket + compact countdown/date/TBD, or a clear "can't
  // reach the API" marker when there's no cached data to fall back to.
  readonly property string label: {
    if (root.offline && root.launches.length === 0) return "󱓞 !"
    return Model.barLabel(root.trackedLaunch, root.nowMs)
  }

  // launches[] projected onto {lat, lon, isTracked, label, launch} for the
  // map, skipping anything whose site isn't in LaunchSites.js.
  //
  // Deliberately excludes nowMs: this only needs to change when launches[]
  // itself changes (a real refresh), not every clock tick. WorldMap tracks
  // hover by this array's object identity, and rebuilding it once a second
  // would orphan whatever marker the mouse is over — the map's tooltip
  // computes its own live countdown from nowMs instead.
  readonly property var mapModel: {
    var out = []
    for (var i = 0; i < root.launches.length; i++) {
      var l = root.launches[i]
      if (l.lat === null || l.lon === null) continue
      // Same id-with-fallback shape as trackedLaunch above (not a plain
      // watchedLaunchId equality check) — a pinned launch that's flown or
      // slipped out of the free tier's next/5 window has to fall back to
      // nextLaunch here too, or the map's pulse marker just disappears
      // while the hero header/bar pill correctly retrack the new next one.
      var tracked = root.trackedLaunch !== null && String(l.id) === String(root.trackedLaunch.id)
      out.push({ key: String(l.id), lat: l.lat, lon: l.lon, isTracked: tracked, label: l.name, launch: l })
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

  // The real response is a few KB (5 launches); this ceiling exists only to
  // bound memory against a compromised/malicious endpoint, not because
  // legitimate responses come close to it. `--max-filesize` aborts early
  // when the server honestly declares an oversized Content-Length, but has
  // no effect on a chunked response with no declared length — piping
  // through `head -c` enforces the cap unconditionally regardless of what
  // the server claims. `set -o pipefail` (bash-specific, hence `bash -c`
  // rather than `sh -c`) keeps curl's own exit code visible through the
  // pipe, so a network failure still surfaces as an offline state instead
  // of being masked by head's own (near-always-zero) exit code.
  readonly property int maxResponseBytes: 2097152

  function refresh() {
    if (fetchProcess.running) return
    root.loading = true
    fetchProcess.command = ["bash", "-c",
      "set -o pipefail; curl -fsS --max-time 10 --max-filesize " + root.maxResponseBytes +
      " https://fdo.rocketlaunch.live/json/launches/next/5 | head -c " + (root.maxResponseBytes + 1)]
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

  // Persists a partial settings update into this widget's inline entry in
  // ~/.config/omarchy/shell.json, mirroring the built-in clock plugin
  // (clock/Panel.qml persistSettings/setWeekStart). Updates root.settings
  // (and the host bar-widget's copy) immediately for instant UI feedback,
  // then writes through the shell so the value survives a restart.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // Pins/unpins a launch to watch. Clicking the star on an already-pinned
  // launch unpins it — no separate "clear" affordance needed. Coerces to
  // String so callers can pass a launch's raw (numeric) id directly.
  function setWatchedLaunch(id) {
    var normalized = String(id)
    persistSettings({ watchedLaunchId: root.watchedLaunchId === normalized ? "" : normalized })
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
        // A refresh can succeed via a different path (manual/periodic)
        // while a retry from an earlier failure is still pending — without
        // this, that stale retry fires 30s later and issues a redundant
        // fetch even though nothing is failing anymore.
        retryTimer.stop()
        root.applyLaunches(Model.parseLaunches(String(fetchStdout.text || "")))
        root.lastError = ""
        root.lastFetchMs = Date.now()
      } else {
        root.lastError = Model.cap(String(fetchStderr.text || "").trim(), 300) || "RocketLaunch.Live unreachable"
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
    interval: (root.opened || Model.isImminent(root.trackedLaunch ? root.trackedLaunch.t0 : null, root.nowMs)) ? 1000 : 30000
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
    contentWidth: panel.fittedContentWidth(Style.space(640))
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
              textFormat: Text.PlainText
              color: Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              text: root.launches.length > 0
                    ? "Can't reach RocketLaunch.Live — showing the last data from "
                      + Model.localTimeLabel(new Date(root.lastFetchMs).toISOString())
                    : "Can't reach RocketLaunch.Live: " + root.lastError
            }
          }

          // Hero header: the countdown is the headline of the panel — the
          // one big accent-colored element, tracking whichever launch is
          // pinned (or otherwise soonest), same subject as the bar pill and
          // the map's pulsing marker.
          Column {
            width: parent.width
            spacing: Style.space(7)
            visible: root.trackedLaunch !== null

            Item {
              width: parent.width
              height: Math.max(nextLabelText.implicitHeight, metaText.implicitHeight)

              Text {
                id: nextLabelText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "NEXT LAUNCH"
                color: root.textLabel
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 2
              }

              Row {
                id: metaText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(7)

                Rectangle {
                  width: 4; height: 4; radius: 2
                  anchors.verticalCenter: parent.verticalCenter
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.7)
                }
                Text {
                  color: root.textMeta
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  text: {
                    var n = root.launches.length + " upcoming"
                    var ago = Model.updatedAgoLabel(root.lastFetchMs, root.nowMs)
                    return ago ? (n + " · updated " + ago) : n
                  }
                }
              }
            }

            Item {
              width: parent.width
              height: Math.max(heroName.height, heroCountdown.height)

              Column {
                id: heroName
                anchors.left: parent.left
                anchors.right: heroCountdown.left
                anchors.rightMargin: Style.space(14)
                anchors.bottom: parent.bottom
                spacing: Style.space(4)

                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: root.trackedLaunch ? root.trackedLaunch.name : ""
                  color: root.textPrimary
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: root.trackedLaunch ? [root.trackedLaunch.provider, root.trackedLaunch.vehicle].filter(function(s) { return s }).join(" · ") : ""
                  color: root.textSecondary
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Column {
                id: heroCountdown
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Style.space(2)

                Text {
                  anchors.right: parent.right
                  text: "T-MINUS"
                  color: root.textLabel
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 2
                  horizontalAlignment: Text.AlignRight
                }
                Text {
                  anchors.right: parent.right
                  // Fixed width (not just right-aligned) so the digits
                  // ticking down don't shift the whole hero row as their
                  // character count changes (e.g. 9:12:40 -> 10:12:39).
                  width: 150
                  horizontalAlignment: Text.AlignRight
                  textFormat: Text.PlainText
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                  font.bold: true
                  text: {
                    if (!root.trackedLaunch) return "—"
                    if (root.trackedLaunch.precision === "exact") {
                      var full = Model.fullCountdownLabel(root.trackedLaunch.t0, root.nowMs)
                      if (full) return full
                    }
                    if (root.trackedLaunch.precision === "date" && root.trackedLaunch.dateLabel) return "~" + root.trackedLaunch.dateLabel
                    return "TBD"
                  }
                }
              }
            }

            Rectangle {
              id: progressTrack
              width: parent.width
              height: 1
              color: root.textMeta

              Rectangle {
                height: parent.height
                width: parent.width * Model.urgencyRatio(root.trackedLaunch ? root.trackedLaunch.t0 : null, root.nowMs)
                color: Color.accent
              }

              // Purely decorative quartile ticks, not data-driven — the
              // spec's own reference for this bar (per Claude Design's
              // handoff spec, section 03).
              Repeater {
                model: [0.25, 0.5, 0.75]
                Rectangle {
                  width: 1; height: 5
                  y: -2
                  x: progressTrack.width * modelData
                  color: root.textMeta
                }
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(16)

            Column {
              id: listColumn
              width: Style.space(238)
              spacing: Style.space(4)

              Repeater {
                model: root.launches

                LaunchRow {
                  width: listColumn.width
                  launch: modelData
                  nowMs: root.nowMs
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  hasCursor: root.hoveredKey === String(modelData.id)
                  current: root.selected !== null && root.selected.id === modelData.id
                  watched: root.watchedLaunchId === String(modelData.id)
                  onEntered: root.hoveredKey = String(modelData.id)
                  onExited: if (root.hoveredKey === String(modelData.id)) root.hoveredKey = ""
                  onRowClicked: root.selectLaunch(modelData)
                  onWatchToggled: root.setWatchedLaunch(modelData.id)
                }
              }
            }

            Rectangle {
              id: divider
              width: 1
              height: Math.max(listColumn.height, mapView.height)
              color: root.borderLine
            }

            WorldMap {
              id: mapView
              width: parent.width - listColumn.width - divider.width - parent.spacing * 2
              launches: root.mapModel
              hoveredKey: root.hoveredKey
              nowMs: root.nowMs
              foreground: root.foreground
              fontFamily: root.fontFamily
              onLaunchClicked: function(item) { root.selectLaunch(item.launch) }
              onMarkerHovered: function(key) { root.hoveredKey = key }
            }
          }

          // Flattened detail strip for root.selected — deliberately keeps a
          // small recap line even though the redesign drops it, because
          // `selected` (click-driven) can diverge from `trackedLaunch` (the
          // hero header's subject); without it, it'd be unclear whose
          // details these are.
          Column {
            width: parent.width
            spacing: Style.space(9)
            visible: root.selected !== null

            Rectangle { width: parent.width; height: 1; color: root.borderLine }

            // Only shown when selected differs from the hero header's
            // subject (trackedLaunch) — in the common case they're the same
            // launch and this line would just repeat the hero name, costing
            // height for nothing. Column skips invisible children, so
            // hiding this also collapses its spacing.
            Text {
              visible: root.selected !== root.trackedLaunch
              width: parent.width
              elide: Text.ElideRight
              textFormat: Text.PlainText
              color: root.textSecondary
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              text: root.selected ? [root.selected.name, root.selected.provider, root.selected.vehicle].filter(function(s) { return s }).join(" · ") : ""
            }

            Row {
              width: parent.width
              spacing: Style.space(16)

              DetailCell {
                label: "PROVIDER"
                value: root.selected ? root.selected.provider : ""
                labelColor: root.textLabel
                valueColor: root.textSecondary
                fontFamily: root.fontFamily
              }
              DetailCell {
                label: "VEHICLE"
                value: root.selected ? root.selected.vehicle : ""
                labelColor: root.textLabel
                valueColor: root.textSecondary
                fontFamily: root.fontFamily
              }
              // Pad name is left out here — it's already shown as the
              // accent site label on the map, repeating it just crowded
              // this column into eliding.
              DetailCell {
                label: "SITE"
                widthRatio: 1.3
                value: root.selected ? [root.selected.locationName, Model.shortCountry(root.selected.country)].filter(function(s) { return s }).join(", ") : ""
                labelColor: root.textLabel
                valueColor: root.textSecondary
                fontFamily: root.fontFamily
              }
              DetailCell {
                label: "LOCAL"
                widthRatio: 0.7
                value: root.selected && root.selected.t0 ? (Model.shortLocalTimeLabel(root.selected.t0) || "") : ""
                labelColor: root.textLabel
                valueColor: root.textSecondary
                fontFamily: root.fontFamily
              }
            }

            Text {
              visible: root.selected && root.selected.missionDescription !== ""
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              color: root.textMeta
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              text: root.selected ? root.selected.missionDescription : ""
            }

            Rectangle { width: parent.width; height: 1; color: root.borderLineSoft }

            Item {
              width: parent.width
              height: Math.max(footerTimeText.implicitHeight, footerLinks.implicitHeight)

              Text {
                id: footerTimeText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                color: root.textSecondary
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
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

              Row {
                id: footerLinks
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(12)

                Text {
                  visible: root.selected && root.selected.detailUrl !== null
                  text: "View on RocketLaunch.Live ↗"
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
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
                  font.pixelSize: Style.font.caption
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.selected && root.selected.livestreamUrl) Qt.openUrlExternally(root.selected.livestreamUrl)
                  }
                }
              }
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
