import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "panda-dl"
  ipcTarget: "panda-dl"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ─── State ────────────────────────────────────────────────────────────────
  property string currentFilter: "all"
  property bool showAddForm: false
  property string addUriText: ""
  property int addParts: 16
  property string addDirText: ""
  property int currentPage: 0
  property int itemsPerPage: 3
  property var filteredDownloads: {
    if (!service.running) return []
    var list = service.downloads || []
    if (currentFilter === "active")
      return list.filter(function(t) { return t.status === "downloading" })
    if (currentFilter === "completed")
      return list.filter(function(t) { return t.status === "completed" })
    return list
  }
  
  onFilteredDownloadsChanged: {
    var maxPage = Math.max(0, Math.ceil(filteredDownloads.length / itemsPerPage) - 1)
    if (currentPage > maxPage) {
      currentPage = maxPage
    }
  }
  
  onCurrentFilterChanged: {
      currentPage = 0
  }

  // ─── Service ──────────────────────────────────────────────────────────────
  Service { id: service; settings: root.settings }

  // ─── Colors & Style ───────────────────────────────────────────────────────
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ─── IPC ──────────────────────────────────────────────────────────────────
  IpcHandler {
    target: root.ipcTarget
    function open(): void   { root.open() }
    function close(): void  { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { service.refresh(); return "ok" }
    function add(uri: string): string { service.addDownload(uri, "", 16); return "ok" }
    function status(): string {
      return service.activeDownloads + " active (" + Model.formatSpeed(service.totalDownloadSpeed) + ")"
    }
  }

  // ─── Bar Button (panda face icon) ─────────────────────────────────────────
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""                              // hide default glyph
    active: service.activeDownloads > 0
    activeColor: Color.accent
    tooltipText: {
      if (service.activeDownloads > 0)
        return "🐼 Panda DL\n⬇ " + Model.formatSpeed(service.totalDownloadSpeed) + "  •  " + service.activeDownloads + " active"
      return "🐼 Panda DL\nIdle"
    }
    onPressed: function(btn) {
      if (btn === Qt.RightButton) service.refresh()
      else root.toggle()
    }

    // Override the icon area with our PandaIcon
    iconComponent: Component {
      PandaIcon {
        size: Style.bar.iconCanvas
        downloading: service.activeDownloads > 0
        active: service.activeDownloads > 0
      }
    }
  }

  // ─── Panel ────────────────────────────────────────────────────────────────
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth:  panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(mainCol.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.showAddForm
      onCloseRequested: root.close()
      onTabRequested: function(d) { root.switchPanel(d) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") service.refresh()
        else if (t === "a" || t === "A" || t === "+") {
          root.showAddForm = !root.showAddForm
          if (root.showAddForm) Qt.callLater(function() { uriInput.forceActiveFocus() })
        }
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: mainCol
          width: parent.width
          spacing: Style.space(10)

          // ═══════════════════════════════════════════ HERO HEADER (PANDA) ══
          PanelHero {
            width: parent.width
            title: "Panda Downloader"
            meta: {
              if (service.activeDownloads > 0)
                return "⬇ " + Model.formatSpeed(service.totalDownloadSpeed) +
                       "  ⬆ " + Model.formatSpeed(service.totalUploadSpeed) +
                       "  •  " + service.activeDownloads + " active"
              return "Ready to chew some bamboo 🎋"
            }
            foreground: root.foreground
            fontFamily: root.fontFamily
            // Animated panda face with sparkle ring when downloading
            iconComponent: Component {
              PandaIcon {
                size: Style.font.display + 8
                downloading: service.activeDownloads > 0
                active: service.activeDownloads > 0
              }
            }
            trailingControl: Component {
              Row {
                spacing: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter

                // ＋ Add button
                Rectangle {
                  width: Style.space(28); height: Style.space(28)
                  radius: Style.space(6)
                  color: addBtnHov.hovered || root.showAddForm ? Color.accent : "transparent"
                  border.color: addBtnHov.hovered || root.showAddForm ? Color.accent : Qt.alpha(root.foreground, 0.25)
                  border.width: 1
                  Text {
                    anchors.centerIn: parent
                    text: root.showAddForm ? "✕" : "＋"
                    font.family: root.fontFamily; font.pixelSize: Style.font.body
                    color: addBtnHov.hovered || root.showAddForm ? Color.menu.background : root.foreground
                  }
                  HoverHandler { id: addBtnHov }
                  TapHandler {
                    onTapped: {
                      root.showAddForm = !root.showAddForm
                      if (root.showAddForm) Qt.callLater(function() { uriInput.forceActiveFocus() })
                    }
                  }
                }

                // ⟳ Refresh button
                Rectangle {
                  width: Style.space(28); height: Style.space(28)
                  radius: Style.space(6)
                  color: refBtnHov.hovered ? Qt.alpha(root.foreground, 0.1) : "transparent"
                  border.color: Qt.alpha(root.foreground, 0.2); border.width: 1
                  Text {
                    anchors.centerIn: parent; text: "⟳"
                    font.family: root.fontFamily; font.pixelSize: Style.font.body
                    color: root.foreground
                    RotationAnimator on rotation {
                      from: 0; to: 360; duration: 900; loops: Animation.Infinite
                      running: service.activeDownloads > 0
                      easing.type: Easing.Linear
                    }
                  }
                  HoverHandler { id: refBtnHov }
                  TapHandler { onTapped: service.refresh() }
                }
              }
            }
          }

          // ══════════════════════════════════════════ UPDATE BANNER ══════════
          Rectangle {
            visible: service.updateAvailable || service.isUpdating
            width: parent.width
            height: Style.space(32)
            radius: Style.space(4)
            color: Qt.alpha(Color.accent, 0.15)
            border.color: Color.accent; border.width: 1

            RowLayout {
              anchors.fill: parent; anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(6)
              Text {
                Layout.fillWidth: true
                text: service.isUpdating ? "Downloading & restarting daemon in background..." : "✨ Update available! (" + service.currentVersion + " ➔ " + service.latestVersion + ")"
                font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.weight: Font.Medium
                color: root.foreground
              }
              Rectangle {
                Layout.preferredWidth: updBtnTxt.implicitWidth + Style.space(16)
                Layout.preferredHeight: Style.space(22)
                radius: Style.space(4)
                color: service.isUpdating ? "transparent" : (updHov.hovered ? Color.accent : "transparent")
                border.color: service.isUpdating ? Qt.alpha(root.foreground, 0.2) : Color.accent; border.width: 1
                Text {
                  id: updBtnTxt; anchors.centerIn: parent
                  text: service.isUpdating ? "Updating..." : "Update Now"
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.weight: Font.Bold
                  color: service.isUpdating ? Qt.alpha(root.foreground, 0.5) : (updHov.hovered ? Color.menu.background : Color.accent)
                }
                HoverHandler { id: updHov; enabled: !service.isUpdating }
                TapHandler { onTapped: { if (!service.isUpdating) service.updateBinary() } }
              }
            }
          }

          // ══════════════════════════════════════════ ADD FORM (COLLAPSIBLE) ═
          Rectangle {
            visible: root.showAddForm
            width: parent.width
            implicitHeight: addFormCol.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: Qt.alpha(Color.menu.selectedBackground, 0.5)
            border.color: Color.accent; border.width: 1

            Column {
              id: addFormCol
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space(12) }
              spacing: Style.space(8)

              Text {
                text: "Add Download — URL, Magnet link, or .torrent path"
                font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.weight: Font.Bold
                color: Color.accent
              }

              // URI field
              Rectangle {
                width: parent.width; height: Style.space(34)
                radius: Style.space(4)
                color: Color.menu.background
                border.color: uriInput.activeFocus ? Color.accent : Qt.alpha(root.foreground, 0.2)
                border.width: 1
                TextInput {
                  id: uriInput
                  anchors { fill: parent; leftMargin: Style.space(8); rightMargin: Style.space(8) }
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: root.fontFamily; font.pixelSize: Style.font.body
                  color: root.foreground; selectByMouse: true; clip: true
                  text: root.addUriText; onTextChanged: root.addUriText = text
                  Keys.onReturnPressed: startBtn.start()

                  Text {
                    visible: !uriInput.text
                    text: "magnet:?, https://, or /path/to/file.torrent"
                    font.family: root.fontFamily; font.pixelSize: Style.font.body
                    color: Qt.alpha(root.foreground, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }

              RowLayout {
                width: parent.width; spacing: Style.space(8)

                // Connection-part pills
                Text {
                  text: "Parts:"
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  color: root.dim
                }
                Row {
                  spacing: Style.space(4)
                  Repeater {
                    model: [4, 8, 16, 32]
                    Rectangle {
                      width: Style.space(30); height: Style.space(24); radius: Style.space(4)
                      color: root.addParts === modelData ? Color.accent
                             : (pH.hovered ? Qt.alpha(root.foreground, 0.08) : "transparent")
                      border.color: root.addParts === modelData ? Color.accent : Qt.alpha(root.foreground, 0.2)
                      border.width: 1
                      Text {
                        anchors.centerIn: parent; text: String(modelData)
                        font.family: root.fontFamily; font.pixelSize: Style.font.caption
                        font.bold: root.addParts === modelData
                        color: root.addParts === modelData ? Color.menu.background : root.foreground
                      }
                      HoverHandler { id: pH }
                      TapHandler { onTapped: root.addParts = modelData }
                    }
                  }
                }

                Item { Layout.fillWidth: true }

                // Start button
                Rectangle {
                  id: startBtn
                  Layout.preferredWidth: Style.space(130); Layout.preferredHeight: Style.space(28)
                  radius: Style.space(4)
                  color: sH.hovered ? Qt.lighter(Color.accent, 1.1) : Color.accent

                  function start() {
                    if (!root.addUriText.trim()) return
                    service.addDownload(root.addUriText.trim(), root.addDirText, root.addParts)
                    root.addUriText = ""
                    root.showAddForm = false
                  }

                  RowLayout {
                    anchors.centerIn: parent; spacing: Style.space(5)
                    Text {
                      text: "🐼"
                      font.family: root.fontFamily; font.pixelSize: Style.font.caption + 1
                    }
                    Text {
                      text: "Download"
                      font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                      color: Color.menu.background
                    }
                  }
                  HoverHandler { id: sH }
                  TapHandler { onTapped: startBtn.start() }
                }
              }
            }
          }

          // ══════════════════════════════════════════════ FILTER TABS ════════
          Row {
            spacing: Style.space(6)
            Repeater {
              model: [
                { id: "all",       label: "All" },
                { id: "active",    label: "⬇ Active" },
                { id: "completed", label: "✓ Done" }
              ]
              Rectangle {
                height: Style.space(24); radius: Style.space(12)
                // Size from the inner Text so pills never overlap
                width: tabLabel.implicitWidth + Style.space(20)
                color: root.currentFilter === modelData.id ? Color.accent : "transparent"
                border.color: root.currentFilter === modelData.id ? Color.accent : Qt.alpha(root.foreground, 0.2)
                border.width: 1
                Text {
                  id: tabLabel
                  anchors.centerIn: parent; text: modelData.label
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  font.bold: root.currentFilter === modelData.id
                  color: root.currentFilter === modelData.id ? Color.menu.background : root.foreground
                }
                HoverHandler { id: tabH }
                TapHandler { onTapped: root.currentFilter = modelData.id }
              }
            }
          }

          // ══════════════════════════════════════════════ DOWNLOAD ITEMS ══════
          Column {
            width: parent.width
            spacing: Style.space(8)

            Repeater {
              model: {
                if (!root.filteredDownloads || root.filteredDownloads.length === 0) return []
                var start = root.currentPage * root.itemsPerPage
                return root.filteredDownloads.slice(start, start + root.itemsPerPage)
              }

              // ─── Per-download card ─────────────────────────────────────────
              Rectangle {
                id: dlCard
                width: mainCol.width
                implicitHeight: cardInner.implicitHeight + Style.space(18)
                radius: Style.cornerRadius
                color: Qt.alpha(Color.menu.selectedBackground, 0.5)
                border.color: Qt.alpha(root.foreground, 0.1)
                border.width: 1

                readonly property var task: modelData
                readonly property real progress: Model.calcProgress(task.downloaded_bytes, task.total_bytes)
                readonly property bool isActive:    task.status === "downloading"
                readonly property bool isDone:      task.status === "completed"
                readonly property bool isPaused:    task.status === "paused"
                readonly property bool isError:     typeof task.status === "object" && "error" in task.status

                Column {
                  id: cardInner
                  anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space(10) }
                  spacing: Style.space(6)

                  // ── Title row ─────────────────────────────────────────────
                  RowLayout {
                    width: parent.width; spacing: Style.space(6)

                    // Small panda / kind icon
                    Item {
                      Layout.preferredWidth: Style.space(20); Layout.preferredHeight: Style.space(20)
                      PandaIcon {
                        anchors.fill: parent
                        size: parent.width
                        downloading: dlCard.isActive
                        active: dlCard.isActive
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: task.name
                      font.family: root.fontFamily; font.pixelSize: Style.font.body; font.weight: Font.Medium
                      color: root.foreground; elide: Text.ElideMiddle
                    }

                    // Status badge
                    Rectangle {
                      Layout.preferredHeight: Style.space(18)
                      Layout.preferredWidth: badge.implicitWidth + Style.space(8)
                      radius: Style.space(4)
                      color: Qt.alpha(badgeColor(), 0.18)
                      border.color: badgeColor(); border.width: 1
                      function badgeColor() {
                        if (dlCard.isActive)  return Color.accent
                        if (dlCard.isDone)    return "#a6e3a1"
                        if (dlCard.isPaused)  return "#f9e2af"
                        if (dlCard.isError)   return "#f38ba8"
                        return Qt.alpha(root.foreground, 0.4)
                      }
                      Text {
                        id: badge
                        anchors.centerIn: parent
                        text: {
                          if (dlCard.isActive)  return "⬇ LIVE"
                          if (dlCard.isDone)    return "✓ DONE"
                          if (dlCard.isPaused)  return "⏸ PAUSED"
                          if (dlCard.isError)   return "✗ ERROR"
                          return "UNKNOWN"
                        }
                        font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true
                        color: parent.badgeColor()
                      }
                    }
                  }

                  // ── IDM-style segmented chunk bar ──────────────────────────
                  Item {
                    width: parent.width; height: Style.space(10)
                    visible: task.parts && task.parts.length > 1 && dlCard.isActive

                    // Bamboo-grove background
                    Rectangle {
                      anchors.fill: parent; radius: 2
                      color: Qt.alpha(root.foreground, 0.06)
                    }

                    Row {
                      anchors.fill: parent; spacing: 1
                      Repeater {
                        model: task.parts || []
                        Rectangle {
                          width: (parent.width - (task.parts.length - 1)) / task.parts.length
                          height: parent.height; radius: 1
                          property real partPct: {
                            var sz = modelData.end - modelData.start + 1
                            return sz > 0 ? modelData.downloaded / sz : 0
                          }
                          color: {
                            if (partPct >= 0.99) return "#a6e3a1"                          // complete — bamboo green
                            if (partPct > 0.02)  return Color.accent                       // in-flight — accent
                            return Qt.alpha(root.foreground, 0.08)                         // pending
                          }

                          // Shimmer animation on active chunks
                          Rectangle {
                            visible: dlCard.isActive && partPct > 0.02 && partPct < 0.99
                            anchors.fill: parent; radius: parent.radius
                            gradient: Gradient {
                              orientation: Gradient.Horizontal
                              GradientStop { position: 0.0; color: "transparent" }
                              GradientStop { position: shimmer.shimmerPos; color: Qt.alpha("#ffffff", 0.25) }
                              GradientStop { position: 1.0; color: "transparent" }
                            }
                          }
                          NumberAnimation {
                            id: shimmer
                            property real shimmerPos: 0
                            target: shimmer; property: "shimmerPos"
                            from: 0.0; to: 1.0; duration: 1100; loops: Animation.Infinite
                            running: dlCard.isActive
                            easing.type: Easing.Linear
                          }
                        }
                      }
                    }
                  }

                  // ── Smooth overall progress bar ────────────────────────────
                  Rectangle {
                    width: parent.width; height: Style.space(5); radius: Style.space(3)
                    color: Qt.alpha(root.foreground, 0.08)

                    Rectangle {
                      height: parent.height; width: parent.width * dlCard.progress
                      radius: Style.space(3)
                      gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: dlCard.isDone ? "#a6e3a1" : Color.accent }
                        GradientStop { position: 1.0; color: dlCard.isDone ? "#94e2d5" : Qt.lighter(Color.accent, 1.2) }
                      }
                      Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                  }

                  // ── Stats row ─────────────────────────────────────────────
                  RowLayout {
                    width: parent.width

                    Text {
                      text: Model.formatBytes(task.downloaded_bytes) + " / " +
                            (task.total_bytes ? Model.formatBytes(task.total_bytes) : "?") +
                            "  (" + (dlCard.progress * 100).toFixed(1) + "%)"
                      font.family: root.fontFamily; font.pixelSize: Style.font.caption
                      color: root.dim
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                      visible: dlCard.isActive && task.download_speed > 0
                      text: "⬇ " + Model.formatSpeed(task.download_speed)
                      font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                      color: Color.accent
                    }

                    Text {
                      visible: dlCard.isActive && task.eta_seconds > 0
                      text: " ETA " + Model.formatEta(task.eta_seconds)
                      font.family: root.fontFamily; font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  // ── Control row ───────────────────────────────────────────
                  Row {
                    spacing: Style.space(5)
                    anchors.right: parent.right

                    // Pause / Resume
                    Rectangle {
                      visible: !dlCard.isDone
                      width: Style.space(26); height: Style.space(26); radius: Style.space(5)
                      color: prH.hovered ? Qt.alpha(Color.accent, 0.15) : "transparent"
                      border.color: Qt.alpha(root.foreground, 0.2); border.width: 1
                      Text {
                        anchors.centerIn: parent; font.family: root.fontFamily; font.pixelSize: Style.font.body
                        text: dlCard.isActive ? "⏸" : "▶"
                        color: dlCard.isActive ? Color.accent : "#a6e3a1"
                      }
                      HoverHandler { id: prH }
                      TapHandler {
                        onTapped: dlCard.isActive
                          ? service.pauseDownload(dlCard.task.id)
                          : service.resumeDownload(dlCard.task.id)
                      }
                    }

                    // Open file
                    Rectangle {
                      visible: dlCard.isDone
                      width: Style.space(26); height: Style.space(26); radius: Style.space(5)
                      color: ofH.hovered ? Qt.alpha(root.foreground, 0.08) : "transparent"
                      border.color: Qt.alpha(root.foreground, 0.2); border.width: 1
                      Text {
                        anchors.centerIn: parent; text: "󰈔"
                        font.family: root.fontFamily; font.pixelSize: Style.font.body; color: root.foreground
                      }
                      HoverHandler { id: ofH }
                      TapHandler { onTapped: service.openFile(dlCard.task.id) }
                    }

                    // Open folder
                    Rectangle {
                      width: Style.space(26); height: Style.space(26); radius: Style.space(5)
                      color: flH.hovered ? Qt.alpha(root.foreground, 0.08) : "transparent"
                      border.color: Qt.alpha(root.foreground, 0.2); border.width: 1
                      Text {
                        anchors.centerIn: parent; text: "󰉋"
                        font.family: root.fontFamily; font.pixelSize: Style.font.body; color: root.foreground
                      }
                      HoverHandler { id: flH }
                      TapHandler { onTapped: service.openFolder(dlCard.task.id) }
                    }

                    // Delete button
                    Rectangle {
                      width: Style.space(26); height: Style.space(26); radius: Style.space(5)
                      color: rmH.hovered ? Qt.alpha("#f38ba8", 0.2) : "transparent"
                      border.color: Qt.alpha(root.foreground, 0.2); border.width: 1
                      Text {
                        anchors.centerIn: parent; text: "✕"
                        font.family: root.fontFamily; font.pixelSize: Style.font.caption
                        color: rmH.hovered ? "#f38ba8" : Qt.alpha(root.foreground, 0.5)
                      }
                      HoverHandler { id: rmH }
                      TapHandler { onTapped: service.removeDownload(dlCard.task.id, false) }
                    }
                  }
                }
              }
            }

            // ── Pagination Controls ──────────────────────────────────────────
            RowLayout {
              width: parent.width
              visible: root.filteredDownloads.length > root.itemsPerPage
              
              Item { Layout.fillWidth: true } // Spacer
              
              Rectangle {
                width: Style.space(24); height: Style.space(24); radius: Style.space(4)
                color: prevHov.hovered && root.currentPage > 0 ? Qt.alpha(root.foreground, 0.1) : "transparent"
                Text { anchors.centerIn: parent; text: "◀"; color: root.currentPage > 0 ? root.foreground : root.dim; font.pixelSize: Style.font.caption }
                HoverHandler { id: prevHov; enabled: root.currentPage > 0 }
                TapHandler { onTapped: if (root.currentPage > 0) root.currentPage-- }
              }
              
              Text {
                text: "Page " + (root.currentPage + 1) + " of " + Math.max(1, Math.ceil(root.filteredDownloads.length / root.itemsPerPage))
                font.family: root.fontFamily; font.pixelSize: Style.font.caption; color: root.dim
              }
              
              Rectangle {
                width: Style.space(24); height: Style.space(24); radius: Style.space(4)
                property bool canNext: root.currentPage < Math.ceil(root.filteredDownloads.length / root.itemsPerPage) - 1
                color: nextHov.hovered && canNext ? Qt.alpha(root.foreground, 0.1) : "transparent"
                Text { anchors.centerIn: parent; text: "▶"; color: parent.canNext ? root.foreground : root.dim; font.pixelSize: Style.font.caption }
                HoverHandler { id: nextHov; enabled: parent.canNext }
                TapHandler { onTapped: if (parent.canNext) root.currentPage++ }
              }
              
              Item { Layout.fillWidth: true } // Spacer
            }

            // ── Empty state: Sleepy panda ────────────────────────────────────
            Rectangle {
              visible: !service.running || root.filteredDownloads.length === 0
              width: parent.width; height: Style.space(160)
              radius: Style.cornerRadius; color: Qt.alpha(Color.menu.selectedBackground, 0.5)
              border.color: Qt.alpha(root.foreground, 0.1); border.width: 1

              Column {
                anchors.centerIn: parent; spacing: Style.space(8)

                // Bigger animated panda in empty state
                PandaIcon {
                  anchors.horizontalCenter: parent.horizontalCenter
                  size: Style.space(64)
                  downloading: false; active: false

                  // Gentle sleepy bob
                  SequentialAnimation on y {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to:  3; duration: 1200; easing.type: Easing.SineCurve }
                    NumberAnimation { to: -3; duration: 1200; easing.type: Easing.SineCurve }
                  }
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: service.running ? "No downloads yet" : "Panda is asleep"
                  font.family: root.fontFamily; font.pixelSize: Style.font.body; font.weight: Font.Medium
                  color: root.foreground
                }
                
                Text {
                  visible: service.running
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Paste a magnet 🧲 or click ＋ to feed this panda"
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  color: root.dim
                }

                // ── Install / Start Button (when backend not running) ──────────
                Rectangle {
                  visible: !service.running
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: installLbl.implicitWidth + Style.space(24)
                  height: Style.space(26)
                  radius: height / 2
                  color: instHov.hovered ? Color.accent : "transparent"
                  border.color: Color.accent; border.width: 1

                  Text {
                    id: installLbl
                    anchors.centerIn: parent
                    text: "Wake up / Install Backend"
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.weight: Font.Bold
                    color: instHov.hovered ? Color.menu.background : Color.accent
                  }
                  HoverHandler { id: instHov }
                  TapHandler { onTapped: service.startDaemon() }
                }
              }
            }
          }
        }
      }
    }
  }
}
