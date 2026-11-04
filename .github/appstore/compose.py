#!/usr/bin/env python3
"""앱스토어 스크린샷 만들기: 시뮬레이터 화면 사진 → 흰 바탕 + 큰 두 줄 제목 + 아이폰 틀 (Pillow)

사용: python3 compose.py <원본 폴더> <결과 폴더> <글꼴 폴더>
- 원본 폴더: iphone/<화면>.png (1320×2868), watch/<화면>.png (워치 원래 크기)
- 결과: iphone/NN-<화면>.png (1320×2868)
        첫 두 장은 크게 기울인 아이폰이 두 장에 걸쳐 이어지는 그림 (나란히 보면 한 장)
        watch/NN-<화면>.png (워치 원래 크기, 제목 넣은 것), watch-raw/NN-<화면>.png (워치 화면 그대로)
- 모두 RGB(알파 없음) · sRGB 프로필 넣은 PNG
- 제목의 [[ ]] 안 글자는 강조색
"""
import io
import math
import sys
from pathlib import Path

from PIL import Image, ImageCms, ImageDraw, ImageFilter, ImageFont

IPHONE = (1320, 2868)

ACCENT = (123, 104, 238)        # #7B68EE 라벤더 (앱 강조색)
INK = (17, 19, 26)              # 거의 검정
BG = (255, 255, 255)

# 첫 두 장: 이어지는 큰 그림 (왼쪽 아래 큰 세 줄 제목 · 오른쪽 위 두 줄 제목)
HERO = {
    "front": "mathNote",
    "back": "mathList",
    "left": ["가장", "쉬운", "[[오답노트]]"],
    "right": ["사진 한 장이면", "[[풀이]]까지"],
}

# 나머지: (화면, 두 줄 제목)
IPHONE_SHOTS = [
    ("timerLock", ["공부할 땐", "다른 앱을 [[잠가요]]"]),
    ("home", ["오늘 할 일과 목표를", "[[한눈에]]"]),
    ("weeklyReport", ["공부 시간은", "[[AI 리포트]]로"]),
    ("wordSession", ["영어 단어는", "[[카드]]로 쏙쏙"]),
    ("ai", ["모르는 건", "[[AI 선생님]]에게"]),
    ("mockResult", ["[[AI 모의고사]]로", "실력을 체크하세요"]),
]

WATCH_SHOTS = [
    ("timer", ["손목에서 바로", "[[타이머]]"]),
    ("today", ["오늘 할 일", "[[체크]]"]),
    ("words", ["틈틈이", "[[단어]] 암기"]),
    ("picker", ["크라운으로", "[[목표 시간]]"]),
]


# MARK: 글자

def font(folder, weight, size):
    return ImageFont.truetype(str(Path(folder) / f"Pretendard-{weight}.otf"), size)


def segments(line):
    """'영어 [[단어]]' → [('영어 ', False), ('단어', True)]"""
    out, rest = [], line
    while "[[" in rest:
        a, b = rest.split("[[", 1)
        k, rest = b.split("]]", 1)
        if a:
            out.append((a, False))
        out.append((k, True))
    if rest:
        out.append((rest, False))
    return out


def line_width(f, line):
    return sum(f.getlength(t) for t, _ in segments(line))


def draw_line(d, line, f, x, y, accent=ACCENT):
    for text, hi in segments(line):
        d.text((x, y), text, font=f, fill=accent if hi else INK)
        x += f.getlength(text)


def fit(folder, weight, size, lines, max_w):
    while size > 10:
        f = font(folder, weight, size)
        if max(line_width(f, l) for l in lines) <= max_w:
            return f, size
        size -= 2
    return font(folder, weight, size), size


def headline(canvas, lines, fonts, size, top, max_w, leading=1.28, align="center", x0=0):
    d = ImageDraw.Draw(canvas)
    f, size = fit(fonts, "ExtraBold", size, lines, max_w)
    y = top
    for l in lines:
        w = line_width(f, l)
        x = (canvas.width - w) / 2 if align == "center" else x0
        draw_line(d, l, f, x, y)
        y += round(size * leading)
    return y


