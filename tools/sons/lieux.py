"""Sons des lieux de la ville, des saisons et des sirènes.

- LIEUX : boucles mono jouées en 3D sur place (stade, cour d'école, manèges,
  zoo, usine, ferme, gare, port, terrasse de café, piscine, incendie) et
  sirènes des véhicules d'urgence (France, Amériques, Japon, avant 1920).
- SAISONS : nappes stéréo (cigales l'été, nature d'hiver, grenouilles).
- EFFETS : but au stade, sifflet de l'arbitre, sonnerie de l'école, cloche à
  main, succès débloqué.
Tout est synthétisé (CC0), comme le reste de tools/sons/.
"""
import numpy as np

from synth import (SR, Rng, secs, samples, lp, hp, bp, reson, pink, brown, white, smooth_noise,
                   env_ad, env_asr, fade, pan, add, add_wrap, loopify, rms_normalize, normalize, reverb, hz, midi)
import instruments as ins
import ambiances as amb


def _put(buf, at, sig, g=1.0):
    """Ajoute un signal mono dans une boucle mono (en revenant au début si besoin)."""
    s = samples(at) % len(buf)
    k = min(len(sig), len(buf) - s)
    buf[s:s + k] += sig[:k] * g
    if k < len(sig):
        r = min(len(sig) - k, len(buf))
        buf[:r] += sig[k:k + r] * g


def _loop_mono(x, xfade=1.5, db=-22):
    """Boucle mono sans couture, normalisée."""
    st = loopify(np.vstack([x, x]), xfade)
    return rms_normalize(st, db)[0]


def _room(x, wet=0.2, seconds=1.4, damp=4000):
    n = len(x)
    st = reverb(np.vstack([x, x]), wet, seconds, damp)
    return st[0, :n]


# --- Voix ------------------------------------------------------------------------

def voices(rng, n, voices=10, f_lo=95, f_hi=230, syl=(4, 6.5), talk=0.35):
    """Brouhaha mono : voix filtrées qui parlent par syllabes (adultes ou enfants)."""
    buf = np.zeros(n)
    for _ in range(voices):
        f0 = rng.u(f_lo, f_hi)
        pitch = f0 * (1 + 0.16 * (smooth_noise(rng, n, 3.0) - 0.5))
        ph = 2 * np.pi * np.cumsum(pitch) / SR
        src = np.zeros(n)
        for k in range(1, 12):
            src += np.sin(ph * k) / k
        src += white(rng, n) * 0.15
        scale = f0 / 160.0
        v = (reson(src, rng.u(500, 800) * scale ** 0.4, 3) + reson(src, rng.u(1100, 1900) * scale ** 0.3, 4) * 0.7
             + reson(src, rng.u(2400, 3000), 6) * 0.3)
        s = lp((smooth_noise(rng, n, rng.u(*syl)) > 0.45).astype(float), 18, 1)
        on = smooth_noise(rng, n, 0.25) > talk
        buf += lp(v * s * on, 3200) * rng.u(0.3, 1.0)
    return buf / np.sqrt(voices)


