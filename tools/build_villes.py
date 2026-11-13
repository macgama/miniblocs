#!/usr/bin/env python3
"""Index des villes du monde pour la recherche du globe (assets/villes_monde.tsv.gz).

Source : paquet npm « all-the-cities » (MIT), tiré de GeoNames cities1000
(villes de 1 000 habitants et plus, © GeoNames, CC BY 4.0).
Usage : python3 tools/build_villes.py chemin/vers/cities.pbf
Sortie : une ligne par ville, triée par population décroissante :
    nom \t clé (minuscules sans accents) \t pays (ISO 3166-1) \t région \t population \t latitude \t longitude
"""
import gzip
import sys
import unicodedata


def varint(b, i):
    r = 0
    s = 0
    while True:
        c = b[i]
        i += 1
        r |= (c & 0x7F) << s
        s += 7
        if c < 0x80:
            return r, i


def zigzag(n):
    return (n >> 1) ^ -(n & 1)


def read(path):
    data = open(path, "rb").read()
    i = 0
    lon = 0
    lat = 0
    out = []
    while i < len(data):
        n, i = varint(data, i)
        end = i + n
        c = {}
        while i < end:
            k, i = varint(data, i)
            tag, wt = k >> 3, k & 7
            if wt == 2:
                n, i = varint(data, i)
                c[tag] = data[i:i + n].decode("utf-8")
                i += n
            else:
                v, i = varint(data, i)
                if tag == 9:
                    c[9] = v
                elif tag == 10:
                    lon += zigzag(v)
                elif tag == 11:
                    lat += zigzag(v)
        out.append((c.get(2, ""), c.get(3, ""), c.get(8, ""), c.get(9, 0), lat / 1e5, lon / 1e5))
    return out


def cle(nom):
    """Nom en minuscules sans accents (la recherche ignore les accents)."""
    n = unicodedata.normalize("NFKD", nom.lower())
    n = "".join(ch for ch in n if not unicodedata.combining(ch))
    return n.replace("ß", "ss").replace("ø", "o").replace("æ", "ae").replace("œ", "oe").replace("ł", "l").replace("đ", "d").replace("ı", "i")


def main():
    cities = read(sys.argv[1])
    cities.sort(key=lambda c: -c[3])
    lines = ["%s\t%s\t%s\t%s\t%d\t%.4f\t%.4f" % (n.replace("\t", " "), cle(n), cc, adm, pop, la, lo)
             for n, cc, adm, pop, la, lo in cities if n]
    with gzip.open("assets/villes_monde.tsv.gz", "wt", encoding="utf-8", compresslevel=9) as f:
        f.write("\n".join(lines) + "\n")
    print(len(lines), "villes")


if __name__ == "__main__":
    main()
