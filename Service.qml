import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property bool running: false
  property int activeDownloads: 0
  property real totalDownloadSpeed: 0
  property real totalUploadSpeed: 0
  property var downloads: []
  property string lastError: ""

  property string binaryPath: {
    var home = Quickshell.env("HOME")
    var localBin = home + "/.local/bin/panda-dl"
    var releaseBin = home + "/Projects/panda-dl/target/release/panda-dl"
    var debugBin = home + "/Projects/panda-dl/target/debug/panda-dl"
    return localBin
  }

  // Pinned panda-dl release. The plugin installs exactly this binary and
  // verifies it against the checksum; there is no auto-update.
  readonly property string pinnedUrl: "https://github.com/pandaind/panda-dl/releases/download/v1.0.8/panda-dl"
  readonly property string pinnedSha256: "cbfe3aa93d03a4551ac493291ad38a02fa7765147ea8f2cc335d167e47636d5c"

  signal statusUpdated()

  // Polling Timer
  Timer {
    id: pollTimer
    interval: root.activeDownloads > 0 ? 1000 : 3000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  function refresh() {
    if (statusProcess.running) return
    statusProcess.command = ["sh", "-c", root.binaryPath + " status"]
    statusProcess.running = true
  }

  Process {
    id: statusProcess
    property string buffer: ""

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        statusProcess.buffer += line
      }
    }

    onExited: function(code) {
      if (code === 0 && statusProcess.buffer.trim().length > 0) {
        var parsed = Model.parseStatus(statusProcess.buffer)
        if (parsed.ok) {
          root.running = true
          root.activeDownloads = parsed.activeDownloads
          root.totalDownloadSpeed = parsed.totalDownloadSpeed
          root.totalUploadSpeed = parsed.totalUploadSpeed
          root.downloads = parsed.downloads
          root.lastError = ""
          root.statusUpdated()
        }
      } else {
        root.running = false
      }
      statusProcess.buffer = ""
    }
  }

  function addDownload(uri, dir, parts) {
    var args = [root.binaryPath, "add", uri]
    if (dir && dir.trim().length > 0) {
      args.push("--dir")
      args.push(dir.trim())
    }
    if (parts && parts > 0) {
      args.push("--parts")
      args.push(String(parts))
    }
    Quickshell.execDetached(args)
    Qt.callLater(function() { root.refresh() })
  }

  function pauseDownload(id) {
    Quickshell.execDetached([root.binaryPath, "pause", id])
    Qt.callLater(function() { root.refresh() })
  }

  function resumeDownload(id) {
    Quickshell.execDetached([root.binaryPath, "resume", id])
    Qt.callLater(function() { root.refresh() })
  }

  function removeDownload(id, deleteFile) {
    var args = [root.binaryPath, "remove", id]
    if (deleteFile) {
      args.push("--delete-file")
    }
    Quickshell.execDetached(args)
    Qt.callLater(function() { root.refresh() })
  }

  function openFile(id) {
    Quickshell.execDetached([root.binaryPath, "open-file", id])
  }

  function openFolder(id) {
    Quickshell.execDetached([root.binaryPath, "open-folder", id])
  }

  function startDaemon() {
    if (startProcess.running) return
    // Install the pinned binary if it is missing or does not match the pinned
    // checksum (the release's `-V` output can't be trusted to tell versions apart).
    // The old daemon is stopped only after the new binary is in place; the
    // "[p]" keeps pkill from matching this shell's own command line.
    var installCmd = "mkdir -p ~/.local/bin && " +
                     "TMP_BIN=$(mktemp) && trap 'rm -f \"$TMP_BIN\"' EXIT && " +
                     "curl -sfL --max-time 60 " + root.pinnedUrl + " -o \"$TMP_BIN\" && " +
                     "echo \"" + root.pinnedSha256 + "  $TMP_BIN\" | sha256sum -c --status - && " +
                     "chmod +x \"$TMP_BIN\" && " +
                     "mv -f \"$TMP_BIN\" " + root.binaryPath + " && " +
                     "{ pkill -f '[p]anda-dl daemon'; sleep 1; " + root.binaryPath + " install-desktop; true; }"
    var checkCmd = "echo \"" + root.pinnedSha256 + "  " + root.binaryPath + "\" | sha256sum -c --status -"

    startProcess.command = ["sh", "-c", "{ " + checkCmd + " || { " + installCmd + "; }; } && " + root.binaryPath + " start >/dev/null 2>&1"]
    startProcess.running = true
  }

  Process {
    id: startProcess
    onExited: function(code) {
      root.lastError = code === 0 ? "" : "Failed to install or start panda-dl"
      root.refresh()
    }
  }

  Component.onCompleted: {
    root.refresh()
  }
}
