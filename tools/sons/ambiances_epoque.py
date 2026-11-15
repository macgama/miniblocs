"""Ambiances du XIXe siècle : la ville avant le moteur (sabots sur les pavés, roues
cerclées de fer, forge, crieurs), la nuit à la lanterne, le trafic des attelages,
et le sifflet de la locomotive à vapeur (effet ponctuel)."""
import numpy as np

from synth import (SR, Rng, secs, samples, lp, hp, bp, reson, pink, brown, white, smooth_noise,
                   env_asr, fade, pan, add_wrap, loopify, rms_normalize, reverb, normalize)
from ambiances import murmur, pigeon, dog_bark, cricket, owl, bird_trill


def hoof(rng, vel=1.0):
    """Un sabot ferré sur le pavé : claquement sec et petit choc grave."""
    n = samples(0.09)
    t = secs(n)
    f = rng.u(330, 460)
    x = bp(white(rng, n), 800, 3200) * np.exp(-t * 80) + np.sin(2 * np.pi * f * t) * np.exp(-t * 60) * 0.5
    return x * vel


def horse_steps(rng, dur, pace="trot"):
    """Pas d'un cheval : trot (deux temps) ou pas (quatre temps), irréguliers."""
    n = samples(dur)
    x = np.zeros(n)
    period = 0.36 if pace == "trot" else 0.62
    t = rng.u(0, 0.1)
    while t < dur - 0.1:
        hits = [0.0, 0.035] if pace == "trot" else [0.0, 0.16, 0.31, 0.45]
        for h in hits:
            s = samples(t + h + rng.u(-0.008, 0.008))
            hf = hoof(rng, rng.u(0.6, 1.0))
            e = min(n, s + len(hf))
            if s < n:
                x[s:e] += hf[: e - s]
        t += period * rng.u(0.95, 1.05)
    return x


def iron_wheels(rng, n):
    """Roulement des roues cerclées de fer : grondement granuleux et cliquetis."""
    rum = lp(brown(rng, n), 260) * 0.7
    grit = bp(white(rng, n), 900, 4000) * (smooth_noise(rng, n, 30.0) > 0.55) * 0.18
    rattle = bp(pink(rng, n), 1500, 5000) * (0.3 + 0.7 * smooth_noise(rng, n, 7.0)) * 0.1
    return rum + grit + rattle


def carriage_pass(rng, dur=None, close=1.0, heavy=False):
    """Une voiture à cheval qui passe : sabots, roues, harnais qui tinte."""
    dur = dur or rng.u(5.0, 8.0)
    n = samples(dur)
    t = secs(n)
    v = rng.u(2.5, 4.5) if not heavy else rng.u(1.3, 2.2)
    d0 = rng.u(3, 9) / close
    x_pos = (t - dur / 2) * v
    dist = np.sqrt(x_pos ** 2 + d0 ** 2)
    pace = "pas" if heavy or rng.u() < 0.3 else "trot"
    x = horse_steps(rng, dur, pace) * 0.9
    if heavy:
        x += horse_steps(rng, dur, pace) * 0.7  # attelage à deux chevaux
    x += iron_wheels(rng, n) * (1.5 if heavy else 1.0)
    # Grelots ou gourmette du harnais.
    jingle = np.zeros(n)
    for k in range(int(dur * 2)):
        s = samples(rng.u(0, dur - 0.2))
        m = samples(0.15)
        tt = secs(m)
        j = np.sin(2 * np.pi * rng.u(2800, 3600) * tt) * np.exp(-tt * 30) * 0.05
        jingle[s:s + m] += j[: max(0, min(m, n - s))]
    x += jingle
    amp = np.clip((d0 / dist) ** 1.4, 0, 1) * np.sin(np.pi * t / dur) ** 1.5
    x = x * amp
    side = -1 if rng.u() < 0.5 else 1
    p = np.clip(x_pos / (d0 * 2.5), -1, 1) * side
    out = np.vstack([x * np.cos((p + 1) * np.pi / 4), x * np.sin((p + 1) * np.pi / 4)])
    return fade(out, 0.4, 0.4)


def neigh(rng):
    """Hennissement lointain."""
    n = samples(1.3)
    t = secs(n)
    f = 520 + 180 * np.sin(np.pi * t / 1.3) + 60 * np.sin(2 * np.pi * 14 * t) * (t > 0.3)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(ph * k) / k ** 1.2 for k in range(1, 8))
    x = reson(x, 900, 3) + reson(x, 2200, 5) * 0.5
    return lp(x * env_asr(n, 0.08, 0.5), 3500) * 0.3


def anvil(rng, n_hits=None):
    """Le maréchal-ferrant frappe l'enclume : tintement aigu qui résonne."""
    hits = n_hits or rng.i(3, 6)
    out = []
    for k in range(hits):
        m = samples(0.55)
        t = secs(m)
        x = np.zeros(m)
        for r, a, d in ((1.0, 1.0, 9), (2.71, 0.6, 14), (4.13, 0.35, 20), (5.4, 0.2, 26)):
            x += a * np.sin(2 * np.pi * 1180 * r * t) * np.exp(-t * d)
        x += bp(white(rng, m), 2000, 7000) * np.exp(-t * 90) * 0.6
        out.append(x[: samples(rng.u(0.42, 0.55))] * rng.u(0.7, 1.0))
    return np.concatenate(out) * 0.25


