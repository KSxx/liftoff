# Research (Phase 1)

## RocketLaunch.Live API

Base: `https://fdo.rocketlaunch.live/json/`

- Endpoints: `/launches`, `/companies`, `/locations`, `/missions`, `/pads`, `/tags`, `/vehicles`.
- Full querying (filters, pagination beyond 25 results) requires a Premium
  API key via `Authorization: Bearer <key>` or `?key=`.
- **`launches/next/5` works without any key or auth** — verified live
  (`200 OK`, `valid_auth:false`, real data returned). This is what the MVP
  uses.
- Server-side cache: `Cache-Control: public, max-age=60`. No documented hard
  rate limit; the plugin polls at a conservative default (5 min, configurable
  60s–1h via the bar-widget settings schema) to be a good citizen.
- Launch object fields (relevant subset): `name`, `provider.name`,
  `vehicle.name`, `pad.name`, `pad.location.name` / `.country` (**no
  lat/lon**), `t0` (ISO datetime, often `null`), `win_open`/`win_close`,
  `est_date` (`month`/`day`/`year`, any of which may be `null`), `date_str`,
  `missions[].description`, `media[]` (livestream links, frequently empty),
  `quicktext` (contains the `rocketlaunch.live` launch page URL).
- Requested attribution: "Data by RocketLaunch.Live" near displayed data.
- No coordinates in the API response → the plugin ships a small local
  pad/location name → lat/lon lookup table for the known set of active
  launch sites, built the same way ProtonVPN bundles its city list (no
  runtime geocoding).

## Omarchy plugin platform

- One Git repo = one plugin, `manifest.json` at repo root. Required fields:
  `schemaVersion` (number `1`), `id`, `name`, `version`, `kinds`,
  `entryPoints`.
- `id` must be namespaced, ASCII, not start with `omarchy.`.
- `kinds: ["bar-widget"]` fits this plugin (a widget in the bar with a
  popup), no need for a separate `panel`/`service` kind.
- Bar-widget settings: `barWidget.schema` + `barWidget.defaults` in the
  manifest; actual values live inline in `~/.config/omarchy/shell.json`,
  editable via the shell settings UI or `omarchy bar plugin set`. No custom
  settings UI or separate config file needed for the MVP.
- First-party reference for network polling: `omarchy.weather`
  (`/usr/share/omarchy/shell/plugins/panels/weather/`). It fetches JSON via
  `Process { command: ["curl", "-fsS", "--max-time", N, url] }` on a
  `Timer`, with a retry timer on failure. This plugin follows the same
  pattern — not `XMLHttpRequest`.
- Structural convention (also from `omarchy.weather`): a thin
  `BarWidget.qml` (the bar pill) loads a `Panel.qml` via `Loader`
  (`active: true`, always mounted) that holds the actual state and popup UI,
  built on the `Panel` base type from `qs.Ui` (`KeyboardPanel`,
  `PanelKeyCatcher`, `IpcHandler` for open/close/toggle).
- Publishing to omarchyplugins.com: submit a public GitHub repo (manifest,
  README, license) through the site's submission form after
  `omarchy plugin validate .` passes locally.

## ProtonVPN plugin map (reference only)

`io.github.grichard99.omaproton-vpn` (`~/.config/omarchy/plugins/...`):

- `WorldMap.qml` + `World.js`: equirectangular projection
  (`x = (lon+180)/360*W`, `y = (latTop-lat)/(latTop-latBottom)*H`), land
  drawn from a single bundled SVG path at low alpha in the theme foreground
  color. Dim 2.5px dots for inactive cities, a brighter larger dot for the
  active one, plus a `Rectangle` ring pulsing via `SequentialAnimation` on
  `scale` (0.8→3.2) and `opacity` (0.9→0) over 1800ms, looping.
- License: plugin code MIT (grichard99, 2026); the bundled map data is
  explicitly credited in-code as Natural Earth, public domain.
- Per the task's instruction to use this only as an interaction-pattern
  reference: no code or the bundled SVG path was copied. The land silhouette
  instead comes from the official Natural Earth 1:110m land dataset
  (`github.com/nvkelso/natural-earth-vector`, public domain, 127 polygons),
  fetched and projected independently with the same (non-copyrightable)
  equirectangular formula. The interaction idea (dim dots, one pulsing
  highlighted marker, hover label) is reimplemented from scratch.
