// Known active orbital/suborbital launch site coordinates, keyed by the
// RocketLaunch.Live `pad.location.slug` value. The API gives us a location
// name and country but no coordinates, so this table fills that gap for the
// map view. A launch whose location slug isn't in this table is still shown
// in lists and detail views; it just isn't plotted on the map.
//
// Two confidence tiers, both sourced from RocketLaunch.Live itself (never
// invented):
//
// - "Confirmed": the slug was seen directly in a live `launches/next/5`
//   response, and the coordinates are the exact per-pad `geo` value from
//   that same launch's `application/ld+json` block on its
//   rocketlaunch.live/launch/<slug> detail page — not a general "site"
//   coordinate. E.g. Vandenberg's entry is SLC-4E's own position, not
//   Vandenberg SFB's overall base coordinate (the two differ by several km).
// - "Best-effort": the *name* is the real one, taken from the location/pad
//   directory embedded in the "report an issue" form on any launch detail
//   page (rocketlaunch.live/launch/<any-slug> — a `<select name="location_id">`
//   listing every location RocketLaunch.Live tracks, ~52 entries as of
//   2026-09-01, plus a chained `<select name="pad_id">` of every pad). That
//   form is the closest free substitute for the paid `/locations`/`/pads`
//   API endpoints. The *slug*, though, never appears anywhere public — only
//   the free API itself ever reveals it, and only for whichever site has an
//   upcoming launch right now. So the slug here is still a guess at
//   RocketLaunch.Live's kebab-case-of-the-full-name convention, just a
//   better-informed one now that the full name is confirmed rather than
//   remembered. That convention isn't perfectly reliable even so — compare
//   the confirmed "andoya" for "Andøya Space" (generic word dropped,
//   diacritic stripped) — so an entry can still simply fail to match.
// Coordinates for the best-effort tier are the site's well-documented public
// pad/base location, not scraped from a live launch page.
//
// Extend this table as new slugs are observed in real API responses, or as
// more of the ~52-location directory gets confirmed the same way.
.pragma library

var SITES = {
  // Confirmed: slug from a live API response, coordinates from that same
  // launch's own JSON-LD geo block (exact pad position).
  "vandenberg-sfb": { lat: 34.632706, lon: -120.613393, name: "Vandenberg SFB" },
  "rocket-lab-launch-complex-mahia-peninsula": { lat: -39.2609, lon: 177.8655, name: "Rocket Lab Launch Complex, Mahia Peninsula" },
  "satish-dhawan-space-centre": { lat: 13.719939, lon: 80.230425, name: "Satish Dhawan Space Centre" },
  "andoya": { lat: 69.1087, lon: 15.5887, name: "Andøya Space" },
  "kennedy-space-center": { lat: 28.6080, lon: -80.6041, name: "Kennedy Space Center" },

  // Best-effort: name confirmed against RocketLaunch.Live's own
  // location/pad directory (see header comment), slug guessed from it,
  // coordinates from public knowledge of the site.
  "cape-canaveral-sfs": { lat: 28.4889, lon: -80.5778, name: "Cape Canaveral SFS" },
  "baikonur-cosmodrome": { lat: 45.9646, lon: 63.3052, name: "Baikonur Cosmodrome" },
  "plesetsk-cosmodrome": { lat: 62.9270, lon: 40.5777, name: "Plesetsk Cosmodrome" },
  "vostochny-cosmodrome": { lat: 51.8838, lon: 128.3339, name: "Vostochny Cosmodrome" },
  "jiuquan-satellite-launch-center": { lat: 40.9675, lon: 100.2913, name: "Jiuquan Satellite Launch Center" },
  "xichang-satellite-launch-center": { lat: 28.2467, lon: 102.0267, name: "Xichang Satellite Launch Center" },
  "taiyuan-satellite-launch-center": { lat: 38.8489, lon: 111.6086, name: "Taiyuan Satellite Launch Center" },
  // Was "wenchang-spacecraft-launch-site" — RocketLaunch.Live's own
  // directory calls it "Wenchang Satellite Launch Center", so the slug
  // guess is corrected to match that name.
  "wenchang-satellite-launch-center": { lat: 19.6144, lon: 110.9510, name: "Wenchang Satellite Launch Center" },
  "tanegashima-space-center": { lat: 30.4008, lon: 130.9714, name: "Tanegashima Space Center" },
  "uchinoura-space-center": { lat: 31.2513, lon: 131.0796, name: "Uchinoura Space Center" },
  "naro-space-center": { lat: 34.4319, lon: 127.5356, name: "Naro Space Center" },
  "wallops-flight-facility": { lat: 37.9403, lon: -75.4664, name: "Wallops Flight Facility" },
  // Distinct from the above in RocketLaunch.Live's own directory — the
  // commercial Mid-Atlantic Regional Spaceport pads on the same island.
  "mid-atlantic-regional-spaceport": { lat: 37.8331, lon: -75.4883, name: "Mid-Atlantic Regional Spaceport (Wallops Island)" },
  "pacific-spaceport-complex-alaska": { lat: 57.4353, lon: -152.3378, name: "Pacific Spaceport Complex - Alaska" },
  // Was "starbase" — the directory lists it as "SpaceX Starbase".
  "spacex-starbase": { lat: 25.9971, lon: -97.1554, name: "SpaceX Starbase" },
  "corn-ranch-spaceport": { lat: 31.4229, lon: -104.7586, name: "Corn Ranch Spaceport" },
  "guiana-space-centre": { lat: 5.2360, lon: -52.7750, name: "Guiana Space Centre" },
  "sohae-satellite-launching-station": { lat: 39.6600, lon: 124.7050, name: "Sohae Satellite Launching Station" },
  "alcantara-space-center": { lat: -2.3736, lon: -44.3958, name: "Alcântara Space Center" },
  // Was "semnan-space-center" — the site is in Semnan province, but
  // RocketLaunch.Live's own directory names the facility "Imam Khomeini
  // Spaceport", not "Semnan Space Center". Coordinates unchanged (they
  // were already right for the actual place, just filed under a name and
  // slug RocketLaunch.Live doesn't use).
  "imam-khomeini-spaceport": { lat: 35.2211, lon: 53.9214, name: "Imam Khomeini Spaceport" },
  "spaceport-america": { lat: 32.9903, lon: -106.9726, name: "Spaceport America" },
  "bowen-orbital-spaceport": { lat: -19.9377, lon: 148.1128, name: "Bowen Orbital Spaceport" },
  "space-port-kii": { lat: 33.4877, lon: 135.8878, name: "Space Port Kii" },
  "mojave-air-and-space-port": { lat: 35.0590, lon: -118.1517, name: "Mojave Air and Space Port" }
}

function forSlug(slug) {
  if (!slug) return null
  return SITES[slug] || null
}