def shriek(rng, dur=None, f0=None):
    """Cri aigu (enfant qui joue, passager des montagnes russes)."""
    dur = dur or rng.u(0.35, 0.9)
    n = samples(dur)
    t = secs(n)
    f0 = f0 or rng.u(700, 1100)
    f = f0 * (1 + 0.35 * np.sin(np.pi * t / dur) + 0.03 * np.sin(2 * np.pi * 7 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.zeros(n)
    for k in range(1, 7):
        x += np.sin(ph * k) / k ** 1.3
    x = reson(x, 1600, 3) + reson(x, 3000, 5) * 0.5 + x * 0.3
    return x * np.sin(np.pi * t / dur) ** 0.6


def laugh(rng):
    """« Ha ha ha » d'une terrasse de café."""
    out = []
    f0 = rng.u(130, 260)
    for k in range(rng.i(3, 6)):
        d = rng.u(0.1, 0.15)
        n = samples(d)
        t = secs(n)
        f = f0 * (1.15 - 0.05 * k) * (1 - 0.1 * t / d)
        ph = 2 * np.pi * np.cumsum(f) / SR
        src = sum(np.sin(ph * j) / j for j in range(1, 10)) + white(rng, n) * 0.4
        out.append((reson(src, 750, 3) + reson(src, 1250, 4) * 0.6) * np.sin(np.pi * t / d))
        out.append(np.zeros(samples(rng.u(0.05, 0.1))))
    return lp(np.concatenate(out), 3000)


def claps(rng, n_people=40, dur=0.25):
    """Un coup de mains de toute une tribune."""
    n = samples(dur)
    x = np.zeros(n)
    for _ in range(n_people):
        at = samples(rng.u(0, 0.04))
        k = samples(0.03)
        c = bp(white(rng, k), rng.u(900, 1500), rng.u(2500, 4000)) * env_ad(k, 0.001, rng.u(90, 160))
        x[at:at + k] += c[: n - at] * rng.u(0.4, 1.0)
    return x / np.sqrt(n_people)


def chant(rng, dur, f0=180):
    """Chœur de supporters sur deux notes (« al-lez, al-lez ! »)."""
    n = samples(dur)
    t = secs(n)
    x = np.zeros(n)
    notes = [(0.0, 1.0), (0.35, 1.0), (0.75, 1.335), (1.15, 1.0)]
    for _ in range(18):
        det = rng.u(0.97, 1.03)
        sig = np.zeros(n)
        for at, r in notes:
            d = 0.3
            k = samples(d)
            s = max(0, samples(at + rng.u(-0.02, 0.02)))
            if s + k > n:
                continue
            tt = secs(k)
            ph = 2 * np.pi * f0 * r * det * tt
            v = sum(np.sin(ph * j) / j for j in range(1, 10))
            v = reson(v, 700, 3) + reson(v, 1150, 4) * 0.6
            sig[s:s + k] += v * np.sin(np.pi * tt / d) ** 0.5
        x += sig
    return lp(x / 4.0, 2600)


# --- Lieux (boucles mono, jouées en 3D) --------------------------------------------

def foule_stade():
    """Tribune pendant le match : rumeur, chants, applaudissements, « ooooh »."""
    rng = Rng(501)
    n = samples(30.0)
    x = voices(rng, n, 16, 110, 240, talk=0.2) * 0.8
    roar = bp(pink(rng, n), 250, 2800) * (0.5 + 0.5 * smooth_noise(rng, n, 0.08)) * 0.12
    x += roar
    t = 2.0
    while t < 28:
        _put(x, t, chant(rng, 1.6, rng.u(160, 200)), 0.5)
        for k in range(3):
            _put(x, t + 1.7 + k * 0.45, claps(rng), 0.6)
        t += rng.u(6, 10)
    # Une occasion manquée : « ooooh ! »
    for at in (rng.u(4, 12), rng.u(16, 26)):
        k = samples(1.8)
        tt = secs(k)
        oh = bp(pink(rng, k), 300, 1200) * np.sin(np.pi * tt / 1.8) ** 2 * 0.35
        oh += voices(rng, k, 12, 140, 260, syl=(0.5, 0.8), talk=-1) * np.sin(np.pi * tt / 1.8) * 0.8
        _put(x, at, oh)
    # Une trompette de supporter, de temps en temps (touche d'humour : elle est fausse).
    _put(x, rng.u(8, 22), ins.trombone_gliss(330, 312, 0.9, 0.5), 0.4)
    return _loop_mono(_room(x, 0.25, 2.0), 1.5, -21)


def cour_recre():
    """Cour d'école à la récré : voix d'enfants, cris, ballon, corde à sauter."""
    rng = Rng(502)
    n = samples(26.0)
    x = voices(rng, n, 12, 230, 420, syl=(5, 8), talk=0.3)
    t = 0.5
    while t < 25:
        _put(x, t, shriek(rng, f0=rng.u(800, 1300)), rng.u(0.15, 0.35))
        t += rng.u(1.0, 3.5)
    # Ballon qui rebondit.
    t = 1.0
    while t < 25:
        for k in range(rng.i(2, 5)):
            m = samples(0.08)
            b = np.sin(2 * np.pi * 120 * secs(m)) * env_ad(m, 0.001, 50) + bp(white(rng, m), 300, 1500) * env_ad(m, 0.001, 120) * 0.3
            _put(x, t + k * 0.5, b, 0.5)
        t += rng.u(3, 7)
    # Corde à sauter : tap régulier.
    for k in range(16):
        m = samples(0.03)
        _put(x, 12 + k * 0.42, bp(white(rng, m), 1500, 5000) * env_ad(m, 0.001, 200), 0.2)
    return _loop_mono(_room(x, 0.2, 1.3), 1.5, -23)


def manege():
    """Parc de loisirs : orgue de manège, chaîne des montagnes russes, cris au passage."""
    rng = Rng(503)
    n = samples(32.0)
    x = np.zeros(n)
    # Orgue de manège (valse en do).
    mel = ["G4", "C5", "E5", "G5", "E5", "C5", "D5", "F5", "A5", "F5", "D5", "B4",
           "C5", "E5", "G5", "C6", "B5", "G5", "A5", "F5", "D5", "G5", "F5", "D5"]
    spb = 60.0 / 168
    org = np.zeros(n)
    for rep in range(int(32.0 / (len(mel) * spb)) + 1):
        for k, m in enumerate(mel):
            at = (rep * len(mel) + k) * spb
            if at > 31:
                break
            _put(org, at, organ(hz(midi(m)), spb * 0.9, 0.7))
            if k % 3 == 0:
                _put(org, at, organ(hz(midi(m) - 24), spb * 0.9, 0.5))
            else:
                _put(org, at, organ(hz(midi(m) - 8), spb * 0.5, 0.25))
    x += org * 0.5
    x += voices(rng, n, 8, 120, 320, talk=0.4) * 0.35
    # Montagnes russes : la chaîne qui monte, puis le passage et les cris.
    t = 3.0
    while t < 28:
        k = samples(3.0)
        tt = secs(k)
        clank = (np.sin(2 * np.pi * 9 * tt) > 0.85).astype(float)
        chain = bp(white(rng, k), 1500, 5000) * lp(clank, 200) * 0.1
        _put(x, t, chain)
        r = samples(2.5)
        rt = secs(r)
        rumble = lp(brown(rng, r), 250) * np.sin(np.pi * rt / 2.5) * 1.2
        _put(x, t + 3.0, rumble)
        for j in range(5):
            _put(x, t + 3.2 + rng.u(0, 0.6), shriek(rng, rng.u(0.8, 1.4), rng.u(650, 1000)), 0.3)
        t += rng.u(10, 14)
    return _loop_mono(_room(x, 0.22, 1.6), 1.5, -21)


def organ(f, dur, vel=0.8):
    t = secs(samples(dur + 0.05))
    ph = 2 * np.pi * f * t
    x = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.28 * np.sin(3 * ph) + 0.12 * np.sin(4 * ph)
    trem = 1 + 0.1 * np.sin(2 * np.pi * 6.5 * t)
    return lp(x * trem * env_asr(len(t), 0.01, 0.04) * vel * 0.25, 5000)


def lion(rng):
    """Rugissement de lion : grave, rauque, qui s'éteint en grognements."""
    d = rng.u(1.6, 2.4)
    n = samples(d)
    t = secs(n)
    f = 95 + 60 * np.sin(np.pi * np.clip(t / d * 1.3, 0, 1)) ** 2
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = sum(np.sin(ph * j) / j ** 0.8 for j in range(1, 16))
    src *= 1 + 0.4 * np.sin(2 * np.pi * 28 * t)
    src += lp(brown(rng, n), 900) * 2
    x = reson(src, 350, 2) + reson(src, 750, 3) * 0.6
    return lp(x * np.sin(np.pi * t / d) ** 0.4 * np.exp(-t * 0.5), 1800)


def elephant(rng):
    """Barrissement d'éléphant : trompette nasale qui monte."""
    d = rng.u(0.9, 1.4)
    x = ins.trombone_gliss(rng.u(380, 450), rng.u(600, 760), d, 0.9, vibrato=0.04)
    n = len(x)
    x = x + bp(white(rng, n), 800, 3000) * env_asr(n, 0.05, 0.2) * 0.2
    return reson(x, 1100, 2) * 0.5 + x


def monkey(rng):
    """Singes : « hou-hou-ha-ha » qui monte."""
    out = []
    f = rng.u(450, 600)
    for k in range(rng.i(4, 8)):
        d = rng.u(0.1, 0.18)
        n = samples(d)
        t = secs(n)
        ff = f * (1 + 0.08 * k) * (1 + 0.5 * t / d)
        ph = 2 * np.pi * np.cumsum(ff) / SR
        out.append((np.sin(ph) + 0.4 * np.sin(2 * ph)) * np.sin(np.pi * t / d))
        out.append(np.zeros(samples(rng.u(0.03, 0.08))))
    return lp(np.concatenate(out), 4000)


def parrot(rng):
    """Perroquet : un cri rauque et aigu."""
    d = rng.u(0.25, 0.45)
    n = samples(d)
    t = secs(n)
    f = rng.u(1100, 1500) * (1 + 0.3 * np.sin(np.pi * t / d))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(ph * j) / j for j in range(1, 6)) * (1 + 0.6 * np.sin(2 * np.pi * 90 * t))
    return bp(x, 900, 6000) * np.sin(np.pi * t / d)


def zoo():
    rng = Rng(504)
    n = samples(34.0)
    x = voices(rng, n, 8, 120, 380, talk=0.45) * 0.3
    x += amb.leaves(rng, n, 0.6)[0] * 0.5
    calls = [(lion, 0.5, 1), (elephant, 0.35, 1), (monkey, 0.25, 3), (parrot, 0.08, 4)]
    for f, g, count in calls:
        for _ in range(count):
            _put(x, rng.u(0, 33), f(rng), g)
    for _ in range(6):
        _put(x, rng.u(0, 33), lp(amb.bird_trill(rng), 6000), 0.08)
    for _ in range(2):
        _put(x, rng.u(0, 33), shriek(rng, 0.4, rng.u(900, 1200)), 0.12)
    return _loop_mono(_room(x, 0.2, 1.6), 2.0, -23)


def usine():
    """Atelier et usine : presse, moteur, vapeur, cliquetis de courroies."""
    rng = Rng(505)
    n = samples(20.0)
    t = secs(n)
    hum = (np.sin(2 * np.pi * 50 * t) + 0.5 * np.sin(2 * np.pi * 100 * t) + 0.2 * np.sin(2 * np.pi * 150 * t)) * 0.04
    belt = bp(white(rng, n), 600, 2500) * (0.6 + 0.4 * np.sin(2 * np.pi * 6 * t)) * 0.03
    x = hum + belt + lp(brown(rng, n), 200) * 0.2
    period = 1.25
    k = 0
    while k * period < 19.8:
        m = samples(0.5)
        tt = secs(m)
        thump = np.sin(2 * np.pi * 55 * tt * (1 + 0.5 * np.exp(-tt * 30))) * np.exp(-tt * 12)
        clank = reson(white(rng, m), 820, 30) * 0.3 + reson(white(rng, m), 1340, 30) * 0.2
        _put(x, k * period, thump * 0.6 + clank * np.exp(-tt * 20))
        k += 1
    for _ in range(3):
        m = samples(1.4)
        tt = secs(m)
        _put(x, rng.u(0, 19), hp(white(rng, m), 2500) * np.sin(np.pi * tt / 1.4) ** 0.5 * 0.12)
    return _loop_mono(_room(x, 0.25, 1.2, 3000), 1.0, -22)


def moo(rng):
    d = rng.u(1.2, 1.8)
    n = samples(d)
    t = secs(n)
    f = rng.u(110, 140) * (1 + 0.25 * np.sin(np.pi * t / d) - 0.15 * t / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = sum(np.sin(ph * j) / j for j in range(1, 14))
    open_ = np.clip(t / (d * 0.3), 0, 1)
    x = reson(src, 320, 3) * (1 - open_) + reson(src, 680, 3) * open_ + reson(src, 1100, 5) * 0.3 * open_
    return lp(x * np.sin(np.pi * t / d) ** 0.5, 2000)


def hen(rng):
    out = []
    for k in range(rng.i(3, 6)):
        d = 0.07 if k < 3 else 0.2
        n = samples(d)
        t = secs(n)
        f = rng.u(320, 420) * (1.3 if k == 4 else 1.0)
        ph = 2 * np.pi * f * t
        src = sum(np.sin(ph * j) / j for j in range(1, 10))
        out.append(reson(src, 1500, 4) * np.sin(np.pi * t / d))
        out.append(np.zeros(samples(rng.u(0.08, 0.2))))
    return lp(np.concatenate(out), 4000)


def sheep(rng):
    d = rng.u(0.6, 0.9)
    n = samples(d)
    t = secs(n)
    f = rng.u(260, 340) * (1 - 0.05 * t / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = sum(np.sin(ph * j) / j for j in range(1, 10)) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t))
    return lp(reson(src, 900, 3) + reson(src, 2200, 5) * 0.3, 3500) * np.sin(np.pi * t / d) ** 0.6


def ferme():
    """Cour de ferme : vaches, poules, moutons, un chien, le vent."""
    rng = Rng(506)
    n = samples(34.0)
    x = amb.leaves(rng, n, 0.5)[0] * 0.6
    for f, g, count in [(moo, 0.5, 3), (hen, 0.25, 6), (sheep, 0.25, 3), (amb.dog_bark, 0.15, 1)]:
        for _ in range(count):
            _put(x, rng.u(0, 33), f(rng), g)
    for _ in range(5):
        _put(x, rng.u(0, 33), lp(amb.bird_tit(rng), 6000), 0.05)
    return _loop_mono(_room(x, 0.15, 1.2), 2.0, -24)


def gare():
    """Quai de gare : foule, annonce (carillon maison), freins, moteur au ralenti."""
    rng = Rng(507)
    n = samples(30.0)
    x = voices(rng, n, 12, 100, 240, talk=0.35) * 0.6
    x += lp(brown(rng, n), 120) * 0.25
    # Carillon d'annonce (trois notes à nous) puis une voix lointaine pleine d'écho.
    for at in (3.0, 18.0):
        for k, m in enumerate(["E5", "A5", "C#6"]):
            _put(x, at + k * 0.32, ins.glock(hz(midi(m)), 0.5, 0.8), 0.6)
        k = samples(3.0)
        anon = voices(rng, k, 1, 130, 140, syl=(5, 6), talk=-1)
        _put(x, at + 1.4, bp(anon, 400, 3000) * 1.2)
    # Freins qui crissent à l'arrivée d'un train.
    m = samples(3.5)
    tt = secs(m)
    sq = np.sin(2 * np.pi * (2600 + 200 * np.sin(2 * np.pi * 0.7 * tt)) * tt) * np.exp(-tt * 0.6) * (0.5 + 0.5 * smooth_noise(rng, m, 8))
    _put(x, 10.0, sq * 0.15 + lp(brown(rng, m), 300) * np.exp(-tt * 0.5) * 0.6)
    # Sifflet du chef de gare.
    _put(x, 25.0, whistle(rng, 0.6), 0.25)
    return _loop_mono(_room(x, 0.35, 2.4, 3500), 1.5, -22)


def gull(rng):
    out = []
    for k in range(rng.i(2, 4)):
        d = rng.u(0.18, 0.35)
        n = samples(d)
        t = secs(n)
        f = rng.u(1100, 1400) * (1 + 0.5 * np.sin(np.pi * t / d)) * (1 - 0.2 * t / d)
        ph = 2 * np.pi * np.cumsum(f) / SR
        src = sum(np.sin(ph * j) / j for j in range(1, 6))
        out.append(bp(src, 900, 5000) * np.sin(np.pi * t / d) ** 0.7)
        out.append(np.zeros(samples(rng.u(0.05, 0.15))))
    return np.concatenate(out)


def port():
    """Port : clapotis, mouettes, cordages qui grincent, corne de brume."""
    rng = Rng(508)
    n = samples(34.0)
    t = secs(n)
    lap = lp(brown(rng, n), 500) * (0.4 + 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.25 * t)) * smooth_noise(rng, n, 0.6)) * 0.5
    x = lap + bp(pink(rng, n), 800, 3000) * smooth_noise(rng, n, 1.2) ** 3 * 0.1
    for _ in range(6):
        _put(x, rng.u(0, 33), gull(rng), 0.2)
    for _ in range(3):
        m = samples(0.8)
        tt = secs(m)
        creak = np.sin(2 * np.pi * (180 + 120 * tt) * tt) * (np.sin(2 * np.pi * 40 * tt) > 0.3) * np.sin(np.pi * tt / 0.8)
        _put(x, rng.u(0, 33), bp(creak, 200, 2000), 0.15)
    m = samples(3.0)
    tt = secs(m)
    horn = sum(np.sin(2 * np.pi * 98 * j * tt) / j for j in range(1, 10)) * env_asr(m, 0.3, 0.6)
    _put(x, 20.0, lp(horn, 900), 0.4)
    return _loop_mono(_room(x, 0.3, 2.5, 3000), 2.0, -23)


