"""Sons ponctuels : interface, construction, argent, météo, cloches, fanfares."""
import numpy as np

from synth import (SR, Rng, secs, samples, lp, hp, bp, reson, pink, brown, white, smooth_noise,
                   env_ad, env_asr, fade, pan, add, rms_normalize, normalize, reverb, hz, midi)
import instruments as ins
import ambiances as amb


def _buf(seconds):
    return np.zeros((2, samples(seconds + 2.0)))


def _place(buf, at, sig, p=0.0, g=1.0):
    add(buf, samples(at), pan(sig * g, p) if sig.ndim == 1 else sig * g)


def _finish(buf, peak=0.8, wet=0.12, room=0.8):
    x = reverb(buf, wet, room, 6000) if wet > 0 else buf
    # Coupe le silence de fin.
    e = np.max(np.abs(x), axis=0)
    last = np.nonzero(e > 1e-4)[0]
    if len(last):
        x = x[:, : min(x.shape[1], last[-1] + samples(0.05))]
    return normalize(fade(x, 0.001, 0.03), peak)


# --- Interface ----------------------------------------------------------------

def ui_clic():
    """Petit « tic » de bois, très court."""
    rng = Rng(101)
    n = samples(0.06)
    t = secs(n)
    x = np.sin(2 * np.pi * 1850 * t) * np.exp(-t * 140) + 0.4 * np.sin(2 * np.pi * 3900 * t) * np.exp(-t * 220)
    x += hp(white(rng, n), 3000) * np.exp(-t * 400) * 0.25
    return normalize(fade(np.vstack([x, x]), 0.0005, 0.01), 0.5)


def ui_ouvrir():
    b = _buf(0.6)
    _place(b, 0.0, ins.marimba(hz(midi("C6")), 0.1, 0.6), -0.1)
    _place(b, 0.06, ins.marimba(hz(midi("G6")), 0.1, 0.5), 0.1)
    return _finish(b, 0.45, 0.1)


def ui_fermer():
    b = _buf(0.6)
    _place(b, 0.0, ins.marimba(hz(midi("G6")), 0.1, 0.45), 0.1)
    _place(b, 0.06, ins.marimba(hz(midi("C6")), 0.1, 0.4), -0.1)
    return _finish(b, 0.38, 0.1)


def ui_notification():
    b = _buf(1.6)
    _place(b, 0.0, ins.glock(hz(midi("E6")), 0.1, 0.7), -0.15)
    _place(b, 0.11, ins.glock(hz(midi("B6")), 0.1, 0.6), 0.15)
    return _finish(b, 0.5, 0.2, 1.2)


def ui_erreur():
    """« Tok-tok » sourd : pas méchant, juste non."""
    b = _buf(0.5)
    _place(b, 0.0, ins.marimba(hz(midi("E3")), 0.1, 0.8))
    _place(b, 0.12, ins.marimba(hz(midi("Eb3")), 0.1, 0.8))
    return _finish(b, 0.55, 0.05)


def ui_vitesse():
    """Changement de vitesse du temps : petit tic-tac."""
    b = _buf(0.4)
    _place(b, 0.0, ins.woodblock(1400, 0.5), -0.2)
    _place(b, 0.11, ins.woodblock(1050, 0.5), 0.2)
    return _finish(b, 0.4, 0.05)


# --- Construction --------------------------------------------------------------

def pose_batiment():
    """Bâtiment posé : « boum » sourd et coup de maillet sur un piquet."""
    rng = Rng(111)
    b = _buf(1.2)
    n = samples(0.8)
    t = secs(n)
    f = 55 + 60 * np.exp(-t * 20)
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)
    _place(b, 0.0, thump, 0, 0.9)
    _place(b, 0.0, lp(white(rng, n), 900) * np.exp(-t * 30), 0, 0.4)
    _place(b, 0.12, amb.hammer_hit(rng, False), 0.2, 0.5)
    return _finish(b, 0.75, 0.12, 0.9)


def pose_route():
    """Voie tracée : gravier raclé puis rouleau qui tasse."""
    rng = Rng(121)
    b = _buf(1.2)
    n = samples(0.6)
    t = secs(n)
    grains = (white(rng, n) > 2.2).astype(float) * white(rng, n)
    scrape = bp(grains + white(rng, n) * 0.3, 800, 6000) * env_asr(n, 0.05, 0.25)
    _place(b, 0.0, scrape, -0.3, 0.5)
    m = samples(0.5)
    tt = secs(m)
    tamp = np.sin(2 * np.pi * 70 * tt) * np.exp(-tt * 12) + lp(white(rng, m), 600) * np.exp(-tt * 25) * 0.5
    _place(b, 0.45, tamp, 0.2, 0.7)
    return _finish(b, 0.65, 0.1)


