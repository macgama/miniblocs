"""Boucles d'ambiance : nature (jour, nuit), ville (jour, nuit), trafic, pluie,
vent, mer et chantier. Chaque fonction renvoie une boucle stéréo sans couture."""
import numpy as np

from synth import (SR, Rng, secs, samples, lp, hp, bp, reson, pink, brown, white, smooth_noise,
                   env_ad, env_asr, fade, pan, add_wrap, loopify, rms_normalize, reverb)
import instruments as ins


# --- Oiseaux, insectes, animaux ----------------------------------------------

def bird_trill(rng):
    """Petit passereau : trille de notes très rapides."""
    f0 = rng.u(3200, 5200)
    notes = rng.i(4, 9)
    d = rng.u(0.05, 0.09)
    gap = rng.u(0.015, 0.04)
    out = []
    for k in range(notes):
        n = samples(d)
        t = secs(n)
        f = f0 * (1 + rng.u(-0.04, 0.04)) + rng.u(-900, 900) * (t / d)
        ph = 2 * np.pi * np.cumsum(f) / SR
        out.append(np.sin(ph) * np.sin(np.pi * t / d) ** 2)
        out.append(np.zeros(samples(gap)))
    return np.concatenate(out)


def bird_whistle(rng):
    """Merle : phrase sifflée qui glisse de note en note."""
    out = []
    base = rng.u(1700, 2600)
    for _ in range(rng.i(3, 6)):
        d = rng.u(0.08, 0.28)
        n = samples(d)
        t = secs(n)
        a = base * rng.u(0.8, 1.35)
        b = base * rng.u(0.8, 1.35)
        f = a + (b - a) * (t / d) ** rng.u(0.5, 2)
        f = f * (1 + 0.02 * np.sin(2 * np.pi * rng.u(20, 40) * t))
        ph = 2 * np.pi * np.cumsum(f) / SR
        e = np.sin(np.pi * t / d) ** 1.5
        out.append((np.sin(ph) + 0.15 * np.sin(2 * ph)) * e)
        out.append(np.zeros(samples(rng.u(0.02, 0.1))))
    return np.concatenate(out)


def bird_tit(rng):
    """Mésange : « ti-tu ti-tu ti-tu »."""
    hi = rng.u(4800, 6200)
    lo = hi * rng.u(0.6, 0.72)
    out = []
    for _ in range(rng.i(3, 5)):
        for f in (hi, lo):
            d = 0.07
            t = secs(samples(d))
            out.append(np.sin(2 * np.pi * f * t) * np.sin(np.pi * t / d) ** 2)
            out.append(np.zeros(samples(0.04)))
        out.append(np.zeros(samples(0.08)))
    return np.concatenate(out)


def cuckoo(rng):
    """Coucou dans le lointain (deux notes, tierce majeure descendante)."""
    out = []
    for _ in range(rng.i(2, 3)):
        for f, d in ((725, 0.22), (580, 0.38)):
            t = secs(samples(d))
            x = np.sin(2 * np.pi * f * t) + 0.1 * np.sin(4 * np.pi * f * t)
            out.append(x * np.sin(np.pi * t / d) ** 0.8)
            out.append(np.zeros(samples(0.09)))
        out.append(np.zeros(samples(0.7)))
    return lp(np.concatenate(out), 2500)


def pigeon(rng):
    """Pigeon des villes : « rrou-rrouuu »."""
    out = []
    for d in (0.25, 0.6):
        n = samples(d)
        t = secs(n)
        f = 380 * (1 + 0.15 * np.sin(np.pi * t / d))
        ph = 2 * np.pi * np.cumsum(f) / SR
        am = 0.6 + 0.4 * np.sin(2 * np.pi * 26 * t)
        out.append(np.sin(ph) * am * np.sin(np.pi * t / d))
        out.append(np.zeros(samples(0.12)))
    return lp(np.concatenate(out), 1500) * 0.7


