"""Musique de MiniBlocs : morceaux composés et joués par ce script.

Petit séquenceur : grilles d'accords, basse, accompagnement et mélodies
générées (notes de l'accord sur les temps forts, gamme ailleurs, motifs repris).
Le ton : réaliste, avec une touche d'humour (valse du permis de construire,
blues des nids-de-poule, basson du conseil municipal en retard).
"""
import numpy as np

from synth import SR, Rng, samples, add, pan, reverb, rms_normalize, soft_clip, lp, hp, midi, hz
import instruments as ins
import effets

QUAL = {
    "maj": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
    "m9": [0, 3, 7, 10, 14], "maj9": [0, 4, 7, 11, 14], "6": [0, 4, 7, 9], "sus": [0, 5, 7, 10],
    "dim": [0, 3, 6], "add9": [0, 4, 7, 14], "m6": [0, 3, 7, 9], "9": [0, 4, 7, 10, 14],
}

SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "lydian": [0, 2, 4, 6, 7, 9, 11],
    "blues": [0, 3, 5, 6, 7, 10], "mixo": [0, 2, 4, 5, 7, 9, 10], "harm": [0, 2, 3, 5, 7, 8, 11],
}


def chord(sym):
    """« Fmaj7 », « Bb7 », « C#m » -> (racine en classe de hauteur, intervalles)."""
    root = sym[0]
    rest = sym[1:]
    if rest[:1] in ("#", "b"):
        root += rest[0]
        rest = rest[1:]
    q = rest if rest else "maj"
    return midi(root + "0") % 12, QUAL[q]


def chord_pcs(sym):
    r, iv = chord(sym)
    return sorted({(r + i) % 12 for i in iv})


def voicing(sym, lo=53, hi=66):
    """Accord en position serrée dans [lo, hi] (s'enchaîne bien d'un accord à l'autre)."""
    r, iv = chord(sym)
    notes = []
    for i in iv:
        pc = (r + i) % 12
        m = lo + ((pc - lo) % 12)
        if m > hi:
            m -= 12
        notes.append(m)
    return sorted(set(notes))


def bass_note(sym, lo=36):
    r, _ = chord(sym)
    return lo + ((r - lo) % 12)


class Song:
    def __init__(self, bpm, beats_per_bar, bars, seed=1, swing=0.0):
        self.spb = 60.0 / bpm
        self.bpb = beats_per_bar
        self.bars = bars
        self.swing = swing
        self.rng = Rng(seed)
        n = samples(bars * beats_per_bar * self.spb + 6.0)
        self.wet = np.zeros((2, n))
        self.dry = np.zeros((2, n))

    def t(self, beat):
        """Temps (s) d'un temps donné, avec le swing des croches."""
        whole = np.floor(beat)
        frac = beat - whole
        if self.swing > 0 and abs(frac - 0.5) < 1e-6:
            frac = self.swing  # croche « et » décalée : 0,5 droit, 0,66 ternaire
        return (whole + frac) * self.spb

    def note(self, inst, bar, beat, dur_beats, m, vel=0.7, p=0.0, wet=True, human=0.012):
        at = self.t(bar * self.bpb + beat) + self.rng.u(-human, human)
        sig = inst(hz(m), dur_beats * self.spb, vel * self.rng.u(0.9, 1.05))
        add(self.wet if wet else self.dry, max(0, samples(at)), pan(sig, p))

    def hit(self, sig, bar, beat, p=0.0, g=1.0, wet=False, human=0.006):
        at = self.t(bar * self.bpb + beat) + self.rng.u(-human, human)
        if sig.ndim == 1:
            sig = pan(sig, p)
        add(self.wet if wet else self.dry, max(0, samples(at)), sig * g)

    def render(self, wet=0.28, room=2.2, dry_room=0.12, target=-17.0):
        a = reverb(self.wet, wet, room, 5200)
        b = reverb(self.dry, dry_room, 1.0, 6000)
        n = max(a.shape[1], b.shape[1])
        out = np.zeros((2, n))
        out[:, : a.shape[1]] += a
        out[:, : b.shape[1]] += b
        # Coupe le silence final, garde la queue de réverbération.
        e = np.max(np.abs(out), axis=0)
        nz = np.nonzero(e > 1e-4)[0]
        out = out[:, : nz[-1] + samples(0.2)]
        out = hp(out, 30)
        out = rms_normalize(out, target, 0.97)
        k = samples(1.5)
        out[:, -k:] *= np.linspace(1, 0, k) ** 2
        return out