def demolition():
    """Démolition : craquement, chute de gravats, poussière."""
    rng = Rng(131)
    b = _buf(2.6)
    n = samples(2.2)
    t = secs(n)
    boom = np.sin(2 * np.pi * np.cumsum(40 + 50 * np.exp(-t * 6)) / SR) * np.exp(-t * 3)
    _place(b, 0.05, boom, 0, 0.8)
    _place(b, 0.0, bp(white(rng, samples(0.3)), 1500, 6000) * np.exp(-secs(samples(0.3)) * 20), 0, 0.5)
    for _ in range(90):
        at = rng.u(0.05, 1.6) ** 1.3
        m = samples(0.05)
        tt = secs(m)
        f = rng.u(300, 2500)
        d = (np.sin(2 * np.pi * f * tt) * 0.5 + bp(white(rng, m), f * 0.7, min(f * 2.5, 15000)) * 0.6) * np.exp(-tt * 70)
        _place(b, at, d, rng.u(-0.7, 0.7), rng.u(0.15, 0.4) * (1 - at / 2.2))
    dust = lp(pink(rng, n), 1200) * env_asr(n, 0.2, 1.4) * 0.25
    _place(b, 0.1, dust, 0, 1)
    return _finish(b, 0.8, 0.15, 1.2)


def chantier_fini():
    """Chantier terminé : coup de klaxon de l'équipe et petit « tada » de cloche."""
    b = _buf(1.6)
    for k, (n_, at) in enumerate((("G5", 0.0), ("C6", 0.09), ("E6", 0.18), ("G6", 0.27))):
        _place(b, at, ins.glock(hz(midi(n_)), 0.1, 0.55), -0.2 + k * 0.13)
    return _finish(b, 0.5, 0.2, 1.2)


def argent():
    """Caisse enregistreuse : « ka-tching »."""
    rng = Rng(141)
    b = _buf(1.4)
    m = samples(0.08)
    tt = secs(m)
    _place(b, 0.0, bp(white(rng, m), 1500, 5000) * np.exp(-tt * 60), -0.1, 0.6)
    _place(b, 0.06, np.sin(2 * np.pi * 180 * tt) * np.exp(-tt * 50), 0, 0.5)
    n = samples(1.2)
    t = secs(n)
    ding = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 3.5), (2.76, 0.4, 6), (5.4, 0.25, 9), (1.5, 0.3, 4)):
        ding += a * np.sin(2 * np.pi * 2200 * r * t) * np.exp(-t * d)
    _place(b, 0.13, fade(ding, 0.001, 0.4), 0.15, 0.35)
    for _ in range(9):
        at = rng.u(0.15, 0.55)
        k = samples(0.15)
        tk = secs(k)
        f = rng.u(4500, 8000)
        _place(b, at, np.sin(2 * np.pi * f * tk) * np.exp(-tk * 40), rng.u(-0.5, 0.5), rng.u(0.05, 0.12))
    return _finish(b, 0.6, 0.12)


def palier():
    """Nouveau palier de population : fanfare de village, un peu trop fière d'elle."""
    b = _buf(3.2)
    notes = [("C5", 0.0, 0.12), ("C5", 0.15, 0.12), ("C5", 0.3, 0.12), ("G5", 0.45, 0.3), ("E5", 0.8, 0.15),
             ("G5", 0.98, 0.8)]
    for n_, at, d in notes:
        _place(b, at, ins.brass(hz(midi(n_)), d, 0.8), -0.15)
        _place(b, at, ins.brass(hz(midi(n_) - 12), d, 0.5), 0.15)
    _place(b, 0.98, ins.cymbal(0.7, 2.0), 0.2)
    for at in (0.0, 0.15, 0.3, 0.45):
        _place(b, at, ins.snare(0.5), 0.1)
    _place(b, 0.98, ins.kick(0.9), 0)
    _place(b, 0.98, ins.tuba(hz(midi("C3")), 0.8, 0.8), 0)
    return _finish(b, 0.8, 0.2, 1.4)


def election_gagnee():
    """Victoire aux municipales : fanfare avec cymbales."""
    b = _buf(5.0)
    mel = [("G4", 0.0, 0.2), ("C5", 0.22, 0.2), ("E5", 0.44, 0.2), ("G5", 0.66, 0.45), ("E5", 1.15, 0.2),
           ("G5", 1.37, 1.6)]
    for n_, at, d in mel:
        _place(b, at, ins.brass(hz(midi(n_)), d, 0.85), -0.2)
        _place(b, at, ins.brass(hz(midi(n_) - 4 if n_ != "G4" else midi(n_) - 5), d, 0.5), 0.2)
    for n_, at, d in [("C3", 0.0, 0.6), ("G2", 0.66, 0.45), ("C3", 1.37, 1.6)]:
        _place(b, at, ins.tuba(hz(midi(n_)), d, 0.9), 0)
    for at in np.arange(0, 1.3, 0.11):
        _place(b, at, ins.snare(0.35), 0.1)
    _place(b, 1.37, ins.cymbal(0.9, 3.0), -0.3)
    _place(b, 1.37, ins.cymbal(0.9, 3.0), 0.3)
    _place(b, 1.37, ins.kick(1.0), 0)
    return _finish(b, 0.85, 0.22, 1.8)


