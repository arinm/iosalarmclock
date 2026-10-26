import sys, math, json, numpy as np; sys.path.insert(0, "../lib")
from sfx import *
mx = Mix(9.8)
r = np.random.default_rng(5)
# lounge bed: a soft A-major pad under the whole board
mx.place(pad((110, 164.81, 220, 277.18, 329.63, 493.88), 7.5, .9, .2), 0.0, .07)
# airport chime + a jet passing left to right
for f, t0 in ((523.25, 0.03), (659.25, 0.27), (783.99, 0.51)): mx.place(bell(f, 1.4), t0, .085, rev=.6)
jet = whoosh(1.6, 220, 1500, lambda p: math.sin(math.pi * p) ** 1.6, 1.2, 13) + .5 * tone(80, 52, 1.6) * np.sin(np.pi * np.linspace(0, 1, int(1.6 * SR))) ** 2
mx.place(jet, -0.05, .16, np.linspace(-.9, .9, len(jet)), rev=.2)
# the board: one clack per falling flap, panned where it sits
def clack(seed, big):
    d = .035
    body = svf_noise(d, lambda p: 2300 if big else 3500, lambda p: math.exp(-p * 9), 2.5, seed)
    tok = tone(800 if big else 1300, 540 if big else 920, d) * env(d, .0004, .005 if big else .0035)
    out = .7 * body + .45 * tok
    if big: out += .4 * tone(190, 120, d) * env(d, .0005, .006)
    return out
BANK = {"L": [clack(100 + i, True) for i in range(10)], "S": [clack(200 + i, False) for i in range(10)]}
for t0, size, cx in json.load(open("flips.json")):
    g = (.085 if size == "L" else .05) * r.uniform(.7, 1.0) * (1 - seg(t0, 7.28, 7.58))
    mx.place(BANK[size][r.integers(10)], t0 + r.uniform(0, .004), g, (cx - 540) / 540 * .75)
# "Pause them for the trip." — statuses fall to PAUSED
for i in range(5): mx.place(marimba(659.25 * 1.12 ** i, .3), 1.62 + i * .07, .04)
for t0 in (2.12, 2.26): mx.place(kick(95, 50, .1, .3), t0, .12)
mx.place(chord((146.83, 220, 293.66, 369.99), 2.2, .3, 1.4), 2.2, .07, rev=.4)
mx.place(whoosh(.3, 600, 2400, seed=17), 2.9, .05)
mx.place(marimba(1046.5), 3.24, .1, rev=.4); mx.place(marimba(1318.5), 3.32, .09, rev=.4)          # the app's status pill
# nine days fly by: one rising note per day
mx.place(riser(1.6, 160, 900, 23), 4.45, .1)
for i in range(4): mx.place(marimba(523.25 * 1.12 ** i, .3), 4.48 + i * .07, .03)
for f, t0 in zip((440, 493.88, 554.37, 659.25, 739.99, 880, 987.77, 1108.73), (4.95, 5.10, 5.23, 5.35, 5.47, 5.59, 5.72, 5.88)):
    mx.place(marimba(f, .4), t0, .075, rev=.3)
# Monday the 28th: it's back — and it rings
mx.place(kick(150, 50, .14), 6.09, .3); mx.place(bell(1318.51, 1.6), 6.10, .1, rev=.6)
mx.place(chord((220, 277.18, 329.63, 440, 554.37), 1.6, .08, 1.0), 6.10, .08, rev=.5)
trill(mx, 6.26, .42, .1)
for i in range(5): mx.place(marimba(880 * 1.12 ** i, .3), 6.24 + i * .07, .04)
# board tips away -> end card
mx.place(riser(.5, 200, 1400, 9), 6.85, .09)
mx.place(whoosh(.5, 1700, 300, Q=1.3, seed=29), 7.08, .08)
mx.place(boom(1.4) * .7, 7.35, .34, rev=.3)
mx.place(whoosh(.45, 500, 2600, lambda p: math.sin(math.pi * p) ** .9, 2.2, 27), 7.5, .08)
for t0 in (7.72, 7.80): mx.place(click(2600, .005), t0, .13)
for t0, pan in ((7.90, -.3), (7.94, .3)): mx.place(metal(1900, .18), t0, .06, pan, rev=.5)
trill(mx, 8.03, .32, .1)
mx.place(chord((220, 277.18, 329.63, 440, 659.25), 1.5, .15, 1.2), 7.98, .07, rev=.5)
mx.place(metal(880, .9, 1.2), 7.98, .06, rev=.6)
mx.place(svf_noise(.4, lambda p: 6500, lambda p: math.sin(math.pi * p) ** 2, 3, 31) + .3 * partials(3520, [1, 1.5], [1, .4], [.4, .3], .4), 8.57, .05, rev=.5)
m = mx.write("audio.wav"); print("05 audio ok, peak", np.abs(m).max())
