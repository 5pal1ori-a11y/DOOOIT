#!/usr/bin/env python3
"""앱스토어 스크린샷 만들기: 시뮬레이터 화면 사진 → 위에 짧은 제목 + 아래 둥근 기기 틀 (Pillow)

사용: python3 compose.py <원본 폴더> <결과 폴더> <글꼴 폴더>
- 원본 폴더: iphone/<화면>.png (1320×2868), watch/<화면>.png (워치 원래 크기)
- 결과: iphone/NN-<화면>.png (1320×2868), watch/NN-<화면>.png (워치 원래 크기, 제목 넣은 것),
        watch-raw/NN-<화면>.png (워치 화면 그대로)
- 모두 RGB(알파 없음) · sRGB 프로필 넣은 PNG
"""
import io
import sys
from pathlib import Path

from PIL import Image, ImageCms, ImageDraw, ImageFilter, ImageFont

# 아이폰 6.9형 (App Store Connect 필수 크기)
IPHONE = (1320, 2868)

# 앱 강조색 (라벤더) · 글자색
ACCENT = (123, 104, 238)        # #7B68EE
INK = (31, 36, 51)              # #1F2433
SUB = (104, 98, 140)            # 부제목 (흐린 보라 회색)

# (화면, 제목, 부제목) — 짧게
IPHONE_SHOTS = [
    ("mathNote", "사진 한 장이면 풀이까지", "AI가 단계별로 풀어줘요"),
    ("mathList", "틀린 문제는 오답노트로", "약한 개념까지 알아서 정리"),
    ("timerLock", "집중할 땐 다른 앱 잠금", "목표 시간이 되면 저절로 풀려요"),
    ("home", "오늘 할 일, 한눈에", "목표 · 플랜 · 연속 공부"),
    ("weeklyReport", "공부 시간은 한눈에", "매주 받아보는 AI 리포트"),
    ("wordSession", "단어는 카드로 쏙쏙", "사진으로 단어장도 만들어요"),
    ("ai", "내 폰 속 AI 선생님", "모르는 건 바로 물어보세요"),
    ("mockResult", "AI 모의고사로 실력 체크", "10문제 풀고 바로 채점"),
]

WATCH_SHOTS = [
    ("timer", "손목에서 바로 타이머"),
    ("today", "오늘 할 일 체크"),
    ("words", "틈틈이 단어 암기"),
    ("picker", "크라운으로 목표 시간"),
]


def font(folder, weight, size):
    return ImageFont.truetype(str(Path(folder) / f"Pretendard-{weight}.otf"), size)


def srgb_profile():
    return ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()


def background(size):
    """부드러운 라벤더 그라데이션 + 흐릿한 빛 두 개"""
    w, h = size
    top, bottom = (236, 232, 255), (249, 248, 255)
    grad = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        grad.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    bg = grad.resize((w, h), Image.BICUBIC)

    # 빛 번짐은 작게 그려서 흐리게 한 뒤 키움 (빠르게)
    s = 8
    glow = Image.new("RGBA", (w // s, h // s), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    r = w * 0.55 / s
    cx, cy = w * 0.05 / s, h * 0.12 / s
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=ACCENT + (60,))
    r2 = w * 0.6 / s
    cx2, cy2 = w * 1.0 / s, h * 0.78 / s
    d.ellipse((cx2 - r2, cy2 - r2, cx2 + r2, cy2 + r2), fill=(150, 190, 255, 55))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.12 / s)).resize((w, h), Image.BICUBIC)
    bg = bg.convert("RGBA")
    bg.alpha_composite(glow)
    return bg


def rounded_mask(size, radius, scale=4):
    """매끄러운 모서리 (크게 그려서 줄임)"""
    w, h = size
    m = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius * scale, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def device(shot, screen_w, radius, bezel, edge=(58, 59, 66)):
    """화면 사진을 검은 테두리의 둥근 기기 모양으로"""
    shot = shot.convert("RGB")
    sw = screen_w
    sh = round(shot.height * sw / shot.width)
    screen = shot.resize((sw, sh), Image.LANCZOS)
    ow, oh = sw + bezel * 2, sh + bezel * 2
    body = Image.new("RGBA", (ow, oh), (0, 0, 0, 0))
    # 바깥 테두리 (살짝 밝은 금속 느낌) → 안쪽 검은 테두리 → 화면
    body.paste(Image.new("RGBA", (ow, oh), edge + (255,)), (0, 0), rounded_mask((ow, oh), radius + bezel))
    e = max(2, bezel // 7)
    inner = (ow - e * 2, oh - e * 2)
    body.paste(Image.new("RGBA", inner, (12, 12, 16, 255)), (e, e), rounded_mask(inner, radius + bezel - e))
    body.paste(screen, (bezel, bezel), rounded_mask((sw, sh), radius))
    return body


def shadow(size, radius, blur, color=(60, 40, 150), alpha=70):
    w, h = size
    pad = blur * 3
    s = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(s).rounded_rectangle((pad, pad, pad + w, pad + h), radius, fill=color + (alpha,))
    return s.filter(ImageFilter.GaussianBlur(blur)), pad


def fit_font(folder, weight, size, text, max_w):
    f = font(folder, weight, size)
    while f.getlength(text) > max_w and size > 10:
        size -= 2
        f = font(folder, weight, size)
    return f


def centered(draw, text, f, y, width, fill):
    x = (width - f.getlength(text)) / 2
    draw.text((x, y), text, font=f, fill=fill)


def save(img, path, profile):
    img = img.convert("RGB")
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True, icc_profile=profile)
    Path(path).write_bytes(buf.getvalue())


