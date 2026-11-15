"""Musique d'époque (XIXe siècle) pour les parties historiques de MiniBlocs.

Mêmes outils que musique.py (séquenceur, grilles, mélodies générées), avec des
instruments d'avant l'électricité : violon, violoncelle, flûte, clavecin, orgue
de barbarie, piano droit, fanfare. Le jeu les joue tant que la partie se passe
avant 1920 environ (Son.MORCEAUX, champ « époque »).
"""
import numpy as np

from synth import SR, Rng, secs, samples, lp, hp, bp, env_asr, fade, white, midi
import instruments as ins
from musique import Song, SCALES, chord, voicing, bass_note, melody, play

_rng = Rng(4321)


def _t(dur, tail):
    return secs(samples(dur + tail))


# --- Instruments d'époque ----------------------------------------------------------

def violin(f, dur, vel=0.8):
    """Violon : dent de scie adoucie, vibrato qui s'installe, caisse (formants)."""
    t = _t(dur, 0.15)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.12) * 4, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.zeros_like(t)
    for k in range(1, 14):
        if f * k > SR / 2.3:
            break
        x += (1.0 / k) * np.sin(ph * k) * (1.0 if k % 2 else 0.85)
    bow = bp(white(_rng, len(t)), f * 1.5, min(f * 8, 9000)) * 0.04
    body = bp(x, 400, 3200) * 0.7 + bp(x, 2400, 4200) * 0.35 + lp(x, 350) * 0.3
    e = env_asr(len(t), 0.06, 0.12)
    return fade((body + bow) * e * vel * 0.32, 0.004, 0.05)


def cello(f, dur, vel=0.8):
    """Violoncelle : comme le violon, plus sombre."""
    t = _t(dur, 0.2)
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.15) * 3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.zeros_like(t)
    for k in range(1, 12):
        if f * k > SR / 2.3:
            break
        x += (1.0 / k) * np.sin(ph * k)
    e = env_asr(len(t), 0.07, 0.15)
    return lp(bp(x, 80, 2200) * e * vel * 0.45, 2600)


def flute(f, dur, vel=0.8):
    """Flûte traversière : presque une sinusoïde, souffle et vibrato léger."""
    t = _t(dur, 0.1)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.2) * 3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    breath = bp(white(_rng, len(t)), f * 0.8, f * 3) * 0.05
    e = env_asr(len(t), 0.04, 0.08)
    return (x + breath) * e * vel * 0.4


def harpsichord(f, dur, vel=0.8):
    """Clavecin : corde pincée par un bec, brillante et vite éteinte (Karplus-Strong)."""
    n = samples(min(dur, 1.2) + 0.6)
    period = max(2, int(SR / f))
    buf = _rng.g.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        j = i % period
        out[i] = buf[j]
        buf[j] = 0.5 * (buf[j] + buf[(j + 1) % period]) * 0.997
    out = hp(out, f * 0.7)
    twang = np.sin(2 * np.pi * f * 2 * secs(n)) * np.exp(-secs(n) * 9) * 0.25
    return fade((out + twang) * vel * 0.35, 0.001, 0.05)


def organ(f, dur, vel=0.8):
    """Orgue de barbarie : tuyaux (fondamentale, octave, quinte), tremblement de la
    manivelle et un peu de désaccord."""
    t = _t(dur, 0.05)
    crank = 1 + 0.003 * np.sin(2 * np.pi * 1.6 * t)
    ph = 2 * np.pi * np.cumsum(f * crank * 1.002) / SR
    x = np.sin(ph) + 0.55 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph) + 0.15 * np.sin(4 * ph) + 0.08 * np.sin(6 * ph)
    reed = np.sign(np.sin(ph)) * 0.06
    trem = 1 + 0.08 * np.sin(2 * np.pi * 6.5 * t)
    e = env_asr(len(t), 0.015, 0.04)
    return lp((x + reed) * trem * e * vel * 0.22, 5000)