def clink(rng):
    """Tasses et verres qui tintent."""
    n = samples(0.4)
    t = secs(n)
    f = rng.u(2200, 3600)
    x = sum(np.sin(2 * np.pi * f * r * t) * np.exp(-t * (10 + 8 * r)) / r for r in (1.0, 2.32, 4.25))
    return x * 0.4


def terrasse():
    """Terrasse de café : conversations, rires, tasses, percolateur."""
    rng = Rng(509)
    n = samples(26.0)
    x = voices(rng, n, 10, 100, 250, talk=0.3) * 0.8
    for _ in range(4):
        _put(x, rng.u(0, 25), laugh(rng), 0.3)
    for _ in range(12):
        _put(x, rng.u(0, 25), clink(rng), 0.4)
    m = samples(2.5)
    tt = secs(m)
    _put(x, 14.0, hp(white(rng, m), 3000) * env_asr(m, 0.1, 0.4) * (0.6 + 0.4 * smooth_noise(rng, m, 6)) * 0.12)
    return _loop_mono(_room(x, 0.15, 1.0), 1.5, -23)


def splash(rng):
    d = rng.u(0.25, 0.6)
    n = samples(d)
    t = secs(n)
    return bp(white(rng, n), 300, 5000) * np.exp(-t * rng.u(6, 12)) * (1 + smooth_noise(rng, n, 30))


