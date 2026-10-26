"""Final render: 1920x1080 @ 60fps, 4-sample motion blur (180° shutter), film grain.
   python3 render.py all [workers]   -> showreel.mp4
   python3 render.py worker a b out  -> frames [a,b) as lossless FFV1"""
import asyncio, io, sys, subprocess, pathlib, time
import numpy as np
from PIL import Image
from playwright.async_api import async_playwright

HERE = pathlib.Path(__file__).resolve().parent
W, H, FPS, DUR, SUB, SHUTTER = 1920, 1080, 60, 15.0, 4, 0.5
NFR = int(DUR * FPS)

async def grab(pg, t):
    await pg.evaluate(f"window.render({t:.6f})")
    return np.asarray(Image.open(io.BytesIO(await pg.screenshot(type="png"))).convert("RGB"), np.float32)

def sub_for(t):
    """More temporal samples where motion is extreme, so blur smears instead of stepping."""
    if 1.95 <= t <= 2.30 or 12.05 <= t <= 12.85: return 12
    if 2.30 < t <= 3.30 or 9.84 <= t <= 10.50 or 8.62 <= t <= 9.06: return 6
    return SUB

def glitched(img):
    # Cold-start compositor glitch paints the stage background white; the stage is
    # never brighter than this at the left-edge midpoint once the vignette applies.
    return img[530:550, 8:24].max() > 200

async def worker(a, b, out):
    ff = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
                           "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "ffv1", "-level", "3", out],
                          stdin=subprocess.PIPE)
    async with async_playwright() as p:
        br = await p.chromium.launch(args=["--force-color-profile=srgb", "--disable-lcd-text"])
        pg = await br.new_page(viewport={"width": W, "height": H}, device_scale_factor=1)
        await pg.goto((HERE / "showreel.html").as_uri()); await pg.evaluate("window.__ready")
        for t in np.linspace(0, DUR, 24): await grab(pg, float(t))      # warm the GPU/compositor
        t0 = time.time()
        for f in range(a, b):
            acc = np.zeros((H, W, 3), np.float32)
            sub = sub_for(f / FPS)
            for k in range(sub):
                t = f / FPS + ((k + 0.5) / sub - 0.5) * SHUTTER / FPS
                img = await grab(pg, t)
                if glitched(img): img = await grab(pg, t)              # one retry; real content passes the 2nd time
                acc += img
            acc /= sub
            g = np.random.default_rng(f).normal(0, 2.6, (H, W, 1)).astype(np.float32)   # luma grain, per frame
            ff.stdin.write(np.clip(acc + g, 0, 255).astype(np.uint8).tobytes())
            if (f - a) % 30 == 0:
                el = time.time() - t0; done = f - a + 1
                print(f"[{a}-{b}] frame {f}  {el/done:.2f}s/frame  eta {(b-f-1)*el/done/60:.1f} min", flush=True)
        await br.close()
    ff.stdin.close(); ff.wait()

def run_all(nw):
    bounds = [round(i * NFR / nw) for i in range(nw + 1)]
    parts = [HERE / f"part{i}.mkv" for i in range(nw)]
    procs = [subprocess.Popen([sys.executable, __file__, "worker", str(bounds[i]), str(bounds[i + 1]), str(parts[i])])
             for i in range(nw)]
    for pr in procs: pr.wait()
    (HERE / "parts.txt").write_text("".join(f"file '{p.name}'\n" for p in parts))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(HERE / "parts.txt"),
                    "-i", str(HERE / "audio.wav"), "-map", "0:v", "-map", "1:a",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "15", "-pix_fmt", "yuv420p", "-profile:v", "high",
                    "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart",
                    str(HERE / "punctual-motion-v1.mp4")], check=True)
    for p in parts: p.unlink()
    (HERE / "parts.txt").unlink()
    print("done:", HERE / "punctual-motion-v1.mp4")

if __name__ == "__main__":
    if sys.argv[1] == "worker": asyncio.run(worker(int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]))
    else: run_all(int(sys.argv[2]) if len(sys.argv) > 2 else 4)