def cricket(rng, n):
    """Grillon : salves d'impulsions vers 4,5 kHz, toute la boucle."""
    f = rng.u(4200, 5200)
    t = secs(n)
    pulse_rate = rng.u(26, 34)
    burst_period = rng.u(0.35, 0.6)
    pulses_per_burst = rng.i(3, 5)
    burst = (t % burst_period) < (pulses_per_burst / pulse_rate)
    pulse = np.sin(np.pi * ((t * pulse_rate) % 1.0)) ** 4
    x = np.sin(2 * np.pi * f * t) * pulse * burst
    # Il s'arrête de temps en temps.
    return x * (smooth_noise(rng, n, 0.15) > 0.25)


def owl(rng):
    """Chouette hulotte : « hou… hou-hou-hou-houuu »."""
    out = []
    for f, d, g in ((420, 0.45, 1.1), (430, 0.18, 0.12), (410, 0.18, 0.12), (400, 0.7, 0.0)):
        n = samples(d)
        t = secs(n)
        ff = f * (1 - 0.06 * t / d)
        ph = 2 * np.pi * np.cumsum(ff) / SR
        breath = bp(white(rng, n), 300, 900) * 0.08
        out.append((np.sin(ph) + breath) * np.sin(np.pi * t / d) ** 0.7)
        out.append(np.zeros(samples(g)))
    return lp(np.concatenate(out), 1200)


def dog_bark(rng):
    """Chien au loin : deux ou trois aboiements."""
    out = []
    for _ in range(rng.i(2, 3)):
        d = rng.u(0.12, 0.18)
        n = samples(d)
        t = secs(n)
        f = rng.u(380, 480) * (1 + 0.4 * np.exp(-t * 25))
        ph = 2 * np.pi * np.cumsum(f) / SR
        voiced = np.zeros(n)
        for k in range(1, 8):
            voiced += np.sin(ph * k) / k
        x = reson(voiced, 900, 4) + reson(voiced, 1800, 5) * 0.5 + bp(white(rng, n), 500, 2500) * 0.3
        out.append(x * env_ad(n, 0.005, 18))
        out.append(np.zeros(samples(rng.u(0.18, 0.35))))
    return lp(np.concatenate(out), 2200)


def frog(rng):
    out = []
    for _ in range(rng.i(2, 4)):
        d = 0.16
        n = samples(d)
        t = secs(n)
        x = np.sign(np.sin(2 * np.pi * 220 * t)) * (0.5 + 0.5 * np.sin(2 * np.pi * 45 * t))
        out.append(reson(x, 700, 3) * np.sin(np.pi * t / d))
        out.append(np.zeros(samples(0.3)))
    return lp(np.concatenate(out), 1500)


# --- Ambiances ---------------------------------------------------------------

def leaves(rng, n, level=1.0):
    """Vent dans les feuilles."""
    x = np.vstack([bp(pink(rng, n), 400, 4500), bp(pink(rng, n), 400, 4500)])
    m = 0.3 + 0.7 * smooth_noise(rng, n, 0.12) ** 1.5
    return x * m * 0.05 * level


def nature_jour():
    rng = Rng(11)
    n = samples(48.0)
    buf = leaves(rng, n, 1.0)
    calls = [bird_trill, bird_whistle, bird_tit]
    t = 0.3
    while t < 46.0:
        f = rng.choice(calls)
        call = f(rng) * rng.u(0.05, 0.14)
        call = lp(call, 7000)
        add_wrap(buf, samples(t), pan(call, rng.u(-0.8, 0.8)))
        t += rng.u(0.6, 2.4)
    add_wrap(buf, samples(rng.u(10, 30)), pan(cuckoo(rng) * 0.05, rng.u(-0.6, 0.6)))
    buf = reverb(buf, 0.18, 1.6, 5000)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -24)