def upright(f, dur, vel=0.8):
    """Piano droit de saloon : désaccordé, un peu métallique."""
    a = ins.piano(f, dur, vel)
    b = ins.piano(f * 1.006, dur, vel * 0.7)
    n = min(len(a), len(b))
    x = a[:n] + b[:n]
    return hp(x, 90) * 0.75


def snare_roll(vel=0.6, beats=1.0, spb=0.5):
    """Roulement de caisse claire (fanfare)."""
    n = samples(beats * spb + 0.1)
    out = np.zeros(n)
    step = samples(0.045)
    for i in range(0, n - step, step):
        s = ins.snare(vel * (0.5 + 0.5 * (i / n)))[: step * 3]
        out[i: i + len(s)] += s[: n - i] * 0.6
    return out


def hoof(vel=0.6):
    """Sabot de cheval sur les pavés (percussion des danses de diligence)."""
    t = secs(samples(0.12))
    x = bp(white(_rng, len(t)), 700, 2600) * np.exp(-t * 70) + np.sin(2 * np.pi * 380 * t) * np.exp(-t * 55) * 0.6
    return x * vel


# --- Morceaux ------------------------------------------------------------------------

def menuet_de_la_place():
    """Menuet à trois temps : clavecin, violon et violoncelle, comme un bal de sous-préfecture."""
    A = ["D", "A7", "D", "G", "D", "A7", "D", "D"]
    B = ["A", "E7", "A", "A", "D", "G", "A7", "D"]
    form = [("intro", ["D", "A7", "D", "A7"]), ("A", A), ("A", A), ("B", B), ("A", A), ("B", B), ("fin", ["D", "D"])]
    song = Song(112, 3, sum(len(c) for _, c in form), seed=301)
    pats = [[(0, 1), (1, 1), (2, 1)], [(0, 2), (2, 1)], [(0, 0.5), (0.5, 0.5), (1, 1), (2, 1)], [(0, 3)]]
    rhA = [pats[0], pats[2], pats[1], pats[2], pats[0], pats[2], pats[1], pats[3]]
    mA = melody(song, A, rhA, 2, SCALES["major"], 69, 86, 74)
    rhB = [pats[2], pats[1], pats[0], pats[3], pats[2], pats[0], pats[2], pats[3]]
    mB = melody(song, B, rhB, 2, SCALES["major"], 69, 88, 76)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            song.note(cello, b, 0, 2.6, bass_note(sym, 38), 0.6, -0.2)
            v = voicing(sym, 62, 76)
            for beat in (1, 2):
                for k, m in enumerate(v):
                    song.note(harpsichord, b, beat + k * 0.04, 0.8, m, 0.35, 0.25)
        if name == "A":
            play(song, mA, violin, bar, 0.62, -0.1, legato=0.95)
        elif name == "B":
            play(song, mB, violin, bar, 0.62, -0.1, legato=0.95)
            play(song, mB, flute, bar, 0.28, 0.3, octave=12, legato=0.9)
        elif name == "fin":
            song.note(violin, bar, 0, 3, midi("D5"), 0.6, -0.1)
            for m in voicing("D", 62, 78):
                song.note(harpsichord, bar, 0, 2, m, 0.4, 0.25)
            song.note(cello, bar, 0, 4, midi("D2"), 0.6, -0.2)
        bar += len(ch)
    return song.render(0.3, 2.0, target=-18.0)


