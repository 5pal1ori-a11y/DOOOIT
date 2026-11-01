# 두잇 AI 오브(앱 안 AIOrb와 같은 모양)를 앱 아이콘으로 그림: 각도 그라데이션 원 + 위쪽 빛 + 흰 반짝이(sparkles)
import sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 1024 * 2  # 2배로 그린 뒤 줄여서 가장자리를 매끄럽게
accent = np.array([0x7B, 0x68, 0xEE], dtype=float)
white = np.array([255, 255, 255], dtype=float)

def mix(a, b, t):
    return a * (1 - t) + b * t

yy, xx = np.mgrid[0:S, 0:S].astype(float)
cx = cy = S / 2

# 바탕: 아주 연한 보라 → 흰색 (위에서 아래로)
bg_top = np.array([0xEF, 0xEB, 0xFF], dtype=float)
bg_bottom = np.array([0xFB, 0xFA, 0xFF], dtype=float)
t = (yy / S)[..., None]
img = mix(bg_top, bg_bottom, t)

# 은은한 빛 번짐
glow_r = S * 0.46
d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
glow = np.clip(1 - d / (glow_r * 1.3), 0, 1) ** 2 * 0.45
img = mix(img, accent[None, None, :], glow[..., None])

# 오브: 각도 그라데이션 [accent, accent 55%(흰 바탕 위), white 90%, accent]
R = S * 0.39
angle = (np.arctan2(yy - cy, xx - cx) + math.pi / 2) % (2 * math.pi) / (2 * math.pi)  # 0..1, 위에서 시작
deep = np.array([0x5A, 0x46, 0xE0], dtype=float)
stops = [(0.0, deep), (1/3, accent), (2/3, mix(accent, white, 0.42)), (1.0, deep)]
col = np.zeros((S, S, 3))
for (a0, c0), (a1, c1) in zip(stops, stops[1:]):
    m = (angle >= a0) & (angle <= a1)
    tt = ((angle - a0) / (a1 - a0))[..., None]
    col = np.where(m[..., None], mix(c0, c1, tt), col)
inside = d <= R
edge = np.clip((R - d) / 2.0, 0, 1)  # 가장자리 부드럽게
img = mix(img, col, edge[..., None])
# 위쪽 빛 (흰색 45% → 투명, 위에서 가운데까지)
hl = np.clip(1 - (yy - (cy - R)) / R, 0, 1) * 0.30
img = mix(img, white[None, None, :], (hl * edge)[..., None])

out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")

# 반짝이: 큰 별 하나 + 작은 별 둘 (SF Symbols sparkles 모양), 흰색 + 옅은 그림자
def star(cx, cy, r, n=200):
    pts = []
    for i in range(n):
        th = 2 * math.pi * i / n
        x = math.cos(th) ** 3 if math.cos(th) >= 0 else -abs(math.cos(th)) ** 3
        y = math.sin(th) ** 3 if math.sin(th) >= 0 else -abs(math.sin(th)) ** 3
        # 별 끝을 살짝 통통하게
        k = 0.82
        x = x * k + math.cos(th) * (1 - k) * 0.35
        y = y * k + math.sin(th) * (1 - k) * 0.35
        pts.append((cx + r * x, cy + r * y))
    return pts

layer = Image.new("L", (S, S), 0)
dr = ImageDraw.Draw(layer)
big = (cx - R * 0.10, cy + R * 0.08, R * 0.62)
small1 = (cx + R * 0.42, cy - R * 0.40, R * 0.24)
small2 = (cx + R * 0.50, cy + R * 0.45, R * 0.15)
for (x, y, r) in [big, small1, small2]:
    dr.polygon(star(x, y, r), fill=255)
shadow = layer.filter(ImageFilter.GaussianBlur(S * 0.006))
shadow_img = Image.new("RGB", (S, S), (40, 30, 90))
out = Image.composite(shadow_img, out, shadow.point(lambda v: int(v * 0.18)))
offset = Image.new("L", (S, S), 0)
offset.paste(layer, (0, -int(S * 0.002)))
out = Image.composite(Image.new("RGB", (S, S), (255, 255, 255)), out, offset)

out = out.resize((1024, 1024), Image.LANCZOS)
out.save(sys.argv[1], "PNG", optimize=True)
print("saved", sys.argv[1])