def piscine():
    """Piscine en plein air : plongeons, éclaboussures, enfants, sifflet du maître-nageur."""
    rng = Rng(510)
    n = samples(26.0)
    x = voices(rng, n, 10, 180, 400, talk=0.35) * 0.6
    t = 0.3
    while t < 25:
        _put(x, t, splash(rng), rng.u(0.2, 0.5))
        t += rng.u(0.4, 2.0)
    for _ in range(4):
        _put(x, rng.u(0, 25), shriek(rng, f0=rng.u(800, 1200)), 0.18)
    _put(x, 17.0, whistle(rng, 0.5), 0.2)
    return _loop_mono(_room(x, 0.35, 1.8, 5000), 1.5, -23)


def feu():
    """Incendie : grondement et crépitements."""
    rng = Rng(511)
    n = samples(16.0)
    x = lp(brown(rng, n), 300) * (0.6 + 0.4 * smooth_noise(rng, n, 0.5)) * 0.8
    x += bp(pink(rng, n), 500, 3000) * smooth_noise(rng, n, 2.0) * 0.1
    for _ in range(260):
        m = samples(0.02)
        c = bp(white(rng, m), rng.u(800, 2000), rng.u(3000, 7000)) * env_ad(m, 0.0005, rng.u(150, 400))
        _put(x, rng.u(0, 16), c, rng.u(0.2, 1.0))
    for _ in range(3):
        m = samples(0.15)
        _put(x, rng.u(0, 16), lp(white(rng, m), 1500) * env_ad(m, 0.001, 30), 1.2)
    return _loop_mono(x, 1.0, -20)


