import asyncio, sys, time, pathlib
from playwright.async_api import async_playwright
HERE = pathlib.Path(__file__).parent
OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
TIMES = [float(x) for x in sys.argv[2:]]
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(args=["--force-color-profile=srgb", "--disable-lcd-text"])
        pg = await b.new_page(viewport={"width": 1920, "height": 1080}, device_scale_factor=1)
        msgs = []
        pg.on("console", lambda m: msgs.append(m.text)); pg.on("pageerror", lambda e: msgs.append("PAGEERROR " + str(e)))
        await pg.goto((HERE / "showreel.html").as_uri())
        await pg.evaluate("window.__ready")
        t0 = time.time()
        for t in TIMES:
            await pg.evaluate(f"window.render({t})")
            await pg.screenshot(path=str(OUT / f"t{t:05.2f}.png"))
        dt = (time.time() - t0) / max(1, len(TIMES))
        print(f"{len(TIMES)} stills, {dt*1000:.0f} ms each")
        for m in msgs: print("console:", m)
        await b.close()
asyncio.run(main())