def nature_nuit():
    rng = Rng(12)
    n = samples(44.0)
    buf = leaves(rng, n, 0.5)
    for _ in range(6):
        add_wrap(buf, 0, pan(cricket(rng, n) * rng.u(0.012, 0.04), rng.u(-0.9, 0.9)))
    add_wrap(buf, samples(rng.u(5, 20)), pan(owl(rng) * 0.12, rng.u(-0.6, 0.6)))
    add_wrap(buf, samples(rng.u(25, 38)), pan(owl(rng) * 0.08, rng.u(-0.6, 0.6)))
    for _ in range(3):
        add_wrap(buf, samples(rng.u(0, 40)), pan(frog(rng) * 0.03, rng.u(-0.8, 0.8)))
    buf = reverb(buf, 0.25, 2.2, 4000)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -27)


def murmur(rng, n, voices=14):
    """Brouhaha de passants : des voix filtrées qui parlent par syllabes."""
    buf = np.zeros((2, n))
    t = secs(n)
    for _ in range(voices):
        f0 = rng.u(95, 230)
        pitch = f0 * (1 + 0.12 * (smooth_noise(rng, n, 3.0) - 0.5))
        ph = 2 * np.pi * np.cumsum(pitch) / SR
        src = np.zeros(n)
        for k in range(1, 14):
            src += np.sin(ph * k) / k
        src += white(rng, n) * 0.15
        # Formants qui bougent : voyelles.
        v = (reson(src, rng.u(500, 800), 3) + reson(src, rng.u(1100, 1800), 4) * 0.7
             + reson(src, rng.u(2400, 2900), 6) * 0.3)
        syl = (smooth_noise(rng, n, rng.u(4, 6.5)) > 0.45).astype(float)
        syl = lp(syl, 18, 1)
        talk = smooth_noise(rng, n, 0.25) > 0.35
        x = v * syl * talk
        buf += pan(lp(x, 2600) * rng.u(0.3, 1.0), rng.u(-0.9, 0.9))
    return buf / np.sqrt(voices)


def car_pass(rng, dur=None, close=1.0, kind="voiture"):
    """Un véhicule qui passe de gauche à droite (ou l'inverse) avec effet Doppler."""
    dur = dur or rng.u(3.5, 6.0)
    n = samples(dur)
    t = secs(n)
    v = rng.u(10, 16)  # m/s
    d0 = rng.u(5, 14) / close
    x_pos = (t - dur / 2) * v
    dist = np.sqrt(x_pos ** 2 + d0 ** 2)
    radial = x_pos / dist * v
    dop = 343.0 / (343.0 + radial)
    if kind == "scooter":
        f_eng = rng.u(110, 140)
    elif kind == "camion":
        f_eng = rng.u(28, 40)
    else:
        f_eng = rng.u(38, 60)
    ph = 2 * np.pi * np.cumsum(f_eng * dop) / SR
    eng = np.zeros(n)
    for k in range(1, 12 if kind != "scooter" else 18):
        eng += np.sin(ph * k + k) / k ** (0.9 if kind == "scooter" else 1.3)
    eng = lp(eng, 1400 if kind != "scooter" else 3500)
    tyre = bp(pink(rng, n), 300, 2500) * (1.6 if kind == "camion" else 1.0)
    amp = 1.0 / (dist / d0) ** 1.6 * np.sin(np.pi * t / dur) ** 2
    x = (eng * (0.4 if kind != "scooter" else 0.8) + tyre) * amp
    side = -1 if rng.u() < 0.5 else 1
    p = np.clip(x_pos / (d0 * 2.5), -1, 1) * side
    left = x * np.cos((p + 1) * np.pi / 4)
    right = x * np.sin((p + 1) * np.pi / 4)
    out = np.vstack([left, right])
    return fade(out, 0.3, 0.3) * (1.4 if kind == "camion" else 1.0)


def horn(rng):
    d = rng.u(0.2, 0.5)
    n = samples(d)
    t = secs(n)
    x = np.zeros(n)
    for f in (420, 520):
        ph = 2 * np.pi * f * t
        for k in range(1, 8):
            x += np.sin(ph * k) / k
    return lp(x * env_asr(n, 0.01, 0.04), 2500) * 0.3


