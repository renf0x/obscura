"""Render the app icon (eye inside a glowing ring) into Android mipmaps and the iOS icon set.
Run: python tools/make_icon.py  (needs opencv-python and numpy)"""
import json
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).parents[1] / "app"
S = 1024
BG, ACCENT = (9, 10, 6), (164, 227, 52)  # BGR of #060A09 and #34E3A4


def render(size: int = S) -> np.ndarray:
    img = np.full((S, S, 3), BG, np.uint8)
    c = (S // 2, S // 2)
    glow = np.zeros_like(img)
    cv2.circle(glow, c, 330, ACCENT, 40, cv2.LINE_AA)
    img = cv2.addWeighted(img, 1, cv2.GaussianBlur(glow, (0, 0), 30), 0.6, 0)
    cv2.circle(img, c, 330, ACCENT, 18, cv2.LINE_AA)
    # eye outline: two arcs
    cv2.ellipse(img, (c[0], c[1] + 150), (300, 300), 0, 215, 325, ACCENT, 22, cv2.LINE_AA)
    cv2.ellipse(img, (c[0], c[1] - 150), (300, 300), 0, 35, 145, ACCENT, 22, cv2.LINE_AA)
    cv2.circle(img, c, 95, ACCENT, -1, cv2.LINE_AA)
    cv2.circle(img, c, 38, BG, -1, cv2.LINE_AA)
    return cv2.resize(img, (size, size), interpolation=cv2.INTER_AREA)


base = render()
for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    cv2.imwrite(str(ROOT / f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png"), cv2.resize(base, (px, px), interpolation=cv2.INTER_AREA))
ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for entry in json.loads((ios / "Contents.json").read_text())["images"]:
    pt = float(entry["size"].split("x")[0]); scale = int(entry["scale"][0])
    px = round(pt * scale)
    cv2.imwrite(str(ios / entry["filename"]), cv2.resize(base, (px, px), interpolation=cv2.INTER_AREA))
print("icons written")