def quadrille_des_diligences():
    """Quadrille au galop : violon et flûte, pizzicati, et les sabots des chevaux en rythme."""
    A = ["G", "G", "D7", "G", "G", "C", "D7", "G"]
    B = ["Em", "Am", "D7", "G", "C", "G", "D7", "G"]
    form = [("intro", ["D7", "D7"]), ("A", A), ("A", A), ("B", B), ("A", A), ("B", B), ("A", A), ("fin", ["G"])]
    song = Song(132, 4, sum(len(c) for _, c in form), seed=302)
    pats = [[(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)], [(0, 1), (1, 0.5), (1.5, 0.5), (2, 2)],
            [(0, 0.5), (0.5, 0.5), (1, 1), (2, 0.5), (2.5, 0.5), (3, 1)], [(0, 3)]]
    rhA = [pats[0], pats[1], pats[2], pats[1], pats[0], pats[2], pats[0], pats[3]]
    mA = melody(song, A, rhA, 7, SCALES["major"], 67, 88, 74)
    rhB = [pats[1], pats[2], pats[0], pats[3], pats[2], pats[1], pats[0], pats[3]]
    mB = melody(song, B, rhB, 7, SCALES["major"], 67, 86, 71)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            r = bass_note(sym, 38)
            for beat in (0, 2):
                song.note(ins.pizz, b, beat, 0.8, r if beat == 0 else (r + 7 if r + 7 <= 52 else r - 5), 0.8, 0.0, wet=False)
            for beat in (1, 3):
                for m in voicing(sym, 59, 71):
                    song.note(ins.pizz, b, beat, 0.4, m, 0.35, -0.3)
            if name not in ("intro", "fin"):
                # Ta-ga-dac, ta-ga-dac : le galop.
                for beat in range(4):
                    song.hit(hoof(0.45), b, beat, 0.4)
                    song.hit(hoof(0.3), b, beat + 0.25, 0.45)
                    song.hit(hoof(0.35), b, beat + 0.5, 0.35)
        if name == "A":
            play(song, mA, violin, bar, 0.6, -0.15, legato=0.85)
        elif name == "B":
            play(song, mB, flute, bar, 0.62, 0.2, octave=12, legato=0.85)
            play(song, mB, violin, bar, 0.35, -0.15, legato=0.85)
        elif name == "intro":
            for k in range(8):
                song.hit(hoof(0.5), bar + k // 4, (k % 4), 0.3)
        elif name == "fin":
            song.note(violin, bar, 0, 1, midi("G5"), 0.7, -0.1)
            song.note(flute, bar, 0, 1, midi("D6"), 0.5, 0.2)
            song.note(ins.pizz, bar, 0, 1, midi("G2"), 0.9, 0.0)
            song.hit(ins.cymbal(0.3, 1.5), bar, 1, 0.0)
        bar += len(ch)
    return song.render(0.24, 1.6, target=-18.0)


def orgue_de_barbarie():
    """Valse tournée à la manivelle sur la place, le dimanche : orgue de barbarie seul."""
    A = ["C", "C", "G7", "G7", "G7", "G7", "C", "C"]
    A2 = ["C", "C", "G7", "G7", "G7", "G7", "C", "C7"]
    B = ["F", "F", "C", "C", "D7", "D7", "G7", "G7"]
    form = [("intro", ["G7", "G7"]), ("A", A + A2), ("B", B + A2), ("A", A + A2), ("B", B + A2), ("fin", ["C", "C"])]
    song = Song(150, 3, sum(len(c) for _, c in form), seed=303)
    pats = [[(0, 2), (2, 1)], [(0, 1), (1, 1), (2, 1)], [(0, 0.5), (0.5, 0.5), (1, 1), (2, 1)], [(0, 3)]]
    rhA = [pats[0], pats[2], pats[1], pats[3], pats[2], pats[1], pats[0], pats[3]] * 2
    mA = melody(song, A + A2, rhA, 0, SCALES["major"], 67, 84, 76)
    rhB = [pats[1], pats[0], pats[2], pats[3], pats[1], pats[2], pats[0], pats[3]] * 2
    mB = melody(song, B + A2, rhB, 0, SCALES["major"], 67, 84, 72)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            song.note(organ, b, 0, 0.9, bass_note(sym, 36), 0.7, 0.0, wet=False)
            for beat in (1, 2):
                for m in voicing(sym, 55, 67):
                    song.note(organ, b, beat, 0.5, m, 0.32, 0.0, wet=False)
        if name == "A":
            play(song, mA, organ, bar, 0.7, 0.0, wet=False, legato=0.9)
            play(song, mA, organ, bar, 0.3, 0.0, wet=False, octave=12, legato=0.9)
        elif name == "B":
            play(song, mB, organ, bar, 0.7, 0.0, wet=False, legato=0.9)
            play(song, mB, ins.glock, bar, 0.22, 0.0, octave=12)
        elif name == "fin":
            for m in voicing("C", 60, 79):
                song.note(organ, bar, 0, 2.6, m, 0.5, 0.0, wet=False)
            song.note(organ, bar, 0, 2.6, midi("C2"), 0.7, 0.0, wet=False)
        bar += len(ch)
    return song.render(0.12, 1.2, dry_room=0.18, target=-19.0)


def fanfare_de_la_gare():
    """Marche de la fanfare municipale pour l'inauguration de la gare (on attend le préfet)."""
    A = ["Bb", "Bb", "F7", "Bb", "Bb", "Eb", "F7", "Bb"]
    B = ["Eb", "Eb", "Bb", "Bb", "C7", "C7", "F7", "F7"]
    form = [("intro", ["F7", "F7"]), ("A", A), ("A", A), ("B", B), ("A", A), ("trio", B), ("A", A), ("fin", ["Bb", "Bb"])]
    song = Song(116, 4, sum(len(c) for _, c in form), seed=304)
    pats = [[(0, 1.5), (1.5, 0.5), (2, 1), (3, 1)], [(0, 1), (1, 1), (2, 2)], [(0, 0.75), (0.75, 0.25), (1, 1), (2, 0.75), (2.75, 0.25), (3, 1)], [(0, 4)]]
    rhA = [pats[0], pats[1], pats[2], pats[3], pats[0], pats[2], pats[1], pats[3]]
    mA = melody(song, A, rhA, 10, SCALES["major"], 65, 82, 70)
    rhB = [pats[1], pats[2], pats[0], pats[3], pats[2], pats[1], pats[0], pats[3]]
    mB = melody(song, B, rhB, 10, SCALES["major"], 63, 80, 70)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            r = bass_note(sym, 34)
            song.note(ins.tuba, b, 0, 0.9, r, 0.85, 0.0, wet=False)
            song.note(ins.tuba, b, 2, 0.9, r + 7 if r + 7 < 48 else r - 5, 0.75, 0.0, wet=False)
            for beat in (1, 3):
                for m in voicing(sym, 58, 70):
                    song.note(ins.brass, b, beat, 0.45, m, 0.25, -0.25)
            if name != "fin":
                song.hit(ins.kick(0.5), b, 0)
                song.hit(ins.kick(0.4), b, 2)
                song.hit(ins.snare(0.45), b, 1, 0.1)
                song.hit(ins.snare(0.45), b, 3, 0.1)
                if i % 2 == 1:
                    song.hit(ins.snare(0.3), b, 3.5, 0.1)
                if i == 0:
                    song.hit(ins.cymbal(0.35, 1.6), b, 0, 0.2)
        if name == "A":
            play(song, mA, ins.brass, bar, 0.62, 0.1, legato=0.9)
            play(song, mA, ins.clarinet, bar, 0.3, 0.3, octave=12, legato=0.9)
        elif name == "B":
            play(song, mB, ins.clarinet, bar, 0.6, 0.25, octave=12, legato=0.9)
        elif name == "trio":
            play(song, mB, flute, bar, 0.55, 0.3, octave=12, legato=0.85)
            play(song, mB, ins.brass, bar, 0.3, -0.2, octave=-12, legato=0.9)
        elif name == "intro":
            song.hit(snare_roll(0.6, 7.5, song.spb), bar, 0, 0.1)
        elif name == "fin":
            for m in voicing("Bb", 58, 74):
                song.note(ins.brass, bar, 0, 3.5, m, 0.55, 0.0)
            song.note(ins.tuba, bar, 0, 3.5, midi("Bb1"), 0.9, 0.0)
            song.hit(ins.cymbal(0.5, 2.5), bar, 0, 0.0)
            song.hit(ins.kick(0.7), bar, 0)
        bar += len(ch)
    return song.render(0.24, 1.8, target=-18.0)


def nocturne_a_la_bougie():
    """Nocturne au piano, la nuit, à la lueur de la bougie (avant l'électricité)."""
    prog = ["Ebmaj7", "Cm7", "Fm7", "Bb7", "Ebmaj7", "Abmaj7", "Fm7", "Bb7",
            "Gm7", "Cm7", "Fm7", "Bb7", "Abmaj7", "Bb7", "Eb", "Eb"]
    form = prog * 2 + ["Eb", "Eb"]
    song = Song(66, 4, len(form), seed=305)
    rng = song.rng
    rh = [[(0, 1.5), (1.5, 0.5), (2, 2)], [(0, 3), (3, 1)], [(0, 1), (1, 1), (2, 1), (3, 1)], [(0, 4)]] * 4
    m1 = melody(song, prog, rh, 3, SCALES["major"], 70, 87, 79)
    for b, sym in enumerate(form):
        r = bass_note(sym, 36)
        # Main gauche en arpèges larges (basse, quinte, dixième).
        arp = [r, r + 7, r + 12 + (chord(sym)[1][1] if len(chord(sym)[1]) > 1 else 4), r + 19]
        for e in range(8):
            song.note(ins.piano, b, e * 0.5, 1.4, arp[[0, 1, 2, 3, 2, 1, 2, 1][e]], 0.32 if e else 0.45, -0.2)
    play(song, m1, ins.piano, 0, 0.55, 0.2, legato=1.1)
    second = [(i + len(prog), bb, d, m + (12 if rng.u() < 0.3 else 0)) for (i, bb, d, m) in m1]
    play(song, second, ins.piano, 0, 0.45, 0.25, legato=1.1)
    end = len(form) - 2
    for m in voicing("Eb", 63, 79):
        song.note(ins.piano, end, 0, 6, m, 0.4, 0.1)
    song.note(ins.piano, end, 0, 6, midi("Eb2"), 0.5, -0.2)
    return song.render(0.36, 3.0, target=-21.0)


def ragtime_du_saloon():
    """Ragtime au piano droit désaccordé : la basse fait oum-pa, la main droite trébuche."""
    A = ["C", "C", "G7", "G7", "G7", "G7", "C", "C"]
    A2 = ["C", "C7", "F", "Fm", "C", "A7", "D7", "G7"]
    B = ["F", "F", "C", "C", "D7", "D7", "G7", "G7"]
    form = [("intro", ["G7", "G7"]), ("A", A + A2), ("B", B + A2), ("A", A + A2), ("fin", ["C", "C"])]
    song = Song(92, 4, sum(len(c) for _, c in form), seed=306)
    rng = song.rng
    sync = [[(0, 0.5), (0.5, 1.0), (1.5, 0.5), (2, 0.5), (2.5, 1.0), (3.5, 0.5)],
            [(0, 0.75), (0.75, 0.75), (1.5, 0.5), (2, 1), (3, 1)],
            [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 1.0), (2.5, 1.5)], [(0, 2), (2, 2)]]
    rhA = [sync[0], sync[1], sync[0], sync[3], sync[2], sync[1], sync[0], sync[3]] * 2
    mA = melody(song, A + A2, rhA, 0, SCALES["major"], 72, 91, 79)
    rhB = [sync[1], sync[2], sync[0], sync[3], sync[0], sync[1], sync[2], sync[3]] * 2
    mB = melody(song, B + A2, rhB, 0, SCALES["major"], 72, 91, 77)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            r = bass_note(sym, 36)
            for beat in range(4):
                if beat % 2 == 0:
                    song.note(upright, b, beat, 0.6, r if beat == 0 else (r + 7 if r + 7 <= 50 else r - 5), 0.6, -0.2)
                else:
                    for m in voicing(sym, 55, 67):
                        song.note(upright, b, beat, 0.4, m, 0.32, -0.15)
        if name == "A":
            play(song, mA, upright, bar, 0.6, 0.2, legato=0.85)
            play(song, mA, upright, bar, 0.3, 0.2, octave=-12, legato=0.85)
        elif name == "B":
            play(song, mB, upright, bar, 0.6, 0.2, legato=0.85)
            play(song, [(i, bb + 0.02, d, m - 3) for (i, bb, d, m) in mB if rng.u() < 0.4 and (m - 3) % 12 in (3, 10, 8)],
                 upright, bar, 0.25, 0.25, legato=0.5)
        elif name == "intro":
            for k, m in enumerate([67, 71, 74, 77, 79, 77, 74, 71]):
                song.note(upright, bar + k // 4, (k % 4), 0.8, m, 0.5, 0.2)
        elif name == "fin":
            for m in voicing("C", 64, 84):
                song.note(upright, bar, 0.5, 3, m, 0.55, 0.2)
            song.note(upright, bar, 0.5, 3, midi("C2"), 0.6, -0.2)
        bar += len(ch)
    return song.render(0.18, 1.4, target=-18.0)


def complainte_du_canal():
    """Valse lente en mineur, accordéon et violon, le long du chemin de halage au soir."""
    A = ["Am", "Am", "E7", "E7", "E7", "E7", "Am", "Am"]
    B = ["Dm", "Dm", "Am", "Am", "B7", "B7", "E7", "E7"]
    form = [("intro", ["Am", "E7", "Am", "E7"]), ("A", A + A), ("B", B + A), ("A", A + A), ("fin", ["Am", "Am"])]
    song = Song(96, 3, sum(len(c) for _, c in form), seed=307)
    pats = [[(0, 2), (2, 1)], [(0, 3)], [(0, 1), (1, 1), (2, 1)], [(0, 1.5), (1.5, 0.5), (2, 1)]]
    rhA = [pats[0], pats[3], pats[2], pats[1], pats[0], pats[2], pats[3], pats[1]] * 2
    mA = melody(song, A + A, rhA, 9, SCALES["harm"], 64, 81, 72)
    rhB = [pats[2], pats[0], pats[3], pats[1], pats[2], pats[3], pats[0], pats[1]] * 2
    mB = melody(song, B + A, rhB, 9, SCALES["harm"], 64, 83, 74)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            song.note(ins.pizz, b, 0, 1, bass_note(sym, 38), 0.7, 0.0, wet=False)
            for beat in (1, 2):
                for m in voicing(sym, 57, 69):
                    song.note(ins.accordion, b, beat, 0.6, m, 0.17, -0.3)
        if name == "A":
            play(song, mA, ins.accordion, bar, 0.62, 0.15, legato=0.95)
        elif name == "B":
            play(song, mB, violin, bar, 0.6, -0.15, legato=1.0)
        elif name == "intro":
            for k, m in enumerate([69, 72, 76, 75]):
                song.note(violin, bar + k, 0, 2.6, m, 0.5, -0.15)
        elif name == "fin":
            song.note(violin, bar, 0, 5, midi("A4"), 0.55, -0.15)
            for m in voicing("Am", 57, 72):
                song.note(ins.accordion, bar, 0, 5, m, 0.35, 0.15)
        bar += len(ch)
    return song.render(0.32, 2.4, target=-19.0)


# id -> (fonction, titre affiché, humeur)
ALL = {
    "menuet_de_la_place": (menuet_de_la_place, "Menuet de la place du marché", "jour"),
    "quadrille_des_diligences": (quadrille_des_diligences, "Quadrille des diligences", "jour"),
    "orgue_de_barbarie": (orgue_de_barbarie, "L'orgue de barbarie du dimanche", "jour"),
    "fanfare_de_la_gare": (fanfare_de_la_gare, "Fanfare pour l'inauguration de la gare", "jour"),
    "ragtime_du_saloon": (ragtime_du_saloon, "Ragtime du saloon", "soir"),
    "complainte_du_canal": (complainte_du_canal, "Complainte du canal", "soir"),
    "nocturne_a_la_bougie": (nocturne_a_la_bougie, "Nocturne à la bougie", "nuit"),
}