def bike_bell(rng):
    out = []
    for _ in range(2):
        n = samples(0.6)
        t = secs(n)
        x = np.zeros(n)
        for r, a, dd in ((1.0, 1.0, 5), (2.32, 0.5, 9), (3.8, 0.3, 14)):
            x += a * np.sin(2 * np.pi * 2650 * r * t) * np.exp(-t * dd)
        out.append(x[: samples(0.18)])
    tail = np.zeros(samples(0.4))
    return np.concatenate(out + [tail]) * 0.25


def door_slam(rng):
    n = samples(0.4)
    t = secs(n)
    x = lp(white(rng, n), 700) * np.exp(-t * 30) + np.sin(2 * np.pi * 90 * t) * np.exp(-t * 25)
    return x * 0.5


def ville_jour():
    rng = Rng(21)
    n = samples(52.0)
    rumble = np.vstack([lp(brown(rng, n), 220), lp(brown(rng, n), 220)]) * 0.35
    mid = np.vstack([bp(pink(rng, n), 200, 1800), bp(pink(rng, n), 200, 1800)]) * 0.06
    buf = rumble + mid * (0.6 + 0.4 * smooth_noise(rng, n, 0.1))
    buf += murmur(rng, n) * 0.5
    t = 1.0
    while t < 50:
        add_wrap(buf, samples(t), car_pass(rng, close=0.35) * 0.22)
        t += rng.u(2.0, 6.0)
    for _ in range(2):
        add_wrap(buf, samples(rng.u(3, 48)), pan(horn(rng) * 0.25, rng.u(-0.8, 0.8)))
    add_wrap(buf, samples(rng.u(5, 45)), pan(bike_bell(rng) * 0.5, rng.u(-0.6, 0.6)))
    for _ in range(3):
        add_wrap(buf, samples(rng.u(2, 48)), pan(pigeon(rng) * 0.12, rng.u(-0.9, 0.9)))
    for _ in range(2):
        add_wrap(buf, samples(rng.u(2, 48)), pan(door_slam(rng) * 0.12, rng.u(-0.9, 0.9)))
    for _ in range(4):
        add_wrap(buf, samples(rng.u(0, 48)), pan(lp(bird_trill(rng), 6000) * 0.04, rng.u(-0.9, 0.9)))
    buf = reverb(buf, 0.3, 1.4, 3500)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -23)


def ville_nuit():
    rng = Rng(22)
    n = samples(48.0)
    t = secs(n)
    rumble = np.vstack([lp(brown(rng, n), 160), lp(brown(rng, n), 160)]) * 0.3
    hum = (np.sin(2 * np.pi * 50 * t) + 0.3 * np.sin(2 * np.pi * 100 * t)) * 0.004
    buf = rumble + hum
    for _ in range(3):
        add_wrap(buf, samples(rng.u(2, 44)), car_pass(rng, close=0.25, dur=rng.u(5, 8)) * 0.15)
    add_wrap(buf, samples(rng.u(4, 20)), pan(dog_bark(rng) * 0.06, rng.u(-0.8, 0.8)))
    add_wrap(buf, samples(rng.u(26, 44)), pan(dog_bark(rng) * 0.04, rng.u(-0.8, 0.8)))
    for _ in range(3):
        add_wrap(buf, 0, pan(cricket(rng, n) * rng.u(0.004, 0.012), rng.u(-0.9, 0.9)))
    buf = reverb(buf, 0.35, 2.4, 3000)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -28)


def trafic():
    rng = Rng(31)
    n = samples(40.0)
    buf = np.vstack([lp(brown(rng, n), 300), lp(brown(rng, n), 300)]) * 0.25
    t = 0.0
    while t < 39:
        kind = "voiture"
        r = rng.u()
        if r < 0.1:
            kind = "camion"
        elif r < 0.17:
            kind = "scooter"
        add_wrap(buf, samples(t), car_pass(rng, kind=kind) * rng.u(0.5, 1.0))
        t += rng.u(0.8, 3.0)
    buf = reverb(buf, 0.15, 1.0, 3000)[:, :n]
    return rms_normalize(loopify(buf, 2.5), -21)


