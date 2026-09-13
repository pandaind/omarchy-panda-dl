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

  property string currentVersion: ""
  property string latestVersion: ""
  property bool updateAvailable: false

  signal statusUpdated()

  // Polling Timer
  Timer {
    id: pollTimer
    interval: root.activeDownloads > 0 ? 1000 : 3000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // Update check timer (checks every 12 hours)
  Timer {
    interval: 12 * 60 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.checkForUpdates()
  }

  function refresh() {
    if (statusProcess.running) return
    statusProcess.command = [root.binaryPath, "status"]
    statusProcess.running = true
  }

  function checkForUpdates() {
    if (!updateCheckProcess.running) {
      updateCheckProcess.running = true
    }
  }

  Process {
    id: updateCheckProcess
    // Strip 'v' from the latest tag so it matches rust 'panda-dl X.Y.Z' output
    command: ["sh", "-c", "curr=$(" + root.binaryPath + " -V 2>/dev/null | awk '{print $2}'); latest=$(curl -s https://api.github.com/repos/pandaind/panda-dl/releases/latest | grep '\"tag_name\":' | sed -E 's/.*\"v?([^\"]+)\".*/\\1/'); echo \"$curr|$latest\""]
    property string buffer: ""
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        updateCheckProcess.buffer += line
      }
    }
    onExited: function(code) {
      var parts = updateCheckProcess.buffer.trim().split("|")
      if (parts.length === 2) {
        root.currentVersion = parts[0]
        root.latestVersion = parts[1]
        // If currentVersion is empty, it's not installed. Don't show update.
        if (root.currentVersion && root.latestVersion && root.currentVersion !== root.latestVersion) {
          root.updateAvailable = true
        } else {
          root.updateAvailable = false
        }
      }
      updateCheckProcess.buffer = ""
    }
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

  function updateBinary() {
    root.updateAvailable = false
    var githubUrl = "https://github.com/pandaind/panda-dl/releases/latest/download/panda-dl"
    var installCmd = "echo \"Updating Panda-DL backend...\"; " +
                     "pkill -f 'panda-dl daemon' || true; " +
                     "curl -sL " + githubUrl + " -o ~/.local/bin/panda-dl && " +
                     "chmod +x ~/.local/bin/panda-dl && " +
                     "~/.local/bin/panda-dl start && " +
                     "echo \"\\nUpdate successful!\"; sleep 3"

    Quickshell.execDetached(["sh", "-c", 
      "alacritty -e sh -c '" + installCmd + "' || foot -e sh -c '" + installCmd + "'"
    ])
    root.running = true
    Qt.callLater(function() { root.checkForUpdates(); root.refresh() })
  }

  Component.onCompleted: {
    root.refresh()
    root.checkForUpdates()
  }
}