def election_perdue():
    """Défaite : le trombone triste (« wah… wah… wah… waaaah »)."""
    b = _buf(4.0)
    seq = [(midi("Bb3"), 0.0, 0.45), (midi("A3"), 0.5, 0.45), (midi("Ab3"), 1.0, 0.45)]
    for m, at, d in seq:
        _place(b, at, ins.trombone_gliss(hz(m), hz(m) * 0.985, d, 0.85), 0)
    _place(b, 1.5, ins.trombone_gliss(hz(midi("G3")), hz(midi("G3")) * 0.97, 1.6, 0.85, vibrato=0.025), 0)
    return _finish(b, 0.75, 0.15, 1.2)


def alerte():
    """Nouvelle importante (incendie, tempête…) : deux notes graves sérieuses."""
    b = _buf(1.6)
    _place(b, 0.0, ins.bell(hz(midi("A4")), 1.4, 0.7), -0.1)
    _place(b, 0.28, ins.bell(hz(midi("F4")), 1.2, 0.7), 0.1)
    return _finish(b, 0.55, 0.15)


# --- Météo et village --------------------------------------------------------

def tonnerre(seed):
    rng = Rng(seed)
    b = _buf(9.0)
    n = samples(8.5)
    t = secs(n)
    crack = hp(white(rng, samples(0.25)), 1500) * np.exp(-secs(samples(0.25)) * 18)
    _place(b, 0.0, crack, rng.u(-0.4, 0.4), 0.5 if seed % 2 else 0.15)
    for c in range(2):
        rum = lp(brown(rng, n), 180) + lp(pink(rng, n), 500) * 0.15
        bursts = np.zeros(n)
        for _ in range(rng.i(5, 9)):
            at = rng.u(0.0, 3.5)
            k = samples(at)
            dec = rng.u(1.2, 3.0)
            bursts[k:] += rng.u(0.4, 1.0) * np.exp(-(t[: n - k]) * dec) * np.clip(t[: n - k] / 0.15, 0, 1)
        b[c, : n] += rum * bursts * np.exp(-t * 0.35)
    return _finish(b, 0.9, 0.2, 2.5)


def cloches():
    """Cloches de l'église à midi : volée de deux cloches."""
    rng = Rng(161)
    b = _buf(14.0)
    f1 = hz(midi("E4"))
    f2 = hz(midi("C#4"))
    at = 0.0
    for k in range(14):
        f = f1 if k % 2 == 0 else f2
        _place(b, at, ins.bell(f, 4.5, rng.u(0.7, 0.9)), -0.35 if k % 2 == 0 else 0.35)
        at += rng.u(0.62, 0.72)
    return _finish(b, 0.7, 0.3, 2.8)


def coq():
    """Le coq du matin (ferme ou village) : un « cocorico » assez fier de lui."""
    rng = Rng(171)
    b = _buf(2.2)
    parts = [(620, 700, 0.12), (700, 1050, 0.18), (1050, 980, 0.6), (980, 700, 0.35)]
    at = 0.0
    for f0, f1, d in parts:
        n = samples(d)
        t = secs(n)
        f = f0 + (f1 - f0) * (t / d)
        f = f * (1 + 0.03 * np.sin(2 * np.pi * 38 * t))
        ph = 2 * np.pi * np.cumsum(f) / SR
        src = np.zeros(n)
        for k in range(1, 9):
            src += np.sin(ph * k) / k
        x = reson(src, 1400, 3) + reson(src, 2600, 4) * 0.6 + bp(white(rng, n), 1500, 4000) * 0.15
        _place(b, at, x * env_asr(n, 0.02, 0.05), 0.1, 0.4)
        at += d + 0.02
    return _finish(b, 0.6, 0.2, 1.5)


ALL = {
    "ui_clic": ui_clic,
    "ui_ouvrir": ui_ouvrir,
    "ui_fermer": ui_fermer,
    "ui_notification": ui_notification,
    "ui_erreur": ui_erreur,
    "ui_vitesse": ui_vitesse,
    "pose_batiment": pose_batiment,
    "pose_route": pose_route,
    "demolition": demolition,
    "chantier_fini": chantier_fini,
    "argent": argent,
    "palier": palier,
    "election_gagnee": election_gagnee,
    "election_perdue": election_perdue,
    "alerte": alerte,
    "tonnerre_1": lambda: tonnerre(181),
    "tonnerre_2": lambda: tonnerre(182),
    "cloches": cloches,
    "coq": coq,
}