def pluie():
    rng = Rng(41)
    n = samples(26.0)
    hiss = np.vstack([bp(white(rng, n), 900, 9000), bp(white(rng, n), 900, 9000)]) * 0.12
    body = np.vstack([lp(pink(rng, n), 700), lp(pink(rng, n), 700)]) * 0.25
    buf = hiss + body
    drops = np.zeros((2, n))
    k = 0
    for _ in range(4500):
        pos = rng.i(0, n - samples(0.02))
        f = rng.u(1800, 7000)
        m = samples(0.012)
        t = secs(m)
        d = np.sin(2 * np.pi * f * t) * np.exp(-t * rng.u(250, 600)) * rng.u(0.02, 0.12)
        side = rng.u(-1, 1)
        drops[0, pos:pos + m] += d * (1 - side) * 0.5
        drops[1, pos:pos + m] += d * (1 + side) * 0.5
        k += 1
    # Gouttes plus grosses (gouttières, tôle).
    for _ in range(120):
        pos = rng.i(0, n - samples(0.1))
        m = samples(0.08)
        t = secs(m)
        f = rng.u(400, 1200)
        d = np.sin(2 * np.pi * f * (1 + 0.6 * t) * t) * np.exp(-t * 60) * rng.u(0.05, 0.15)
        drops[rng.i(0, 1), pos:pos + m] += d
    buf += drops
    buf = reverb(buf, 0.2, 1.2, 6000)[:, :n]
    return rms_normalize(loopify(buf, 2.0), -20)


def vent():
    rng = Rng(51)
    n = samples(36.0)
    buf = np.zeros((2, n))
    gust = smooth_noise(rng, n, 0.18)
    for c in range(2):
        p = pink(rng, n)
        low = lp(p, 250) * 0.8
        g = gust ** 1.8
        # Sifflement : bandes dont le poids suit les rafales.
        w1 = bp(p, 350, 600) * (g * 0.6)
        w2 = bp(p, 600, 1100) * (g ** 2 * 0.5)
        w3 = reson(p, 780 + c * 40, 18) * (g ** 3 * 0.25)
        buf[c] = (low * (0.4 + 0.6 * g) + w1 + w2 + w3)
    return rms_normalize(loopify(buf, 3.0), -22)


def mer():
    rng = Rng(61)
    n = samples(40.0)
    t = secs(n)
    buf = np.zeros((2, n))
    starts = []
    s = 0.5
    while s < 39:
        starts.append(s)
        s += rng.u(6.0, 9.5)
    for s in starts:
        dur = rng.u(5.0, 7.0)
        m = samples(dur)
        tt = secs(m)
        swell = np.clip(tt / 2.2, 0, 1) ** 2 * np.exp(-np.clip(tt - 2.2, 0, None) * 0.9)
        crash = np.exp(-np.clip(tt - 2.3, 0, None) * 1.8) * np.clip((tt - 1.7) / 0.6, 0, 1) ** 2
        for c in range(2):
            x = lp(pink(rng, m), 900) * swell * 0.8 + hp(white(rng, m), 2500) * crash * 0.18 \
                + bp(white(rng, m), 600, 3000) * crash * 0.2
            add_wrap(buf[c:c + 1], samples(s + c * 0.05), x[None, :])
    buf += np.vstack([lp(brown(rng, n), 200), lp(brown(rng, n), 200)]) * 0.12
    buf = reverb(buf, 0.2, 1.8, 4000)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -22)


# --- Chantier (mono, joué en 3D sur les chantiers proches) ---------------------

def hammer_hit(rng, metal=False):
    n = samples(0.35)
    t = secs(n)
    x = lp(white(rng, n), 4000) * np.exp(-t * 120) * 0.6
    if metal:
        for f in (1240, 2730, 4110):
            x += np.sin(2 * np.pi * f * rng.u(0.97, 1.03) * t) * np.exp(-t * 18) * 0.3
    else:
        x += reson(white(rng, n), rng.u(180, 260), 8) * np.exp(-t * 35) * 0.5
        x += np.sin(2 * np.pi * rng.u(400, 600) * t) * np.exp(-t * 50) * 0.4
    return x