# MARK: 기기 틀

def aa_mask(size, radius, scale=3):
    """매끄러운 둥근 모서리 마스크 (크게 그려서 줄임)"""
    w, h = size
    m = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius * scale, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def metal(size, dark=False):
    """티타늄 느낌: 가로로 밝기가 바뀌는 회색"""
    w, h = size
    stops = [(0, 150), (0.08, 222), (0.5, 196), (0.92, 226), (1, 150)] if not dark else [(0, 40), (0.5, 70), (1, 40)]
    row = Image.new("L", (w, 1))
    for x in range(w):
        t = x / max(1, w - 1)
        for (t0, v0), (t1, v1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                v = v0 + (v1 - v0) * (t - t0) / (t1 - t0)
                break
        row.putpixel((x, 0), round(v))
    g = row.resize((w, h))
    return Image.merge("RGB", (g, g, g.point(lambda v: min(255, v + 4))))


def iphone(shot, screen_w):
    """화면 사진 → 아이폰 모양 (티타늄 테 · 검은 테두리 · 옆 버튼). 투명 바탕 RGBA"""
    shot = shot.convert("RGB")
    k = screen_w / 1320                     # 원래 화면 대비 크기
    sw, sh = screen_w, round(shot.height * screen_w / shot.width)
    radius = round(186 * k)
    bezel = round(30 * k)                   # 검은 테두리
    rim = max(4, round(13 * k))             # 금속 테
    btn = max(4, round(11 * k))             # 버튼이 튀어나온 만큼
    ow, oh = sw + 2 * (bezel + rim), sh + 2 * (bezel + rim)
    W, H = ow + 2 * btn, oh
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # 옆 버튼 (왼쪽: 동작 버튼 · 음량 둘, 오른쪽: 측면 버튼 · 카메라 컨트롤)
    def button(x, y, h):
        size = (btn * 2 + 2, h)
        img.paste(metal(size).convert("RGBA"), (x, y), aa_mask(size, btn))
    button(0, round(oh * 0.185), round(oh * 0.045))
    button(0, round(oh * 0.255), round(oh * 0.075))
    button(0, round(oh * 0.345), round(oh * 0.075))
    button(W - btn * 2 - 2, round(oh * 0.285), round(oh * 0.11))
    button(W - btn * 2 - 2, round(oh * 0.56), round(oh * 0.06))

    outer_r = radius + bezel + rim
    img.paste(metal((ow, oh)).convert("RGBA"), (btn, 0), aa_mask((ow, oh), outer_r))
    # 테 안쪽 가는 어두운 선 → 검은 테두리 → 화면
    e = max(2, rim - max(2, round(4 * k)))
    inner = (ow - 2 * e, oh - 2 * e)
    img.paste(Image.new("RGBA", inner, (70, 70, 76, 255)), (btn + e, e), aa_mask(inner, outer_r - e))
    inner2 = (ow - 2 * rim, oh - 2 * rim)
    img.paste(Image.new("RGBA", inner2, (8, 8, 10, 255)), (btn + rim, rim), aa_mask(inner2, outer_r - rim))
    img.paste(shot.resize((sw, sh), Image.LANCZOS), (btn + rim + bezel, rim + bezel), aa_mask((sw, sh), radius))
    return img


def shadow_of(layer, blur, alpha=70, color=(20, 20, 40)):
    a = layer.getchannel("A").point(lambda v: v * alpha // 255)
    pad = blur * 3
    s = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2), color + (0,))
    sa = Image.new("L", s.size, 0)
    sa.paste(a, (pad, pad))
    s.putalpha(sa.filter(ImageFilter.GaussianBlur(blur)))
    return s, pad


def place(canvas, layer, cx, cy, blur=50, alpha=60, dy=40):
    """가운데 (cx, cy)에 그림자와 함께 놓음 (캔버스 밖으로 나가도 됨)"""
    s, pad = shadow_of(layer, blur, alpha)
    x, y = round(cx - layer.width / 2), round(cy - layer.height / 2)
    paste_clipped(canvas, s, x - pad, y - pad + dy)
    paste_clipped(canvas, layer, x, y)


