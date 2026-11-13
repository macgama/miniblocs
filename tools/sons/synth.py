"""Petite boîte à outils de synthèse sonore pour MiniBlocs (numpy + scipy).

Tous les sons du jeu sont fabriqués ici, à partir de bruit et d'oscillateurs :
aucun enregistrement extérieur, donc aucune licence à respecter (les fichiers
produits sont placés sous CC0, voir assets/son/LICENCE.md).
"""
import os
import subprocess
import tempfile

import numpy as np
import scipy.io.wavfile as wavfile
import scipy.signal as ss

SR = 44100


class Rng:
    """Générateur aléatoire partagé (graine fixe : sons reproductibles)."""

    def __init__(self, seed):
        self.g = np.random.default_rng(seed)

    def u(self, a=0.0, b=1.0):
        return float(self.g.uniform(a, b))

    def i(self, a, b):
        return int(self.g.integers(a, b + 1))

    def choice(self, seq):
        return seq[int(self.g.integers(0, len(seq)))]

    def normal(self, n):
        return self.g.standard_normal(n)


def secs(n):
    return np.arange(int(n)) / SR


def samples(s):
    return int(round(s * SR))


# --- Bruits -------------------------------------------------------------------

def white(rng, n):
    return rng.normal(n)


def pink(rng, n):
    """Bruit rose (1/f) par mise en forme du spectre."""
    x = rng.normal(n)
    f = np.fft.rfft(x)
    k = np.arange(len(f))
    k[0] = 1
    f /= np.sqrt(k)
    y = np.fft.irfft(f, n)
    return y / (np.std(y) + 1e-9)


def brown(rng, n):
    """Bruit brun (1/f²), sans dérive."""
    x = rng.normal(n)
    f = np.fft.rfft(x)
    k = np.arange(len(f)).astype(float)
    k[0] = 1e9
    f /= k
    y = np.fft.irfft(f, n)
    return y / (np.std(y) + 1e-9)


def smooth_noise(rng, n, rate_hz):
    """Courbe aléatoire lente (0..1), environ rate_hz variations par seconde."""
    pts = max(4, int(n / SR * rate_hz) + 4)
    v = rng.g.uniform(0, 1, pts)
    xp = np.linspace(0, n, pts)
    y = np.interp(np.arange(n), xp, v)
    # Lissage en cosinus entre les points.
    return lp(y, max(rate_hz * 1.5, 0.2), order=1)


# --- Filtres ------------------------------------------------------------------

def _sos(kind, fc, order):
    nyq = SR / 2
    if isinstance(fc, (list, tuple)):
        wn = [min(max(f / nyq, 1e-5), 0.999) for f in fc]
    else:
        wn = min(max(fc / nyq, 1e-5), 0.999)
    return ss.butter(order, wn, btype=kind, output="sos")


def lp(x, fc, order=2):
    return ss.sosfilt(_sos("lowpass", fc, order), x, axis=-1)


def hp(x, fc, order=2):
    return ss.sosfilt(_sos("highpass", fc, order), x, axis=-1)


def bp(x, lo, hi, order=2):
    return ss.sosfilt(_sos("bandpass", [lo, hi], order), x, axis=-1)


def reson(x, f, q=20.0):
    """Résonateur (pic étroit autour de f)."""
    b, a = ss.iirpeak(min(f, SR / 2 - 10) / (SR / 2), q)
    return ss.lfilter(b, a, x)


# --- Enveloppes et placement --------------------------------------------------

def env_ad(n, attack, decay_rate):
    t = secs(n)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t * decay_rate)


def env_asr(n, attack, release):
    """Montée, plateau, descente (sur n échantillons)."""
    e = np.ones(n)
    na = min(n, max(1, samples(attack)))
    nr = min(n - na, max(1, samples(release)))
    e[:na] = np.linspace(0, 1, na) ** 1.5
    if nr > 0:
        e[n - nr:] *= np.linspace(1, 0, nr) ** 1.5
    return e


def fade(x, fin=0.005, fout=0.02):
    x = x.copy()
    a = min(len(x), samples(fin))
    b = min(len(x), samples(fout))
    if a > 0:
        x[..., :a] *= np.linspace(0, 1, a)
    if b > 0:
        x[..., -b:] *= np.linspace(1, 0, b)
    return x