# --- Sirènes (boucles mono, une période exacte) ------------------------------------

def _tone(f, n, ph0=0.0, bright=1.0):
    """Son de trompe (sirène électronique) : impulsions filtrées, fréquence variable (tableau)."""
    ph = ph0 + 2 * np.pi * np.cumsum(f) / SR
    x = np.zeros(n)
    for k in range(1, 9):
        x += np.sin(ph * k) * (1.0 / k) * (bright ** (k - 1))
    return x, ph[-1]


def _sirene(pattern, rep=2):
    """pattern : liste de (fréquence de départ, fréquence d'arrivée, durée)."""
    parts = []
    ph = 0.0
    for _ in range(rep):
        for f0, f1, d in pattern:
            n = samples(d)
            f = np.linspace(f0, f1, n)
            x, ph = _tone(f, n, ph, 0.7)
            parts.append(x)
    x = np.concatenate(parts)
    x = bp(x, 300, 3500) * 0.5
    return normalize(x, 0.7)


def sirene_pompiers():
    """Deux-tons des pompiers (la – si, 435 et 488 Hz)."""
    return _sirene([(435, 435, 0.6), (488, 488, 0.6)])


def sirene_police():
    """Deux-tons de la police, plus rapide."""
    return _sirene([(435, 435, 0.4), (580, 580, 0.4)], 3)


