"""Shared sound design kit for the reels (synthesised, deterministic).
   mx = Mix(dur); mx.place(signal, t0, gain, pan, rev); mx.write("audio.wav")"""
import numpy as np, wave, math
SR = 48000
_rng = np.random.default_rng(42)

def clamp(x, a=0.0, b=1.0): return min(b, max(a, x))
def seg(t, a, b): return clamp((t - a) / (b - a))
def outBack(p, s=1.70158): return 0.0 if p <= 0 else 1 + (s + 1) * (p - 1) ** 3 + s * (p - 1) ** 2
def inOutQuint(p): return 16 * p ** 5 if p < .5 else 1 - (-2 * p + 2) ** 5 / 2
def T(dur): return np.arange(int(dur * SR)) / SR

class Mix:
    def __init__(self, dur):
        self.dur = dur; self.n = int(SR * dur); self.bus = np.zeros((2, self.n)); self.wet = np.zeros((2, self.n))
    def place(self, sig, t0, gain=1.0, pan=0.0, rev=0.0):
        i0 = int(round(t0 * SR)); s = np.asarray(sig, float) * gain
        if i0 < 0: s = s[-i0:]; i0 = 0
        s = s[:max(0, self.n - i0)]
        if not len(s): return
        pn = pan if np.ndim(pan) == 0 else np.asarray(pan, float)[:len(s)]
        if np.ndim(pn) and len(pn) < len(s): pn = np.pad(pn, (0, len(s) - len(pn)), mode="edge")
        th = (np.clip(pn, -1, 1) + 1) * np.pi / 4; l, r = np.cos(th), np.sin(th)
        self.bus[0, i0:i0 + len(s)] += s * l; self.bus[1, i0:i0 + len(s)] += s * r
        if rev: self.wet[0, i0:i0 + len(s)] += s * l * rev; self.wet[1, i0:i0 + len(s)] += s * r * rev
    def write(self, path, drive=1.6, peak=0.89):
        ir_n = int(1.8 * SR); tt = np.arange(ir_n) / SR
        for c in range(2):
            ir = np.random.default_rng(100 + c).standard_normal(ir_n) * np.exp(-tt / .42)
            IR = np.fft.rfft(ir); IR[int(len(IR) * 7000 / (SR / 2)):] = 0; ir = np.fft.irfft(IR, ir_n)
            L = 1 << (self.n + ir_n).bit_length()
            w = np.fft.irfft(np.fft.rfft(self.wet[c], L) * np.fft.rfft(ir, L), L)[:self.n]
            self.bus[c] += w / np.max(np.abs(ir)) * .02
        m = np.tanh(self.bus * drive) / np.tanh(drive); m /= max(1e-9, np.max(np.abs(m))) / peak
        f = int(.05 * SR); m[:, -f:] *= np.linspace(1, 0, f)
        with wave.open(path, "wb") as wf:
            wf.setnchannels(2); wf.setsampwidth(2); wf.setframerate(SR); wf.writeframes((m.T * 32767).astype(np.int16).tobytes())
        return m

def tone(f0, f1, dur):
    t = T(dur); f = np.full(len(t), f0) if f0 == f1 else f0 * (f1 / f0) ** (t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)
def env(dur, a, d):
    t = T(dur); e = np.exp(-t / d); n = int(a * SR)
    if n: e[:n] *= np.linspace(0, 1, n)
    return e
def partials(f, ratios, amps, decays, dur, a=0.001):
    t = T(dur); out = np.zeros(len(t))
    for r, am, d in zip(ratios, amps, decays): out += am * np.sin(2 * np.pi * f * r * t + _rng.random() * 6.28) * np.exp(-t / d)
    n = int(a * SR); out[:n] *= np.linspace(0, 1, n); return out
def metal(f, d=0.25, dur=0.6): return partials(f, [1, 2.756, 5.404, 8.933], [1, .6, .35, .18], [d, d * .6, d * .4, d * .25], dur)
def marimba(f, dur=0.7): return partials(f, [1, 3.932, 9.538], [1, .28, .08], [.32, .07, .025], dur, a=.002)
def bell(f, dur=1.6): return partials(f, [1, 1.5, 2, 3], [1, .5, .35, .2], [.6, .5, .35, .2], dur)
def click(f=3200, d=0.004, dur=0.03):
    t = T(dur); return 0.6 * _rng.standard_normal(len(t)) * np.exp(-t / 0.0015) + np.sin(2 * np.pi * f * t) * np.exp(-t / d)
def kick(f0=140, f1=45, d=0.16, dur=0.5): return tone(f0, f1, dur) * env(dur, 0.002, d) + 0.25 * click(2400, 0.003, dur)[:int(dur * SR)]
def boom(dur=1.6): return tone(72, 34, dur) * env(dur, 0.004, 0.5) + 0.5 * tone(150, 60, dur) * env(dur, 0.002, 0.12)
def noise(dur, seed=0): return np.random.default_rng(seed).standard_normal(int(dur * SR))

