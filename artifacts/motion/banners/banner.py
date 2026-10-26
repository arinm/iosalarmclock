"""python3 banner.py <scene.html> <out.png> [scale] [t] [safe]   (safe: draw the scene's #safe rectangle, QA only)
Static banner from a motion-engine scene. The scene declares window.CLIP = {w, h} in CSS pixels;
the PNG comes out at w*scale x h*scale, opaque RGB (App Store rejects alpha). Never overwrites: -vN."""
import asyncio, sys, pathlib
from PIL import Image
from playwright.async_api import async_playwright
scene, out = sys.argv[1], pathlib.Path(sys.argv[2])
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
t = float(sys.argv[4]) if len(sys.argv) > 4 else 99.0
if out.exists():
    i = 2
    while out.with_name(f"{out.stem}-v{i}{out.suffix}").exists(): i += 1
    out = out.with_name(f"{out.stem}-v{i}{out.suffix}")
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(args=["--force-color-profile=srgb"])
        pg = await b.new_page(viewport={"width": 800, "height": 600})
        await pg.goto(pathlib.Path(scene).resolve().as_uri()); await pg.wait_for_function("window.CLIP")
        clip = await pg.evaluate("window.CLIP")
        ctx = await b.new_context(viewport={"width": clip["w"], "height": clip["h"]}, device_scale_factor=scale)
        pg = await ctx.new_page(); errs = []
        pg.on("pageerror", lambda e: errs.append(str(e)))
        await pg.goto(pathlib.Path(scene).resolve().as_uri()); await pg.wait_for_function("window.CLIP")
        await pg.evaluate("window.__ready"); await pg.evaluate(f"window.render({t})"); await pg.evaluate(f"window.render({t})")
        if len(sys.argv) > 5 and sys.argv[5] == "safe": await pg.evaluate("document.body.classList.add('showsafe')")
        tmp = out.with_suffix(".tmp.png"); await pg.screenshot(path=str(tmp)); await b.close()
        for e in errs: print("PAGEERROR", e)
    Image.open(tmp).convert("RGB").save(out); tmp.unlink()
    print(out, Image.open(out).size, Image.open(out).mode)
asyncio.run(main())