def sirene_samu():
    """Trois tons du SAMU."""
    return _sirene([(420, 420, 0.4), (516, 516, 0.4), (420, 420, 0.4), (620, 620, 0.4)])


def sirene_us():
    """Sirène américaine qui ondule (wail)."""
    return _sirene([(650, 1350, 2.0), (1350, 650, 2.0)], 1)


def sirene_japon():
    """« Pii-poo » japonais."""
    return _sirene([(960, 960, 0.6), (770, 770, 0.6)])


def hand_bell(rng, n_strokes=6, rate=0.18):
    """Cloche à main secouée (pompiers à cheval, école d'autrefois)."""
    n = samples(n_strokes * rate + 1.5)
    x = np.zeros(n)
    f = 1350.0
    for k in range(n_strokes):
        m = samples(1.2)
        t = secs(m)
        s = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * dd) for r, a, dd in
                ((1.0, 1.0, 4), (2.76, 0.5, 7), (5.4, 0.25, 12), (8.9, 0.12, 20)))
        s += bp(white(rng, m), 2000, 8000) * np.exp(-t * 200) * 0.3
        at = samples(k * rate + rng.u(-0.01, 0.01))
        x[at:at + m] += s[: n - at] * rng.u(0.7, 1.0)
    return x


def cloche_pompiers():
    """Pompiers à cheval (avant 1920) : cloche de bronze secouée sans arrêt, sur les sabots."""
    rng = Rng(520)
    d = 2.4
    n = samples(d)
    x = np.zeros(n)
    bell = hand_bell(rng, 10, 0.24)
    _put(x, 0.0, bell * 0.6)
    import ambiances_epoque as ae
    t = 0.05
    while t < d - 0.1:
        for h in (0.0, 0.035):
            _put(x, t + h, ae.hoof(rng, rng.u(0.6, 1.0)), 0.8)
        t += 0.3
    return normalize(x, 0.7)


