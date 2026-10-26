"""Dump the scene's flap schedule (window.FLIPS) to flips.json so the sound design clacks in sync."""
import asyncio, json, pathlib
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(); pg = await b.new_page(viewport={"width": 1080, "height": 1920})
        await pg.goto(pathlib.Path("scene.html").resolve().as_uri()); await pg.wait_for_function("window.CLIP")
        await pg.evaluate("window.__ready"); f = await pg.evaluate("window.FLIPS"); await b.close()
    json.dump(f, open("flips.json", "w")); print(len(f), "flips")
asyncio.run(main())
