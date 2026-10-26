import sys, math, numpy as np; sys.path.insert(0, "../lib")
from sfx import *
mx = Mix(12.0)
# --- hook: "Day off / tomorrow?" slams in
mx.place(kick(150, 50, .14), 0.02, .42); mx.place(metal(2093, .12), 0.02, .08, rev=.4)
mx.place(kick(130, 48, .12), 0.16, .32); mx.place(marimba(1568, .5), 0.16, .09, rev=.3)
mx.place(whoosh(.5, 250, 2200), 0.30, .14)                                         # card rises
# --- "So you switch it off."
for i in range(5): mx.place(marimba(784 * 1.12 ** i, .25), 1.36 + i * .07, .04)
mx.place(click(1800, .006), 1.88, .3, .3); mx.place(tone(620, 300, .22) * env(.22, .002, .07), 1.92, .16, .3)   # tap + toggle off
mx.place(whoosh(.4, 2000, 400, Q=1.2, seed=4), 1.95, .08)                          # colour drains
# --- "...and forget": days fly by
for i in range(7): mx.place(marimba(523 * 0.94 ** i, .3), 2.68 + i * .06, .035)
ticks = np.cumsum(np.linspace(.18, .05, 26)) + 2.85
for t0 in ticks[ticks < 4.25]: mx.place(click(2600, .003), t0, .07, np.random.uniform(-.3, .3))
for t0 in (3.25, 3.75):                                                             # split-flap day change
    for k in range(9): mx.place(click(1200 + 300 * (k % 3), .002), t0 + k * .022, .09)
mx.place(riser(1.4, 180, 900), 2.86, .18)
# --- hard cut: "THURSDAY 8:47 — You're late."
mx.place(glitch(.32, 5), 4.28, .3); mx.place(sting(98), 4.30, .55, rev=.3); mx.place(boom(1.2), 4.30, .4)
mx.place(kick(160, 55, .15), 4.36, .3); mx.place(kick(140, 50, .15), 4.44, .28)
for t0 in (4.85, 5.35): mx.place(click(1500, .008, .05), t0, .2)                 # loud, anxious ticks
mx.place(glitch(.14, 9), 5.02, .22); mx.place(glitch(.1, 12), 5.42, .2)
# --- rewind
mx.place(tape_rewind(.86), 5.86, .34); mx.place(glitch(.1, 15), 5.86, .16)
mx.place(riser(.3, 400, 2400, 21) * np.linspace(0, 1, int(.3 * SR)) ** 2, 6.40, .25)
mx.place(boom(1.0) * .6, 6.70, .4, rev=.2)                                          # warm world returns
mx.place(chord((220, 277.18, 329.63, 440), 2.4, .3, 1.6), 6.70, .07, rev=.4)
# --- "Or skip just one day."
for i in range(5): mx.place(marimba(880 * 1.12 ** i, .3), 6.84 + i * .07, .045)
mx.place(whoosh(.3, 600, 2000, seed=19), 6.86, .06)
mx.place(click(2000, .006), 7.56, .3, .3); mx.place(kick(110, 60, .06, .2), 7.56, .16)   # tap
mx.place(whoosh(.3, 1800, 500, Q=1.6, seed=11), 7.74, .08)
mx.place(marimba(880), 7.82, .1, rev=.3); mx.place(marimba(1318.5), 7.90, .1, rev=.3)   # skipped ✓
for i, f in enumerate((1046.5, 1174.7, 1318.5, 1568, 1760, 2093, 2349)): mx.place(marimba(f, .4), 8.05 + i * .045, .055, -.5 + i / 6)
mx.place(tone(210, 120, .2) * env(.2, .002, .06), 8.40, .18)                       # Wednesday skipped
mx.place(bell(1760, 1.4), 8.70, .13, .2, rev=.6)                                    # Thursday armed
# --- "Thursday, 6:30. Right on time."
mx.place(whoosh(.36, 2400, 300, seed=17), 9.02, .12)
for i in range(5): mx.place(marimba(1046.5 * 1.12 ** i, .3), 9.22 + i * .07, .04)
mx.place(tone(640, 170, .12) * env(.12, .002, .035), 9.14, .3)
trill(mx, 9.40, 0.95, .2)
mx.place(chord((293.66, 369.99, 440, 587.33), 1.6, .25, 1.2), 9.40, .06, rev=.4)
# --- end card
mx.place(whoosh(.4, 3000, 600, seed=31), 10.06, .08)
mx.place(boom(1.4) * .7, 10.30, .38, rev=.3)
mx.place(chord((220, 277.18, 329.63, 440, 659.25), 1.7, .15, 1.4), 10.86, .07, rev=.5)
mx.place(metal(880, .9, 1.6), 10.86, .06, rev=.6)
mx.place(svf_noise(.5, lambda p: 6500, lambda p: math.sin(math.pi * p) ** 2, 3, 31) + .3 * partials(3520, [1, 1.5], [1, .4], [.4, .3], .5), 11.5, .05, rev=.5)
mx.write("audio.wav"); print("02 audio ok")