def whistle(rng, dur=0.6):
    """Sifflet à roulette (arbitre, sergent de ville, maître-nageur)."""
    n = samples(dur)
    t = secs(n)
    trill = 0.6 + 0.4 * np.sin(2 * np.pi * 38 * t)
    f = 2900 * (1 + 0.02 * np.sin(2 * np.pi * 38 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = (np.sin(ph) + 0.1 * np.sin(2 * ph)) * trill + bp(white(rng, n), 2000, 6000) * 0.08
    return x * env_asr(n, 0.01, 0.05)


def sifflet_police():
    """Sergents de ville (avant 1920) : un coup de sifflet de temps en temps."""
    rng = Rng(521)
    n = samples(3.0)
    x = np.zeros(n)
    _put(x, 0.0, whistle(rng, 0.5))
    _put(x, 0.65, whistle(rng, 0.9))
    return normalize(x, 0.6)


# --- Saisons (nappes stéréo) ----------------------------------------------------------

def cigales():
    """Midi d'été dans le Sud : un mur de cigales qui enfle et retombe."""
    rng = Rng(530)
    n = samples(36.0)
    t = secs(n)
    buf = amb.leaves(rng, n, 0.4)
    for _ in range(9):
        f = rng.u(4300, 6500)
        am = (0.5 + 0.5 * np.sin(2 * np.pi * rng.u(90, 140) * t)) ** 3
        swell = np.clip(smooth_noise(rng, n, rng.u(0.05, 0.12)) * 1.6 - 0.4, 0, 1)
        x = bp(white(rng, n), f * 0.85, f * 1.15) * am * swell
        buf += pan(x * rng.u(0.03, 0.07), rng.u(-0.9, 0.9))
    buf = reverb(buf, 0.12, 1.0, 7000)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -25)


def crow(rng):
    """Corneille : « crôa » rauque."""
    out = []
    for _ in range(rng.i(2, 4)):
        d = rng.u(0.22, 0.32)
        n = samples(d)
        t = secs(n)
        f = rng.u(480, 620) * (1 - 0.15 * t / d)
        ph = 2 * np.pi * np.cumsum(f) / SR
        src = sum(np.sin(ph * j) / j ** 0.7 for j in range(1, 10)) + white(rng, n) * 0.5
        out.append(bp(reson(src, 1200, 3), 400, 4000) * np.sin(np.pi * t / d) ** 0.5)
        out.append(np.zeros(samples(rng.u(0.15, 0.3))))
    return np.concatenate(out)


def nature_hiver():
    """Campagne en hiver : vent froid, corneilles, un rouge-gorge, silence feutré."""
    rng = Rng(531)
    n = samples(44.0)
    buf = np.vstack([bp(pink(rng, n), 150, 1500), bp(pink(rng, n), 150, 1500)])
    buf *= (0.3 + 0.7 * smooth_noise(rng, n, 0.07) ** 2) * 0.06
    for _ in range(5):
        add_wrap(buf, samples(rng.u(0, 43)), pan(lp(crow(rng), 5000) * rng.u(0.05, 0.1), rng.u(-0.8, 0.8)))
    for _ in range(3):
        add_wrap(buf, samples(rng.u(0, 43)), pan(lp(amb.bird_trill(rng), 7000) * 0.03, rng.u(-0.8, 0.8)))
    add_wrap(buf, samples(rng.u(10, 30)), pan(amb.dog_bark(rng) * 0.03, rng.u(-0.5, 0.5)))
    buf = reverb(buf, 0.3, 2.6, 3000)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -27)


def grenouilles():
    """Mare au printemps : chœur de grenouilles et de crapauds."""
    rng = Rng(532)
    n = samples(36.0)
    buf = np.zeros((2, n))
    for _ in range(40):
        add_wrap(buf, samples(rng.u(0, 35)), pan(amb.frog(rng) * rng.u(0.03, 0.08), rng.u(-0.9, 0.9)))
    # Crapaud : note pure et longue.
    for _ in range(6):
        m = samples(rng.u(1.0, 2.0))
        tt = secs(m)
        x = np.sin(2 * np.pi * rng.u(1100, 1400) * tt) * (0.6 + 0.4 * np.sin(2 * np.pi * 40 * tt)) * np.sin(np.pi * tt / tt[-1])
        add_wrap(buf, samples(rng.u(0, 35)), pan(x * 0.02, rng.u(-0.8, 0.8)))
    buf = reverb(buf, 0.3, 1.8, 4000)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -27)