def saw_cut(rng):
    d = rng.u(2.0, 3.2)
    n = samples(d)
    t = secs(n)
    spin = np.clip(t / 0.4, 0, 1)
    f = 2900 * (0.6 + 0.4 * spin) * (1 - 0.12 * ((t > 0.7) & (t < d - 0.5)))
    ph = 2 * np.pi * np.cumsum(f / 20) / SR
    x = np.zeros(n)
    for k in range(1, 40):
        x += np.sin(ph * k * 1.0) / k
    cut = bp(white(rng, n), 2000, 8000) * ((t > 0.7) & (t < d - 0.5)) * 0.5
    return lp(x * 0.25 + cut, 9000) * env_asr(n, 0.05, 0.6)


def drill(rng):
    d = rng.u(1.0, 1.8)
    n = samples(d)
    t = secs(n)
    f = 1600 * (1 + 0.03 * np.sin(2 * np.pi * 7 * t))
    ph = 2 * np.pi * np.cumsum(f / 8) / SR
    x = np.zeros(n)
    for k in range(1, 20):
        x += np.sin(ph * k) / k ** 1.2
    am = 0.7 + 0.3 * np.sin(2 * np.pi * 31 * t)
    return x * am * env_asr(n, 0.08, 0.15) * 0.4


def beeper(rng, count=6):
    """Bip de recul du camion : « bip… bip… bip… »."""
    out = []
    for _ in range(count):
        n = samples(0.45)
        t = secs(n)
        x = np.sin(2 * np.pi * 1050 * t) + 0.2 * np.sin(2 * np.pi * 3150 * t)
        out.append(x * env_asr(n, 0.01, 0.02) * 0.3)
        out.append(np.zeros(samples(0.5)))
    return np.concatenate(out)


def diesel(rng, n):
    t = secs(n)
    f = 28 * (1 + 0.05 * smooth_noise(rng, n, 0.4))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.zeros(n)
    for k in range(1, 14):
        x += np.sin(ph * k + k) / k
    knock = (np.sin(ph * 0.5) > 0.95) * lp(white(rng, n), 2000) * 0.3
    return lp(x + knock, 900) * 0.3


def chantier():
    rng = Rng(71)
    n = samples(34.0)
    buf = np.zeros(n)
    buf += diesel(rng, n) * 0.35
    t = 0.5
    while t < 33:
        r = rng.u()
        if r < 0.45:
            metal = rng.u() < 0.3
            for k in range(rng.i(3, 7)):
                h = hammer_hit(rng, metal) * rng.u(0.6, 1.0)
                add_wrap(buf[None, :], samples(t + k * rng.u(0.42, 0.55)), h[None, :])
            t += rng.u(3.0, 5.0)
        elif r < 0.62:
            add_wrap(buf[None, :], samples(t), saw_cut(rng)[None, :] * 0.5)
            t += rng.u(3.5, 5.0)
        elif r < 0.8:
            add_wrap(buf[None, :], samples(t), drill(rng)[None, :] * 0.5)
            t += rng.u(2.0, 3.0)
        elif r < 0.9:
            add_wrap(buf[None, :], samples(t), beeper(rng, rng.i(4, 7))[None, :] * 0.6)
            t += rng.u(4.0, 6.0)
        else:
            m = hammer_hit(rng, True) * 0.8
            add_wrap(buf[None, :], samples(t), m[None, :])
            t += rng.u(1.0, 2.0)
    out = reverb(buf, 0.15, 0.9, 5000)[0, :n]
    return rms_normalize(loopify(out, 1.5), -18)


ALL = {
    "nature_jour": nature_jour,
    "nature_nuit": nature_nuit,
    "ville_jour": ville_jour,
    "ville_nuit": ville_nuit,
    "trafic": trafic,
    "pluie": pluie,
    "vent": vent,
    "mer": mer,
    "chantier": chantier,
}
