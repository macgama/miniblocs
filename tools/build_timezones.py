"""Fabrique la carte mondiale des fuseaux horaires du jeu.

Source : timezone-boundary-builder (frontières des fuseaux IANA, licence ODbL),
fichier « combined-now.json » (les fuseaux qui ont les mêmes règles aujourd'hui
sont regroupés). Téléchargement :
https://github.com/evansiroky/timezone-boundary-builder/releases (timezones-now.geojson.zip)

Sorties :
- assets/fuseaux_monde.png : 3600 × 1800 pixels (0,1° par pixel), niveau de gris =
  numéro du fuseau (0 = mer, hors fuseau).
- assets/fuseaux.json : pour chaque fuseau, son nom IANA et ses changements
  d'heure de 2000 à 2055 (heure d'été comprise), calculés avec la base IANA de
  Python (zoneinfo).

Usage : python3 tools/build_timezones.py combined-now.json
"""
import json
import sys
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from PIL import Image, ImageChops, ImageDraw

W, H = 3600, 1800
START = datetime(2000, 1, 1, tzinfo=timezone.utc)
END = datetime(2056, 1, 1, tzinfo=timezone.utc)


def px(lon, lat):
    return ((lon + 180.0) / 360.0 * W, (90.0 - lat) / 180.0 * H)


def polygons(geom):
    if geom["type"] == "Polygon":
        return [geom["coordinates"]]
    if geom["type"] == "MultiPolygon":
        return geom["coordinates"]
    return []


def offset(tz, t):
    return int(t.astimezone(tz).utcoffset().total_seconds())


def transitions(name):
    tz = ZoneInfo(name)
    out = [[int(START.timestamp()), offset(tz, START)]]
    t = START
    day = timedelta(days=1)
    while t < END:
        n = t + day
        if offset(tz, n) != offset(tz, t):
            a, b = t, n
            while (b - a) > timedelta(minutes=1):
                m = a + (b - a) / 2
                if offset(tz, m) == offset(tz, a):
                    a = m
                else:
                    b = m
            b = b.replace(second=0, microsecond=0)
            out.append([int(b.timestamp()), offset(tz, n)])
        t = n
    return out


def main(path):
    data = json.load(open(path))
    feats = sorted(data["features"], key=lambda f: f["properties"]["tzid"])
    assert len(feats) < 256
    img = Image.new("L", (W, H), 0)
    zones = []
    for i, f in enumerate(feats, start=1):
        name = f["properties"]["tzid"]
        mask = Image.new("1", (W, H), 0)
        draw = ImageDraw.Draw(mask)
        for poly in polygons(f["geometry"]):
            outer = [px(x, y) for x, y in poly[0]]
            if len(outer) > 2:
                draw.polygon(outer, fill=1, outline=1)
        for poly in polygons(f["geometry"]):
            for hole in poly[1:]:
                pts = [px(x, y) for x, y in hole]
                if len(pts) > 2:
                    draw.polygon(pts, fill=0)
        img.paste(i, mask=mask)
        zones.append({"id": name, "t": transitions(name)})
        print(i, name, len(zones[-1]["t"]))
    img.save("assets/fuseaux_monde.png", optimize=True)
    json.dump({"source": "timezone-boundary-builder (ODbL) + IANA tzdata",
               "res": 0.1, "zones": zones}, open("assets/fuseaux.json", "w"), separators=(",", ":"))


if __name__ == "__main__":
    main(sys.argv[1])
