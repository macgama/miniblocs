"""Musique de la première moitié du XXe siècle (1900-1950) pour MiniBlocs.

Bal musette, swing, tango et nocturne de piano-bar : le jeu les joue dans les
parties qui se passent entre 1895 et 1965 environ (Son.MORCEAUX, époque
« 1920 »). Mêmes outils que musique.py et musique_epoque.py. Ton : réaliste,
avec une touche d'humour (le tramway sonne en plein solo, le tampon du cadastre
ponctue le tango, le gazomètre a sa berceuse).
"""
import numpy as np

from synth import SR, Rng, secs, samples, lp, hp, bp, env_asr, white, midi
import instruments as ins
from musique import Song, SCALES, voicing, bass_note, melody, play, repeat_with
from musique_epoque import violin, upright

_rng = Rng(1920)


def _t(dur, tail):
    return secs(samples(dur + tail))


def banjo(f, dur, vel=0.8):
    """Banjo : attaque claquante, résonance courte et métallique."""
    t = _t(dur, 0.3)
    x = np.zeros_like(t)
    for k in range(1, 10):
        if f * k > SR / 2.3:
            break
        x += np.sin(2 * np.pi * f * k * t) * np.exp(-t * (6 + k * 2.5)) / k ** 0.8
    pick = bp(white(_rng, len(t)), 2000, 8000) * np.exp(-t * 200) * 0.2
    return hp((x + pick) * vel * 0.35, 150)


def muted_trumpet(f, dur, vel=0.8):
    """Trompette bouchée (sourdine « wah ») des orchestres de danse."""
    t = _t(dur, 0.1)
    x = np.zeros_like(t)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t - 0.2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    for k in range(1, 12):
        if f * k > SR / 2.3:
            break
        x += np.sin(ph * k) / k
    x = bp(x, 900, 3200) * 0.8 + lp(x, 900) * 0.2
    return x * env_asr(len(t), 0.02, 0.07) * vel * 0.3


def tram_bell(vel=0.7):
    """« Ding-ding » de la cloche du tramway."""
    out = np.zeros(samples(1.4))
    for at in (0.0, 0.22):
        b = ins.bell(1560.0, 1.0, vel)
        s = samples(at)
        out[s:s + len(b)] += b[: len(out) - s]
    return out


def stamp(vel=0.8):
    """Coup de tampon (le cadastre valide)."""
    n = samples(0.25)
    t = secs(n)
    x = np.sin(2 * np.pi * 85 * t) * np.exp(-t * 30) + bp(white(_rng, n), 300, 2500) * np.exp(-t * 60) * 0.6
    return x * vel


# --- Morceaux ---------------------------------------------------------------------

