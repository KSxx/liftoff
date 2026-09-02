#!/usr/bin/env python3
"""Generate World.js from the official Natural Earth 1:110m land dataset,
projected with the Natural Earth pseudo-cylindrical projection (curved
meridians/parallels, the same one the reference redesign mockup used via
d3.geoNaturalEarth1()) rather than a flat equirectangular grid.

Source: https://github.com/nvkelso/natural-earth-vector (public domain).
Run manually to regenerate World.js; the plugin itself never fetches this
at runtime — the generated file is committed.

Usage:
    curl -fsS -o /tmp/ne_110m_land.geojson \\
      https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson
    python3 scripts/generate-world-map.py /tmp/ne_110m_land.geojson > World.js
"""
import json
import math
import sys

LAT_TOP = 84
LAT_BOTTOM = -90

# Natural Earth projection polynomial coefficients (Šavrič et al. 2011 /
# Tom Patterson's original fit — the same one D3's geoNaturalEarth1 uses).
# Operates on lon/lat in radians; output is in the projection's own
# (unitless) space, mapped to a WIDTH x HEIGHT pixel box below.
A0, A1, A2, A3, A4 = 0.8707, -0.131979, -0.013791, 0.003971, -0.001529
B0, B1, B2, B3, B4 = 1.007226, 0.015085, -0.044475, 0.028874, -0.005916


def project_raw(lon, lat):
    lam = math.radians(lon)
    phi = math.radians(lat)
    phi2 = phi * phi
    x = lam * (A0 + phi2 * (A1 + phi2 * (A2 + phi2 * phi2 * phi2 * (A3 + phi2 * A4))))
    y = phi * (B0 + phi2 * (B1 + phi2 * phi2 * (B2 + phi2 * B3 + phi2 * phi2 * B4)))
    return x, y


# Bounding box of the raw projection over our actual lon/lat range (full
# longitude, latitude clipped to [LAT_BOTTOM, LAT_TOP]) — used to scale into
# a WIDTH x HEIGHT pixel box with (0,0) at the top-left, matching the old
# equirectangular box's conventions so WorldMap.qml needs no changes beyond
# reading WIDTH/HEIGHT.
_X_MIN, _ = project_raw(-180, 0)
_X_MAX, _ = project_raw(180, 0)
_, _Y_MIN = project_raw(0, LAT_BOTTOM)
_, _Y_MAX = project_raw(0, LAT_TOP)
WIDTH = 360.0
SCALE = WIDTH / (_X_MAX - _X_MIN)
HEIGHT = (_Y_MAX - _Y_MIN) * SCALE


def project(lon, lat):
    lat = max(LAT_BOTTOM, min(LAT_TOP, lat))
    x, y = project_raw(lon, lat)
    return (x - _X_MIN) * SCALE, (_Y_MAX - y) * SCALE


def ring_to_path(ring):
    parts = []
    for i, (lon, lat) in enumerate(ring):
        x, y = project(lon, lat)
        cmd = "M" if i == 0 else "L"
        parts.append(f"{cmd}{x:.2f} {y:.2f}")
    parts.append("Z")
    return "".join(parts)


# Antarctica-only filter: no other landmass in ne_110m_land.geojson extends
# below -60°, so a feature entirely south of that is Antarctica. Left out —
# it's a large, complex-coastlined shape at the very bottom of the panel's
# small map, mostly just adding rendering noise, not recognizable detail.
ANTARCTICA_LAT_CUTOFF = -60


def feature_max_lat(geom):
    polys = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]
    max_lat = -90.0
    for poly in polys:
        for ring in poly:
            for lon, lat in ring:
                if lat > max_lat:
                    max_lat = lat
    return max_lat


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        data = json.load(f)

    path_parts = []
    for feature in data["features"]:
        geom = feature["geometry"]
        if feature_max_lat(geom) < ANTARCTICA_LAT_CUTOFF:
            continue
        polys = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]
        for poly in polys:
            for ring in poly:
                path_parts.append(ring_to_path(ring))

    path = "".join(path_parts)

    print(f"""// World land outline for the panel mini-map.
// Source: Natural Earth 1:110m land, https://www.naturalearthdata.com/
// (public domain), via https://github.com/nvkelso/natural-earth-vector,
// projected with the Natural Earth pseudo-cylindrical projection (curved
// meridians/parallels — see project() below for the polynomial) into a
// {WIDTH:.4f}x{HEIGHT:.4f} box, latitude clipped to [{LAT_BOTTOM}, {LAT_TOP}].
// Generated once by scripts/generate-world-map.py; the plugin never fetches
// this at runtime.
.pragma library
var WIDTH = {WIDTH:.4f}
var HEIGHT = {HEIGHT:.4f}
var LAT_TOP = {LAT_TOP}
var LAT_BOTTOM = {LAT_BOTTOM}
var PATH = "{path}"

// Natural Earth projection (Šavrič et al. / Tom Patterson's polynomial fit —
// same one the design mockup used via d3.geoNaturalEarth1()). lon/lat in
// degrees; returns [x, y] in this file's WIDTH x HEIGHT pixel box, (0,0) at
// the top-left, y growing downward — same contract the old flat
// equirectangular project() had, so callers don't need to change.
function project(lon, lat) {{
  var clamped = Math.max(LAT_BOTTOM, Math.min(LAT_TOP, lat))
  var lam = lon * Math.PI / 180
  var phi = clamped * Math.PI / 180
  var phi2 = phi * phi
  var x = lam * ({A0} + phi2 * ({A1} + phi2 * ({A2} + phi2 * phi2 * phi2 * ({A3} + phi2 * {A4}))))
  var y = phi * ({B0} + phi2 * ({B1} + phi2 * phi2 * ({B2} + phi2 * {B3} + phi2 * phi2 * {B4})))
  return [(x - ({_X_MIN})) * {SCALE}, (({_Y_MAX}) - y) * {SCALE}]
}}
""")


if __name__ == "__main__":
    main()
