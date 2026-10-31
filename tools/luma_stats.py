"""Luma statistics from the raw Y plane (limited range: 16 black, 235 white), sampled at 2 fps.
usage: luma_stats.py <video>"""
import subprocess
import sys

import numpy as np

path = sys.argv[1]
w, h = 1920, 1080
cmd = ["ffmpeg", "-v", "error", "-i", path, "-vf", "fps=2", "-f", "rawvideo", "-pix_fmt", "yuv420p", "-"]
p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
size = w * h * 3 // 2
hist = np.zeros(256, np.int64)
sat = []
small_hi = []          # share of bright pixels that sit in small specks (glints) rather than big areas
frames = 0
while True:
    buf = p.stdout.read(size)
    if len(buf) < size:
        break
    y = np.frombuffer(buf, np.uint8, w * h).reshape(h, w)
    u = np.frombuffer(buf, np.uint8, w * h // 4, w * h).astype(np.int16) - 128
    v = np.frombuffer(buf, np.uint8, w * h // 4, w * h * 5 // 4).astype(np.int16) - 128
    hist += np.bincount(y.ravel(), minlength=256)
    sat.append(np.sqrt(u.astype(np.float32) ** 2 + v.astype(np.float32) ** 2).mean())
    hi = y >= 215
    if hi.any():
        # a bright pixel is a "speck" if the 15x15 box around it is mostly not bright
        k = 15
        c = np.pad(hi.astype(np.int32), ((k // 2 + 1, k // 2), (k // 2 + 1, k // 2))).cumsum(0).cumsum(1)
        box = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
        small_hi.append(((box < k * k * 0.35) & hi).sum() / hi.sum())
    frames += 1
p.wait()

n = hist.sum()
cdf = hist.cumsum() / n
pct = lambda q: int(np.searchsorted(cdf, q))
share = lambda lo: 100 * hist[lo:].sum() / n
print(f"frames {frames}  Y min {np.nonzero(hist)[0][0]} max {np.nonzero(hist)[0][-1]}")
print(f"Y p10 {pct(.1)}  p50 {pct(.5)}  p90 {pct(.9)}  p99 {pct(.99)}  p99.9 {pct(.999)}")
print(f">=180 (above HLG-ref-white equivalent) {share(180):.1f}%   >=215 {share(215):.1f}%   >=230 {share(230):.2f}%   >=235 clipped {share(235):.2f}%")
print(f"mean chroma (saturation proxy) {np.mean(sat):.1f}")
print(f"bright pixels that are small specks/glints {100 * np.mean(small_hi) if small_hi else 0:.0f}%")
