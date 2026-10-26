"""Synthesised sound design for the Punctual motion piece — every cue is timed
to the same easing curves the visuals use, so ticks land on digit changes."""
import numpy as np, wave, math
SR = 48000; DUR = 15.0; N = int(SR * DUR)
bus = np.zeros((2, N)); wet = np.zeros((2, N))
rng = np.random.default_rng(42)

def clamp(x, a=0.0, b=1.0): return min(b, max(a, x))
def seg(t, a, b): return clamp((t - a) / (b - a))
def outBack(p, s=1.70158): return 0.0 if p <= 0 else 1 + (s + 1) * (p - 1) ** 3 + s * (p - 1) ** 2
def inOutQuint(p): return 16 * p ** 5 if p < .5 else 1 - (-2 * p + 2) ** 5 / 2
def T(dur): return np.arange(int(dur * SR)) / SR

def place(sig, t0, gain=1.0, pan=0.0, rev=0.0):
    i0 = int(round(t0 * SR)); s = np.asarray(sig, float) * gain
    if i0 < 0: s = s[-i0:]; i0 = 0
    s = s[:max(0, N - i0)]
    if not len(s): return
    p = np.broadcast_to(np.asarray(pan, float), (len(np.asarray(pan).reshape(-1)) if np.ndim(pan) else 1,))
    th = (np.clip(pan if np.ndim(pan) == 0 else np.asarray(pan)[:len(s)], -1, 1) + 1) * np.pi / 4
    l, r = np.cos(th), np.sin(th)
    bus[0, i0:i0 + len(s)] += s * l; bus[1, i0:i0 + len(s)] += s * r
    if rev: wet[0, i0:i0 + len(s)] += s * l * rev; wet[1, i0:i0 + len(s)] += s * r * rev

def tone(f0, f1, dur):
    t = T(dur); f = np.full(len(t), f0) if f0 == f1 else f0 * (f1 / f0) ** (t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)
def env(dur, a, d):
    t = T(dur); e = np.exp(-t / d); n = int(a * SR)
    if n: e[:n] *= np.linspace(0, 1, n)
    return e
def partials(f, ratios, amps, decays, dur, a=0.001):
    t = T(dur); out = np.zeros(len(t))
    for r, am, d in zip(ratios, amps, decays): out += am * np.sin(2 * np.pi * f * r * t + rng.random() * 6.28) * np.exp(-t / d)
    n = int(a * SR); out[:n] *= np.linspace(0, 1, n); return out
def metal(f, d=0.25, dur=0.6): return partials(f, [1, 2.756, 5.404, 8.933], [1, .6, .35, .18], [d, d * .6, d * .4, d * .25], dur)
def marimba(f, dur=0.7): return partials(f, [1, 3.932, 9.538], [1, .28, .08], [.32, .07, .025], dur, a=.002)
def click(f=3200, d=0.004, dur=0.03):
    t = T(dur); return (0.6 * rng.standard_normal(len(t)) * np.exp(-t / 0.0015) + np.sin(2 * np.pi * f * t) * np.exp(-t / d))
def kick(f0=140, f1=45, d=0.16, dur=0.5): return tone(f0, f1, dur) * env(dur, 0.002, d) + 0.25 * click(2400, 0.003, dur)[:int(dur*SR)]
def boom(dur=1.6): return tone(72, 34, dur) * env(dur, 0.004, 0.5) + 0.5 * tone(150, 60, dur) * env(dur, 0.002, 0.12)