def crier(rng):
    """Un crieur de rue (« Marchand d'habits ! », « Vitrier ! ») : voix chantée lointaine."""
    n = samples(rng.u(1.4, 2.0))
    t = secs(n)
    f0 = rng.u(160, 230)
    steps = rng.i(2, 4)
    notes = np.repeat([f0 * rng.choice([1.0, 1.125, 1.25, 1.5]) for _ in range(steps)], n // steps + 1)[:n]
    notes = lp(notes, 12, 1)
    ph = 2 * np.pi * np.cumsum(notes) / SR
    src = sum(np.sin(ph * k) / k for k in range(1, 16))
    v = reson(src, rng.u(600, 800), 3) + reson(src, rng.u(1100, 1500), 4) * 0.7 + reson(src, 2600, 6) * 0.3
    return lp(v * env_asr(n, 0.08, 0.35), 3000) * 0.18


def ville_jour_ancien():
    rng = Rng(121)
    n = samples(56.0)
    # Pas de grondement de moteurs : un fond bien plus léger qu'en ville moderne.
    buf = np.vstack([lp(brown(rng, n), 180), lp(brown(rng, n), 180)]) * 0.12
    buf += murmur(rng, n) * 0.6
    t = 1.0
    while t < 52:
        add_wrap(buf, samples(t), carriage_pass(rng, close=0.5, heavy=rng.u() < 0.25) * 0.3)
        t += rng.u(5.0, 11.0)
    for _ in range(2):
        add_wrap(buf, samples(rng.u(2, 50)), pan(anvil(rng) * 0.25, rng.u(-0.9, 0.9)))
    for _ in range(2):
        add_wrap(buf, samples(rng.u(3, 50)), pan(crier(rng), rng.u(-0.8, 0.8)))
    add_wrap(buf, samples(rng.u(10, 45)), pan(neigh(rng) * 0.3, rng.u(-0.8, 0.8)))
    for _ in range(4):
        add_wrap(buf, samples(rng.u(2, 52)), pan(pigeon(rng) * 0.12, rng.u(-0.9, 0.9)))
    for _ in range(6):
        add_wrap(buf, samples(rng.u(0, 52)), pan(lp(bird_trill(rng), 6000) * 0.05, rng.u(-0.9, 0.9)))
    buf = reverb(buf, 0.3, 1.3, 3500)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -24)


def ville_nuit_ancien():
    rng = Rng(122)
    n = samples(50.0)
    buf = np.vstack([lp(brown(rng, n), 120), lp(brown(rng, n), 120)]) * 0.08
    add_wrap(buf, samples(rng.u(5, 20)), carriage_pass(rng, close=0.3, dur=rng.u(7, 10)) * 0.15)
    add_wrap(buf, samples(rng.u(28, 40)), pan(horse_steps(rng, 4.0, "pas") * 0.05, rng.u(-0.7, 0.7)))
    add_wrap(buf, samples(rng.u(4, 22)), pan(dog_bark(rng) * 0.06, rng.u(-0.8, 0.8)))
    add_wrap(buf, samples(rng.u(30, 46)), pan(owl(rng) * 0.05, rng.u(-0.8, 0.8)))
    for _ in range(4):
        add_wrap(buf, 0, pan(cricket(rng, n) * rng.u(0.006, 0.014), rng.u(-0.9, 0.9)))
    buf = reverb(buf, 0.35, 2.4, 3000)[:, :n]
    return rms_normalize(loopify(buf, 3.0), -29)


def trafic_attelages():
    rng = Rng(131)
    n = samples(44.0)
    buf = np.vstack([lp(brown(rng, n), 200), lp(brown(rng, n), 200)]) * 0.1
    t = 0.0
    while t < 42:
        heavy = rng.u() < 0.3
        add_wrap(buf, samples(t), carriage_pass(rng, heavy=heavy) * rng.u(0.5, 1.0))
        t += rng.u(1.8, 4.5)
    for _ in range(2):
        add_wrap(buf, samples(rng.u(2, 42)), pan(neigh(rng) * 0.25, rng.u(-0.8, 0.8)))
    # Claquement de fouet du cocher.
    for _ in range(3):
        m = samples(0.06)
        tt = secs(m)
        w = hp(white(rng, m), 1500) * np.exp(-tt * 120) * 0.6
        add_wrap(buf, samples(rng.u(1, 42)), pan(w, rng.u(-0.7, 0.7)))
    buf = reverb(buf, 0.15, 1.0, 3000)[:, :n]
    return rms_normalize(loopify(buf, 2.5), -22)


def sifflet_vapeur():
    """Sifflet de locomotive à vapeur : accord de trois tuyaux, attaque soufflée."""
    rng = Rng(141)
    dur = 2.6
    n = samples(dur + 1.5)
    t = secs(n)
    env = np.clip(t / 0.15, 0, 1) * np.clip((dur - t) / 0.4, 0, 1)
    pitch = 1.0 - 0.03 * np.exp(-t * 6)  # le sifflet « monte » en pression
    x = np.zeros(n)
    for f, a in ((440.0, 1.0), (554.4, 0.8), (659.3, 0.7)):
        ph = 2 * np.pi * np.cumsum(f * pitch) / SR
        x += a * (np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph))
    breath = bp(white(rng, n), 1500, 6000) * 0.25
    steam = bp(white(rng, n), 300, 3000) * np.exp(-np.maximum(t - dur, 0) * 3) * (t > dur - 0.2) * 0.3
    x = (x * 0.25 + breath) * env + steam
    stereo = np.vstack([x, x])
    stereo = reverb(stereo, 0.35, 2.5, 4000)[:, :n]
    return normalize(stereo, 0.8)


ALL = {
    "ville_jour_ancien": ville_jour_ancien,
    "ville_nuit_ancien": ville_nuit_ancien,
    "trafic_attelages": trafic_attelages,
}

EFFETS = {
    "sifflet_vapeur": sifflet_vapeur,
}
