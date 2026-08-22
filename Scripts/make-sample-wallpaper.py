#!/usr/bin/env python3
"""
Generate the Aurora demo wallpaper — a seamlessly looping 4K H.264 clip.

Every animated phase advances by an exact multiple of 2π over the clip, so the
last frame lands back on the first and the loop point is invisible.

The aurora is computed at 720p (it's a smooth field — there is no high-frequency
detail to lose) and upscaled to 3840×2160 by ffmpeg, which is ~16× faster than
computing at native 4K for an identical result. A touch of noise is added at
full resolution to prevent banding in the gradients.

Requirements:  python3, numpy, ffmpeg (with libx264)
Usage:         python3 Scripts/make-sample-wallpaper.py [output.mp4]
"""

import subprocess
import sys
import shutil

import numpy as np

W, H, FPS, SECONDS = 1280, 720, 30, 10
FRAMES = FPS * SECONDS
OUTPUT = sys.argv[1] if len(sys.argv) > 1 else "Aurora 4K Sample.mp4"

if shutil.which("ffmpeg") is None:
    sys.exit("ffmpeg not found. Install it with:  brew install ffmpeg")

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
xx /= W
yy /= H

# Fixed seed so the star field is identical on every frame — a re-rolled field
# would shimmer like static instead of twinkling.
rng = np.random.default_rng(7)
stars = np.zeros((H, W), np.float32)
for _ in range(520):
    sx, sy = rng.integers(0, W), rng.integers(0, int(H * 0.62))
    stars[sy, sx] = rng.uniform(0.35, 1.0)
star_phase = rng.uniform(0, 2 * np.pi, size=(H, W)).astype(np.float32)


def ribbon(y0, amp, freq, phase, width, colour, gain):
    """One band of light following a sine centreline, fading in and out along x."""
    centre = y0 + amp * np.sin(xx * freq * np.pi + phase)
    band = np.exp(-((np.abs(yy - centre) / width) ** 2) * 2.2)
    envelope = np.clip(np.sin((xx * 0.92 + 0.04) * np.pi), 0, 1) ** 0.6
    return (band * envelope * gain)[..., None] * np.array(colour, np.float32)


ffmpeg = subprocess.Popen(
    [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24",
        "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-vf", "scale=3840:2160:flags=lanczos,noise=alls=7:allf=t+u,format=yuv420p",
        "-c:v", "libx264", "-profile:v", "high", "-level", "5.1",
        "-preset", "medium", "-crf", "20", "-g", str(FPS),
        "-movflags", "+faststart", "-an",
        OUTPUT,
    ],
    stdin=subprocess.PIPE,
)

sky = np.array([6, 9, 34], np.float32) + (
    np.array([22, 10, 50], np.float32) - np.array([6, 9, 34], np.float32)
) * yy[..., None]

for frame in range(FRAMES):
    a = 2 * np.pi * frame / FRAMES          # wraps exactly at the loop point
    c = sky.copy()

    c += ribbon(0.30 + 0.014 * np.sin(a),       0.10, 1.7, 0.4 + a,   0.115, (40, 225, 235), 1.00)
    c += ribbon(0.41 + 0.012 * np.sin(a + 1.7), 0.09, 1.5, 2.3 + a,   0.100, (88, 118, 255), 0.95)
    c += ribbon(0.56 + 0.016 * np.sin(a + 3.1), 0.11, 1.9, 3.9 - a,   0.120, (168, 86, 255), 1.05)
    c += ribbon(0.71 + 0.013 * np.sin(a + 4.6), 0.10, 1.6, 5.4 - a,   0.105, (255, 74, 160), 1.00)
    c += ribbon(0.50,                           0.13, 1.2, 1.1 + 2*a, 0.185, (110, 70, 220), 0.42)
    c += ribbon(0.34 + 0.014 * np.sin(a),       0.10, 1.7, 0.4 + a,   0.026, (190, 255, 255), 0.55)
    c += ribbon(0.66 + 0.013 * np.sin(a + 4.6), 0.10, 1.6, 5.4 - a,   0.028, (255, 190, 225), 0.50)

    c += (stars * (0.62 + 0.38 * np.sin(a * 2 + star_phase)) * 210)[..., None]

    luma = c @ np.array([0.299, 0.587, 0.114], np.float32)
    c = luma[..., None] + (c - luma[..., None]) * 1.20      # saturation lift

    ffmpeg.stdin.write(np.clip(c, 0, 255).astype(np.uint8).tobytes())

    if frame % 30 == 0:
        print(f"\r  {frame}/{FRAMES} frames", end="", flush=True)

ffmpeg.stdin.close()
rc = ffmpeg.wait()
print(f"\r  {FRAMES}/{FRAMES} frames")

if rc != 0:
    sys.exit(f"ffmpeg exited with {rc}")
print(f"Wrote {OUTPUT}")