def pan(mono, p):
    """Stéréo à puissance constante, p de -1 (gauche) à 1 (droite)."""
    a = (p + 1) * np.pi / 4
    return np.vstack([mono * np.cos(a), mono * np.sin(a)])


def add(buf, start, sig):
    """Ajoute sig (mono ou stéréo) dans buf (stéréo) à partir de l'échantillon start."""
    if sig.ndim == 1:
        sig = np.vstack([sig, sig])
    n = buf.shape[1]
    if start >= n:
        return
    if start < 0:
        sig = sig[:, -start:]
        start = 0
    m = min(sig.shape[1], n - start)
    buf[:, start:start + m] += sig[:, :m]


def add_wrap(buf, start, sig):
    """Comme add, mais ce qui dépasse revient au début (pour les boucles)."""
    if sig.ndim == 1:
        sig = np.vstack([sig, sig])
    n = buf.shape[1]
    start %= n
    m = sig.shape[1]
    pos = 0
    while pos < m:
        k = min(m - pos, n - start)
        buf[:, start:start + k] += sig[:, pos:pos + k]
        pos += k
        start = 0


def loopify(x, xfade_s=2.0):
    """Rend une prise (plus longue que la boucle voulue) bouclable sans clic :
    la fin est fondue dans le début. Renvoie len(x) - xfade échantillons."""
    k = samples(xfade_s)
    head = x[..., :k]
    tail = x[..., -k:]
    w = np.sin(np.linspace(0, np.pi / 2, k)) ** 2
    out = x[..., :-k].copy()
    out[..., :k] = head * w + tail * (1 - w)
    return out


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x * (peak / m)


def rms_normalize(x, target_db=-20.0, peak=0.95):
    r = np.sqrt(np.mean(x ** 2)) + 1e-9
    y = x * (10 ** (target_db / 20) / r)
    m = np.max(np.abs(y))
    if m > peak:
        y = soft_clip(y / m * 1.05) * peak
    return y


def soft_clip(x):
    return np.tanh(x)


# --- Réverbération ------------------------------------------------------------

_IR_CACHE = {}


def reverb_ir(seconds=2.0, damp=3000.0, seed=7):
    key = (seconds, damp, seed)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    rng = Rng(seed)
    n = samples(seconds)
    t = secs(n)
    irs = []
    for _ in range(2):
        e = rng.normal(n) * np.exp(-t * 6.9 / seconds)
        e = lp(e, damp, 1)
        e[: samples(0.012)] *= np.linspace(0, 1, samples(0.012))
        irs.append(e / np.sqrt(np.sum(e ** 2)))
    ir = np.vstack(irs)
    _IR_CACHE[key] = ir
    return ir


def reverb(x, wet=0.25, seconds=2.0, damp=3000.0, predelay=0.02):
    """Réverbération à convolution (salle synthétique)."""
    if x.ndim == 1:
        x = np.vstack([x, x])
    ir = reverb_ir(seconds, damp)
    pd = samples(predelay)
    out = np.zeros((2, x.shape[1] + ir.shape[1] + pd))
    for c in range(2):
        w = ss.fftconvolve(x[c], ir[c])
        out[c, pd:pd + len(w)] += w
    out *= wet
    out[:, : x.shape[1]] += x * (1 - wet * 0.5)
    return out


# --- Écriture -----------------------------------------------------------------

def write_ogg(path, x, quality=4, mono=False):
    """Écrit un fichier OGG Vorbis (via ffmpeg)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if x.ndim == 2 and mono:
        x = x.mean(axis=0)
    data = np.clip(x, -1, 1)
    if data.ndim == 2:
        data = data.T
    pcm = (data * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wavfile.write(tmp.name, SR, pcm)
        tmp_name = tmp.name
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp_name, "-c:a", "libvorbis",
                        "-q:a", str(quality), "-map_metadata", "-1", path], check=True)
    finally:
        os.unlink(tmp_name)


# --- Notes --------------------------------------------------------------------

NOTE_INDEX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """« C4 », « F#3 », « Bb2 » -> numéro MIDI."""
    n = NOTE_INDEX[name[0]]
    rest = name[1:]
    while rest and rest[0] in "#b":
        n += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return n + 12 * (int(rest) + 1)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)
