import QtQuick
import QtQuick.Shapes
import qs.Commons
import "World.js" as World
import "Model.js" as Model

// A quiet, single-color world silhouette with upcoming launch sites marked
// on it. The soonest launch gets a bright, slowly pulsing marker; every
// other upcoming launch is a dim, static dot. Hover or click a dot for its
// details. Land data is local (Natural Earth, public domain, see World.js)
// — no tiles, no network access from this component.
Item {
  id: root

  // Each entry: {key, lat, lon, isNext, label, launch}
  property var launches: []
  property real nowMs: Date.now()
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.55)

  // Tracked by key, not object reference: launches[] is rebuilt wholesale on
  // every refresh, and a raw reference would go stale (pointing at an
  // object no longer in the array) with no further hover/exit event ever
  // firing to clear it — a permanently stuck tooltip.
  property string hoveredKey: ""
  readonly property var hovered: {
    for (var i = 0; i < launches.length; i++) if (launches[i].key === hoveredKey) return launches[i]
    return null
  }

  signal launchClicked(var launch)

  implicitHeight: Math.round(width * World.HEIGHT / World.WIDTH)
  readonly property real sx: width / World.WIDTH
  readonly property real sy: height / World.HEIGHT
  clip: true

  function px(l) { return World.project(l.lon, l.lat)[0] * sx }
  function py(l) { return World.project(l.lon, l.lat)[1] * sy }

  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.GeometryRenderer
    transform: Scale { xScale: root.sx; yScale: root.sy }

    ShapePath {
      fillColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
      strokeColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.28)
      strokeWidth: 0.35
      joinStyle: ShapePath.RoundJoin
      fillRule: ShapePath.OddEvenFill
      PathSvg { path: World.PATH }
    }
  }

  // Pulse ring behind the next launch's site.
  Rectangle {
    id: pulse
    readonly property var next: root.launches.find(function(l) { return l.isNext })
    visible: next !== undefined
    width: 8; height: 8; radius: 4
    color: "transparent"
    border.color: root.foreground
    border.width: 1.5
    x: visible ? root.px(next) - width / 2 : 0
    y: visible ? root.py(next) - height / 2 : 0
    transformOrigin: Item.Center

    SequentialAnimation on scale {
      running: pulse.visible
      loops: Animation.Infinite
      NumberAnimation { from: 0.8; to: 3.2; duration: 1800; easing.type: Easing.OutQuad }
    }
    SequentialAnimation on opacity {
      running: pulse.visible
      loops: Animation.Infinite
      NumberAnimation { from: 0.9; to: 0.0; duration: 1800; easing.type: Easing.OutQuad }
    }
  }

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
      z: modelData.isNext ? 3 : (hot ? 2 : 1)

      Rectangle {
        anchors.centerIn: parent
        width: marker.modelData.isNext ? 7 : (marker.hot ? 5 : 2.5)
        height: width
        radius: width / 2
        color: marker.modelData.isNext || marker.hot ? root.foreground : root.dim
        opacity: marker.modelData.isNext ? 1.0 : (marker.hot ? 1.0 : 0.55)
        Behavior on width { NumberAnimation { duration: 90 } }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hoveredKey = marker.modelData.key
        onExited: if (root.hoveredKey === marker.modelData.key) root.hoveredKey = ""
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
