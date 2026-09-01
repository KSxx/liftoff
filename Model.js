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

// Shared tail for countdowns beyond the hour-level tiers: "3d" under two
// weeks, "6w" under two months, "3mo" beyond that.
function daySpanLabel(days) {
  if (days < 14) return days + "d"
  if (days < 60) return Math.floor(days / 7) + "w"
  return Math.floor(days / 30) + "mo"
}

// Countdown formatter shared by the bar pill and the popup. Precision
// scales with urgency: seconds/minutes inside the final hour (where it
// actually matters), then whole hours only — no minute-level jitter, since
// "14h" and "14h 32m" mean the same thing at that range — up to
// coarsenAtHours, then day/week/month tiers.
function formatCountdown(t0, nowMs, coarsenAtHours) {
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
  if (hours < coarsenAtHours) return hours + "h"
  return daySpanLabel(Math.floor(hours / 24))
}

// Compact countdown for the popup (list rows, map tooltip, detail view),
// e.g. "3d", "14h", "58m", "Now". Whole hours until two days out.
function countdownLabel(t0, nowMs) {
  return formatCountdown(t0, nowMs, 48)
}

// Countdown for the bar pill specifically: coarsens a day earlier than the
// popup's, so the pill reads as a clean "2d" sooner rather than lingering
// on hour-level detail for anything not actually close.
function barCountdownLabel(t0, nowMs) {
  return formatCountdown(t0, nowMs, 24)
}

// Full ticking H:MM:SS countdown for the hero header — this is the one
// place in the panel that shows genuine seconds-level precision (everywhere
// else deliberately coarsens per formatCountdown above, since minute/second
// detail isn't useful when just scanning a list). Hours aren't padded, so
// it grows naturally past 99h instead of truncating.
function fullCountdownLabel(t0, nowMs) {
  if (!t0) return null
  var target = Date.parse(t0)
  if (isNaN(target)) return null
  var now = nowMs || Date.now()
  var diffSec = Math.max(0, Math.round((target - now) / 1000))
  var hours = Math.floor(diffSec / 3600)
  var minutes = Math.floor((diffSec % 3600) / 60)
  var seconds = diffSec % 60
  function pad(n) { return (n < 10 ? "0" : "") + n }
  return hours + ":" + pad(minutes) + ":" + pad(seconds)
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

// 0..1 urgency signal for "how soon is this", used to ramp color/width from
// a neutral tone toward the accent color. Full urgency inside the final
// hour (matching isImminent's window), fully neutral from three days out;
// 0 for anything without a usable countdown (TBD/date-only precision).
function urgencyRatio(t0, nowMs) {
  if (!t0) return 0
  var target = Date.parse(t0)
  if (isNaN(target)) return 0
  var now = nowMs || Date.now()
  var hoursRemaining = (target - now) / 3600000
  return Math.max(0, Math.min(1, 1 - (hoursRemaining - 1) / 71))
}

function barLabel(launch, nowMs) {
  if (!launch) return "󱓞"
  if (launch.precision === "exact") {
    var c = barCountdownLabel(launch.t0, nowMs)
    return c ? ("󱓞 " + c) : "󱓞"
  }
  if (launch.precision === "date" && launch.dateLabel) return "󱓞 ~" + launch.dateLabel
  return "󱓞 TBD"
}

// Short country form for the narrow SITE column, e.g. "United States" -> "US".
// Small, static — only the countries LaunchSites.js's known sites actually
// sit in. Unlisted countries just pass through unabbreviated.
var COUNTRY_SHORT = {
  "United States": "US",
  "United States of America": "US",
  "New Zealand": "NZ",
  "India": "India",
  "Norway": "Norway",
  "Kazakhstan": "Kazakhstan",
  "Russia": "Russia",
  "Russian Federation": "Russia",
  "China": "China",
  "Japan": "Japan",
  "South Korea": "South Korea",
  "Republic of Korea": "South Korea",
  "North Korea": "North Korea",
  "France": "France",
  "Brazil": "Brazil",
  "Iran": "Iran"
}
function shortCountry(country) {
  if (!country) return ""
  return COUNTRY_SHORT[country] || country
}

// Local wall-clock time for the detail view, e.g. "Sun, 30 Aug · 11:26".
function localTimeLabel(t0) {
  if (!t0) return null
  var d = new Date(t0)
  if (isNaN(d.getTime())) return null
  return Qt.formatDateTime(d, "ddd, d MMM · HH:mm")
}

// Compact one-line variant for narrow columns, e.g. "Wed 09:46" — drops the
// day-of-month/name, weekday + time is enough to disambiguate within the
// one-week span the next-5 launches ever cover.
function shortLocalTimeLabel(t0) {
  if (!t0) return null
  var d = new Date(t0)
  if (isNaN(d.getTime())) return null
  return Qt.formatDateTime(d, "ddd HH:mm")
}

// "just now" / "2 min ago" for the header's last-refresh meta line.
function updatedAgoLabel(lastFetchMs, nowMs) {
  if (!lastFetchMs) return null
  var now = nowMs || Date.now()
  var minutes = Math.floor((now - lastFetchMs) / 60000)
  if (minutes < 1) return "just now"
  return minutes + " min ago"
}
