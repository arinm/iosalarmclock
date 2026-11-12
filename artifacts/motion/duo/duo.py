"""python3 duo.py [--lang en|ja] [--size duo|69] [--only 2,4] [--out dir]
App Store screenshots, opaque RGB: iPhone Duo slot (portrait 1398x2034) or the 6.9" slot (1320x2868).
Same look as the 6.9" store slices: terracotta/dark background, caption on top, the real capture in a phone frame.
Captures come from app-store-screenshots/iphone-17-pro-max-v2/png (en) and iphone-17-pro-max-ja/png
(ja, the Japanese UI since 1.0.3; the first ja frames used the English captures). Never overwrites: -vN."""
import asyncio, sys, pathlib
from PIL import Image
from playwright.async_api import async_playwright

ROOT = pathlib.Path(__file__).resolve().parents[2]
import argparse
ap = argparse.ArgumentParser(); ap.add_argument("--lang", default="en"); ap.add_argument("--size", default="duo")
ap.add_argument("--only", default=""); ap.add_argument("--out", default="")
A = ap.parse_args()
SRC = ROOT / "app-store-screenshots" / ("iphone-17-pro-max-ja" if A.lang == "ja" else "iphone-17-pro-max-v2") / "png"
ONLY = {int(x) for x in A.only.split(",")} if A.only else None
# size: (W, H, phone width, phone top, caption top). Blob paths are drawn for 1398x2034 and scaled.
SIZES = {"duo": (1398, 2034, 880, 760, 150), "69": (1320, 2868, 1000, 860, 230)}
W, H, PW, PT, CT = SIZES[A.size]
OUT = pathlib.Path(A.out) if A.out else ROOT / "app-store-screenshots" / ("iphone-duo" if A.size == "duo" else "iphone-69") / A.lang

# (capture, headline, subline, blob variant). No price talk, no "free" (2.3.7).
FRAMES = {"en": [
    ("01-Home", "Skip today.<br>Never forget tomorrow.", "The alarm that tells you before it rings.", 0),
    ("02-Editor", "Always know<br>when it rings", "A live countdown on every alarm.", 1),
    ("06-SkipConfirmation", "One tap.<br>One day skipped.", "Tomorrow stays armed.", 2),
    ("05-Detail", "Go Pro when<br>you're ready", "Vacation pause, alarm groups, custom heads-ups and themes.", 1),
], "ja": [
    ("01-Home", "今日だけスキップ。<br>明日は忘れない。", "鳴る前に知らせてくれる目覚まし。", 0),
    ("02-Editor", "いつ鳴るか、<br>ひと目でわかる", "すべてのアラームに残り時間を表示。", 1),
    ("07-SkipConfirmation", "ワンタップで、<br>1日だけお休み。", "翌日のアラームはそのまま有効。", 2),
    ("05-Detail", "必要になったら<br>Proへ", "祝日の自動スキップ、休暇中の一時停止、<br>アラームのグループなど。", 1),
]}[A.lang]
BLOBS = [
    "M0,1250 C300,1050 650,1350 900,1150 C1150,950 1300,1100 1398,1000 L1398,2034 L0,2034 Z",
    "M0,0 L1398,0 L1398,700 C1100,900 800,500 450,760 C250,900 100,800 0,880 Z M0,1600 C400,1450 900,1800 1398,1550 L1398,2034 L0,2034 Z",
    "M1398,0 L1398,1200 C1100,1000 900,1400 600,1250 C350,1120 200,1300 0,1200 L0,0 Z",
]

def html(img, head, sub, b):
    return f"""<!doctype html><html lang="{A.lang}"><head><meta charset="utf-8"><style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{width:{W}px;height:{H}px;overflow:hidden;background:#B9725A;font-family:-apple-system,'SF Pro Display','Hiragino Sans',sans-serif;position:relative}}
svg{{position:absolute;inset:0}}
:lang(ja) h1{{font-size:{104 if A.size=="duo" else 100}px;letter-spacing:0;line-height:1.2;font-weight:800}} :lang(ja) p{{font-size:44px;line-height:1.45}}
.cap{{position:absolute;top:{CT}px;left:0;right:0;text-align:center;color:#F4F4F7}}
h1{{font-size:112px;font-weight:700;letter-spacing:-0.035em;line-height:1.02}}
p{{margin:34px auto 0;font-size:46px;font-weight:500;line-height:1.25;max-width:1020px;color:#F4EDEA}}
.phone{{position:absolute;left:50%;top:{PT}px;width:{PW}px;height:{round((PW-52)*2868/1320)+52}px;transform:translateX(-50%);
  border-radius:150px;background:#0b0b0e;padding:26px;box-shadow:0 0 0 6px #2a2a30,0 60px 140px rgba(0,0,0,.55)}}
.phone img{{width:100%;height:100%;border-radius:126px;display:block;object-fit:cover;object-position:top}}
</style></head><body>
<svg viewBox="0 0 1398 2034" width="{W}" height="{H}" preserveAspectRatio="none"><path d="{BLOBS[b]}" fill="#1E1512"/></svg>
<div class="cap"><h1>{head}</h1><p>{sub}</p></div>
<div class="phone"><img src="{img.as_uri()}"></div>
</body></html>"""

def free(p):
    if not p.exists(): return p
    i = 2
    while p.with_name(f"{p.stem}-v{i}{p.suffix}").exists(): i += 1
    return p.with_name(f"{p.stem}-v{i}{p.suffix}")

async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as pw:
        b = await pw.chromium.launch(args=["--force-color-profile=srgb", "--allow-file-access-from-files"])
        pg = await b.new_page(viewport={"width": W, "height": H}, device_scale_factor=1)
        for k, (cap, head, sub, blob) in enumerate(FRAMES, 1):
            if ONLY and k not in ONLY: continue
            tmp = OUT / f"_tmp{k}.html"
            tmp.write_text(html(SRC / f"{cap}.png", head, sub, blob))
            await pg.goto(tmp.as_uri()); await pg.wait_for_load_state("networkidle")
            out = free(OUT / f"duo-{k:02d}-{cap.split('-',1)[1].lower()}-{W}x{H}.png")
            png = out.with_suffix(".tmp.png"); await pg.screenshot(path=str(png)); tmp.unlink()
            Image.open(png).convert("RGB").save(out); png.unlink()
            print(out.name, Image.open(out).size, Image.open(out).mode)
        await b.close()

asyncio.run(main())