def compose_iphone(shot, title, subtitle, fonts):
    W, H = IPHONE
    canvas = background(IPHONE)
    d = ImageDraw.Draw(canvas)
    tf = fit_font(fonts, "ExtraBold", 104, title, W - 160)
    centered(d, title, tf, 176, W, INK)
    if subtitle:
        sf = fit_font(fonts, "SemiBold", 52, subtitle, W - 200)
        centered(d, subtitle, sf, 322, W, SUB)

    screen_w, bezel = 1020, 22
    radius = round(186 * screen_w / 1320)
    body = device(shot, screen_w, radius, bezel)
    x = (W - body.width) // 2
    y = H - body.height - 92
    sh, pad = shadow(body.size, radius + bezel, 48)
    canvas.alpha_composite(sh, (x - pad, y - pad + 28))
    canvas.alpha_composite(body, (x, y))
    return canvas


def compose_watch(shot, title, fonts):
    W, H = shot.size
    canvas = background((W, H))
    d = ImageDraw.Draw(canvas)
    tf = fit_font(fonts, "ExtraBold", round(H * 0.068), title, W - 36)
    centered(d, title, tf, round(H * 0.055), W, INK)

    screen_w = round(W * 0.70)
    bezel = max(8, round(W * 0.026))
    radius = round(screen_w * 0.21)
    body = device(shot, screen_w, radius, bezel)
    x = (W - body.width) // 2
    y = H - body.height - round(H * 0.045)
    sh, pad = shadow(body.size, radius + bezel, 12, alpha=80)
    canvas.alpha_composite(sh, (x - pad, y - pad + 6))
    canvas.alpha_composite(body, (x, y))
    return canvas


def main():
    src, out, fonts = (Path(a) for a in sys.argv[1:4])
    profile = srgb_profile()
    (out / "iphone").mkdir(parents=True, exist_ok=True)
    n = 0
    for name, title, subtitle in IPHONE_SHOTS:
        p = src / "iphone" / f"{name}.png"
        if not p.exists():
            print(f"건너뜀 (사진 없음): {p}")
            continue
        n += 1
        img = compose_iphone(Image.open(p), title, subtitle, fonts)
        assert img.size == IPHONE, img.size
        save(img, out / "iphone" / f"{n:02d}-{name}.png", profile)
        print(f"iphone {n:02d}-{name}: {title}")

    watch_dir = src / "watch"
    if watch_dir.exists():
        (out / "watch").mkdir(parents=True, exist_ok=True)
        (out / "watch-raw").mkdir(parents=True, exist_ok=True)
        n = 0
        for name, title in WATCH_SHOTS:
            p = watch_dir / f"{name}.png"
            if not p.exists():
                print(f"건너뜀 (사진 없음): {p}")
                continue
            n += 1
            shot = Image.open(p)
            # 워치 화면 그대로 (알파만 없앰, 검은 바탕)
            raw = Image.new("RGB", shot.size, (0, 0, 0))
            raw.paste(shot.convert("RGBA"), (0, 0), shot.convert("RGBA"))
            save(raw, out / "watch-raw" / f"{n:02d}-{name}.png", profile)
            img = compose_watch(raw, title, fonts)
            save(img, out / "watch" / f"{n:02d}-{name}.png", profile)
            print(f"watch {n:02d}-{name} {shot.size}: {title}")

    # 확인: 크기 · 알파 없음
    for f in sorted(out.rglob("*.png")):
        im = Image.open(f)
        assert im.mode == "RGB", (f, im.mode)
        print(f"{f.relative_to(out)}  {im.size[0]}x{im.size[1]}  {im.mode}  {f.stat().st_size // 1024}KB")


if __name__ == "__main__":
    main()
