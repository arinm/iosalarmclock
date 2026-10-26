"""python3 qa.py <video.mp4> <sheet.png> [t1 t2 ...]
Post-render QA on the FINAL encode: flags single-frame flashes, white frames and
one-frame pops, then writes a contact sheet (12 evenly spaced frames, or the given times)."""
import sys, io, subprocess, numpy as np
from PIL import Image, ImageDraw
src, sheet = sys.argv[1], sys.argv[2]
W, H = 135, 240
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-vf", f"scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
fr = np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3).astype(np.float32)
lum = fr.mean(axis=(1, 2, 3)); n = len(lum); fps = 60
print(f"{n} frames, mean luma {lum.mean():.1f}, min {lum.min():.1f}, max {lum.max():.1f}")
bad = []
for i in range(1, n - 1):
    d1, d2 = lum[i] - lum[i - 1], lum[i] - lum[i + 1]
    if (d1 > 12 and d2 > 12) or (d1 < -12 and d2 < -12): bad.append((i, "spike", lum[i - 1], lum[i], lum[i + 1]))
    if fr[i, H // 2 - 3:H // 2 + 3, 1:4].mean() > 200 and fr[i - 1, H // 2 - 3:H // 2 + 3, 1:4].mean() < 120: bad.append((i, "white-edge", 0, 0, 0))
    diff = np.abs(fr[i] - fr[i - 1]).mean() + np.abs(fr[i] - fr[i + 1]).mean() - np.abs(fr[i + 1] - fr[i - 1]).mean()
    if diff > 18: bad.append((i, f"pop {diff:.1f}", lum[i - 1], lum[i], lum[i + 1]))
for b in bad: print(f"  frame {b[0]} ({b[0]/fps:.3f}s) {b[1]}  {b[2]:.1f} {b[3]:.1f} {b[4]:.1f}")
print("clean" if not bad else f"{len(bad)} suspicious frame(s)")
times = [float(t) for t in sys.argv[3:]] or list(np.linspace(0.05, n / fps - 0.05, 12))
tw, th = 270, 480; cols = 6; rows = (len(times) + cols - 1) // cols
S = Image.new("RGB", (tw * cols, th * rows), (40, 40, 40))
for k, t in enumerate(times):
    png = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t:.3f}", "-i", src, "-frames:v", "1", "-vf", f"scale={tw}:{th}", "-f", "image2pipe", "-vcodec", "png", "-"], capture_output=True).stdout
    S.paste(Image.open(io.BytesIO(png)).convert("RGB"), ((k % cols) * tw, (k // cols) * th))
    ImageDraw.Draw(S).text(((k % cols) * tw + 6, (k // cols) * th + 4), f"{t:.2f}s", fill=(255, 255, 0))
S.save(sheet); print("sheet ->", sheet)