def svf_noise(dur, fc_curve, amp_curve, Q=1.6, seed=0):
    """Band-passed noise with a time-varying centre (Chamberlin SVF)."""
    n = int(dur * SR); x = np.random.default_rng(seed).standard_normal(n)
    out = np.empty(n); low = band = 0.0; q = 1.0 / Q
    fcs = np.minimum(np.array([fc_curve(i / n) for i in range(0, n, 64)]), 7000)
    for blk in range(0, n, 64):
        f = 2 * math.sin(math.pi * fcs[blk // 64] / SR)
        for i in range(blk, min(n, blk + 64)):
            low += f * band; high = x[i] - low - q * band; band += f * high; out[i] = band
    a = np.array([amp_curve(i / n) for i in range(n)]); return out * a / (np.max(np.abs(out)) + 1e-9)

def whoosh(dur, f0, f1, shape=lambda p: math.sin(math.pi * p) ** 1.3, Q=1.4, seed=1):
    return svf_noise(dur, lambda p: f0 * (f1 / f0) ** p, shape, Q, seed)

# ---------------- B1: the mark builds and rings ----------------
place(tone(640, 170, .12) * env(.12, .002, .035), 0.04, .35)                       # dot pops
place(whoosh(0.85, 500, 2600, lambda p: math.sin(math.pi * p) ** .9, 2.2, 3), 0.28, .16,
      pan=np.linspace(-.35, .35, int(.85 * SR)))                                   # ring draws (pans with the comet)
place(tone(220, 440, .85) * np.sin(np.pi * np.linspace(0, 1, int(.85 * SR))) ** 2, 0.28, .035)
for t0, pan in ((0.56, -.05), (0.68, .08)): place(click(2600, .005), t0, .22, pan)  # hands
for t0, pan in ((0.86, -.3), (0.93, .3)): place(metal(1900, .18), t0, .10, pan, rev=.5)  # bells pop
for i, t0 in enumerate(np.arange(1.12, 1.80, 1 / 26)):                              # the alarm trill
    e = clamp((t0 - 1.12) / .08) * (1 - clamp((t0 - 1.40) / .55))
    place(metal(1567 if i % 2 else 2093, .05, .2), t0, .17 * e, -.35 if i % 2 else .35, rev=.35)
place(whoosh(0.54, 300, 6500, lambda p: (2 ** (10 * p - 10)) * (1 - max(0, (p - .97) / .03)), 1.1, 5), 1.68, .5)  # dive into the gap
place(tone(110, 880, .54) * np.linspace(0, 1, int(.54 * SR)) ** 3, 1.68, .07)
place(boom(), 2.22, .62, rev=.25)                                                  # impact
place(rng.standard_normal(int(.15 * SR)) * env(.15, .001, .03), 2.22, .22, rev=.4)

# ---------------- B2: digit roll, live countdown ----------------
for (st, frm, to, pan) in ((2.13, 1, 26, -.25), (2.20, 7, 23, 0), (2.27, 4, 20, .25)):
    last = math.floor(frm)
    for k in range(1, 1000):
        t = st + k / 1000.0 * 0.95
        idx = frm + (to - frm) * outBack(k / 1000.0, 0.9)
        if math.floor(idx) != last: last = math.floor(idx); place(click(2900 + 400 * rng.random(), .003), t, .07, pan)
place(marimba(1318.5), 2.40, .08)                                                  # colon pops
place(tone(320, 210, .1) * env(.1, .002, .04), 2.66, .14)                          # AM
for i in range(4): place(marimba(784 * (1.1225 ** i), .3), 2.98 + i * .06, .045)   # words rise
place(click(2400, .006), 3.42, .14)                                                # first live tick
place(whoosh(.6, 900, 300, Q=1.2, seed=8), 3.60, .09)                              # time lifts
for i in range(60): place(click(3800, .0015, .01), 3.66 + i * .007, .016, -.6 + 1.2 * i / 59)  # dial ticks

# ---------------- B3: time-lapse, heads-up ----------------
lastm, lastt = 461, 0
for k in range(1200):
    t = 4.05 + k * 0.001
    m = round(461 - 446 * inOutQuint(seg(t, 4.05, 5.25)))
    if m != lastm and t - lastt > 1 / 42: place(click(2500 + 900 * rng.random(), .002), t, .085, rng.uniform(-.4, .4)); lastt = t
    lastm = m
place(whoosh(1.25, 250, 2600, lambda p: (p ** 1.6) * (1 - max(0, (p - .9) / .1)), 1.0, 9), 4.02, .24)
place(tone(196, 588, 1.2) * np.linspace(0, 1, int(1.2 * SR)) ** 2 * np.linspace(1, .2, int(1.2 * SR)), 4.05, .03)
place(marimba(1046.5), 5.32, .22, rev=.3); place(marimba(1568), 5.41, .2, rev=.3)  # heads-up
for i, t0 in enumerate(np.arange(5.47, 5.95, 1 / 22)): place(metal(2349 if i % 2 else 2793, .03, .12), t0, .04 * (1 - (t0 - 5.47) / .5))

# ---------------- B4: tap, skip, tomorrow armed ----------------
place(click(2000, .006) + 0.0, 6.32, .32); place(kick(110, 60, .06, .2), 6.32, .18)  # tap
place(whoosh(.35, 1800, 500, Q=1.6, seed=11), 6.50, .1)                            # morph
place(marimba(880), 6.88, .1, rev=.3); place(marimba(1318.5), 6.95, .1, rev=.3)   # check
for i, f in enumerate((1046.5, 1174.7, 1318.5, 1568, 1760, 2093, 2349)):            # week pops
    place(marimba(f, .4), 6.96 + i * .045, .06, -.5 + i / 6)
place(tone(210, 120, .2) * env(.2, .002, .06), 7.52, .2, .25)                       # today: skipped
place(whoosh(.22, 3000, 6000, Q=2, seed=13), 7.54, .06, .25)
place(partials(1760, [1, 1.5, 2, 3], [1, .5, .35, .2], [.6, .5, .35, .2], 1.6), 7.92, .14, .35, rev=.6)  # tomorrow: armed
for t0 in (7.95, 8.21): place(tone(523, 523, .4) * env(.4, .03, .12), t0, .04, .35)

# ---------------- B5: kinetic type, the phone ----------------
place(whoosh(.36, 2400, 300, seed=17), 8.64, .12)
for t0, g in ((8.90, .34), (8.98, .3), (9.50, .34), (9.58, .4)): place(kick(), t0, g)
place(whoosh(.3, 2000, 6500, Q=2.2, seed=19), 9.34, .1)                             # strike-through
place(partials(2637, [1, 1.33, 2], [1, .5, .3], [.5, .4, .25], 1.0), 9.80, .05, rev=.6)
place(whoosh(.85, 250, 3200, lambda p: math.sin(math.pi * p) ** 1.1, 1.2, 21), 9.84, .2, pan=np.linspace(.8, 0, int(.85 * SR)))
for i in range(8): place(marimba(1568 * (1.06 ** i), .25), 10.10 + i * .07, .03, .4)
place(whoosh(.3, 1500, 4000, Q=2, seed=23), 10.92, .05, .4); place(marimba(1318.5, .4), 11.0, .05, .4)
place(click(1500, .006), 11.38, .14, .4); place(click(2200, .004), 11.42, .1, .4)  # toggle
place(whoosh(.52, 300, 5200, lambda p: (p ** 1.4) * (1 - max(0, (p - .9) / .1)), 1.0, 25), 11.96, .5, pan=np.linspace(.6, -.8, int(.52 * SR)))  # whip

# ---------------- B6: the lockup ----------------
place(boom(1.8), 12.34, .5, rev=.3)
place(whoosh(.55, 500, 2600, lambda p: math.sin(math.pi * p) ** .9, 2.2, 27), 12.52, .1)
for t0 in (12.72, 12.80): place(click(2600, .005), t0, .16)
for t0, pan in ((12.92, -.3), (12.97, .3)): place(metal(1900, .18), t0, .07, pan, rev=.5)
for i, t0 in enumerate(np.arange(13.08, 13.48, 1 / 26)):
    e = 1 - (t0 - 13.08) / .4; place(metal(1567 if i % 2 else 2093, .05, .2), t0, .09 * e, -.35 if i % 2 else .35, rev=.4)
place(whoosh(.3, 3000, 7000, Q=2.4, seed=29), 13.02, .06)
ch = sum(tone(f, f, 3.0) * a for f, a in ((220, 1), (277.18, .8), (329.63, .75), (440, .6), (659.25, .35)))
chord_env = np.minimum(1, T(3.0) / .18) * np.exp(-T(3.0) / 1.5)
place(ch * chord_env, 13.36, .055, rev=.5)
place(metal(880, .9, 2.4), 13.36, .07, rev=.6)
place(svf_noise(.7, lambda p: 6500, lambda p: math.sin(math.pi * p) ** 2, 3, 31) + 0.3 * partials(3520, [1, 1.5], [1, .4], [.4, .3], .7), 14.30, .05, rev=.5)

# ---------------- bed: tick-tock + a warm pad that resolves on the logo ----------------
for i, t0 in enumerate(np.arange(2.25, 12.05, 0.5)): place(click(2400 if i % 2 == 0 else 1500, .004, .04), t0, .045, -.15 if i % 2 == 0 else .15)
chords = [(4.0, 6.5, (110, 138.59, 164.81, 220)), (6.4, 8.8, (92.5, 138.59, 185, 220)),
          (8.7, 12.2, (73.42, 146.83, 185, 220)), (12.3, 15.0, (110, 164.81, 220, 277.18))]
for a, b, fs in chords:
    dur = b - a; t = T(dur); e = np.minimum(1, t / .45) * np.minimum(1, (dur - t) / .45)
    sig = sum(np.sin(2 * np.pi * f * d * t + rng.random() * 6) for f in fs for d in (0.997, 1.003)) / 8
    place(sig * e * (1 + .15 * np.sin(2 * np.pi * .3 * t)), a, .09)

# ---------------- reverb (synthetic plate) + master ----------------
ir_n = int(1.8 * SR); tt = np.arange(ir_n) / SR
for ch_i in range(2):
    ir = np.random.default_rng(100 + ch_i).standard_normal(ir_n) * np.exp(-tt / .42)
    IR = np.fft.rfft(ir); IR[int(len(IR) * 7000 / (SR / 2)):] = 0; ir = np.fft.irfft(IR, ir_n)
    L = 1 << (N + ir_n).bit_length()
    w = np.fft.irfft(np.fft.rfft(wet[ch_i], L) * np.fft.rfft(ir, L), L)[:N]
    bus[ch_i] += w / np.max(np.abs(ir)) * .02
mix = np.tanh(bus * 1.6) / np.tanh(1.6)
mix /= np.max(np.abs(mix)) / 0.89
fade = int(.06 * SR); mix[:, -fade:] *= np.linspace(1, 0, fade)
pcm = (mix.T * 32767).astype(np.int16)
with wave.open("audio.wav", "wb") as wf:
    wf.setnchannels(2); wf.setsampwidth(2); wf.setframerate(SR); wf.writeframes(pcm.tobytes())
print("audio.wav", pcm.shape, "peak", np.max(np.abs(mix)).round(3))
