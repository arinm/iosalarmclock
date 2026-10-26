# How we make Punctual's marketing (screenshots, banners, clips)

Read this before making any new marketing asset. It records how the existing ones
were built, the rules they had to pass, and the commands to rebuild them.

**Git rule:** media stays local only. The `.md` files and the small sources that
rebuild the media are versioned (see `.gitignore`). Losing the local folder loses
only renders, never the recipe.

---

## Rules every asset must pass

- **No price talk in anything App Store-facing.** Screenshots, captions,
  subtitle, promotional text: no price, no discount, not even the word "free"
  (guideline 2.3.7; build 20 was rejected over the paywall screenshot). Prices
  belong in the description only. There is no paywall screenshot that can go in
  the store set.
- **No competitor or other-platform names** in the binary or keyword metadata
  (2.3.10 rejection, build 12).
- **Honest copy.**
  - Show the app's real wording: "Skipped today · still active",
    "Paused until Sun 27 Dec", "Off - won't ring", "Rings in 7h 42m". These come
    from `StatusPresenter` in `App/Design/Theme.swift`.
  - Pro features (vacation pause, groups, custom heads-up timing, snooze past
    15 minutes) carry a visible **PRO** label.
  - Never promise that an alarm will always ring.
- **Never overwrite or delete an earlier render.** Every new pass is a new file
  (`-v2`, `-v3`, ...). `render.py` enforces this.
- Social clips are not App Previews. An App Store preview must be a real
  screen capture of the app; these motion pieces are for socials and the site.

## Brand tokens

| Token | Value | Used for |
|---|---|---|
| Background | `#060609` (radial to `#120f14`) | every frame |
| Peach (accent, armed/next) | `#FFA885` (raw `#F58C6B`) | the mark, "armed", CTAs |
| Sage (skipped / still active) | `#8FC7A0` | skip states |
| Amber (paused) | `#E2B23E` | pause states, PRO badge |
| Grey (off) | `#8E8E98` / `#5E5E68` | off states |
| Text | `#F4F4F7`, muted `#A6A6B0` | |
| Type | SF Pro (`-apple-system`), 800 weight, tight tracking (−0.045em) for headlines | |

The mark ("the missing hour") is the dial with a ~7% gap at 2 o'clock, two bells
and sound arcs. Its exact geometry lives in `generate-icons.py`. Don't
"improve" it: the outer arc is deliberately shorter than the inner one, and the
inset is 74%.

---

## App Store screenshots

1. **Capture.** `PunctualUITests/ScreenshotTests.swift` drives the app with
   `--seed-demo --demo-free --skip-onboarding --app-store-screenshots` (demo
   data, presented as Free, en_US) and attaches one screenshot per screen.
   ```sh
   xcodegen generate
   xcodebuild test -scheme Punctual -only-testing:PunctualUITests/ScreenshotTests \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
     -resultBundlePath artifacts/app-store-screenshots/<name>.xcresult
   xcrun xcresulttool export attachments --path artifacts/app-store-screenshots/<name>.xcresult \
     --output-path artifacts/app-store-screenshots/<name>/png
   ```
   The `NOT-FOR-STORE-iap-review-Paywall` shot is only for the In-App Purchase
   review screenshot in App Store Connect. It never goes in the store set.
2. **Frame.** The designed marketing frames ("Slice N.png") are exported at
   1290×2796, the 6.9" slot. Their captions are in `app-store-listing.md`.
3. **6.5" slot.** `./to-65-inch.sh ~/Downloads/Slice*.png` resamples them to
   1284×2778 into `artifacts/6.5-inch/`. It never stretches the image.

## App icon and site logo

`python3 artifacts/generate-icons.py` regenerates the whole icon set and the web
logo from the approved geometry. It needs cairosvg. Dash lengths are in user
units because cairosvg ignores `pathLength`.

---

## Motion (social clips)

Everything is a deterministic HTML/SVG/JS scene rendered frame by frame.
`window.render(t)` is a pure function of time, so frames can render in any
order and in parallel, and each frame is sampled several times for real motion
blur. The sound is synthesised in numpy, so there is no licensed music and no
copyright issue on any platform.

**Requirements:** `python3` with `numpy`, `Pillow` and `playwright`
(`python3 -m playwright install chromium`), plus `ffmpeg`.

### Layout

```
artifacts/motion/
  showreel.html  audio.py  render.py  stills.py   # v1: the 16:9 15s showreel (1920x1080)
  reels/                                          # vertical 9:16 reels (1080x1920)
    lib/engine.js   shared motion engine
    lib/base.css    shared styles (cards, week strip, phone, end card)
    lib/sfx.py      sound kit
    render.py  stills.py  qa.py  queue.sh
    NN-name/scene.html + audio.py                 # one folder per reel
    out/                                          # renders (local only)
```

### Making a new reel

