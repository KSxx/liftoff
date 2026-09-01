<div align="center">

# Rocket Launches

<sub>An Omarchy bar plugin: live countdown to the next launch, the next 5
upcoming missions, and a stylized world map of their launch sites — right
in the shell.</sub>

[Install](#install) · [Data source](#data-source) · [Security](#security)

</div>

<table>
  <tr>
    <td align="center" width="50%">
      <strong>Dark</strong><br>
      <img src="screenshot-dark.png" alt="Rocket Launches panel on a dark Omarchy theme" width="100%">
    </td>
    <td align="center" width="50%">
      <strong>Light</strong><br>
      <img src="screenshot-light.png" alt="Rocket Launches panel on a light Omarchy theme (Catppuccin Latte)" width="100%">
    </td>
  </tr>
</table>

## Status

Feature-complete and in daily use. The bar pill shows a live countdown to
the tracked launch (accent-tinted in the final hour before T-0); the popup
lists the next 5 upcoming launches with a pin/watch toggle, a hero countdown
header, and a world map (curved Natural Earth projection, no map tiles —
launch sites plotted from local coordinates) that zooms in on hover. See
[docs/DECISIONS.md](docs/DECISIONS.md) for the design decisions behind the
original MVP and [docs/RESEARCH.md](docs/RESEARCH.md) for the API/plugin-
platform research it's based on.

## Data source

Launch data comes from the free [RocketLaunch.Live](https://fdo.rocketlaunch.live/)
`launches/next/5` endpoint — no API key required. Data by RocketLaunch.Live.

The API doesn't include launch site coordinates, so the map plots sites from
a small local lookup table (`LaunchSites.js`). Only a handful of entries
have been confirmed against a real API response; the rest are best-effort
guesses at the site-name-to-slug convention. A launch at an unlisted or
mismatched site still shows up in the list and detail view — it just won't
appear on the map. Pull requests adding confirmed slugs are welcome.

## Install

Review the repository, then add the plugin:

```bash
omarchy plugin add <actual-plugin-git-url>
```

Accept the prompt to enable the plugin during installation.

For an unattended install from a repository you already trust:

```bash
omarchy plugin add <actual-plugin-git-url> --enable --yes
```

## Update

```bash
omarchy plugin update ksxx.rocket-launches
```

## Validate from source

```bash
omarchy plugin validate .
```

## Security

This plugin runs unsandboxed inside `omarchy-shell` when enabled.

- Network access: periodic `curl` requests to `https://fdo.rocketlaunch.live/`
  to fetch upcoming launch data (no API key, no request body, no
  authentication).
- No files are read or written outside the plugin's own settings stored in
  `~/.config/omarchy/shell.json` by the shell itself.
- No background services outside the widget's own poll timer.
- No user configuration is required outside the plugin's bar-widget
  settings.

<div align="center">

---

[Decisions](docs/DECISIONS.md) · [Research](docs/RESEARCH.md) · [MIT License](LICENSE)

</div>
