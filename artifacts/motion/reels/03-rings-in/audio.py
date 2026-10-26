import sys, math, numpy as np; sys.path.insert(0, "../lib")
from sfx import *
import importlib.util
mx = Mix(8.8)
# reproduce the wheel motion exactly, so every detent clicks when a number crosses the band
def wheel(t):
    h = 10 - 5 * outBack(seg(t, 0, 2.0), 1.05)
    m = 45 + 105 * (1 - 2 ** (-10 * seg(t, 0, 2.25)) if seg(t, 0, 2.25) < 1 else 1)
    ap = 1 - outBack(seg(t, 0.85, 1.25), 1.6)
    return h, m, ap
last = [round(v) for v in wheel(0)]
for k in range(1, 2600):
    t = k / 1000; cur = [round(v) for v in wheel(t)]
    for ci, (a, b) in enumerate(zip(last, cur)):
        if a != b: mx.place(click((2300, 3100, 1700)[ci] + np.random.uniform(-150, 150), .0025, .02), t, (.10, .06, .12)[ci], (-.35, 0, .35)[ci])
    last = cur
mx.place(whoosh(.5, 600, 2400, lambda p: (1 - p) ** 2, 1.2, 3), 0.0, .12)           # hook: wheels already whirling
for i in range(3): mx.place(marimba(784 * 1.12 ** i, .25), 0.0 + i * .07, .05)
mx.place(marimba(1318.5, .8), 2.30, .14, rev=.4); mx.place(marimba(1975.5, .8), 2.38, .12, rev=.4)   # lands: 7h 42m
mx.place(bell(2637, 1.0), 2.34, .05, rev=.5)
for i in range(5): mx.place(marimba(880 * 1.12 ** i, .3), 2.58 + i * .07, .045)
mx.place(click(2400, .006), 3.30, .15)                                              # live tick
mx.place(whoosh(.45, 1200, 300, seed=8), 3.80, .12)
for i in range(3): mx.place(kick(120, 55, .08, .25) * .6, 3.95 + i * .09, .2); mx.place(marimba(1046.5 * 1.26 ** i, .3), 3.97 + i * .09, .05)
for i in range(5): mx.place(marimba(988 * 1.12 ** i, .3), 4.02 + i * .07, .04)
for k in range(3): mx.place(click(2600, .003), 4.4 + k * .55, .09, .3)               # cards tick live
mx.place(whoosh(.36, 2400, 300, seed=17), 5.52, .12)
for i in range(4): mx.place(marimba(659.25 * 1.12 ** i, .3), 5.78 + i * .07, .045)
mx.place(tone(300, 220, .12) * env(.12, .002, .05), 6.0, .12)
mx.place(whoosh(.28, 2000, 6500, Q=2.2, seed=19), 6.42, .1)                          # the sum gets struck out
mx.place(kick(150, 60, .12), 6.55, .3); mx.place(marimba(1568, .8), 6.56, .14, rev=.4); mx.place(bell(2093, 1.0), 6.56, .05, rev=.5)
# end card (speed 1.6 from 7.05)
mx.place(boom(1.4) * .7, 7.05, .36, rev=.3)
mx.place(whoosh(.45, 500, 2600, lambda p: math.sin(math.pi * p) ** .9, 2.2, 27), 7.2, .09)
for t0 in (7.42, 7.5): mx.place(click(2600, .005), t0, .14)
for t0, pan in ((7.6, -.3), (7.64, .3)): mx.place(metal(1900, .18), t0, .06, pan, rev=.5)
trill(mx, 7.73, .32, .1)
mx.place(chord((220, 277.18, 329.63, 440, 659.25), 1.4, .15, 1.2), 7.68, .07, rev=.5)
mx.place(metal(880, .9, 1.2), 7.68, .06, rev=.6)
mx.place(svf_noise(.45, lambda p: 6500, lambda p: math.sin(math.pi * p) ** 2, 3, 31) + .3 * partials(3520, [1, 1.5], [1, .4], [.4, .3], .45), 8.25, .05, rev=.5)
mx.write("audio.wav"); print("03 audio ok")