1. **Scene.** Copy the reel folder closest to what you want, e.g. `04-pillow`.
   - Declare `window.CLIP = {w:1080, h:1920, fps:60, dur, sub:[[t0,t1,samples]]}`.
     `sub` raises the motion-blur samples (default 4) inside fast windows such as
     a dive, a whip or the end card.
   - Implement `init()` (build the DOM) and `render(t)`, then call
     `boot({init, render})`.
   - Engine helpers:
     - Easing and springs: `E.*`, `spring`, `keyed`.
     - Masked word reveals: `setWords`, `wordsIn`, `wordsInOut`. Words stay
       hidden outside their cue, so no glyph tips peek under the mask.
     - The mark: `buildMark`, `drawMark`, `ringMark`.
     - Heads-up notification that morphs into the pill: `buildNotif`, `drawNotif`.
     - Finger tap: `tapFX`.
     - Week strip: `buildWeek`, `daySkip`, `dayArm`.
     - Phone home screen: `buildPhone`.
     - End card: `buildLockup`, `renderLockup` (`speed` 1.5–1.6 for reels).
2. **Safe zones** (TikTok / Reels / Shorts UI covers these):
   - Avoid the top ~220px, the bottom ~400px, and the right rail (x > 960, y 1050–1650).
   - Keep the key content between y ≈ 280 and 1400, centred around y ≈ 850–950.
     Earlier drafts that sat too high had to be shifted down.
3. **Stills before rendering.** QA the frames that matter:
   ```sh
   python3 stills.py NN-name/scene.html /tmp/qa 0.0 0.5 1.2 ...   # PNGs + sheet.png
   ```
   Check four things:
   - Frame 0 is never empty, because it is the hook and the thumbnail.
   - No two headlines overlap during a hand-off. Exit the old text fully before
     the next text enters.
   - Paint order: the finger and ripple come last in the DOM.
   - Nothing sits in the safe zones.
4. **Sound.** Write `audio.py` with `Mix(dur)` and `mx.place(sig, t0, gain, pan, rev)`,
   then `mx.write("audio.wav")`. Time every cue to the scene's numbers.
   - Keep a soft pad bed under the whole clip. Reel 03 v1 had half-second holes
     of digital silence that read as a glitch.
   - When a scene generates many events, export them from the page and play one
     sound per event. Reel 05 does this for the flaps (`flips.py` →
     `flips.json`, one clack per flap).
5. **Render.**
   ```sh
   python3 render.py NN-name/scene.html NN-name/audio.wav out/NN-title.mp4 5   # 5 workers
   ```
   Output:
   - `out/NN-title.mp4`: 2-pass ~16 Mbps, grain-tuned, 17–30MB. This is the
     file to upload.
   - `out/NN-title-master.mp4`: x264 CRF 15, kept as the archive.

   The render includes a Chromium warm-up and retries white glitch frames.
   About 0.7–1s per frame-sample, so a 10s reel takes ~6 minutes.
   - To render several clips in sequence: put one line per clip in `queue.txt`
     and run `./queue.sh`. A final line `END` stops it.
6. **QA the final encode.**
   ```sh
   python3 qa.py out/NN-title.mp4 /tmp/sheet.png
   ```
   It flags flashes, white frames and one-frame pops, and makes a contact sheet.
7. **Audio-only fix.** Remux into a new file instead of re-rendering:
   ```sh
   ffmpeg -n -i out/X.mp4 -i NN/audio-v2.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest out/X-v2.mp4
   ```

### What exists (October 2026)

| Clip | Length | Concept | End-card tag |
|---|---|---|---|
| `punctual-motion-v1` (16:9) | 15s | Showreel: mark build, dial, countdown, heads-up, skip, phone | Skip today. Keep tomorrow. |
| `01-showreel-916-v2` | 15s | The same showreel re-laid for 9:16 | Skip today. Keep tomorrow. |
| `02-forgot-to-turn-it-back-on` | 12s | Turn it off for a day off → forget → "You're late." → rewind → skip one day | Skip today. Keep tomorrow. |
| `03-always-know-when-it-rings-v2` | 8.8s | Wheel picker with a live "Rings in", three cards, the "no mental math" gag | Always know when it rings. |
| `04-decide-from-your-pillow` | 8.6s | Night lock screen, the 15-min heads-up, skip from bed, tomorrow armed | Skip it from your pillow. |
| `05-going-away-pause-it` | 9.8s | Split-flap departures board: alarms go PAUSED, the days fly by, back ON TIME on the 28th (PRO) | Going away? Pause it. |
| `06-skip-pause-off-v2` | 11.3s | Typographic explainer of the three states on one week strip, then the real status pills | Know exactly what will ring. |

Posting captions:
1. Skip today. Keep tomorrow. The smart alarm clock for iPhone.
2. Turned your alarm off for a day off… and forgot to turn it back on? Skip just one day instead.
3. No more mental math at midnight. Every alarm shows exactly when it rings.
4. A heads-up 15 minutes before it rings. Skip it without getting up.
5. Going away? Pause your alarms for the trip. They come back on their own. (Punctual Pro)
6. Skip, pause, off: three different things. Punctual keeps them straight.

Hashtags: `#iphone #alarmclock #iosapps #productivity #morningroutine`

### Banners and static images

Use the same engine. Write a one-frame scene (or reuse a reel scene) and
capture it with `stills.py` at the size you need: set `CLIP.w` and `CLIP.h`,
e.g. 1200×630 for a link card, 1080×1080 or 1080×1350 for a feed post, 1500×500
for an X header. The brand tokens and the end-card lockup then stay identical
across clips and banners.
