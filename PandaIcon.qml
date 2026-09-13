import QtQuick
import qs.Commons

// Theme-aware panda face — every colour derives from Omarchy Color tokens.
// The panda re-paints instantly whenever the theme changes.
Item {
  id: root

  property real size: 32
  property bool downloading: false   // sparkle ring + ear wiggle
  property bool active: false        // nose turns accent colour

  // ── Derived palette from live theme tokens ─────────────────────────────
  // Dark regions (ears, eye patches) → near-black tinted with accent colour
  readonly property color clrDark: Qt.rgba(
    Color.accent.r * 0.20 + 0.05,
    Color.accent.g * 0.20 + 0.05,
    Color.accent.b * 0.20 + 0.05,
    1.0)
  // Face / light regions → near-white tinted with background colour
  readonly property color clrFace: Qt.rgba(
    Color.background.r * 0.10 + 0.90,
    Color.background.g * 0.10 + 0.90,
    Color.background.b * 0.10 + 0.90,
    1.0)
  // Inner ear → accent at 35% over the dark ear, so it picks up the theme
  readonly property color clrEarInner: Qt.rgba(
    Color.accent.r * 0.35 + Color.muted.r * 0.65,
    Color.accent.g * 0.35 + Color.muted.g * 0.65,
    Color.accent.b * 0.35 + Color.muted.b * 0.65,
    1.0)
  // Muted mid-tone
  readonly property color clrMid:    Color.muted
  // Eye whites → natural white so eyes are always visible inside the dark patches
  readonly property color clrLight:  "#f4f4f5"
  // Blush dots → accent at low opacity
  readonly property color clrBlush:  Qt.alpha(Color.accent, 0.55)
  // Nose → accent when active, muted when idle
  readonly property color clrNose:   active ? Color.accent : Color.muted
  // Smile stroke
  readonly property color clrSmile:  Qt.alpha(Color.foreground, 0.45)
  // Subtle face stroke for light mode visibility
  readonly property color clrStroke: Qt.alpha(Color.foreground, 0.45)

  width: size
  height: size

  // ── Repaint whenever any colour token changes ──────────────────────────
  onClrDarkChanged:     canvas.requestPaint()
  onClrFaceChanged:     canvas.requestPaint()
  onClrEarInnerChanged: canvas.requestPaint()
  onClrMidChanged:      canvas.requestPaint()
  onClrBlushChanged:    canvas.requestPaint()
  onClrNoseChanged:     canvas.requestPaint()
  onClrSmileChanged:    canvas.requestPaint()
  onClrStrokeChanged:   canvas.requestPaint()
  onActiveChanged:      canvas.requestPaint()
  onBlinkEyesChanged:   canvas.requestPaint()

  // ── Ear Wiggle (while downloading) ────────────────────────────────────
  SequentialAnimation on rotation {
    id: wiggleAnim
    running: root.downloading
    loops: Animation.Infinite
    NumberAnimation { to: -6; duration: 200; easing.type: Easing.SineCurve }
    NumberAnimation { to:  6; duration: 200; easing.type: Easing.SineCurve }
    NumberAnimation { to:  0; duration: 150; easing.type: Easing.OutBounce }
    PauseAnimation  { duration: 1400 }
  }

  // ── Blink ──────────────────────────────────────────────────────────────
  property bool blinkEyes: false
  Timer {
    interval: 3400; running: true; repeat: true
    onTriggered: {
      root.blinkEyes = true
      blinkOff.start()
    }
  }
  Timer {
    id: blinkOff; interval: 110; repeat: false
    onTriggered: root.blinkEyes = false
  }

  // ── Canvas ────────────────────────────────────────────────────────────
  Canvas {
    id: canvas
    anchors.fill: parent

    Component.onCompleted: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)

      var cx = width  / 2
      var cy = height / 2
      // Reduce radius multiplier so the larger ears fit entirely within the bounding box
      var r  = Math.min(width, height) / 2 * 0.78

      // ── Ears (outer: dark, inner: accent-tinted) ──────────────────────
      ctx.fillStyle = root.clrDark
      ctx.beginPath()
      ctx.arc(cx - r * 0.65, cy - r * 0.75, r * 0.46, 0, Math.PI * 2)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(cx + r * 0.65, cy - r * 0.75, r * 0.46, 0, Math.PI * 2)
      ctx.fill()

      // Inner ear — blend of accent + muted so it shifts with the theme
      ctx.fillStyle = root.clrEarInner
      ctx.beginPath()
      ctx.arc(cx - r * 0.65, cy - r * 0.75, r * 0.24, 0, Math.PI * 2)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(cx + r * 0.65, cy - r * 0.75, r * 0.24, 0, Math.PI * 2)
      ctx.fill()

      // ── White face circle ─────────────────────────────────────────────
      ctx.fillStyle = root.clrFace
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, Math.PI * 2)
      ctx.fill()
      ctx.lineWidth = Math.max(1, r * 0.04)
      ctx.strokeStyle = root.clrStroke
      ctx.stroke()

      // ── Eye patches — fill() INSIDE save/restore so transforms apply ──
      ctx.fillStyle = root.clrDark
      ctx.save()
      ctx.translate(cx - r * 0.3, cy - r * 0.1)
      ctx.rotate(-0.3)
      ctx.scale(1, 0.72)
      ctx.beginPath()
      ctx.arc(0, 0, r * 0.28, 0, Math.PI * 2)
      ctx.fill()                    // ← BEFORE restore
      ctx.restore()

      ctx.fillStyle = root.clrDark
      ctx.save()
      ctx.translate(cx + r * 0.3, cy - r * 0.1)
      ctx.rotate(0.3)
      ctx.scale(1, 0.72)
      ctx.beginPath()
      ctx.arc(0, 0, r * 0.28, 0, Math.PI * 2)
      ctx.fill()                    // ← BEFORE restore
      ctx.restore()

      // ── Eyes ──────────────────────────────────────────────────────────
      if (!root.blinkEyes) {
        // Whites
        ctx.fillStyle = root.clrLight
        ctx.beginPath()
        ctx.arc(cx - r * 0.3, cy - r * 0.1, r * 0.14, 0, Math.PI * 2)
        ctx.fill()
        ctx.beginPath()
        ctx.arc(cx + r * 0.3, cy - r * 0.1, r * 0.14, 0, Math.PI * 2)
        ctx.fill()

        // Pupils
        ctx.fillStyle = root.clrDark
        ctx.beginPath()
        ctx.arc(cx - r * 0.28, cy - r * 0.11, r * 0.07, 0, Math.PI * 2)
        ctx.fill()
        ctx.beginPath()
        ctx.arc(cx + r * 0.28, cy - r * 0.11, r * 0.07, 0, Math.PI * 2)
        ctx.fill()

        // Catchlights
        ctx.fillStyle = root.clrLight
        ctx.beginPath()
        ctx.arc(cx - r * 0.255, cy - r * 0.14, r * 0.03, 0, Math.PI * 2)
        ctx.fill()
        ctx.beginPath()
        ctx.arc(cx + r * 0.305, cy - r * 0.14, r * 0.03, 0, Math.PI * 2)
        ctx.fill()
      } else {
        // Blink lines
        ctx.strokeStyle = root.clrLight
        ctx.lineWidth   = r * 0.045
        ctx.lineCap     = "round"
        ctx.beginPath()
        ctx.moveTo(cx - r * 0.44, cy - r * 0.12)
        ctx.lineTo(cx - r * 0.16, cy - r * 0.08)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(cx + r * 0.16, cy - r * 0.08)
        ctx.lineTo(cx + r * 0.44, cy - r * 0.12)
        ctx.stroke()
      }

      // ── Nose — fill() INSIDE save/restore ─────────────────────────────
      ctx.fillStyle = root.clrNose
      ctx.save()
      ctx.translate(cx, cy + r * 0.2)
      ctx.scale(1, 0.65)
      ctx.beginPath()
      ctx.arc(0, 0, r * 0.13, 0, Math.PI * 2)
      ctx.fill()                    // ← BEFORE restore
      ctx.restore()

      // ── Smile ─────────────────────────────────────────────────────────
      ctx.strokeStyle = root.clrSmile
      ctx.lineWidth   = r * 0.055
      ctx.lineCap     = "round"
      ctx.beginPath()
      ctx.arc(cx, cy + r * 0.28, r * 0.18, 0.2, Math.PI - 0.2)
      ctx.stroke()

      // ── Blush cheeks ──────────────────────────────────────────────────
      ctx.fillStyle    = root.clrBlush
      ctx.globalAlpha  = 1.0
      ctx.beginPath()
      ctx.arc(cx - r * 0.54, cy + r * 0.22, r * 0.1, 0, Math.PI * 2)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(cx + r * 0.54, cy + r * 0.22, r * 0.1, 0, Math.PI * 2)
      ctx.fill()
    }
  }

  // ── Sparkle orbit ring (while downloading) ─────────────────────────────
  Item {
    anchors.fill: parent
    visible: root.downloading

    Repeater {
      model: 8
      Rectangle {
        id: dot
        width:  root.size * 0.07
        height: root.size * 0.07
        radius: width / 2
        color:  Color.accent

        x: root.size / 2 + (root.size * 0.54) * Math.cos(index * Math.PI / 4 + spinAngle.angle) - width  / 2
        y: root.size / 2 + (root.size * 0.54) * Math.sin(index * Math.PI / 4 + spinAngle.angle) - height / 2

        SequentialAnimation on opacity {
          loops: Animation.Infinite; running: root.downloading
          NumberAnimation { to: 0.75; duration: 350; easing.type: Easing.SineCurve }
          NumberAnimation { to: 0.10; duration: 700; easing.type: Easing.SineCurve }
        }
      }
    }

    NumberAnimation {
      id: spinAngle
      property real angle: 0
      target: spinAngle; property: "angle"
      from: 0; to: Math.PI * 2
      duration: 2800; loops: Animation.Infinite
      running: root.downloading; easing.type: Easing.Linear
    }
  }
}
