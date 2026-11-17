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
   - **Japanese UI:** prefix the test with `TEST_RUNNER_SCREENSHOT_LANG=ja` (ja/ja_JP)
     and use `<name>` = `iphone-17-pro-max-ja`. The exported files are UUIDs; rename
     each one from `suggestedHumanReadableName` in `png/manifest.json`.
   - The simulator can't arm AlarmKit alarms, so `--app-store-screenshots` hides
     both the permission banner and the per-card "Couldn't schedule" warning.
     The capture uses the real clock: in the evening the card button reads
     "Skip tomorrow" (明日をスキップ).
2. **Frame.** The designed marketing frames ("Slice N.png") are exported at
   1290×2796, the 6.9" slot. Their captions are in `app-store-listing.md`.
3. **6.5" slot.** `./to-65-inch.sh ~/Downloads/Slice*.png` resamples them to
   1284×2778 into `artifacts/6.5-inch/`. It never stretches the image.

4. **iPhone Duo slot and other languages.** `motion/duo/duo.py` builds simple
   frames (caption on top, the real capture in a phone frame, the store colours)
   from the captures: `iphone-17-pro-max-v2` for en, `iphone-17-pro-max-ja`
   (Japanese UI, since 1.0.3) for ja:
   ```sh
   python3 artifacts/motion/duo/duo.py --lang en --size duo   # 1398x2034 -> app-store-screenshots/iphone-duo/en
   python3 artifacts/motion/duo/duo.py --lang ja --size 69    # 1320x2868 -> app-store-screenshots/iphone-69/ja
   python3 artifacts/motion/duo/duo.py --lang ja --only 2     # re-render one frame (as -vN)
   ```
   The captions live in the script's `FRAMES` table. The ja texts and the full ja
   listing are in `app-store-listing-ja.md`. The Settings capture is left out on
   purpose, because it shows "Alarms (AlarmKit) Off".

5. **Japanese copy of the designed Slices (since 1.0.3).** `motion/ja-slices/` rebuilds the
   8 English Figma Slices (the live en set, from `~/Downloads/500+ App store screenshot
   templates ... (10)/(11)/(12)`) in Japanese: `find.py` locates each en capture in the
   panorama (SIFT), `phones.py` warps the ja captures onto the screens (keeps the island),
   `text.py` + `erase.py` remove the en captions, `ja_text.py` draws the ja captions
   (Hiragino W5/W3) and writes `app-store-screenshots/iphone-69/ja-slices/` (1290x2796; since 16 Nov
   2026 those live in `by-country/ja Japanese/1290x2796/`, so move a new render there).
   The 6.5" copies are in `app-store-screenshots/6.5-inch/ja/`. ASC's current iPhone slot
   ("iPhone with Dynamic Island (medium display)") takes only 1206x2622 or 1179x2556: upload
   `app-store-screenshots/by-country/ja Japanese/` (1206x2622, numbered in the live en order
   1,2,3,7,8,4,6,5). Run them in that order
   from one working folder. These are the ja store frames; the `duo.py` ja set is not.

