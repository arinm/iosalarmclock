"""Render any reel scene: motion blur (adaptive samples per frame, 180° shutter), film grain, audio mux.
   python3 render.py <scene.html> <audio.wav> <out.mp4> [workers]
   The scene declares window.CLIP = {w, h, fps, dur, sub: [[t0, t1, samples], ...]}."""
import asyncio, io, sys, subprocess, pathlib, time, base64
import numpy as np
from PIL import Image
from playwright.async_api import async_playwright

BASE_SUB, SHUTTER = 4, 0.5

async def open_page(p, scene):
    br = await p.chromium.launch(args=["--force-color-profile=srgb", "--disable-lcd-text"])
    pg = await br.new_page(viewport={"width": 1080, "height": 1920}, device_scale_factor=1)
    await pg.goto(pathlib.Path(scene).resolve().as_uri()); await pg.wait_for_function("window.CLIP")
    clip = await pg.evaluate("window.CLIP")
    await pg.set_viewport_size({"width": clip["w"], "height": clip["h"]})
    await pg.evaluate("window.__ready")
    cdp = await pg.context.new_cdp_session(pg)
    return br, pg, cdp, clip

async def grab(pg, cdp, t):
    await pg.evaluate(f"window.render({t:.6f})")
    r = await cdp.send("Page.captureScreenshot", {"format": "png", "optimizeForSpeed": True})
    return np.asarray(Image.open(io.BytesIO(base64.b64decode(r["data"]))).convert("RGB"), np.float32)

def sub_for(t, clip):
    for a, b, n in clip.get("sub", []):
        if a <= t <= b: return n
    return BASE_SUB

def glitched(img):
    h = img.shape[0]  # cold-start compositor glitch paints the stage white
    return img[h // 2 - 10:h // 2 + 10, 8:24].max() > 200

async def worker(scene, a, b, out):
    async with async_playwright() as p:
        br, pg, cdp, clip = await open_page(p, scene)
        W, H, FPS = clip["w"], clip["h"], clip["fps"]
        ff = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                               "-r", str(FPS), "-i", "-", "-c:v", "ffv1", "-level", "3", out], stdin=subprocess.PIPE)
        for t in np.linspace(0, clip["dur"], 24): await grab(pg, cdp, float(t))   # warm the compositor
        t0 = time.time()
        for f in range(a, b):
            n = sub_for(f / FPS, clip); acc = np.zeros((H, W, 3), np.float32)
            for k in range(n):
                t = f / FPS + ((k + 0.5) / n - 0.5) * SHUTTER / FPS
                img = await grab(pg, cdp, t)
                if glitched(img): img = await grab(pg, cdp, t)
                acc += img
            acc /= n
            g = np.random.default_rng(f).normal(0, 2.6, (H, W, 1)).astype(np.float32)
            ff.stdin.write(np.clip(acc + g, 0, 255).astype(np.uint8).tobytes())
            if (f - a) % 60 == 0:
                el = time.time() - t0; d = f - a + 1
                print(f"[{a}-{b}] frame {f} {el/d:.2f}s/f eta {(b-f-1)*el/d/60:.1f}m", flush=True)
        await br.close(); ff.stdin.close(); ff.wait()

async def clip_info(scene):
    async with async_playwright() as p:
        br, pg, cdp, clip = await open_page(p, scene); await br.close(); return clip

def fresh(path):
    """Never overwrite an earlier render: pick the next free -vN name instead."""
    p = pathlib.Path(path)
    if not p.exists(): return str(p)
    i = 2
    while (p.with_name(f"{p.stem}-v{i}{p.suffix}")).exists(): i += 1
    return str(p.with_name(f"{p.stem}-v{i}{p.suffix}"))

def run_all(scene, audio, out, nw):
    clip = asyncio.run(clip_info(scene)); nfr = int(round(clip["dur"] * clip["fps"]))
    out = fresh(out)
    tmp = pathlib.Path(out).with_suffix(""); bounds = [round(i * nfr / nw) for i in range(nw + 1)]
    parts = [f"{tmp}.part{i}.mkv" for i in range(nw)]
    procs = [subprocess.Popen([sys.executable, __file__, "--worker", scene, str(bounds[i]), str(bounds[i + 1]), parts[i]]) for i in range(nw)]
    for pr in procs: pr.wait()
    lst = pathlib.Path(f"{tmp}.parts.txt"); lst.write_text("".join(f"file '{pathlib.Path(x).resolve()}'\n" for x in parts))
    master = fresh(f"{tmp}-master.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-i", audio,
                    "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "slow", "-crf", "15", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", master], check=True)
    # social-ready: 2-pass ~16 Mbps, grain-tuned (TikTok / Reels / X all accept this comfortably)
    pl = f"{tmp}.x264"
    for pas in (1, 2):
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", master, "-c:v", "libx264", "-preset", "slow", "-tune", "grain",
               "-b:v", "16M", "-maxrate", "24M", "-bufsize", "32M", "-pix_fmt", "yuv420p", "-pass", str(pas), "-passlogfile", pl]
        cmd += (["-an", "-f", "null", "/dev/null"] if pas == 1 else ["-c:a", "copy", "-movflags", "+faststart", out])
        subprocess.run(cmd, check=True)
    for x in parts: pathlib.Path(x).unlink()
    lst.unlink()
    for x in pathlib.Path(out).parent.glob(pathlib.Path(pl).name + "*"): x.unlink()
    print("done:", out, "| master:", master)

if __name__ == "__main__":
    if sys.argv[1] == "--worker": asyncio.run(worker(sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]))
    else: run_all(sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 5)