# --- Effets ---------------------------------------------------------------------------

def _stereo_fx(x, wet=0.2, room=1.6, peak=0.8):
    n = len(x)
    st = reverb(np.vstack([x, x]), wet, room, 4500)
    e = np.max(np.abs(st), axis=0)
    last = np.nonzero(e > 1e-4)[0]
    st = st[:, : last[-1] + samples(0.05)] if len(last) else st[:, :n]
    return normalize(fade(st, 0.002, 0.2), peak)


def but_foule():
    """BUT ! La tribune explose."""
    rng = Rng(540)
    n = samples(6.0)
    t = secs(n)
    env = np.clip(t / 0.25, 0, 1) * np.exp(-np.maximum(t - 1.2, 0) * 0.7)
    roar = bp(pink(rng, n), 250, 3500) * env * 0.6
    roar += voices(rng, n, 20, 150, 330, syl=(1, 2), talk=-1) * env * 1.4
    for k in range(6):
        _put(roar, 2.6 + k * 0.42, claps(rng, 60), 0.5 * np.exp(-k * 0.15))
    _put(roar, 0.4, ins.trombone_gliss(330, 340, 1.2, 0.6), 0.3)
    return _stereo_fx(roar, 0.3, 2.2, 0.8)


def sifflet_arbitre():
    rng = Rng(541)
    x = np.zeros(samples(2.0))
    _put(x, 0.0, whistle(rng, 0.3))
    _put(x, 0.4, whistle(rng, 0.3))
    _put(x, 0.8, whistle(rng, 0.9))
    return _stereo_fx(x, 0.25, 2.0, 0.6)


def sonnerie_ecole():
    """Sonnerie électrique de l'école (marteau sur timbre)."""
    rng = Rng(542)
    d = 2.2
    n = samples(d + 0.8)
    t = secs(n)
    f = 1500.0
    tone = sum(a * np.sin(2 * np.pi * f * r * t) for r, a in ((1.0, 1.0), (2.76, 0.4), (5.4, 0.2)))
    ham = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 24 * t))) * (t < d)
    x = tone * lp(ham, 300) * 0.4
    x += reson(white(rng, n), 1500, 40) * lp(ham, 300) * 0.1
    x *= np.exp(-np.maximum(t - d, 0) * 6)
    return _stereo_fx(x, 0.3, 1.8, 0.6)


def cloche_main():
    """Cloche à main de l'instituteur (avant 1920)."""
    return _stereo_fx(hand_bell(Rng(543), 8, 0.2), 0.25, 1.6, 0.6)


def succes():
    """Succès débloqué : petite fanfare de cuivres et carillon."""
    b = np.zeros((2, samples(3.0)))
    for at, m, d in [(0.0, "G4", 0.12), (0.13, "C5", 0.12), (0.26, "E5", 0.12), (0.39, "G5", 0.6)]:
        add(b, samples(at), pan(ins.brass(hz(midi(m)), d, 0.8), -0.1))
        add(b, samples(at), pan(ins.brass(hz(midi(m) - 12), d, 0.5), 0.1))
    for k, m in enumerate(["C6", "E6", "G6", "C7"]):
        add(b, samples(0.42 + k * 0.08), pan(ins.glock(hz(midi(m)), 0.3, 0.5), 0.3 - k * 0.2))
    x = reverb(b, 0.2, 1.6, 6000)
    e = np.max(np.abs(x), axis=0)
    last = np.nonzero(e > 1e-4)[0]
    x = x[:, : last[-1] + samples(0.05)]
    return normalize(fade(x, 0.001, 0.2), 0.7)


# Boucles mono jouées en 3D (assets/son/ambiance/), nappes stéréo et effets.
LIEUX = {
    "foule_stade": foule_stade, "cour_recre": cour_recre, "manege": manege, "zoo": zoo,
    "usine": usine, "ferme": ferme, "gare": gare, "port": port, "terrasse": terrasse,
    "piscine": piscine, "feu": feu,
    "sirene_pompiers": sirene_pompiers, "sirene_police": sirene_police, "sirene_samu": sirene_samu,
    "sirene_us": sirene_us, "sirene_japon": sirene_japon, "cloche_pompiers": cloche_pompiers,
    "sifflet_police": sifflet_police,
}

SAISONS = {
    "cigales": cigales, "nature_hiver": nature_hiver, "grenouilles": grenouilles,
}

EFFETS = {
    "but_foule": but_foule, "sifflet_arbitre": sifflet_arbitre, "sonnerie_ecole": sonnerie_ecole,
    "cloche_main": cloche_main, "succes": succes,
}