6. **Latin-script copies of the Slices (1.0.5: de, fr, es-ES, es-MX, pt-BR).** Same folder,
   same order, with `SLICE_LANG=<lang>` on `phones.py`, `erase.py` and `latin_text.py`
   (`find.py` and `text.py` run once, they don't depend on the language). The captures come
   from `app-store-screenshots/iphone-17-pro-max-<lang>/png/` (ScreenshotTests with
   `TEST_RUNNER_SCREENSHOT_LANG=<lang>`); es-ES uses the `es` captures, es-MX has its own
   (a.m./p.m., "Configuración"). `latin_text.py` draws the captions as Figma did: DM Sans
   Medium (variable font, wght 500, opsz 14), titles 104px (slice 1: 140px), subtitles 64px,
   line height 100%, white, rendered in Chromium (Playwright) for the kerning. The font goes
   in `motion/ja-slices/fonts/` (gitignored; the script prints the Google Fonts URL, OFL).
   The captions are in its `C` table. A title or subtitle wider than 1060px shrinks for that
   slice, and the script warns below ~90%: break the line differently instead. Self-test:
   `SLICE_LANG=en` must give back the live en Slices (`ln -s pano-en.png pano-en-phones.png`
   first). `latin_text.py save` writes the upload set into `by-country/<lang ...>/` (1206x2622,
   numbered 1,2,3,7,8,4,6,5) and the 1290x2796 copies into its `1290x2796/`. It never
   overwrites: the earlier version moves to `old/` and the new one gets -v2, -v3…

**Upload folders (since 16 Nov 2026).** `app-store-screenshots/by-country/<code> <ASC language>/`
(e.g. `es-MX Spanish (Mexico)`) holds exactly what goes into App Store Connect for that
localization: the 8 screenshots, numbered 01–08 in upload order, and the header banner.
`1290x2796/` has the larger copies (not uploaded) and `old/` the superseded versions. Spain and
Mexico are separate folders with the same header image.

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

### App Store header and search-results banners (since iOS 27, Oct 2026)

Sources live in `artifacts/motion/banners/`: `header.html`, `search.html`, plus
the shared `common.js` and `common.css`. Render them with:

```sh
cd artifacts/motion/banners
python3 banner.py header.html out/header-21x9-3840x1646.png 2      # @2x, opaque RGB (no alpha allowed)
python3 banner.py search.html out/search-3x2-3840x2560.png 2
python3 banner.py header.html /tmp/qa.png 1 99 safe                 # QA: draws the safe box
```

The localized headers (12 Nov 2026) are two scenes that read `?lang=`:
`header-week.html` ("the skipped day": the week on a dial's rim, today struck
through in sage, tomorrow armed in peach) and `header-mark.html` (the mark with
sound waves). `BANNER_LANG=ja` sets the language: the tagline (`TAG` in
`common.js`), Hiragino for the text, and kanji weekdays (日月火…).

The tagline is "Skip today before it rings. / Tomorrow still rings." (ja:
鳴る前に、今日だけスキップ / 明日はいつも通り鳴る). The earlier "Skip today. Keep
tomorrow." read as Stop, which every alarm already has. The banner has to say
that the skip comes before the ring, and that tomorrow still rings. "Day off? Skip
just today." was tried on 16 Nov 2026 and dropped: a day off sounds like the repeat
days every alarm already has, while "before it rings" names the one-time skip ahead
of time. Line 2 says "as usual" in every translation, because "keeps ringing" reads
as ringing non-stop.

```sh
python3 banner.py header-week.html out/header-week-en-3840x1646.png 2
BANNER_LANG=ja python3 banner.py header-week.html out/header-week-ja-3840x1646.png 2
```

A new language needs a `TAG` entry in `common.js`. Check both lines against
the safe box with the `safe` QA render (52px for en, 46–48px for ja).

Since 1.0.5 (16 Nov 2026) `TAG` also has de, fr, es and pt-BR, rendered with
`header-mark.html`; es-ES and es-MX share the `es` header. The final header of each
localization goes into its `app-store-screenshots/by-country/` folder (the one it replaces
moves to `old/` there). At 52px the de and fr first lines run past the safe box, so
`header-mark.html` sets 48px for de and 46px for fr (`html[lang=de] #head .l`).

| Slot | Size | Template safe box (centred) |
|---|---|---|
| Header | 21:9, 3840×1646 (JPEG/PNG) | 1646×661 |
| Search results | 3:2, 1920×1280 to 3840×2560 | 2168×1030 |
| Universal, both slots | 16:9, 5244×2950 (PNG only) | 1402×962, 334px above centre |

The safe boxes are a third party's measurement of Apple's templates, not a
published spec. Verify every upload with the **Preview** button in App Store
Connect.

- The message goes inside the safe box: the tagline, and for search the real
  alarm card. Everything outside it is decoration that wide screens show and
  iPhone crops away.
- Apple's rules: one clear idea per asset; text only as a short phrase,
  localized; no price, URL or © sign; no other platform's logo; 4+ content.
- Both slots also accept a looping, muted 5–30s video at the same ratios.
- These banners appear on iOS 27 and later.

### Banners and static images

Use the same engine. Write a one-frame scene (or reuse a reel scene) and
capture it with `stills.py` at the size you need: set `CLIP.w` and `CLIP.h`,
e.g. 1200×630 for a link card, 1080×1080 or 1080×1350 for a feed post, 1500×500
for an X header. The brand tokens and the end-card lockup then stay identical
across clips and banners.
