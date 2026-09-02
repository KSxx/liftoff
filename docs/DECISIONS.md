# Design decisions (MVP)

## Bar: permanent icon vs. only-before-launch

**Decision:** Permanent compact icon (rocket + short countdown/date),
visually intensifying (pulse/color) inside the last ~60 minutes before T-0.

Bar-widget slots are static entries in `shell.json`; the platform's
convention (weather, ProtonVPN) is an always-present pill, not a
widget that adds/removes itself. A permanent low-key icon is also more
discoverable than one that only appears occasionally.

## Default launch set: all vs. curated

**Decision:** Show everything the free API tier returns (up to 5 upcoming
launches), no provider/mission curation.

The free `launches/next/5` endpoint already caps us at 5 launches, so a
curation step would add subjective filtering logic for no real benefit at
this stage. Provider/country filtering is explicitly a later iteration.

## Config file vs. settings UI

**Decision:** Use the manifest's `barWidget.schema` / `defaults`
mechanism (editable via the existing Omarchy settings UI and
`omarchy bar plugin set`). No custom settings UI, no separate plugin config
file for the MVP.

This is the standard first-party mechanism (see `omarchy.weather`,
`omaproton-vpn`) and covers the one setting the MVP needs (poll interval).

## Handling TBD / shifted launch dates

**Decision:** Three precision tiers, derived from what the API actually
gives us — never invented:

1. Exact `t0` present → live countdown to that instant.
2. No `t0`, but `est_date`/`date_str` gives a date → a date badge (e.g.
   "~ Aug 30"), no seconds-level countdown.
3. Nothing usable → a "TBD" badge, sorted last.

A launch whose `t0` changes between two polls is simply displayed with the
new value — the API has no explicit "delayed" flag, so no separate
reschedule indicator is invented.

## API key

**Decision:** None for the MVP — `launches/next/5` needs no key.

If a future iteration needs the full `/launches` endpoint (more results,
server-side filters), the key would be read from a local, git-ignored file
outside the plugin's settings, e.g. `~/.config/omarchy/rocket-launch/config.json`
with an `apiKey` field — never hardcoded, never written into `shell.json`
(which is not a secret store).
