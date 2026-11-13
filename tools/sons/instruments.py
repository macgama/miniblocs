"""Instruments synthétiques : chaque fonction renvoie un signal mono (numpy)."""
import numpy as np

from synth import SR, Rng, secs, samples, lp, hp, bp, env_ad, env_asr, fade, white

_rng = Rng(1234)


def _t(dur, tail):
    return secs(samples(dur + tail))


def epiano(f, dur, vel=0.8):
    """Piano électrique (synthèse FM, façon « Rhodes »)."""
    t = _t(dur, 0.9)
    idx = (1.6 + 2.2 * vel) * np.exp(-t * 2.8)
    mod = np.sin(2 * np.pi * f * t) * idx
    car = np.sin(2 * np.pi * f * t + mod)
    tine = np.sin(2 * np.pi * f * 14.0 * t) * np.exp(-t * 28) * 0.18 * vel
    bell = np.sin(2 * np.pi * f * 2.0 * t + mod * 0.5) * np.exp(-t * 4) * 0.12
    amp = np.exp(-t * (0.9 + f / 900.0))
    rel = np.ones_like(t)
    k = samples(dur)
    if k < len(t):
        rel[k:] = np.exp(-(t[k:] - t[k]) * 9)
    x = (car + bell) * amp * rel + tine
    return fade(x * vel, 0.002, 0.05)


def piano(f, dur, vel=0.8):
    """Piano acoustique simplifié : partiels un peu désaccordés, marteau."""
    t = _t(dur, 1.6)
    B = 0.00035
    x = np.zeros_like(t)
    for k in range(1, 12):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > SR / 2.2:
            break
        a = (1.0 / k ** 1.15) * (0.6 + 0.4 * vel ** (k * 0.3))
        dec = 0.6 + k * 0.55 + f / 700.0
        x += a * np.sin(2 * np.pi * fk * t + k) * np.exp(-t * dec)
    # Deux cordes légèrement désaccordées : battements.
    x += 0.25 * np.sin(2 * np.pi * f * 1.0012 * t) * np.exp(-t * (0.8 + f / 700))
    ham = lp(white(_rng, len(t)), 3000) * np.exp(-t * 90) * 0.06 * vel
    rel = np.ones_like(t)
    k = samples(dur)
    if k < len(t):
        rel[k:] = np.exp(-(t[k:] - t[k]) * 7)
    return fade((x * rel + ham) * vel * 0.5, 0.001, 0.08)


def bass(f, dur, vel=0.8):
    """Contrebasse pincée."""
    t = _t(dur, 0.25)
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) * np.exp(-t * 6) \
        + 0.12 * np.sin(6 * np.pi * f * t) * np.exp(-t * 10)
    thump = lp(white(_rng, len(t)), 900) * np.exp(-t * 60) * 0.25
    amp = np.exp(-t * 1.8)
    rel = np.ones_like(t)
    k = samples(dur)
    if k < len(t):
        rel[k:] = np.exp(-(t[k:] - t[k]) * 18)
    return fade((x * amp + thump) * rel * vel, 0.004, 0.04)


def tuba(f, dur, vel=0.8):
    """Tuba / soubassophone (pour la touche d'humour)."""
    t = _t(dur, 0.12)
    x = np.zeros_like(t)
    for k, a in enumerate([1.0, 0.7, 0.45, 0.25, 0.12], start=1):
        x += a * np.sin(2 * np.pi * f * k * t)
    e = env_asr(len(t), 0.035, 0.1)
    return lp(x * e * vel * 0.5, 1200)


def pizz(f, dur, vel=0.8):
    """Cordes pincées (pizzicato)."""
    t = _t(min(dur, 0.6), 0.5)
    x = np.zeros_like(t)
    for k in range(1, 9):
        if f * k > SR / 2.2:
            break
        x += (1.0 / k) * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (5 + k * 2.5))
    return fade(x * vel * 0.6, 0.002, 0.05)


def clarinet(f, dur, vel=0.8):
    """Clarinette : harmoniques impaires, vibrato tardif."""
    t = _t(dur, 0.12)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) * 3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.zeros_like(t)
    for k, a in [(1, 1.0), (3, 0.55), (5, 0.3), (7, 0.15), (9, 0.07), (2, 0.08)]:
        x += a * np.sin(ph * k)
    breath = bp(white(_rng, len(t)), f * 2, f * 6) * 0.03
    e = env_asr(len(t), 0.05, 0.1)
    return lp((x + breath) * e * vel * 0.45, 3500)


def bassoon(f, dur, vel=0.8):
    """Basson nasillard, joué staccato : l'instrument du conseil municipal."""
    t = _t(dur, 0.08)
    ph = 2 * np.pi * f * t
    x = np.zeros_like(t)
    for k, a in [(1, 0.6), (2, 1.0), (3, 0.8), (4, 0.5), (5, 0.35), (6, 0.2), (7, 0.1)]:
        x += a * np.sin(ph * k)
    e = env_asr(len(t), 0.025, 0.06)
    return lp(x * e * vel * 0.3, 2200)


def accordion(f, dur, vel=0.8):
    """Accordéon musette : deux anches désaccordées (battement)."""
    t = _t(dur, 0.1)
    x = np.zeros_like(t)
    for det in (1.0, 1.0045, 0.9975):
        ph = 2 * np.pi * f * det * t
        for k in range(1, 10):
            if f * k > SR / 2.5:
                break
            x += (0.9 / k ** 1.1) * np.sin(ph * k + det * k)
    e = env_asr(len(t), 0.04, 0.08)
    return lp(x * e * vel * 0.18, 4000)