def svf_noise(dur, fc_curve, amp_curve, Q=1.6, seed=0):
    n = int(dur * SR); x = np.random.default_rng(seed).standard_normal(n); out = np.empty(n); low = band = 0.0; q = 1.0 / Q
    fcs = np.minimum(np.array([fc_curve(i / n) for i in range(0, n, 64)]), 7000)
    for blk in range(0, n, 64):
        f = 2 * math.sin(math.pi * fcs[blk // 64] / SR)
        for i in range(blk, min(n, blk + 64)):
            low += f * band; high = x[i] - low - q * band; band += f * high; out[i] = band
    a = np.array([amp_curve(i / n) for i in range(n)]); return out * a / (np.max(np.abs(out)) + 1e-9)
def whoosh(dur, f0, f1, shape=lambda p: math.sin(math.pi * p) ** 1.3, Q=1.4, seed=1):
    return svf_noise(dur, lambda p: f0 * (f1 / f0) ** p, shape, Q, seed)
def riser(dur, f0=200, f1=1200, seed=3):
    w = whoosh(dur, f0 * 1.5, f1 * 4, lambda p: p ** 1.8, 1.1, seed)
    return w + 0.25 * tone(f0, f1, dur) * np.linspace(0, 1, int(dur * SR)) ** 2

def chord(freqs, dur, attack=.18, decay=1.5, detune=(0.997, 1.003)):
    t = T(dur); e = np.minimum(1, t / attack) * np.exp(-t / decay)
    return sum(np.sin(2 * np.pi * f * d * t + _rng.random() * 6) for f in freqs for d in detune) / (2 * len(freqs)) * e
def pad(freqs, dur, fade=.45, trem=.3):
    t = T(dur); e = np.minimum(1, t / fade) * np.minimum(1, (dur - t) / fade)
    return sum(np.sin(2 * np.pi * f * d * t + _rng.random() * 6) for f in freqs for d in (0.997, 1.003)) / (2 * len(freqs)) * e * (1 + .15 * np.sin(2 * np.pi * trem * t))
def tick_tock(mx, start, end, step=0.5, gain=.045):
    for i, t0 in enumerate(np.arange(start, end, step)): mx.place(click(2400 if i % 2 == 0 else 1500, .004, .04), t0, gain, -.15 if i % 2 == 0 else .15)
def trill(mx, t0, dur, gain=.17, rev=.35):
    for i, t in enumerate(np.arange(t0, t0 + dur, 1 / 26)):
        e = clamp((t - t0) / .08) * (1 - clamp((t - t0 - dur * .45) / (dur * .55)))
        mx.place(metal(1567 if i % 2 else 2093, .05, .2), t, gain * e, -.35 if i % 2 else .35, rev=rev)

# --- new for the reels -------------------------------------------------------------
def bitcrush(x, bits=5, hold=6):
    y = np.round(x * (2 ** bits)) / (2 ** bits); return np.repeat(y[::hold], hold)[:len(x)]
def glitch(dur, seed=5):
    """Digital stutter: bit-crushed noise bursts and square blips."""
    r = np.random.default_rng(seed); n = int(dur * SR); out = np.zeros(n); i = 0
    while i < n:
        L = int(r.uniform(.012, .06) * SR); L = min(L, n - i)
        if r.random() < .55:
            f = r.choice([180, 360, 720, 1440, 2880]); t = np.arange(L) / SR
            out[i:i + L] = np.sign(np.sin(2 * np.pi * f * t)) * .5
        else: out[i:i + L] = bitcrush(r.standard_normal(L) * .6, 3, r.integers(4, 20))
        i += L + int(r.uniform(0, .02) * SR)
    return out
def tape_rewind(dur, seed=7):
    """VHS rewind chatter: warbling, pitch-climbing squeal over hiss."""
    t = T(dur); r = np.random.default_rng(seed)
    f = 500 * (1 + 4 * (t / dur) ** 1.5) * (1 + .25 * np.sin(2 * np.pi * 23 * t))
    squeal = np.sin(2 * np.pi * np.cumsum(f) / SR) * (.6 + .4 * np.sin(2 * np.pi * 11 * t))
    chatter = np.zeros(len(t))
    for k in range(int(dur * 30)):
        s = int(r.uniform(0, dur - .03) * SR); L = int(.02 * SR); ff = r.uniform(900, 3000)
        chatter[s:s + L] += np.sin(2 * np.pi * ff * np.arange(L) / SR) * np.hanning(L) * .5
    hiss = whoosh(dur, 2500, 6500, lambda p: .7, 1.0, seed)
    return (squeal * .45 + chatter + hiss * .5) * np.minimum(1, t / .05)
def sting(f=98, dur=1.4):
    """Low dissonant hit — something went wrong."""
    t = T(dur); e = env(dur, .003, .35)
    s = (np.sin(2 * np.pi * f * t) + .8 * np.sin(2 * np.pi * f * 1.0595 * t) + .5 * np.sin(2 * np.pi * f * 1.5 * 1.0595 * t)
         + .4 * np.sign(np.sin(2 * np.pi * f / 2 * t)) * np.exp(-t / .08))
    return s * e * .5 + .4 * noise(dur, 11) * env(dur, .001, .05)
def tape_stop(dur=.5):
    t = T(dur); f = 220 * (1 - t / dur) ** 2 + 20
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * (1 - t / dur)
