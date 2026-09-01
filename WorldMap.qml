import QtQuick
import QtQuick.Shapes
import qs.Commons
import "World.js" as World
import "Model.js" as Model

// A quiet, single-color world silhouette with upcoming launch sites marked
// on it. The tracked launch (watched, or otherwise soonest) gets a bright,
// slowly pulsing marker; every other upcoming launch is a dim, static dot.
// Hover or click a dot for its details. Hovering also drives an animated
// camera zoom/pan onto the hovered site — hoveredKey is set from outside
// (Panel.qml), so a list row can drive the same zoom as hovering a dot.
// Land data is local (Natural Earth, public domain, see World.js) — no
// tiles, no network access from this component.
Item {
  id: root

  // Each entry: {key, lat, lon, isTracked, label, launch}
  property var launches: []
  property real nowMs: Date.now()
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  // Map-layer color roles, per the Claude Design map spec — all theme-
  // sourced (Color.background/Color.foreground), never hardcoded hex, so
  // the map keeps following the active Omarchy theme like everything else.
  //
  // "Lightened by ~N%" turned out to mean a linear blend, not Qt.lighter()'s
  // HSL-multiplicative factor (near a no-op on an already-near-black base).
  // The first fix blended toward literal white, which read fine on the dark
  // theme this was tuned against but turned out to be direction-blind: on a
  // light theme the background is already near-white, so blending further
  // toward white is just as invisible as Qt.lighter() was on near-black
  // (confirmed live — land/coast were indistinguishable from the page
  // background on a light Omarchy theme). blendToward() below steps toward
  // `foreground` instead of a hardcoded end point — foreground is guaranteed
  // by the theme to contrast with background in either direction, so a
  // small step toward it is a visible step regardless of which one is dark.
  function blendToward(c, target, fraction) {
    return Qt.rgba(
      c.r + (target.r - c.r) * fraction,
      c.g + (target.g - c.g) * fraction,
      c.b + (target.b - c.b) * fraction,
      c.a
    )
  }
  readonly property color mapLand: blendToward(Color.background, foreground, 0.08)
  readonly property color mapCoast: blendToward(Color.background, foreground, 0.14)
  readonly property color mapGrid: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
  readonly property color markerIdle: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)

  // Tracked by key, not object reference: launches[] is rebuilt wholesale on
  // every refresh, and a raw reference would go stale (pointing at an
  // object no longer in the array) with no further hover/exit event ever
  // firing to clear it — a permanently stuck tooltip. Set from outside
  // (Panel.qml owns the single source of hover truth across list + map).
  property string hoveredKey: ""
  readonly property var hovered: {
    for (var i = 0; i < launches.length; i++) if (launches[i].key === hoveredKey) return launches[i]
    return null
  }

  signal launchClicked(var launch)
  signal markerHovered(string key)

  implicitHeight: Math.round(width * World.HEIGHT / World.WIDTH)
  readonly property real sx: width / World.WIDTH
  readonly property real sy: height / World.HEIGHT
  clip: true

  // Default (no-hover) camera is always the plain sx/sy identity — the
  // whole world, unshifted. An earlier version fit the camera to the
  // bounding box of the currently-plotted launches instead ("populate the
  // map"), but that shifts the vertical offset to center on wherever the
  // launches happen to cluster, which crops the world asymmetrically and
  // hides the very thing that makes the Natural Earth projection read as a
  // curved globe (e.g. Antarctica, sitting well below any realistic launch
  // latitude). The reference redesign mockup never does this either — it
  // always fits the *whole* world. Reverted in favor of matching that.
  //
  // Zoomed-in "camera" onto the hovered site, country-level rather than
  // pad-level given the 1:110m land dataset's resolution. Four independently
  // animated reals rather than one object property, since QML's Behavior
  // can't animate `var`.
  //
  // Zooms around the hovered marker's OWN current (pre-hover) screen
  // position — not the map's center. Centering on the map's middle used to
  // drag the marker across the screen as the camera animated, which could
  // carry it out from under a stationary cursor mid-transition: the
  // marker's MouseArea would then fire onExited, the camera would revert,
  // the marker would drift back under the cursor, onEntered would fire
  // again, and so on — a fast feedback-loop jitter. Anchoring the zoom at
  // the marker's own position keeps it pinned at that exact screen point
  // for the whole animation (both camScaleX/Y and camOffsetX/Y are linear
  // interpolations over the same duration/easing, so offset stays exactly
  // `anchor - project(hovered)*scale` at every intermediate frame, not just
  // the two endpoints), so the cursor never has to chase it.
  readonly property real zoomFactor: 4
  readonly property real hoverAnchorX: hovered ? World.project(hovered.lon, hovered.lat)[0] * sx : 0
  readonly property real hoverAnchorY: hovered ? World.project(hovered.lon, hovered.lat)[1] * sy : 0
  readonly property real targetScaleX: hovered ? sx * zoomFactor : sx
  readonly property real targetScaleY: hovered ? sy * zoomFactor : sy
  readonly property real targetOffsetX: hovered ? hoverAnchorX - World.project(hovered.lon, hovered.lat)[0] * targetScaleX : 0
  readonly property real targetOffsetY: hovered ? hoverAnchorY - World.project(hovered.lon, hovered.lat)[1] * targetScaleY : 0

  property real camScaleX: targetScaleX
  property real camScaleY: targetScaleY
  property real camOffsetX: targetOffsetX
  property real camOffsetY: targetOffsetY
  Behavior on camScaleX { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
  Behavior on camScaleY { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
  Behavior on camOffsetX { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
  Behavior on camOffsetY { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

  function px(l) { return World.project(l.lon, l.lat)[0] * camScaleX + camOffsetX }
  function py(l) { return World.project(l.lon, l.lat)[1] * camScaleY + camOffsetY }

  // Traces a "path" of (lon,lat) samples through World.project() into an
  // SVG polyline. World.project() is curved (Natural Earth projection, not
  // flat equirectangular), so a meridian/parallel needs enough intermediate
  // points to read as a smooth curve rather than a straight chord between
  // its two endpoints.
  function polyline(points) {
    var parts = []
    for (var i = 0; i < points.length; i++) {
      var p = World.project(points[i][0], points[i][1])
      parts.push((i === 0 ? "M" : "L") + p[0].toFixed(1) + " " + p[1].toFixed(1))
    }
    return parts.join("")
  }

  // Lat/lon grid, computed once — gives the otherwise empty ocean/space some
  // structure. Meridians every 30°, parallels every 20°, the equator
  // singled out as a slightly stronger line.
  readonly property string graticulePath: {
    var parts = []
    var lon, lat
    for (lon = -150; lon <= 150; lon += 30) {
      var meridian = []
      for (lat = World.LAT_BOTTOM; lat <= World.LAT_TOP; lat += 5) meridian.push([lon, lat])
      parts.push(polyline(meridian))
    }
    for (lat = Math.ceil(World.LAT_BOTTOM / 20) * 20; lat <= World.LAT_TOP; lat += 20) {
      if (lat === 0) continue
      var parallel = []
      for (lon = -180; lon <= 180; lon += 10) parallel.push([lon, lat])
      parts.push(polyline(parallel))
    }
    return parts.join("")
  }
  readonly property string equatorPath: {
    var equator = []
    for (var lon = -180; lon <= 180; lon += 10) equator.push([lon, 0])
    return polyline(equator)
  }

  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.GeometryRenderer
    transform: [
      Scale { xScale: root.camScaleX; yScale: root.camScaleY },
      Translate { x: root.camOffsetX; y: root.camOffsetY }
    ]

    ShapePath {
      strokeColor: root.mapGrid
      strokeWidth: 0.6
      fillColor: "transparent"
      PathSvg { path: root.graticulePath }
    }
    ShapePath {
      strokeColor: root.mapGrid
      strokeWidth: 0.6
      fillColor: "transparent"
      PathSvg { path: root.equatorPath }
    }
  }

  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.GeometryRenderer
    transform: [
      Scale { xScale: root.camScaleX; yScale: root.camScaleY },
      Translate { x: root.camOffsetX; y: root.camOffsetY }
    ]

    ShapePath {
      fillColor: root.mapLand
      strokeColor: root.mapCoast
      strokeWidth: 0.5
      joinStyle: ShapePath.RoundJoin
      fillRule: ShapePath.OddEvenFill
      PathSvg { path: World.PATH }
    }
  }

  // Pulse ring behind the tracked launch's site — radius literally animates
  // 3px -> 14px (not a scale transform), per the map spec. width/height are
  // live bindings, so x/y (centered on the marker via width/2) stay
  // correctly centered as the ring grows every frame.
  Rectangle {
    id: pulse
    readonly property var next: root.launches.find(function(l) { return l.isTracked })
    visible: next !== undefined
    radius: width / 2
    color: "transparent"
    border.color: Color.accent
    border.width: 0.9
    x: visible ? root.px(next) - width / 2 : 0
    y: visible ? root.py(next) - height / 2 : 0

    SequentialAnimation on width {
      running: pulse.visible
      loops: Animation.Infinite
      NumberAnimation { from: 6; to: 28; duration: 2600; easing.type: Easing.OutQuad }
    }
    SequentialAnimation on height {
      running: pulse.visible
      loops: Animation.Infinite
      NumberAnimation { from: 6; to: 28; duration: 2600; easing.type: Easing.OutQuad }
    }
    SequentialAnimation on opacity {
      running: pulse.visible
      loops: Animation.Infinite
      NumberAnimation { from: 0.5; to: 0.0; duration: 2600; easing.type: Easing.OutQuad }
    }
  }

  // Second ring, staggered 1300ms behind the first (one-shot pause, then an
  // infinite loop with the same period — stays in sync forever rather than
  // drifting the way re-pausing every loop would).
  Rectangle {
    id: pulse2
    visible: pulse.visible
    radius: width / 2
    color: "transparent"
    border.color: Color.accent
    border.width: 0.9
    x: visible ? root.px(pulse.next) - width / 2 : 0
    y: visible ? root.py(pulse.next) - height / 2 : 0

    SequentialAnimation on width {
      running: pulse2.visible
      PauseAnimation { duration: 1300 }
      SequentialAnimation {
        loops: Animation.Infinite
        NumberAnimation { from: 6; to: 28; duration: 2600; easing.type: Easing.OutQuad }
      }
    }
    SequentialAnimation on height {
      running: pulse2.visible
      PauseAnimation { duration: 1300 }
      SequentialAnimation {
        loops: Animation.Infinite
        NumberAnimation { from: 6; to: 28; duration: 2600; easing.type: Easing.OutQuad }
      }
    }
    SequentialAnimation on opacity {
      running: pulse2.visible
      PauseAnimation { duration: 1300 }
      SequentialAnimation {
        loops: Animation.Infinite
        NumberAnimation { from: 0.5; to: 0.0; duration: 2600; easing.type: Easing.OutQuad }
      }
    }
  }

  // Uppercase pad/site label hanging off the tracked marker — persistent,
  // not hover-gated, since that marker is already the map's one highlighted
  // subject.
  Text {
    id: siteLabel
    visible: pulse.visible
    z: 5
    text: {
      if (!pulse.next) return ""
      var l = pulse.next.launch
      return (l.padName || l.locationName || "").toUpperCase()
    }
    color: Color.accent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
    x: Math.max(0, Math.min(root.width - implicitWidth, (pulse.visible ? root.px(pulse.next) : 0) + 9))
    y: Math.max(0, Math.min(root.height - implicitHeight, (pulse.visible ? root.py(pulse.next) : 0) - implicitHeight / 2 - 8))
  }

  // No top-left corner readout: the pad name lives once, at the marker
  // label above (not duplicated here), and a "WINDOW" line has nowhere
  // honest to pull data from — win_open/win_close come back null for every
  // launch the live API has ever returned in this project (checked
  // repeatedly, including immediately before this edit). Adding either
  // back here would mean either duplicating the marker's own label or
  // shipping a line that's permanently empty.

  Repeater {
    model: root.launches

    Item {
      id: marker
      required property var modelData
      readonly property bool hot: root.hoveredKey === modelData.key

      // A generous hit area around a small dot, so it stays clickable.
      width: 14; height: 14
      x: root.px(modelData) - width / 2
      y: root.py(modelData) - height / 2
      z: modelData.isTracked ? 3 : (hot ? 2 : 1)

      // Tracked/hovered launches are solid dots; everything else is a
      // hollow ring (per the redesign: "populated" reads better with rings
      // than with faint filled dots), brightening slightly with urgency.
      // Only the tracked marker is ever solid/accent-colored — hover just
      // brightens the ring (per spec: idle=dim ring, hover=foreground ring,
      // tracked=solid accent dot), it doesn't turn it into a filled dot.
      Rectangle {
        anchors.centerIn: parent
        readonly property bool solid: marker.modelData.isTracked
        // Idle rings sized/stroked a bit past the spec's literal 2.2px/0.9px
        // — those numbers kept getting missed in screenshot review (twice,
        // both times disproven by pixel-sampling the actual render), so
        // this trades a small spec deviation for rings that are unambiguous
        // at a glance rather than merely present.
        width: marker.modelData.isTracked ? 5.6 : 5.2
        height: width
        radius: width / 2
        color: solid ? Color.accent : "transparent"
        border.color: marker.hot ? root.foreground : root.markerIdle
        border.width: solid ? 0 : 1.3
        Behavior on width { NumberAnimation { duration: 90 } }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.markerHovered(marker.modelData.key)
        onExited: if (root.hoveredKey === marker.modelData.key) root.markerHovered("")
        onClicked: root.launchClicked(marker.modelData)
      }
    }
  }

  // Hover tooltip, kept inside the map's own bounds.
  Rectangle {
    id: tooltip
    visible: root.hovered !== null
    z: 10
    readonly property real dotX: root.hovered ? root.px(root.hovered) : 0
    readonly property real dotY: root.hovered ? root.py(root.hovered) : 0
    width: tooltipText.implicitWidth + Style.space(8)
    height: tooltipText.implicitHeight + Style.space(4)
    radius: Style.cornerRadius > 0 ? Style.space(3) : 0
    color: Style.controlFill(false, true, root.foreground, Color.accent)
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
    border.width: 1
    x: Math.max(0, Math.min(root.width - width, dotX + 9))
    y: Math.max(0, Math.min(root.height - height, dotY - height / 2))

    Text {
      id: tooltipText
      anchors.centerIn: parent
      text: {
        if (!root.hovered) return ""
        var l = root.hovered.launch
        var countdown = Model.countdownLabel(l.t0, root.nowMs)
        var tail = countdown ? (" · " + countdown) : (l.dateLabel ? (" · ~" + l.dateLabel) : "")
        return root.hovered.label + tail
      }
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
