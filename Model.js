.pragma library

function formatBytes(bytes) {
  if (bytes === null || bytes === undefined || isNaN(bytes)) return "—";
  var b = Number(bytes);
  if (b < 0) return "0 B";
  if (b === 0) return "0 B";
  var k = 1024;
  var sizes = ["B", "KB", "MB", "GB", "TB"];
  var i = Math.floor(Math.log(b) / Math.log(k));
  if (i >= sizes.length) i = sizes.length - 1;
  return (b / Math.pow(k, i)).toFixed(i === 0 ? 0 : 2) + " " + sizes[i];
}

function formatSpeed(bytesPerSec) {
  if (!bytesPerSec || bytesPerSec <= 0) return "0 B/s";
  return formatBytes(bytesPerSec) + "/s";
}

function formatEta(seconds) {
  if (seconds === null || seconds === undefined || !isFinite(seconds) || seconds <= 0) return "—";
  var s = Math.floor(seconds);
  var hours = Math.floor(s / 3600);
  var minutes = Math.floor((s % 3600) / 60);
  var remSecs = s % 60;
  if (hours > 0) return hours + "h " + minutes + "m";
  if (minutes > 0) return minutes + "m " + remSecs + "s";
  return remSecs + "s";
}

function calcProgress(downloaded, total) {
  if (!total || total <= 0) return 0.0;
  var p = downloaded / total;
  return Math.max(0.0, Math.min(1.0, p));
}

function statusColor(status, Color) {
  if (!status) return Color.muted;
  var s = typeof status === "object" ? Object.keys(status)[0] : String(status);
  switch (s.toLowerCase()) {
    case "downloading": return Color.accent;
    case "completed": return "#a6e3a1"; // Green
    case "paused": return "#f9e2af";    // Yellow
    case "error": return Color.urgent;
    default: return Color.muted;
  }
}

function parseStatus(raw) {
  try {
    if (!raw || !raw.trim()) return { ok: false };
    var obj = JSON.parse(raw);
    return {
      ok: true,
      activeDownloads: obj.active_downloads || 0,
      totalDownloadSpeed: obj.total_download_speed || 0,
      totalUploadSpeed: obj.total_upload_speed || 0,
      downloads: obj.downloads || []
    };
  } catch (e) {
    return { ok: false, error: e.toString() };
  }
}
