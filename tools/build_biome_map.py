#!/usr/bin/env python3
"""Fabrique la carte mondiale des biomes du globe (assets/biomes_monde.png).

Source : ESA WorldCover 2021 v200 (10 m), CC BY 4.0, sur AWS Open Data
(s3://esa-worldcover). Pour chacun des ~2 650 fichiers de 3° × 3°, on ne
télécharge que l'en-tête et le plus petit aperçu (~95 Ko), puis on garde la
classe majoritaire par pixel d'une image équirectangulaire 4096 × 2048
(≈ 10 km par pixel). Les valeurs du PNG sont les codes WorldCover
(0 = pas de donnée / océan, 10 forêt, 20 broussailles, 30 prairie, 40 champs,
50 bâti, 60 sol nu, 70 neige/glace, 80 eau, 90 marais, 95 mangrove, 100 mousses).

Usage : python3 tools/build_biome_map.py [dossier_cache]
Nécessite numpy et Pillow. Durée : quelques minutes (~250 Mo téléchargés).
"""
import concurrent.futures as cf
import os
import re
import struct
import sys
import time
import urllib.parse
import urllib.request
import zlib

import numpy as np
from PIL import Image

BUCKET = "https://esa-worldcover.s3.eu-central-1.amazonaws.com/"
PREFIX = "v200/2021/map/"
W, H = 4096, 2048
CLASSES = [10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 100]
CACHE = sys.argv[1] if len(sys.argv) > 1 else "/tmp/worldcover_cache"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "biomes_monde.png")
TYPES = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 7: 1, 11: 4, 12: 8, 16: 8}


def list_keys():
    keys, token = [], None
    while True:
        url = BUCKET + "?list-type=2&max-keys=1000&prefix=" + PREFIX
        if token:
            url += "&continuation-token=" + urllib.parse.quote(token)
        x = urllib.request.urlopen(url).read().decode()
        keys += re.findall(r"<Key>([^<]+_Map\.tif)</Key>", x)
        m = re.search(r"<NextContinuationToken>([^<]+)</NextContinuationToken>", x)
        if not m:
            return keys
        token = m.group(1)


def fetch(key, start, end):
    req = urllib.request.Request(BUCKET + key, headers={"Range": f"bytes={start}-{end}"})
    for attempt in range(5):
        try:
            return urllib.request.urlopen(req, timeout=60).read()
        except OSError:
            if attempt == 4:
                raise
            time.sleep(2 ** attempt)


def ifds(data):
    off = struct.unpack("<I", data[4:8])[0]
    while off:
        n = struct.unpack("<H", data[off:off + 2])[0]
        tags = {}
        for i in range(n):
            e = data[off + 2 + 12 * i: off + 14 + 12 * i]
            tag, typ, cnt = struct.unpack("<HHI", e[:8])
            size = TYPES.get(typ, 1) * cnt
            raw = e[8:8 + size] if size <= 4 else data[struct.unpack("<I", e[8:12])[0]:][:size]
            fmt = {3: "H", 4: "I", 12: "d"}.get(typ)
            tags[tag] = struct.unpack("<" + fmt * cnt, raw) if fmt else raw
        yield tags
        off = struct.unpack("<I", data[off + 2 + 12 * n: off + 6 + 12 * n])[0]


def overview(key):
    path = os.path.join(CACHE, os.path.basename(key) + ".head")
    if os.path.exists(path):
        data = open(path, "rb").read()
    else:
        data = fetch(key, 0, 98303)
        open(path, "wb").write(data)
    levels = list(ifds(data))
    tie = levels[0][33922]  # (i, j, k, lon, lat, z) du coin haut-gauche
    last = levels[-1]
    w, h = last[256][0], last[257][0]
    tw, th = last[322][0], last[323][0]
    offs, cnts = last[324], last[325]
    if len(offs) != 1 or tw < w or th < h:
        raise RuntimeError("aperçu inattendu pour " + key)
    end = offs[0] + cnts[0]
    if end > len(data):
        data = data + fetch(key, len(data), end - 1)
        open(path, "wb").write(data)
    tile = np.frombuffer(zlib.decompress(data[offs[0]:end]), np.uint8).reshape(th, tw)[:h, :w]
    return tie[3], tie[4], tile


def main():
    os.makedirs(CACHE, exist_ok=True)
    keys = list_keys()
    print(len(keys), "fichiers WorldCover")
    counts = np.zeros((len(CLASSES), H, W), np.uint32)
    lut = np.full(256, -1, np.int16)
    for i, c in enumerate(CLASSES):
        lut[c] = i
    done = 0
    with cf.ThreadPoolExecutor(16) as ex:
        for lon0, lat0, tile in ex.map(overview, keys):
            n = tile.shape[0]
            # Pixels de l'aperçu -> pixels de la carte mondiale.
            lats = lat0 - (np.arange(n) + 0.5) * 3.0 / n
            lons = lon0 + (np.arange(n) + 0.5) * 3.0 / n
            ys = np.clip(((90.0 - lats) / 180.0 * H).astype(int), 0, H - 1)
            xs = np.clip(((lons + 180.0) / 360.0 * W).astype(int), 0, W - 1)
            yy, xx = np.meshgrid(ys, xs, indexing="ij")
            ci = lut[tile]
            ok = ci >= 0
            np.add.at(counts, (ci[ok], yy[ok], xx[ok]), 1)
            done += 1
            if done % 200 == 0:
                print(done, "/", len(keys))
    best = np.argmax(counts, axis=0)
    total = counts.sum(axis=0)
    out = np.where(total > 0, np.array(CLASSES, np.uint8)[best], 0).astype(np.uint8)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(out, "L").save(OUT, optimize=True)
    print("écrit", OUT, os.path.getsize(OUT), "octets")


if __name__ == "__main__":
    main()
