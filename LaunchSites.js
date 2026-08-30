// Known active orbital launch site coordinates, keyed by the RocketLaunch.Live
// `pad.location.slug` value. The API gives us a location name and country but
// no coordinates, so this table fills that gap for the map view.
//
// Entries marked "confirmed" were observed directly in a live API response.
// The rest are a best-effort guess at RocketLaunch.Live's slug convention
// (lowercase, hyphenated location name) for other well-known active sites —
// RocketLaunch.Live doesn't always drop generic words the same way (compare
// the confirmed "andoya" for "Andøya Space"), so an unconfirmed entry can
// simply fail to match. A launch whose location slug isn't in this table is
// still shown in lists and detail views; it just isn't plotted on the map.
//
// Extend this table as new slugs are observed in real API responses.
.pragma library

var SITES = {
  // Confirmed from a live API response.
  "kennedy-space-center": { lat: 28.6080, lon: -80.6041, name: "Kennedy Space Center" },
  "rocket-lab-launch-complex-mahia-peninsula": { lat: -39.2622, lon: 177.8648, name: "Mahia Peninsula" },
  "vandenberg-sfb": { lat: 34.7420, lon: -120.5724, name: "Vandenberg SFB" },
  "satish-dhawan-space-centre": { lat: 13.7199, lon: 80.2304, name: "Satish Dhawan Space Centre" },
  "andoya": { lat: 69.2944, lon: 16.0117, name: "Andøya Space" },

  // Best-effort guesses for other well-known active sites.
  "cape-canaveral-sfs": { lat: 28.4889, lon: -80.5778, name: "Cape Canaveral SFS" },
  "baikonur-cosmodrome": { lat: 45.9646, lon: 63.3052, name: "Baikonur Cosmodrome" },
  "plesetsk-cosmodrome": { lat: 62.9270, lon: 40.5777, name: "Plesetsk Cosmodrome" },
  "vostochny-cosmodrome": { lat: 51.8838, lon: 128.3339, name: "Vostochny Cosmodrome" },
  "jiuquan-satellite-launch-center": { lat: 40.9675, lon: 100.2913, name: "Jiuquan SLC" },
  "xichang-satellite-launch-center": { lat: 28.2467, lon: 102.0267, name: "Xichang SLC" },
  "taiyuan-satellite-launch-center": { lat: 38.8489, lon: 111.6086, name: "Taiyuan SLC" },
  "wenchang-spacecraft-launch-site": { lat: 19.6144, lon: 110.9510, name: "Wenchang" },
  "tanegashima-space-center": { lat: 30.4008, lon: 130.9714, name: "Tanegashima" },
  "uchinoura-space-center": { lat: 31.2513, lon: 131.0796, name: "Uchinoura" },
  "naro-space-center": { lat: 34.4319, lon: 127.5356, name: "Naro Space Center" },
  "wallops-flight-facility": { lat: 37.9403, lon: -75.4664, name: "Wallops Flight Facility" },
  "pacific-spaceport-complex-alaska": { lat: 57.4353, lon: -152.3378, name: "Pacific Spaceport Complex Alaska" },
  "starbase": { lat: 25.9971, lon: -97.1554, name: "Starbase" },
  "guiana-space-centre": { lat: 5.2360, lon: -52.7750, name: "Guiana Space Centre" },
  "sohae-satellite-launching-station": { lat: 39.6600, lon: 124.7050, name: "Sohae" },
  "alcantara-space-center": { lat: -2.3736, lon: -44.3958, name: "Alcântara" },
  "semnan-space-center": { lat: 35.2211, lon: 53.9214, name: "Semnan" }
}

function forSlug(slug) {
  if (!slug) return null
  return SITES[slug] || null
}
