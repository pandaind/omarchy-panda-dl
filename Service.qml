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
    statusProcess.command = [root.binaryPath, "status"]
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
    // Attempt to start it; if it fails (doesn't exist), launch a terminal to download the release binary
    var githubUrl = "https://github.com/pandaind/panda-dl/releases/latest/download/panda-dl"
    
    var installCmd = "echo \"Installing Panda-DL backend...\"; " +
                     "mkdir -p ~/.local/bin && " +
                     "curl -sL " + githubUrl + " -o ~/.local/bin/panda-dl && " +
                     "chmod +x ~/.local/bin/panda-dl && " +
                     "~/.local/bin/panda-dl start && " +
                     "echo \"\\nSuccessfully installed and started!\"; sleep 3"

    Quickshell.execDetached(["sh", "-c", 
      root.binaryPath + " start || (alacritty -e sh -c '" + installCmd + "' || foot -e sh -c '" + installCmd + "')"
    ])
    root.running = true // optimistic
    Qt.callLater(function() { root.refresh() })
  }

  Component.onCompleted: {
    root.refresh()
  }
}
