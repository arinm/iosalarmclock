import sys, math, numpy as np; sys.path.insert(0, "../lib")
from sfx import *
mx = Mix(11.3)
# bed
mx.place(pad((130.81, 196, 261.63, 329.63, 392, 493.88), 9.9, .8, .2), 0.0, .06)
# hook: three words, three sounds - bright / held / switched off
mx.place(kick(150, 50, .14), 0.0, .4); mx.place(marimba(1318.5, .6), 0.0, .12, rev=.4); mx.place(marimba(1975.5, .6), 0.04, .07, rev=.4)
mx.place(kick(130, 48, .14), 0.2, .36); mx.place(chord((392, 493.88, 587.33), .7, .01, .4), 0.2, .12, rev=.4)
mx.place(kick(110, 40, .16), 0.4, .4); mx.place(tape_stop(.35), 0.4, .12)
for i in range(4): mx.place(marimba(523.25 * 1.12 ** i, .3), 0.72 + i * .06, .045)       # "Three different things."
mx.place(whoosh(.35, 2000, 500, Q=1.3, seed=7), 1.34, .1)
# SKIP: the week pops in, today gets skipped, tomorrow rings
for i, f in enumerate((523.25, 587.33, 659.25, 698.46, 783.99, 880, 987.77)): mx.place(marimba(f, .3), 1.62 + i * .05, .045, (i - 3) / 4)
for i in range(4): mx.place(marimba(880 * 1.12 ** i, .3), 1.66 + i * .07, .03)
mx.place(whoosh(.25, 1800, 600, Q=1.6, seed=11), 2.2, .07); mx.place(marimba(1568), 2.3, .1, rev=.4); mx.place(marimba(2093), 2.38, .08, rev=.4)
trill(mx, 2.72, .3, .09)
# PAUSE: a held amber chord, the range stretches across four days, Sunday comes back
mx.place(whoosh(.35, 600, 2200, seed=13), 3.78, .08)
mx.place(kick(120, 48, .12), 3.86, .25); mx.place(chord((196, 246.94, 293.66, 392), 2.0, .2, 1.4), 3.88, .08, rev=.5)
mx.place(click(2400, .005), 4.05, .14); mx.place(marimba(1174.66, .4), 4.07, .07)                 # PRO tag
mx.place(riser(.5, 200, 700, 17), 4.36, .06)
for i, f in enumerate((392, 440, 493.88, 523.25)): mx.place(marimba(f, .35), 4.42 + i * .1, .06, -.3 + i * .2)
trill(mx, 5.27, .3, .09)
# OFF: one switch, everything powers down
mx.place(whoosh(.35, 2000, 400, seed=19), 6.1, .08); mx.place(kick(100, 40, .18), 6.18, .3)
mx.place(click(1700, .006), 6.5, .32, .1); mx.place(tone(520, 260, .2) * env(.2, .002, .06), 6.52, .14)
mx.place(tape_stop(.6), 6.6, .14)
for i in range(7): mx.place(marimba(659.25 * 0.92 ** i, .3), 6.62 + i * .06, .03, (i - 3) / 4)
# payoff: the three status lines
mx.place(whoosh(.4, 500, 2400, seed=23), 7.98, .08)
for i in range(4): mx.place(marimba(783.99 * 1.12 ** i, .3), 8.08 + i * .07, .04)
for t0, f in ((8.26, 1318.5), (8.38, 1046.5), (8.50, 783.99)): mx.place(click(2600, .004), t0, .1); mx.place(marimba(f, .5), t0 + .01, .09, rev=.4)
# end card at 9.5, speed 1.6
mx.place(riser(.5, 200, 1400, 9), 9.0, .09)
mx.place(boom(1.4) * .7, 9.5, .34, rev=.3)
mx.place(whoosh(.45, 500, 2600, lambda p: math.sin(math.pi * p) ** .9, 2.2, 27), 9.65, .08)
for t0 in (9.87, 9.95): mx.place(click(2600, .005), t0, .13)
for t0, pan in ((10.05, -.3), (10.09, .3)): mx.place(metal(1900, .18), t0, .06, pan, rev=.5)
trill(mx, 10.18, .32, .1)
mx.place(chord((220, 277.18, 329.63, 440, 659.25), 1.1, .15, 1.0), 10.13, .07, rev=.5)
mx.place(metal(880, .9, 1.1), 10.13, .06, rev=.6)
mx.place(svf_noise(.4, lambda p: 6500, lambda p: math.sin(math.pi * p) ** 2, 3, 31) + .3 * partials(3520, [1, 1.5], [1, .4], [.4, .3], .4), 10.72, .05, rev=.5)
mx.write("audio.wav"); print("06 audio ok")
