// Parsing and formatting helpers for the RocketLaunch.Live `launches/next/5`
// response. Kept separate from the QML so the shape of the API and the shape
// of the UI can change independently.
.pragma library
.import "LaunchSites.js" as Sites

// Turns the raw JSON body into a normalized, sorted list of launch objects.
// Returns [] on anything unexpected rather than throwing — the caller is
// responsible for treating an empty result plus a fetch error differently
// from an empty result with no error (nothing currently scheduled).
function parseLaunches(rawText) {
  var parsed
  try {
    parsed = JSON.parse(String(rawText || ""))
  } catch (e) {
    return []
  }
  var list = parsed && Array.isArray(parsed.result) ? parsed.result : []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var launch = normalizeLaunch(list[i])
    if (launch) out.push(launch)
  }
  out.sort(function(a, b) { return a.sortKey - b.sortKey })
  for (var j = 0; j < out.length; j++) out[j].isNext = (j === 0)
  return out
}

function normalizeLaunch(raw) {
  if (!raw) return null

  var pad = raw.pad || {}
  var location = pad.location || {}
  var provider = raw.provider || {}
  var vehicle = raw.vehicle || {}
  var mission = (raw.missions && raw.missions.length > 0) ? raw.missions[0] : null

  var t0 = typeof raw.t0 === "string" && raw.t0 !== "" ? raw.t0 : null
  var precision = "unknown"
  if (t0 !== null) precision = "exact"
  else if (raw.date_str || (raw.est_date && (raw.est_date.month || raw.est_date.year))) precision = "date"

  var site = Sites.forSlug(location.slug)

  return {
    id: raw.id,
    name: raw.name || (mission ? mission.name : "") || "Unnamed mission",
    provider: provider.name || "",
    vehicle: vehicle.name || "",
    padName: pad.name || "",
    locationName: location.name || "",
    country: location.country || "",
    locationSlug: location.slug || "",
    missionDescription: raw.mission_description || (mission ? mission.description : "") || "",
    t0: t0,
    dateLabel: raw.date_str || "",
    precision: precision,
    detailUrl: raw.slug ? ("https://rocketlaunch.live/launch/" + raw.slug) : null,
    livestreamUrl: firstLivestreamUrl(raw.media),
    lat: site ? site.lat : null,
    lon: site ? site.lon : null,
    isNext: false,
    // sort_date is a unix-seconds string; fall back to a value that sorts
    // "unknown" launches last.
    sortKey: raw.sort_date ? parseInt(raw.sort_date, 10) : Number.MAX_SAFE_INTEGER
  }
}

// The `media` field's exact shape when populated isn't documented; this
// tries the field names that would plausibly carry a playable/watchable URL
// and gives up cleanly rather than guessing at HTML.
function firstLivestreamUrl(media) {
  if (!Array.isArray(media) || media.length === 0) return null
  for (var i = 0; i < media.length; i++) {
    var m = media[i]
    if (!m) continue
    if (typeof m === "string" && m.indexOf("http") === 0) return m
    if (m.url && typeof m.url === "string") return m.url
    if (m.youtube_id) return "https://www.youtube.com/watch?v=" + m.youtube_id
  }
  return null
}

// Compact countdown for the bar pill and map markers, e.g. "3d", "58m", "Now".
function countdownLabel(t0, nowMs) {
  if (!t0) return null
  var target = Date.parse(t0)
  if (isNaN(target)) return null
  var now = nowMs || Date.now()
  var diffSec = Math.round((target - now) / 1000)
  if (diffSec <= 0) return "Now"
  if (diffSec < 60) return diffSec + "s"
  var minutes = Math.floor(diffSec / 60)
  if (minutes < 60) return minutes + "m"
  var hours = Math.floor(minutes / 60)
  if (hours < 48) return hours + "h " + (minutes % 60) + "m"
  var days = Math.floor(hours / 24)
  return days + "d"
}

// Whether T-0 is close enough that the bar pill should draw attention.
function isImminent(t0, nowMs) {
  if (!t0) return false
  var target = Date.parse(t0)
  if (isNaN(target)) return false
  var now = nowMs || Date.now()
  var diffSec = (target - now) / 1000
  return diffSec > -300 && diffSec < 3600
}

function barLabel(launch, nowMs) {
  if (!launch) return "🚀"
  if (launch.precision === "exact") {
    var c = countdownLabel(launch.t0, nowMs)
    return c ? ("🚀 " + c) : "🚀"
  }
  if (launch.precision === "date" && launch.dateLabel) return "🚀 ~" + launch.dateLabel
  return "🚀 TBD"
}

// Local wall-clock time for the detail view, e.g. "Sun, 30 Aug · 11:26".
function localTimeLabel(t0) {
  if (!t0) return null
  var d = new Date(t0)
  if (isNaN(d.getTime())) return null
  return Qt.formatDateTime(d, "ddd, d MMM · HH:mm")
}