def swing_du_tramway():
    """Swing en fa : clarinette, trompettes bouchées, piano, contrebasse et balais.
    Le tramway passe en plein milieu du solo et ne s'excuse pas."""
    A = ["F6", "D7", "Gm7", "C7", "F6", "D7", "Gm7", "C7"]
    A2 = ["F6", "F7", "Bb6", "Bdim", "F6", "D7", "Gm7", "C7"]
    B = ["A7", "A7", "D7", "D7", "G7", "G7", "C7", "C7"]
    form = [("intro", ["Gm7", "C7", "F6", "C7"]), ("A", A), ("A2", A2), ("B", B), ("A2", A2),
            ("solo", A), ("solo", A2), ("riff", B), ("A2", A2), ("fin", ["F6", "F6"])]
    song = Song(138, 4, sum(len(c) for _, c in form), seed=1901, swing=0.66)
    rng = song.rng
    root = midi("F0") % 12
    rh = [[(0, 0.5), (0.5, 0.5), (1, 1), (2.5, 1.5)], [(0, 1.5), (1.5, 0.5), (2, 2)],
          [(0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)], [(0, 3)]]
    mot = melody(song, A, [rh[0], rh[1], rh[2], rh[3]] * 2, root, SCALES["major"], 65, 81, 72)
    mot2 = repeat_with(song, mot, A2, root, SCALES["mixo"])
    rhB = [[(0, 1), (1, 1), (2, 2)], [(0, 3)], [(0, 0.5), (0.5, 0.5), (1, 1), (2, 2)], [(0, 3)]] * 2
    mB = melody(song, B, rhB, root, SCALES["mixo"], 64, 81, 73)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            r = bass_note(sym, 34)
            nxt = bass_note(ch[(i + 1) % len(ch)], 34)
            if name == "fin":
                if i == 0:
                    song.note(ins.bass, b, 0, 4, r, 0.8, 0, wet=False)
                    for m in voicing(sym, 57, 72):
                        song.note(upright, b, 0, 6, m, 0.4, -0.2)
                continue
            walk = [r, r + 4 if "m" not in sym else r + 3, r + 7, nxt + (1 if rng.u() < 0.5 else -1)]
            for k, m in enumerate(walk):
                song.note(ins.bass, b, k, 0.95, m, 0.72 if k == 0 else 0.6, 0, wet=False)
            for m in voicing(sym, 56, 70):
                song.note(upright, b, 1, 0.4, m, 0.26, -0.25)
                song.note(upright, b, 3, 0.4, m, 0.24, -0.25)
            for bt in range(4):
                song.hit(ins.brush(0.45 if bt % 2 else 0.3, long=True), b, bt, 0.1)
                song.hit(ins.hat(0.22), b, bt + 0.5, 0.3)
        if name == "A":
            play(song, mot, ins.clarinet, bar, 0.7, 0.15, legato=0.92)
        elif name == "A2":
            play(song, mot2, ins.clarinet, bar, 0.7, 0.15, legato=0.92)
            play(song, mot2, muted_trumpet, bar, 0.35, -0.3, octave=-12, legato=0.8)
        elif name == "B":
            play(song, mB, muted_trumpet, bar, 0.65, -0.2, legato=0.9)
        elif name == "riff":
            for i in range(len(ch)):
                for bt in (0, 1.5, 3):
                    for m in voicing(ch[i], 62, 74):
                        song.note(muted_trumpet, bar + i, bt, 0.4, m, 0.45, -0.2)
        elif name == "solo":
            rhs = [rng.choice([[(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)],
                               [(0.5, 0.5), (1, 1), (2, 0.5), (2.5, 1.5)], [(0, 2), (2, 2)],
                               [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 0.5), (2.5, 0.5), (3, 1)]])
                   for _ in ch]
            solo = melody(song, ch, rhs, root, SCALES["mixo"], 67, 86, 77)
            play(song, solo, ins.clarinet, bar, 0.62, 0.2, legato=0.88)
            if ch == A:
                song.hit(tram_bell(0.6), bar + 4, 0, -0.5, wet=True)
        elif name == "intro":
            for k, m in enumerate(["C5", "D5", "F5", "A5", "G5", "F5", "D5", "C5"]):
                song.note(ins.clarinet, bar + k // 2, (k % 2) * 2, 1.7, midi(m), 0.55, 0.15)
        bar += len(ch)
    # Tout le monde descend : dernier « ding-ding ».
    song.hit(tram_bell(0.7), bar - 1, 2, -0.4, wet=True)
    song.hit(ins.cymbal(0.4, 3.0), bar - 2, 0, 0.3)
    return song.render(0.22, 1.8, target=-18.0)


def bal_musette_du_14_juillet():
    """Valse musette en sol : accordéon qui virevolte, banjo, contrebasse.
    Un pétard du 14 Juillet éclate au mauvais moment."""
    A = ["G", "G", "D7", "D7", "D7", "D7", "G", "G", "G", "G7", "C", "Cm", "G", "D7", "G", "G"]
    B = ["Em", "Em", "B7", "B7", "B7", "B7", "Em", "Em", "Am", "Am", "Em", "Em", "F#7", "B7", "Em", "D7"]
    C = ["C", "C", "G7", "G7", "G7", "G7", "C", "C", "C", "C7", "F", "Fm", "C", "G7", "C", "D7"]
    form = [("intro", ["D7", "D7", "D7", "D7"]), ("A", A), ("B", B), ("A", A), ("C", C), ("A", A), ("fin", ["G", "G"])]
    song = Song(176, 3, sum(len(c) for _, c in form), seed=1902)
    rng = song.rng
    pats = [[(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1)], [(0, 1), (1, 1), (2, 1)],
            [(0, 2), (2, 1)], [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 0.5), (2.5, 0.5)], [(0, 3)]]
    def rhy():
        return [pats[k] for k in (0, 1, 3, 2, 0, 3, 1, 4)] * 2
    mA = melody(song, A, rhy(), 7, SCALES["major"], 67, 88, 74)
    mB = melody(song, B, rhy(), 4, SCALES["harm"], 64, 86, 71)
    mC = melody(song, C, rhy(), 0, SCALES["major"], 67, 88, 72)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            r = bass_note(sym, 38)
            if name == "fin":
                if i == 0:
                    song.note(ins.pizz, b, 0, 2, r, 0.8, 0, wet=False)
                    for m in voicing(sym, 59, 74):
                        song.note(ins.accordion, b, 0, 4, m, 0.4, 0)
                continue
            song.note(ins.pizz, b, 0, 1, r if i % 2 == 0 else r + 7 - (12 if r + 7 > 50 else 0), 0.75, 0, wet=False)
            for beat in (1, 2):
                for m in voicing(sym, 55, 67):
                    song.note(banjo, b, beat, 0.4, m, 0.35, 0.3)
        mel = {"A": mA, "B": mB, "C": mC}.get(name)
        if mel is not None:
            play(song, mel, ins.accordion, bar, 0.62, -0.1, legato=0.9)
            if name == "C":
                play(song, mel, ins.accordion, bar, 0.3, 0.1, octave=-12, legato=0.9)
        elif name == "intro":
            for k in range(12):
                song.note(ins.accordion, bar + k // 3, k % 3, 0.9, midi("D5") + [0, 4, 7, 12][k % 4], 0.5, -0.1)
        if name == "C":
            # Le pétard : caisse claire sèche et woodblock, puis l'accordéon fait semblant de rien.
            song.hit(ins.snare(0.9), bar + 7, 2.5, 0.6, g=1.2)
            song.hit(ins.woodblock(1400, 0.8), bar + 7, 2.6, 0.6)
        bar += len(ch)
    return song.render(0.24, 1.7, target=-18.0)


def tango_du_cadastre():
    """Tango en ré mineur : bandonéon (accordéon), violon, piano.
    Chaque phrase se termine sur un coup de tampon du cadastre."""
    A = ["Dm", "Dm", "A7", "A7", "A7", "A7", "Dm", "Dm", "Gm", "Gm", "Dm", "Dm", "E7", "A7", "Dm", "A7"]
    B = ["F", "F", "C7", "C7", "C7", "C7", "F", "F", "Bb", "Bb", "F", "D7", "Gm", "A7", "Dm", "A7"]
    form = [("intro", ["A7", "A7"]), ("A", A), ("B", B), ("A", A), ("fin", ["Dm", "Dm"])]
    song = Song(118, 4, sum(len(c) for _, c in form), seed=1903)
    pats = [[(0, 1.5), (1.5, 0.5), (2, 1), (3, 1)], [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 2)],
            [(0, 3), (3, 1)], [(0, 4)]]
    rh = [pats[k] for k in (0, 1, 0, 3, 1, 0, 2, 3)] * 2
    mA = melody(song, A, rh, 2, SCALES["harm"], 62, 84, 69)
    mB = melody(song, B, rh, 5, SCALES["major"], 65, 86, 72)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            r = bass_note(sym, 38)
            if name == "fin":
                if i == 0:
                    for bt in (0, 0.75, 1.5):
                        song.note(ins.pizz, b, bt, 0.5, r, 0.8, 0, wet=False)
                    for m in voicing(sym, 57, 72):
                        song.note(ins.piano, b, 0, 1.5, m, 0.5, -0.2)
                    song.hit(stamp(0.9), b, 2, 0.0)
                continue
            # Rythme de tango : 3-3-2 (habanera marquée).
            for bt in (0, 1.5, 3):
                song.note(ins.pizz, b, bt, 0.6, r if bt != 1.5 else r + 7 - (12 if r + 7 > 50 else 0), 0.75, 0, wet=False)
                for m in voicing(sym, 55, 67):
                    song.note(ins.piano, b, bt, 0.35, m, 0.3, -0.25)
            if i % 4 == 3:
                song.hit(stamp(0.7), b, 3.5, 0.2)
        if name == "A":
            play(song, mA, ins.accordion, bar, 0.62, -0.1, legato=0.75)
            play(song, mA[len(mA) // 2:], violin, bar, 0.4, 0.2, octave=12, legato=0.95)
        elif name == "B":
            play(song, mB, violin, bar, 0.6, 0.15, legato=0.95)
        elif name == "intro":
            for k, m in enumerate(["A4", "Bb4", "C#5", "E5", "G5", "E5", "C#5", "A4"]):
                song.note(ins.accordion, bar + k // 4, k % 4, 0.8, midi(m), 0.5, -0.1)
        bar += len(ch)
    return song.render(0.24, 1.8, target=-18.0)


def clair_de_lune_sur_le_gazometre():
    """Nocturne de piano-bar : piano, clarinette douce, contrebasse et balais.
    Le gazomètre veille sur le quartier endormi."""
    A = ["Ebmaj7", "Cm7", "Fm7", "Bb7", "Ebmaj7", "Ab7", "Gm7", "C7"]
    A2 = ["Fm7", "Bb7", "Gm7", "C7", "Fm7", "Bb7", "Eb6", "Eb6"]
    B = ["Abmaj7", "Abm6", "Gm7", "C7", "Fm7", "Bb7", "Eb6", "Bb7"]
    form = [("intro", ["Fm7", "Bb7"]), ("A", A + A2), ("B", B), ("A", A + A2), ("fin", ["Eb6", "Eb6"])]
    song = Song(70, 4, sum(len(c) for _, c in form), seed=1904, swing=0.62)
    root = midi("Eb0") % 12
    pats = [[(0, 1.5), (1.5, 0.5), (2, 2)], [(0, 3), (3, 1)], [(0.5, 0.5), (1, 1), (2, 1), (3, 1)], [(0, 4)]]
    mA = melody(song, A + A2, [pats[k] for k in (0, 1, 2, 3, 0, 2, 1, 3)] * 2, root, SCALES["major"], 63, 80, 70)
    mB = melody(song, B, [pats[k] for k in (2, 0, 1, 3, 2, 1, 0, 3)], root, SCALES["major"], 63, 82, 72)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            r = bass_note(sym, 34)
            song.note(ins.bass, b, 0, 1.8, r, 0.62, 0, wet=False)
            song.note(ins.bass, b, 2, 1.8, r + 7 if r + 7 <= 46 else r - 5, 0.52, 0, wet=False)
            for m in voicing(sym, 55, 70):
                song.note(ins.piano, b, 0, 1.6, m, 0.24, -0.2)
                song.note(ins.piano, b, 2.5, 1.2, m, 0.18, -0.2)
            if name != "fin":
                for bt in range(4):
                    song.hit(ins.brush(0.25, long=True), b, bt, 0.15)
        if name == "A":
            play(song, mA, ins.piano, bar, 0.5, 0.15, octave=12, legato=1.0)
        elif name == "B":
            play(song, mB, ins.clarinet, bar, 0.5, 0.2, legato=1.0)
        elif name == "intro":
            for k, m in enumerate(["Bb5", "Ab5", "G5", "F5"]):
                song.note(ins.piano, bar + k // 2, (k % 2) * 2, 1.8, midi(m), 0.45, 0.15)
        elif name == "fin":
            for k, m in enumerate(["G5", "Bb5", "Eb6"]):
                song.note(ins.piano, bar, k * 0.6, 6, midi(m), 0.4, 0.1)
        bar += len(ch)
    return song.render(0.3, 2.4, target=-19.0)


# id -> (fonction, titre affiché, humeur)
ALL = {
    "swing_du_tramway": (swing_du_tramway, "Swing du tramway", "jour"),
    "bal_musette_du_14_juillet": (bal_musette_du_14_juillet, "Bal musette du 14 Juillet", "jour"),
    "tango_du_cadastre": (tango_du_cadastre, "Tango du cadastre", "soir"),
    "clair_de_lune_sur_le_gazometre": (clair_de_lune_sur_le_gazometre, "Clair de lune sur le gazomètre", "nuit"),
}
