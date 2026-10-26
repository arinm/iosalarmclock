import sys, math, numpy as np; sys.path.insert(0, "../lib")
from sfx import *
mx = Mix(8.6)
r = np.random.default_rng(3)
# night: a soft dreamy pad (Fmaj9) and distant crickets
mx.place(pad((87.31, 174.61, 220, 261.63, 329.63, 392), 6.9, .9, .2), 0.0, .085)
for k in range(40):
    t0 = r.uniform(0, 6.3); L = int(.09 * SR); tt = np.arange(L) / SR
    chirp = np.sin(2 * np.pi * 4300 * tt) * (np.sin(2 * np.pi * 45 * tt) > 0) * np.hanning(L)
    mx.place(chirp, t0, .012, r.uniform(-.8, .8))
for i in range(5): mx.place(marimba(659.25 * 1.12 ** i, .3), 0.0 + i * .07, .04)
# the heads-up arrives
mx.place(whoosh(.35, 300, 1600, seed=5), 0.72, .07)
mx.place(marimba(1046.5), 0.80, .2, rev=.4); mx.place(marimba(1568), 0.89, .18, rev=.4)
for i, t0 in enumerate(np.arange(0.97, 1.5, 1 / 22)): mx.place(metal(2349 if i % 2 else 2793, .03, .12), t0, .035 * (1 - (t0 - .97) / .55))
# "Day off?"
mx.place(kick(140, 50, .12), 1.98, .3); mx.place(marimba(1318.5, .5), 2.06, .08, rev=.3)
mx.place(click(2000, .006), 2.58, .3, .3); mx.place(kick(110, 60, .06, .2), 2.58, .15)          # tap
mx.place(whoosh(.3, 1800, 500, Q=1.6, seed=11), 2.75, .08)
mx.place(marimba(880), 3.02, .1, rev=.4); mx.place(marimba(1318.5), 3.10, .1, rev=.4)          # skipped ✓
# the screen goes back to sleep: z z z
mx.place(tone(400, 200, .9) * np.minimum(1, T(.9) / .3) * np.exp(-T(.9) / .5), 3.35, .05)
for i in range(3):
    st = 3.55 + i * .38; mx.place(tone(620 - 60 * i, 360 - 40 * i, .5) * np.sin(np.pi * np.linspace(0, 1, int(.5 * SR))), st, .035, .3, rev=.5)
for i in range(6): mx.place(marimba(523.25 * 1.12 ** i, .35), 3.42 + i * .07, .035)
# tomorrow stays armed
for i in range(5): mx.place(marimba(698.46 * 1.12 ** i, .3), 5.20 + i * .07, .04)
mx.place(bell(1760, 1.4), 5.34, .12, rev=.6); mx.place(kick(120, 55, .1, .3), 5.34, .15)
# morning: end card
mx.place(riser(.5, 200, 1400, 9), 6.25, .12)
mx.place(boom(1.4) * .7, 6.75, .34, rev=.3)
mx.place(whoosh(.45, 500, 2600, lambda p: math.sin(math.pi * p) ** .9, 2.2, 27), 6.9, .08)
for t0 in (7.12, 7.2): mx.place(click(2600, .005), t0, .13)
for t0, pan in ((7.3, -.3), (7.34, .3)): mx.place(metal(1900, .18), t0, .06, pan, rev=.5)
trill(mx, 7.43, .32, .1)
mx.place(chord((220, 277.18, 329.63, 440, 659.25), 1.3, .15, 1.2), 7.38, .07, rev=.5)
mx.place(metal(880, .9, 1.2), 7.38, .06, rev=.6)
mx.place(svf_noise(.4, lambda p: 6500, lambda p: math.sin(math.pi * p) ** 2, 3, 31) + .3 * partials(3520, [1, 1.5], [1, .4], [.4, .3], .4), 7.95, .05, rev=.5)
mx.write("audio.wav"); print("04 audio ok")