def glock(f, dur, vel=0.8):
    """Glockenspiel."""
    t = _t(0.1, 1.4)
    x = np.zeros_like(t)
    for r, a, d in [(1.0, 1.0, 2.2), (2.756, 0.35, 6), (5.404, 0.18, 12), (8.933, 0.08, 20)]:
        x += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * d)
    return fade(x * vel * 0.4, 0.001, 0.05)


def marimba(f, dur, vel=0.8):
    t = _t(0.1, 0.8)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 5) + 0.25 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 18) \
        + 0.08 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 40)
    return fade(x * vel * 0.6, 0.001, 0.05)


def pad(f, dur, vel=0.6):
    """Nappe douce (trois voix désaccordées, attaque lente)."""
    t = _t(dur, 1.4)
    x = np.zeros_like(t)
    for det in (0.997, 1.0, 1.004):
        ph = 2 * np.pi * f * det * t
        for k in range(1, 7):
            x += (0.6 / k ** 1.6) * np.sin(ph * k + det * 7 * k)
    e = env_asr(len(t), 0.7, 1.3)
    return x * e * vel * 0.12


def brass(f, dur, vel=0.8):
    """Cuivre (trompette douce) : la brillance suit l'attaque."""
    t = _t(dur, 0.1)
    bright = 0.55 + 0.45 * np.exp(-t * 6)
    x = np.zeros_like(t)
    for k in range(1, 12):
        if f * k > SR / 2.3:
            break
        x += (1.0 / k) * np.sin(2 * np.pi * f * k * t) * bright ** (k * 0.6)
    vib = 1 + 0.15 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t - 0.3, 0, 1)
    e = env_asr(len(t), 0.03, 0.08)
    return lp(x * e * vib * vel * 0.3, 5000)


def trombone_gliss(f0, f1, dur, vel=0.8, vibrato=0.0):
    """Trombone qui glisse de f0 à f1 (le « wah-wah » des défaites)."""
    t = _t(dur, 0.1)
    f = f0 * (f1 / f0) ** np.clip(t / dur, 0, 1)
    f = f * (1 + vibrato * np.sin(2 * np.pi * 6.0 * t) * np.clip(t / dur * 2 - 0.3, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.zeros_like(t)
    # Sourdine « wah » : brillance qui s'ouvre et se ferme.
    wah = 0.4 + 0.6 * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.7
    for k in range(1, 10):
        x += (1.0 / k) * np.sin(ph * k) * wah ** (k * 0.7)
    e = env_asr(len(t), 0.04, 0.12)
    return lp(x * e * vel * 0.32, 2500)


# --- Percussions --------------------------------------------------------------

def kick(vel=0.8):
    t = secs(samples(0.35))
    f = 48 + 90 * np.exp(-t * 30)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * vel


def brush(vel=0.6, long=False):
    """Balai sur la caisse claire."""
    n = samples(0.35 if long else 0.18)
    t = secs(n)
    x = bp(white(_rng, n), 1500, 7000)
    e = np.clip(t / (0.04 if long else 0.008), 0, 1) * np.exp(-t * (9 if long else 22))
    return x * e * vel * 0.25


def hat(vel=0.5, open_=False):
    n = samples(0.25 if open_ else 0.06)
    t = secs(n)
    x = hp(white(_rng, n), 7000)
    return x * np.exp(-t * (14 if open_ else 70)) * vel * 0.2


def shaker(vel=0.4):
    n = samples(0.09)
    t = secs(n)
    x = bp(white(_rng, n), 4000, 10000)
    e = np.sin(np.pi * t / t[-1]) ** 2
    return x * e * vel * 0.15


def woodblock(f=900, vel=0.6):
    t = secs(samples(0.12))
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 45) + 0.4 * np.sin(2 * np.pi * f * 2.7 * t) * np.exp(-t * 70)
    return x * vel * 0.5


def cymbal(vel=0.6, seconds=2.5):
    n = samples(seconds)
    t = secs(n)
    x = hp(white(_rng, n), 3500)
    for f in (3150, 4870, 6230, 7810):
        x += 0.3 * np.sin(2 * np.pi * f * t + f)
    return x * np.exp(-t * 2.2) * vel * 0.15


def snare(vel=0.7):
    n = samples(0.22)
    t = secs(n)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    rattle = bp(white(_rng, n), 1800, 9000) * np.exp(-t * 16)
    return (body * 0.6 + rattle * 0.5) * vel * 0.5


def bell(f, seconds=6.0, vel=0.8):
    """Cloche d'église : partiels de cloche (bourdon, tierce mineure, quinte…)."""
    n = samples(seconds)
    t = secs(n)
    x = np.zeros(n)
    for r, a, d in [(0.5, 0.5, 0.35), (1.0, 1.0, 0.6), (1.183, 0.6, 0.9), (1.506, 0.35, 1.2),
                    (2.0, 0.45, 1.4), (2.514, 0.2, 2.2), (2.662, 0.18, 2.4), (3.011, 0.12, 3.0), (4.166, 0.08, 4)]:
        beat = 1 + 0.08 * np.sin(2 * np.pi * (0.7 + r * 0.3) * t)
        x += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * d) * beat
    strike = bp(white(_rng, n), 1500, 6000) * np.exp(-t * 80) * 0.3
    return fade((x + strike) * vel * 0.3, 0.001, 0.3)
