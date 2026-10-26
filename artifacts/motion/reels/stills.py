"""python3 stills.py <scene.html> <outdir> t1 t2 ...  -> PNG stills + contact sheet (sheet.png)"""
import asyncio, sys, time, pathlib
from PIL import Image, ImageDraw
from playwright.async_api import async_playwright
scene, out = sys.argv[1], pathlib.Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
TIMES = [float(x) for x in sys.argv[3:]]
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(args=["--force-color-profile=srgb", "--disable-lcd-text"])
        pg = await b.new_page(viewport={"width": 1080, "height": 1920}, device_scale_factor=1)
        msgs = []; pg.on("console", lambda m: msgs.append(m.text)); pg.on("pageerror", lambda e: msgs.append("PAGEERROR " + str(e)))
        await pg.goto(pathlib.Path(scene).resolve().as_uri()); await pg.wait_for_function("window.CLIP")
        clip = await pg.evaluate("window.CLIP"); await pg.set_viewport_size({"width": clip["w"], "height": clip["h"]})
        await pg.evaluate("window.__ready")
        for t in (0.5, 3, 6, 9): await pg.evaluate(f"window.render({t})"); await pg.screenshot()   # warm-up
        files = []
        for t in TIMES:
            await pg.evaluate(f"window.render({t})"); f = out / f"t{t:05.2f}.png"; await pg.screenshot(path=str(f)); files.append((t, f))
        for m in msgs: print("console:", m)
        await b.close()
    tw, th = clip["w"] // 4, clip["h"] // 4; cols = min(6, len(files)); rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (tw * cols, th * rows), (40, 40, 40))
    for i, (t, f) in enumerate(files):
        sheet.paste(Image.open(f).resize((tw, th), Image.LANCZOS), ((i % cols) * tw, (i // cols) * th))
        ImageDraw.Draw(sheet).text(((i % cols) * tw + 6, (i // cols) * th + 4), f"{t:.2f}s", fill=(255, 255, 0))
    sheet.save(out / "sheet.png"); print(f"{len(files)} stills -> {out/'sheet.png'}")
asyncio.run(main())
