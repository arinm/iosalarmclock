import sys, math, numpy as np; sys.path.insert(0, "../lib")
from sfx import *
# One track for en and ja (same timing). The quiet check at 3.0 s gets no chime:
# the real notification is silent (content.sound = nil).
mx = Mix(12.0)
def alarm(a, b, gain):   # a phone alarm going off: bright two-note beeps, cut dead at b
    for k, t0 in enumerate(np.arange(a, b - .05, .21)):
        f = 1568 if k % 4 < 2 else 2093
        s = marimba(f, .2) + .4 * metal(f * 2, .05, .2)
        n = min(len(s), int((b - t0) * SR)); mx.place(s[:n], t0, gain, .15 if k % 2 else -.15)
# night bed, then a warmer one for the app
mx.place(pad((87.31, 174.61, 220, 261.63, 329.63, 392), 6.4, .9, .2), 0.0, .07)
mx.place(pad((98, 196, 246.94, 293.66, 369.99, 440), 4.0, .6, .15), 5.9, .06)
# 6:30 — Wake up rings; the finger taps Stop
alarm(0.12, 0.95, .07)
mx.place(click(2000, .006), 0.95, .3, .2); mx.place(kick(110, 60, .06, .2), 0.95, .15)
# back to sleep: z z z, the clock rolls to 6:35
mx.place(tone(400, 200, .9) * np.minimum(1, T(.9) / .3) * np.exp(-T(.9) / .5), 1.3, .05)
for i in range(3):
    st = 1.75 + i * .33; mx.place(tone(620 - 60 * i, 360 - 40 * i, .5) * np.sin(np.pi * np.linspace(0, 1, int(.5 * SR))), st, .03, .3, rev=.5)
for k in range(5): mx.place(click(1500, .004), 1.98 + k * .13, .06, .3)
# 6:35 — the quiet check: air only
mx.place(whoosh(.5, 400, 1100, Q=1.2, seed=17), 2.95, .025)
# 6:37 — no answer: it rings once more
for k in range(2): mx.place(click(1500, .004), 4.98 + k * .12, .06, .3)
alarm(5.28, 6.0, .08)
mx.place(kick(130, 50, .1, .3), 5.26, .14)
# the app, filmed
mx.place(whoosh(.45, 300, 1800, seed=21), 5.85, .08); mx.place(kick(140, 50, .12), 6.05, .22)
mx.place(click(2400, .005), 6.63, .28, .3); mx.place(kick(110, 60, .06, .2), 6.63, .12)        # switch on
mx.place(marimba(1174.66), 6.70, .07, rev=.4)
mx.place(whoosh(.3, 1800, 600, Q=1.6, seed=11), 7.3, .05)
mx.place(click(2400, .005), 8.68, .28, .3); mx.place(kick(110, 60, .06, .2), 8.68, .12)        # I'm up
mx.place(marimba(880), 8.76, .1, rev=.4); mx.place(marimba(1318.5), 8.84, .1, rev=.4)
mx.place(bell(1760, 1.2), 8.92, .06, rev=.6)
# end card (04's, shifted)
mx.place(riser(.4, 200, 1400, 9), 9.22, .1)
mx.place(boom(1.4) * .7, 9.62, .34, rev=.3)
mx.place(whoosh(.45, 500, 2600, lambda p: math.sin(math.pi * p) ** .9, 2.2, 27), 9.77, .08)
for t0 in (9.99, 10.07): mx.place(click(2600, .005), t0, .13)
for t0, pan in ((10.17, -.3), (10.21, .3)): mx.place(metal(1900, .18), t0, .06, pan, rev=.5)
trill(mx, 10.30, .32, .1)
mx.place(chord((220, 277.18, 329.63, 440, 659.25), 1.3, .15, 1.2), 10.25, .07, rev=.5)
mx.place(metal(880, .9, 1.2), 10.25, .06, rev=.6)
mx.place(svf_noise(.4, lambda p: 6500, lambda p: math.sin(math.pi * p) ** 2, 3, 31) + .3 * partials(3520, [1, 1.5], [1, .4], [.4, .3], .4), 10.82, .05, rev=.5)
mx.write("audio.wav"); print("07 audio ok")