def paste_clipped(canvas, layer, x, y):
    """캔버스 밖으로 나간 부분은 잘라서 붙임"""
    l, t = max(0, -x), max(0, -y)
    r, b = min(layer.width, canvas.width - x), min(layer.height, canvas.height - y)
    if r <= l or b <= t:
        return
    canvas.alpha_composite(layer.crop((l, t, r, b)), (x + l, y + t))


# MARK: 아이폰 장

def soft_glow(size, cx, cy, r, color, alpha):
    """아주 옅은 빛 (흰 바탕이 밋밋하지 않게)"""
    s = 8
    g = Image.new("RGBA", (size[0] // s, size[1] // s), color + (0,))
    a = Image.new("L", g.size, 0)
    ImageDraw.Draw(a).ellipse(((cx - r) / s, (cy - r) / s, (cx + r) / s, (cy + r) / s), fill=alpha)
    g.putalpha(a.filter(ImageFilter.GaussianBlur(r / s * 0.6)))
    return g.resize(size, Image.BICUBIC)


def compose_standard(shot, lines, fonts):
    W, H = IPHONE
    canvas = Image.new("RGBA", IPHONE, BG + (255,))
    canvas.alpha_composite(soft_glow(IPHONE, W / 2, 1900, 900, ACCENT, 26))
    headline(canvas, lines, fonts, 118, 210, W - 150)
    phone = iphone(shot, 1060)
    top = 700
    place(canvas, phone, W / 2, top + phone.height / 2, blur=60, alpha=70, dy=30)
    return canvas


def compose_hero(front, back, left, right, fonts):
    """두 장에 걸친 큰 그림 → (왼쪽 장, 오른쪽 장)"""
    W, H = IPHONE
    pano = Image.new("RGBA", (W * 2, H), BG + (255,))
    pano.alpha_composite(soft_glow(pano.size, W * 1.05, H * 0.45, 1300, ACCENT, 34))

    angle = 28  # 위가 왼쪽으로 가게 기울임
    b = iphone(back, 1000).rotate(angle, resample=Image.BICUBIC, expand=True)
    f = iphone(front, 1180).rotate(angle, resample=Image.BICUBIC, expand=True)
    # 뒤 폰: 오른쪽 장 아래쪽 · 앞 폰: 두 장 사이에 걸침 (나란히 놓으면 한 그림)
    place(pano, b, W * 1.75, H * 0.66, blur=70, alpha=55, dy=50)
    place(pano, f, W * 0.95, H * 0.52, blur=80, alpha=80, dy=60)

    # 왼쪽 장: 왼쪽 아래 큰 세 줄
    size = 236
    fbig, size = fit(fonts, "ExtraBold", size, left, W * 0.62)
    lead = round(size * 1.12)
    y = H - 170 - lead * len(left) + (lead - size)
    d = ImageDraw.Draw(pano)
    for l in left:
        draw_line(d, l, fbig, 110, y)
        y += lead

    # 오른쪽 장: 위쪽 가운데 두 줄
    right_half = Image.new("RGBA", IPHONE, (0, 0, 0, 0))
    headline(right_half, right, fonts, 118, 210, W - 150)
    pano.alpha_composite(right_half, (W, 0))
    return pano.crop((0, 0, W, H)), pano.crop((W, 0, W * 2, H))


# MARK: 워치

def watch(shot, screen_w):
    """워치 화면 → 워치 모양 (검은 테두리 · 금속 테 · 크라운)"""
    shot = shot.convert("RGB")
    sw, sh = screen_w, round(shot.height * screen_w / shot.width)
    radius = round(sw * 0.2)
    bezel = max(6, round(sw * 0.045))
    rim = max(3, round(sw * 0.022))
    crown = max(6, round(sw * 0.05))
    ow, oh = sw + 2 * (bezel + rim), sh + 2 * (bezel + rim)
    img = Image.new("RGBA", (ow + crown, oh), (0, 0, 0, 0))
    cs = (crown * 2, round(oh * 0.2))
    img.paste(metal(cs).convert("RGBA"), (ow - crown, round(oh * 0.24)), aa_mask(cs, crown // 2))
    bs = (crown, round(oh * 0.22))
    img.paste(metal(bs).convert("RGBA"), (ow - 2, round(oh * 0.55)), aa_mask(bs, crown // 2))
    outer_r = radius + bezel + rim
    img.paste(metal((ow, oh)).convert("RGBA"), (0, 0), aa_mask((ow, oh), outer_r))
    inner = (ow - 2 * rim, oh - 2 * rim)
    img.paste(Image.new("RGBA", inner, (6, 6, 8, 255)), (rim, rim), aa_mask(inner, outer_r - rim))
    img.paste(shot.resize((sw, sh), Image.LANCZOS), (rim + bezel, rim + bezel), aa_mask((sw, sh), radius))
    return img


def compose_watch(shot, lines, fonts):
    W, H = shot.size
    canvas = Image.new("RGBA", (W, H), BG + (255,))
    canvas.alpha_composite(soft_glow((W, H), W / 2, H * 0.75, W * 0.6, ACCENT, 30))
    bottom = headline(canvas, lines, fonts, round(H * 0.064), round(H * 0.045), W - 40, leading=1.22)
    body = watch(shot, round(W * 0.60))
    top = bottom + round(H * 0.035)
    place(canvas, body, W / 2 + body.width * 0.0, top + body.height / 2, blur=12, alpha=70, dy=8)
    return canvas


# MARK: 저장

def save(img, path, profile):
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "PNG", optimize=True, icc_profile=profile)
    Path(path).write_bytes(buf.getvalue())


def main():
    src, out, fonts = (Path(a) for a in sys.argv[1:4])
    profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    (out / "iphone").mkdir(parents=True, exist_ok=True)
    ip = src / "iphone"
    n = 0
    if (ip / f"{HERO['front']}.png").exists() and (ip / f"{HERO['back']}.png").exists():
        a, b = compose_hero(Image.open(ip / f"{HERO['front']}.png"), Image.open(ip / f"{HERO['back']}.png"),
                            HERO["left"], HERO["right"], fonts)
        save(a, out / "iphone" / f"01-{HERO['front']}.png", profile)
        save(b, out / "iphone" / f"02-{HERO['back']}.png", profile)
        n = 2
        print("iphone 01·02: 이어지는 큰 그림")
    for name, lines in IPHONE_SHOTS:
        p = ip / f"{name}.png"
        if not p.exists():
            print(f"건너뜀 (사진 없음): {p}")
            continue
        n += 1
        img = compose_standard(Image.open(p), lines, fonts)
        save(img, out / "iphone" / f"{n:02d}-{name}.png", profile)
        print(f"iphone {n:02d}-{name}: {' / '.join(lines)}")

    wd = src / "watch"
    if wd.exists():
        (out / "watch").mkdir(parents=True, exist_ok=True)
        (out / "watch-raw").mkdir(parents=True, exist_ok=True)
        n = 0
        for name, lines in WATCH_SHOTS:
            p = wd / f"{name}.png"
            if not p.exists():
                print(f"건너뜀 (사진 없음): {p}")
                continue
            n += 1
            shot = Image.open(p).convert("RGBA")
            raw = Image.new("RGB", shot.size, (0, 0, 0))
            raw.paste(shot, (0, 0), shot)
            save(raw, out / "watch-raw" / f"{n:02d}-{name}.png", profile)
            save(compose_watch(raw, lines, fonts), out / "watch" / f"{n:02d}-{name}.png", profile)
            print(f"watch {n:02d}-{name} {shot.size}")

    # 확인: 크기 · 알파 없음
    for f in sorted(out.rglob("*.png")):
        im = Image.open(f)
        assert im.mode == "RGB", (f, im.mode)
        if f.parent.name == "iphone":
            assert im.size == IPHONE, (f, im.size)
        print(f"{f.relative_to(out)}  {im.size[0]}x{im.size[1]}  {im.mode}  {f.stat().st_size // 1024}KB")


if __name__ == "__main__":
    main()
