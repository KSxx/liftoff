#!/usr/bin/env python3
"""Generate World.js from the official Natural Earth 1:110m land dataset.

Source: https://github.com/nvkelso/natural-earth-vector (public domain).
Run manually to regenerate World.js; the plugin itself never fetches this
at runtime — the generated file is committed.

Usage:
    curl -fsS -o /tmp/ne_110m_land.geojson \\
      https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson
    python3 scripts/generate-world-map.py /tmp/ne_110m_land.geojson > World.js
"""
import json
import sys

WIDTH = 360
HEIGHT = 140
LAT_TOP = 80
LAT_BOTTOM = -60


def project(lon, lat):
    lat = max(LAT_BOTTOM, min(LAT_TOP, lat))
    x = (lon + 180) / 360 * WIDTH
    y = (LAT_TOP - lat) / (LAT_TOP - LAT_BOTTOM) * HEIGHT
    return x, y


def ring_to_path(ring):
    parts = []
    for i, (lon, lat) in enumerate(ring):
        x, y = project(lon, lat)
        cmd = "M" if i == 0 else "L"
        parts.append(f"{cmd}{x:.1f} {y:.1f}")
    parts.append("Z")
    return "".join(parts)


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        data = json.load(f)

    path_parts = []
    for feature in data["features"]:
        geom = feature["geometry"]
        polys = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]
        for poly in polys:
            for ring in poly:
                path_parts.append(ring_to_path(ring))

    path = "".join(path_parts)

    print(f"""// World land outline for the panel mini-map.
// Source: Natural Earth 1:110m land, https://www.naturalearthdata.com/
// (public domain), via https://github.com/nvkelso/natural-earth-vector,
// projected equirectangular into a {WIDTH}x{HEIGHT} box with latitude
// clipped to [{LAT_BOTTOM}, {LAT_TOP}]. Generated once by
// scripts/generate-world-map.py; the plugin never fetches this at runtime.
.pragma library
var WIDTH = {WIDTH}
var HEIGHT = {HEIGHT}
var LAT_TOP = {LAT_TOP}
var LAT_BOTTOM = {LAT_BOTTOM}
var PATH = "{path}"

function project(lon, lat) {{
  var clamped = Math.max(LAT_BOTTOM, Math.min(LAT_TOP, lat))
  return [(lon + 180) / 360 * WIDTH, (LAT_TOP - clamped) / (LAT_TOP - LAT_BOTTOM) * HEIGHT]
}}
""")


if __name__ == "__main__":
    main()