# --- Mélodies -----------------------------------------------------------------

def melody(song, bars_chords, rhythm, scale_root, scale, lo, hi, start, end_on_root=True, rng=None):
    """Mélodie sur une suite d'accords (un accord par mesure, ou liste par mesure).
    rhythm : pour chaque mesure, une liste de (temps, durée). Renvoie [(mesure, temps, durée, note)]."""
    rng = rng or song.rng
    sc = [(scale_root + s) % 12 for s in scale]
    prev = start
    out = []
    total = sum(len(r) for r in rhythm)
    k = 0
    for i, (ch, rh) in enumerate(zip(bars_chords, rhythm)):
        for (b, d) in rh:
            k += 1
            sym = ch if isinstance(ch, str) else ch[min(int(b // (song.bpb / len(ch))), len(ch) - 1)]
            cp = chord_pcs(sym)
            strong = abs(b - round(b)) < 1e-6 and (int(round(b)) % 2 == 0 or d >= 1.0)
            last = k == total
            pool = cp if (strong or last) else sc
            if last and end_on_root:
                pool = [chord(sym)[0]]
            cands = [m for m in range(max(lo, prev - 7), min(hi, prev + 7) + 1) if m % 12 in pool]
            if not cands:
                cands = [m for m in range(lo, hi + 1) if m % 12 in pool]
            w = np.array([np.exp(-abs(m - prev) / 2.2) * (0.35 if m == prev else 1.0) for m in cands])
            m = cands[int(rng.g.choice(len(cands), p=w / w.sum()))]
            out.append((i, b, d, m))
            prev = m
    return out


def play(song, notes, inst, bar0, vel=0.7, p=0.0, wet=True, octave=0, legato=1.0):
    for (i, b, d, m) in notes:
        song.note(inst, bar0 + i, b, d * legato, m + octave, vel, p, wet)


def repeat_with(song, notes, bars_chords, scale_root, scale):
    """Reprend un motif sur d'autres accords : chaque note est recalée sur l'accord."""
    out = []
    sc = [(scale_root + s) % 12 for s in scale]
    for (i, b, d, m) in notes:
        sym = bars_chords[i]
        cp = chord_pcs(sym)
        strong = abs(b - round(b)) < 1e-6
        pool = cp if strong else sc
        best = min((x for x in range(m - 4, m + 5) if x % 12 in pool), key=lambda x: abs(x - m))
        out.append((i, b, d, best))
    return out


# --- Morceaux -----------------------------------------------------------------

def premier_coup_de_pioche():
    """Matin de chantier : piano électrique, glockenspiel, contrebasse, balais."""
    A = ["Fmaj7", "Dm7", "Gm7", "C7"] * 2
    B = ["Bbmaj7", "Am7", "Gm7", "C7", "Bbmaj7", "Am7", "Gm7", "C7"]
    form = [("intro", ["Fmaj7", "Dm7", "Gm7", "C7"]), ("A", A), ("A2", A), ("B", B), ("A", A), ("B", B),
            ("A2", A), ("fin", ["Fmaj7", "Fmaj7"])]
    song = Song(100, 4, sum(len(c) for _, c in form), seed=201)
    rng = song.rng
    rhA = [[(0, 1), (1, 0.5), (1.5, 1.5), (3, 1)], [(0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 2)],
           [(0, 1), (1, 1), (2, 0.5), (2.5, 1.5)], [(0, 3)]] * 2
    motif = melody(song, A, rhA, midi("F0") % 12, SCALES["major"], 72, 86, 77)
    rhB = [[(0, 1.5), (1.5, 0.5), (2, 2)], [(0, 1), (1, 1), (2, 1), (3, 1)], [(0, 2), (2, 1), (3, 1)], [(0, 3.5)]] * 2
    motifB = melody(song, B, rhB, midi("F0") % 12, SCALES["major"], 67, 81, 74)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            v = voicing(sym, 55, 68)
            # Accompagnement : temps 1, puis « et » de 2 poussé.
            for m in v:
                song.note(ins.epiano, b, 0, 1.4, m, 0.32, -0.25)
                if name != "fin":
                    song.note(ins.epiano, b, 2.5, 1.2, m, 0.26, -0.25)
            if name != "intro" or i >= 2:
                r = bass_note(sym)
                fifth = r + 7 if r + 7 <= 52 else r - 5
                song.note(ins.bass, b, 0, 1.6, r, 0.8, 0.0, wet=False)
                if name != "fin":
                    song.note(ins.bass, b, 2, 1.0, fifth, 0.65, 0.0, wet=False)
                    nxt = ch[(i + 1) % len(ch)]
                    song.note(ins.bass, b, 3, 0.9, bass_note(nxt) - 1 if rng.u() < 0.5 else fifth + 2, 0.55, 0.0, wet=False)
            if name not in ("intro", "fin"):
                song.hit(ins.kick(0.55), b, 0)
                song.hit(ins.kick(0.4), b, 2)
                for bt in (1, 3):
                    song.hit(ins.brush(0.55), b, bt, 0.15)
                for e in range(8):
                    song.hit(ins.shaker(0.35 if e % 2 else 0.22), b, e * 0.5, 0.35)
        if name in ("A", "A2"):
            if name == "A":
                notes = motif
            else:
                keep = [n_ for n_ in motif if n_[0] < 6]
                var = melody(song, A[6:], rhA[6:], 5, SCALES["major"], 72, 86, keep[-1][3])
                notes = keep + [(i + 6, bb, d, m) for (i, bb, d, m) in var]
            play(song, notes, ins.glock, bar, 0.55, 0.2)
            play(song, notes, ins.marimba, bar, 0.35, -0.1, octave=-12)
        elif name == "B":
            play(song, motifB, ins.clarinet, bar, 0.6, 0.15, legato=0.95)
        elif name == "fin":
            song.note(ins.glock, bar, 0, 2, midi("F6"), 0.5, 0.2)
            song.note(ins.glock, bar, 0.5, 2, midi("C6"), 0.4, 0.2)
            song.note(ins.glock, bar, 1, 4, midi("A5"), 0.4, 0.2)
            song.note(ins.bass, bar, 0, 4, midi("F2"), 0.8, 0, wet=False)
        bar += len(ch)
    return song.render(0.26, 2.0)


def valse_du_permis_de_construire():
    """Valse musette à l'accordéon. À la fin, le tampon du permis (accordé, enfin)."""
    A = ["G", "G", "D7", "D7", "D7", "D7", "G", "G"]
    A2 = ["G", "G", "D7", "D7", "D7", "D7", "G", "G7"]
    B = ["C", "C", "G", "Em", "A7", "A7", "D7", "D7"]
    B2 = ["C", "Cm6", "G", "E7", "A7", "D7", "G", "G"]
    form = [("intro", ["D7", "D7", "D7", "D7"]), ("A", A + A2), ("B", B + B2), ("A", A + A2), ("B", B + B2),
            ("A", A + A2), ("fin", ["G", "G", "G", "G"])]
    song = Song(156, 3, sum(len(c) for _, c in form), seed=202)
    rng = song.rng
    pats = [[(0, 2), (2, 1)], [(0, 1), (1, 1), (2, 1)], [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1)],
            [(0, 3)], [(0, 1.5), (1.5, 0.5), (2, 1)]]
    rhA = [pats[0], pats[2], pats[1], pats[3], pats[4], pats[2], pats[1], pats[3]] * 2
    mA = melody(song, A + A2, rhA, 7, SCALES["major"], 67, 83, 74)
    rhB = [pats[1], pats[0], pats[2], pats[3], pats[2], pats[4], pats[1], pats[3]] * 2
    mB = melody(song, B + B2, rhB, 7, SCALES["major"], 67, 84, 76)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            r = bass_note(sym, 38)
            alt = r + 7 if (i % 2) else r
            if alt > 52:
                alt -= 12
            # Oum-pa-pa : basse pincée sur 1, accord sur 2 et 3.
            song.note(ins.pizz, b, 0, 1, alt, 0.85, 0.0, wet=False)
            if name != "fin" or i == 0:
                for m in voicing(sym, 57, 69):
                    song.note(ins.accordion, b, 1, 0.45, m, 0.22, -0.3)
                    song.note(ins.accordion, b, 2, 0.45, m, 0.2, -0.3)
            if name not in ("intro", "fin"):
                song.hit(ins.brush(0.35), b, 1, 0.2)
                song.hit(ins.brush(0.3), b, 2, 0.2)
        if name == "A":
            play(song, mA, ins.accordion, bar, 0.75, 0.15, legato=0.92)
        elif name == "B":
            play(song, mB, ins.accordion, bar, 0.75, 0.15, legato=0.92)
            play(song, mB, ins.glock, bar, 0.2, 0.3, octave=12)
        elif name == "intro":
            for k, m in enumerate([62, 66, 69, 72, 74, 72, 69, 66]):
                song.note(ins.accordion, bar + k // 2, (k % 2) * 1.5, 1.4, m + 12, 0.6, 0.15)
        elif name == "fin":
            song.note(ins.accordion, bar, 0, 2.5, midi("G5"), 0.7, 0.1)
            song.note(ins.accordion, bar, 0, 2.5, midi("B4"), 0.5, 0.1)
            # Le tampon : « tchac ! », puis petit « ding » satisfait.
            stamp = effets.pose_batiment()
            song.hit(stamp * 0.5, bar + 2, 0, g=1.0)
            song.note(ins.glock, bar + 2, 1, 2, midi("G6"), 0.5, 0.3)
        bar += len(ch)
    return song.render(0.22, 1.6)


def nids_de_poule_blues():
    """Blues en shuffle : la route est pleine de trous, la clarinette aussi."""
    grid = ["Bb7", "Eb7", "Bb7", "Bb7", "Eb7", "Eb7", "Bb7", "G7", "Cm7", "F7", "Bb7", "F7"]
    form = [("intro", grid[8:]), ("tete", grid), ("piano", grid), ("clar", grid), ("tete", grid),
            ("fin", ["Bb7", "Bb7"])]
    song = Song(84, 4, sum(len(c) for _, c in form), seed=203, swing=0.66)
    rng = song.rng
    blues = SCALES["blues"]
    root = midi("Bb0") % 12
    # Tête : motif de deux mesures, repris, puis réponse (forme AAB du blues).
    rh = [[(0.5, 0.5), (1, 0.5), (1.5, 1), (3, 1)], [(0, 2)]]
    mot = melody(song, grid[:2], rh, root, blues, 65, 79, 70, end_on_root=False)
    head = list(mot)
    head += [(i + 4, b, d, m) for (i, b, d, m) in repeat_with(song, mot, ["Eb7", "Eb7"], root, blues)]
    rh2 = [[(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1.5)], [(0, 0.5), (0.5, 1.5), (2, 1)], [(0, 3)]]
    ans = melody(song, grid[8:11], rh2, root, blues, 65, 79, mot[-1][3])
    head += [(i + 8, b, d, m) for (i, b, d, m) in ans]
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            # Contrebasse qui marche.
            r = bass_note(sym, 34)
            nxt = bass_note(ch[(i + 1) % len(ch)], 34)
            steps = [r, r + 4 if "m" not in sym else r + 3, r + 7, nxt + (1 if rng.u() < 0.5 else -1)]
            if name == "fin":
                song.note(ins.bass, b, 0, 4 if i else 1, r, 0.85, 0, wet=False)
            else:
                for k, m in enumerate(steps):
                    song.note(ins.bass, b, k, 0.95, m, 0.75 if k == 0 else 0.62, 0, wet=False)
            # Piano électrique : coups sur 2 et le « et » de 4.
            for m in voicing(sym, 56, 69):
                if name == "fin":
                    if i == 0:
                        song.note(ins.epiano, b, 0, 6, m, 0.3, -0.25)
                    continue
                song.note(ins.epiano, b, 1, 0.5, m, 0.27, -0.25)
                song.note(ins.epiano, b, 3.5, 0.9, m, 0.24, -0.25)
            if name != "fin":
                for bt in range(4):
                    song.hit(ins.brush(0.5 if bt % 2 else 0.35, long=True), b, bt, 0.1)
                    song.hit(ins.hat(0.25), b, bt + 0.5, 0.3)
                for bt in (1, 3):
                    song.hit(ins.hat(0.4), b, bt, 0.3)
        if name == "tete":
            play(song, head, ins.clarinet, bar, 0.72, 0.15, legato=0.95)
        elif name in ("piano", "clar"):
            rhs = []
            for k in range(12):
                rhs.append(rng.choice([[(0, 0.5), (0.5, 0.5), (1, 1), (2.5, 0.5), (3, 1)],
                                       [(0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 0.5), (2.5, 1.5)],
                                       [(0, 1.5), (2, 0.5), (2.5, 0.5), (3, 1)], [(0, 3)],
                                       [(1, 0.5), (1.5, 0.5), (2, 2)]]))
            solo = melody(song, ch, rhs, root, blues, 63 if name == "clar" else 70, 82 if name == "clar" else 88, 72)
            if name == "piano":
                play(song, solo, ins.epiano, bar, 0.5, 0.2)
            else:
                play(song, solo, ins.clarinet, bar, 0.65, 0.15, legato=0.9)
                # Un nid-de-poule : « bonk » de woodblock et tuba vexé.
                song.hit(ins.woodblock(380, 0.8), bar + 7, 3.5, -0.3, wet=True)
                song.note(ins.tuba, bar + 7, 3.5, 0.5, midi("F1"), 0.7, 0.0)
        elif name == "intro":
            for k, m in enumerate([midi("F5"), midi("Eb5"), midi("D5"), midi("Db5"), midi("C5"), midi("Bb4")]):
                song.note(ins.clarinet, bar + k // 2, (k % 2) * 2, 1.8, m, 0.55, 0.15)
        elif name == "fin":
            song.note(ins.clarinet, bar, 0.5, 0.5, midi("D5"), 0.6, 0.15)
            song.note(ins.clarinet, bar, 1, 4, midi("Bb4"), 0.65, 0.15)
            song.hit(ins.cymbal(0.4, 3.0), bar, 0, 0.3)
            song.note(ins.tuba, bar + 1, 2, 1.0, midi("Bb1"), 0.7, 0.0)
        bar += len(ch)
    return song.render(0.24, 1.8)


def conseil_municipal_en_retard():
    """Marche sautillante au basson : le conseil devait commencer il y a dix minutes."""
    A = ["C", "G7", "G7", "C", "C", "F", "G7", "C"]
    B = ["Am", "E7", "E7", "Am", "Dm", "Am", "E7", "Am"]
    form = [("horloge", ["C", "C"]), ("A", A), ("A2", A), ("B", B), ("A", A), ("B", B), ("A2", A),
            ("fin", ["C", "C"])]
    song = Song(116, 4, sum(len(c) for _, c in form), seed=204)
    rng = song.rng
    pats = [[(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 0.5), (3.5, 0.5)],
            [(0, 1), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)],
            [(0, 0.5), (0.5, 0.5), (1, 1), (2, 0.5), (2.5, 0.5), (3, 1)], [(0, 1), (1, 1), (2, 2)]]
    rhA = [pats[0], pats[1], pats[2], pats[3], pats[0], pats[2], pats[1], pats[3]]
    mA = melody(song, A, rhA, 0, SCALES["major"], 55, 72, 64)
    rhB = [pats[1], pats[0], pats[2], pats[3], pats[1], pats[0], pats[2], pats[3]]
    mB = melody(song, B, rhB, 9, SCALES["harm"], 57, 72, 69)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            # Tic-tac de l'horloge de la mairie.
            for e in range(8):
                if name == "horloge" or (name != "fin" and e % 2 == 0):
                    song.hit(ins.woodblock(1300 if e % 2 == 0 else 1000, 0.45 if name == "horloge" else 0.25), b, e * 0.5,
                             -0.4 if e % 2 else 0.4)
            if name in ("horloge",):
                continue
            r = bass_note(sym, 31)
            five = r + 7 if r + 7 <= 47 else r - 5
            if name == "fin":
                if i == 0:
                    song.note(ins.tuba, b, 0, 1, r, 0.9, 0)
                continue
            song.note(ins.tuba, b, 0, 0.8, r, 0.85, 0.0)
            song.note(ins.tuba, b, 2, 0.8, five, 0.75, 0.0)
            for m in voicing(sym, 60, 72):
                song.note(ins.pizz, b, 1, 0.4, m, 0.35, 0.3)
                song.note(ins.pizz, b, 3, 0.4, m, 0.32, 0.3)
            song.hit(ins.kick(0.35), b, 0)
            song.hit(ins.snare(0.25), b, 1, 0.1)
            song.hit(ins.snare(0.2), b, 3, 0.1)
        if name in ("A", "A2"):
            play(song, mA, ins.bassoon, bar, 0.8, -0.1, legato=0.6)
            if name == "A2":
                play(song, mA, ins.glock, bar, 0.3, 0.3, octave=24)
        elif name == "B":
            play(song, mB, ins.clarinet, bar, 0.6, 0.15, legato=0.7)
            play(song, mB, ins.bassoon, bar, 0.45, -0.15, octave=-12, legato=0.6)
        elif name == "fin":
            # Le coucou de l'horloge : on est en retard, c'est officiel.
            for k in range(3):
                song.note(ins.glock, bar, k * 1.0, 0.4, midi("E6"), 0.55, 0.2)
                song.note(ins.glock, bar, k * 1.0 + 0.4, 0.5, midi("C6"), 0.5, 0.2)
            song.note(ins.bassoon, bar + 1, 0, 0.3, midi("G3"), 0.8, 0)
            song.note(ins.bassoon, bar + 1, 0.5, 0.5, midi("C3"), 0.8, 0)
        bar += len(ch)
    return song.render(0.2, 1.4)


def lampadaires():
    """Nuit en ville : piano seul et nappe, les lampadaires s'allument un à un."""
    A = ["Am9", "Fmaj7", "Cmaj7", "Em7", "Dm9", "Fmaj7", "Am9", "E7"]
    B = ["Fmaj7", "G6", "Em7", "Am9", "Dm9", "G6", "Cmaj7", "E7"]
    form = [("intro", ["Am9", "Fmaj7", "Cmaj7", "Em7"]), ("A", A), ("A", A), ("B", B), ("A", A),
            ("fin", ["Am9", "Am9"])]
    song = Song(68, 4, sum(len(c) for _, c in form), seed=205)
    rng = song.rng
    rhA = [[(0, 1.5), (1.5, 0.5), (2, 2)], [(0.5, 0.5), (1, 1), (2, 2)], [(0, 1), (1, 1), (2, 1.5), (3.5, 0.5)],
           [(0, 4)]] * 2
    mA = melody(song, A, rhA, 9, SCALES["minor"], 69, 84, 76)
    mA2 = repeat_with(song, mA, A, 9, SCALES["minor"])
    rhB = [[(0, 2), (2, 1), (3, 1)], [(0, 3), (3, 1)], [(0, 1), (1, 1), (2, 2)], [(0, 4)]] * 2
    mB = melody(song, B, rhB, 9, SCALES["minor"], 71, 86, 79)
    count = 0
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            r, iv = chord(sym)
            low = 45 + ((r - 45) % 12)
            arp = [low, low + 7, low + 12 + (iv[1] if len(iv) > 1 else 4), low + 7 + 12, low + 12 + iv[-1] % 12]
            pattern = [0, 1, 2, 3, 4, 3, 2, 1]
            if name == "fin":
                if i == 0:
                    for m in [low, low + 7, low + 15, low + 19, low + 26]:
                        song.note(ins.piano, b, 0, 8, m, 0.45, -0.1)
                continue
            for e in range(8):
                song.note(ins.piano, b, e * 0.5, 1.6, arp[pattern[e]], 0.4 if e == 0 else 0.3, -0.15)
            for m in voicing(sym, 57, 70):
                song.note(ins.pad, b, 0, 4, m, 0.5, 0.0)
        if name == "A":
            count += 1
            play(song, mA if count != 2 else mA2, ins.piano, bar, 0.6, 0.15, octave=0)
        elif name == "B":
            play(song, mB, ins.piano, bar, 0.6, 0.15)
            play(song, mB, ins.glock, bar, 0.12, 0.3, octave=12)
        bar += len(ch)
    return song.render(0.34, 2.8, target=-19.0)


def heure_creuse():
    """Ambiance de nuit : nappes lentes, quelques notes de glockenspiel."""
    prog = ["Dmaj9", "Dmaj9", "Emaj", "Emaj", "Bm9", "Bm9", "Gmaj7", "Gmaj7"]
    prog = [p.replace("Emaj", "E") for p in prog]
    form = prog * 4
    song = Song(60, 4, len(form), seed=206)
    rng = song.rng
    sc = SCALES["lydian"]
    for b, sym in enumerate(form):
        if b % 2 == 0:
            for m in voicing(sym, 50, 64):
                song.note(ins.pad, b, 0, 8, m, 0.6, rng.u(-0.3, 0.3))
            song.note(ins.piano, b, 0, 6, bass_note(sym, 38), 0.4, 0.0)
        for bt in range(4):
            if rng.u() < 0.38:
                pcs = [(2 + s) % 12 for s in sc]
                cands = [m for m in range(74, 91) if m % 12 in (chord_pcs(sym) if rng.u() < 0.6 else pcs)]
                song.note(ins.glock, b, bt + rng.choice([0, 0.5]), 1, rng.choice(cands), rng.u(0.2, 0.4), rng.u(-0.6, 0.6))
        if b % 4 == 2 and rng.u() < 0.7:
            cands = [m for m in range(62, 76) if m % 12 in chord_pcs(sym)]
            song.note(ins.piano, b, rng.choice([0, 1, 2]), 2, rng.choice(cands), 0.35, 0.2)
    for m in voicing("Dmaj9", 50, 64):
        song.note(ins.pad, len(form), 0, 6, m, 0.5, 0)
    return song.render(0.42, 3.2, target=-21.0)


def une_terre_a_batir():
    """Thème du globe : on choisit où poser la première pierre."""
    A = ["C", "Am7", "Fmaj7", "G", "C", "Em7", "Fmaj7", "Gsus"]
    B = ["Am7", "Fmaj7", "C", "G", "Am7", "Fmaj7", "Dm7", "G7"]
    form = [("intro", ["C", "Am7", "Fmaj7", "Gsus"]), ("A", A), ("B", B), ("A", A), ("B", B),
            ("fin", ["Fmaj7", "C", "C"])]
    song = Song(84, 4, sum(len(c) for _, c in form), seed=207)
    rng = song.rng
    rhA = [[(0, 1), (1, 1), (2, 2)], [(0, 1.5), (1.5, 0.5), (2, 2)], [(0, 1), (1, 0.5), (1.5, 0.5), (2, 2)],
           [(0, 4)]] * 2
    mA = melody(song, A, rhA, 0, SCALES["major"], 67, 81, 72)
    rhB = [[(0, 2), (2, 1), (3, 1)], [(0, 1), (1, 1), (2, 2)], [(0, 1.5), (1.5, 0.5), (2, 2)], [(0, 4)]] * 2
    mB = melody(song, B, rhB, 0, SCALES["major"], 69, 84, 76)
    bar = 0
    for name, ch in form:
        for i, sym in enumerate(ch):
            b = bar + i
            for m in voicing(sym, 55, 67):
                song.note(ins.pad, b, 0, 4, m, 0.55, 0)
            arp = voicing(sym, 60, 76)
            if name != "fin":
                for e in range(8):
                    song.note(ins.epiano, b, e * 0.5, 0.6, arp[(e * 2) % len(arp)] + (12 if e in (3, 6) else 0),
                              0.22, -0.3 + 0.08 * e)
                r = bass_note(sym, 36)
                song.note(ins.bass, b, 0, 2.5, r, 0.7, 0, wet=False)
                song.note(ins.bass, b, 2.5, 1.5, r + 7 if r + 7 < 52 else r - 5, 0.55, 0, wet=False)
            if name in ("A", "B") and bar > 12:
                song.hit(ins.kick(0.35), b, 0)
                song.hit(ins.brush(0.35, long=True), b, 2, 0.1)
                for e in range(4):
                    song.hit(ins.shaker(0.25), b, e + 0.5, 0.3)
        if name == "A":
            play(song, mA, ins.clarinet, bar, 0.55, 0.15, legato=0.97)
        elif name == "B":
            play(song, mB, ins.brass, bar, 0.45, 0.1, legato=0.95)
            play(song, mB, ins.glock, bar, 0.18, 0.3, octave=12)
        elif name == "fin":
            song.note(ins.glock, bar + 1, 0, 3, midi("E6"), 0.45, 0.2)
            song.note(ins.glock, bar + 1, 0.5, 3, midi("G6"), 0.4, 0.2)
            song.note(ins.glock, bar + 1, 1, 4, midi("C7"), 0.4, 0.2)
            song.note(ins.bass, bar + 1, 0, 6, midi("C2"), 0.7, 0, wet=False)
        bar += len(ch)
    return song.render(0.3, 2.4)


# id -> (fonction, titre affiché, humeur)
ALL = {
    "une_terre_a_batir": (une_terre_a_batir, "Une Terre à bâtir", "menu"),
    "premier_coup_de_pioche": (premier_coup_de_pioche, "Premier coup de pioche", "jour"),
    "valse_du_permis_de_construire": (valse_du_permis_de_construire, "Valse du permis de construire", "jour"),
    "nids_de_poule_blues": (nids_de_poule_blues, "Nids-de-poule blues", "soir"),
    "conseil_municipal_en_retard": (conseil_municipal_en_retard, "Conseil municipal (en retard)", "jour"),
    "lampadaires": (lampadaires, "Lampadaires", "nuit"),
    "heure_creuse": (heure_creuse, "Heure creuse", "nuit"),
}
