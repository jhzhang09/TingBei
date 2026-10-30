#!/usr/bin/env python3
"""生成停杯 App 图标（1024×1024）。

设计：玄漆描金主题——乌黑漆地、泥金表盘刻度与节奏弧、描金高足酒盏，
右下钤一方朱砂「停」字印。

用法：python3 scripts/make_icon.py <思源宋体/Noto Serif SC Black 字体路径> [输出路径]
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 4096  # 超采样画布，最后缩到 1024
OUT = 1024

LACQUER_EDGE = (10, 9, 8)       # 玄漆 #0A0908
LACQUER_CENTER = (34, 30, 26)   # 退光漆面
GOLD = (200, 164, 110)          # 泥金 #C8A46E
GOLD_BRIGHT = (230, 198, 144)   # 描金高光 #E6C690
GOLD_DEEP = (150, 116, 70)
CINNABAR = (198, 59, 52)        # 朱漆 #C63B34
IVORY = (241, 234, 224)         # 象牙白 #F1EAE0
AMBER = (217, 154, 85)          # 琥珀 #D99A55


def lerp(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


def background():
    img = Image.new("RGB", (S, S), LACQUER_EDGE)
    px = img.load()
    cx, cy = S * 0.5, S * 0.44
    rmax = S * 0.78
    small = 512
    grad = Image.new("RGB", (small, small))
    gp = grad.load()
    for y in range(small):
        for x in range(small):
            d = math.hypot(x / small * S - cx, y / small * S - cy) / rmax
            gp[x, y] = lerp(LACQUER_CENTER, LACQUER_EDGE, min(1.0, d) ** 1.2)
    return grad.resize((S, S), Image.BICUBIC)


def polar(cx, cy, r, deg):
    a = math.radians(deg - 90)  # 0° 指向 12 点，顺时针
    return cx + r * math.cos(a), cy + r * math.sin(a)


def dial(draw, cx, cy):
    r_out = S * 0.395
    for i in range(60):
        deg = i * 6
        major = i % 5 == 0
        length = S * (0.040 if major else 0.018)
        width = int(S * (0.0085 if major else 0.0038))
        color = GOLD if major else lerp(GOLD, LACQUER_EDGE, 0.45)
        p1 = polar(cx, cy, r_out, deg)
        p2 = polar(cx, cy, r_out - length, deg)
        draw.line([p1, p2], fill=color, width=width)
    # 12 点位置一颗描金菱形
    tip = polar(cx, cy, r_out + S * 0.028, 0)
    d = S * 0.014
    draw.polygon(
        [(tip[0], tip[1] - d), (tip[0] + d * 0.7, tip[1]), (tip[0], tip[1] + d), (tip[0] - d * 0.7, tip[1])],
        fill=GOLD_BRIGHT,
    )


def pace_arc(img, cx, cy):
    """内圈节奏弧：泥金渐入描金，弧端一点朱漆，示意「到此当止」。"""
    r = S * 0.322
    w = int(S * 0.020)
    start, end = 0, 250
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # 底轨
    bbox = [cx - r, cy - r, cx + r, cy + r]
    d.arc(bbox, 0, 360, fill=(*lerp(GOLD, LACQUER_EDGE, 0.82), 255), width=int(w * 0.45))
    steps = 200
    for i in range(steps):
        a0 = start + (end - start) * i / steps
        a1 = start + (end - start) * (i + 1.4) / steps
        t = i / steps
        c = lerp(GOLD_DEEP, GOLD_BRIGHT, t)
        d.arc(bbox, a0 - 90, a1 - 90, fill=(*c, 255), width=w)
    x, y = polar(cx, cy, r, end)
    rad = w * 0.95
    d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(*CINNABAR, 255))
    img.alpha_composite(layer)


def cup(img, cx, cy):
    """描金高足酒盏（宋式斗笠盏轮廓），盏中琥珀酒色。"""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    mouth_w = S * 0.300
    mouth_h = S * 0.050
    top = cy - S * 0.080
    bowl_bottom = cy + S * 0.075
    # 盏身：口沿到盏底的弧形收分
    pts = []
    n = 80
    for i in range(n + 1):
        t = i / n
        y = top + (bowl_bottom - top) * t
        half = mouth_w / 2 * (1 - t ** 1.6 * 0.86)
        pts.append((cx + half, y))
    pts += [(cx - x + cx, y) for x, y in reversed(pts)]
    # 竖向描金渐变
    grad = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    y0, y1 = int(top), int(cy + S * 0.20)
    for y in range(y0, y1):
        t = (y - y0) / (y1 - y0)
        gd.line([(0, y), (S, y)], fill=(*lerp(GOLD_BRIGHT, GOLD_DEEP, t), 255))
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    md.polygon(pts, fill=255)
    # 高足与圈足
    stem_w = S * 0.030
    stem_top = bowl_bottom - S * 0.010
    stem_bottom = cy + S * 0.150
    md.rectangle([cx - stem_w / 2, stem_top, cx + stem_w / 2, stem_bottom], fill=255)
    md.polygon(
        [(cx - stem_w / 2, stem_bottom - S * 0.012), (cx + stem_w / 2, stem_bottom - S * 0.012),
         (cx + S * 0.075, stem_bottom + S * 0.022), (cx - S * 0.075, stem_bottom + S * 0.022)],
        fill=255,
    )
    md.ellipse([cx - S * 0.080, stem_bottom + S * 0.008, cx + S * 0.080, stem_bottom + S * 0.036], fill=255)
    layer.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(layer)
    # 口沿：外圈描金，内为漆黑盏心，盏心盛琥珀酒
    d.ellipse([cx - mouth_w / 2, top - mouth_h / 2, cx + mouth_w / 2, top + mouth_h / 2], fill=(*GOLD_BRIGHT, 255))
    rim = S * 0.010
    d.ellipse([cx - mouth_w / 2 + rim, top - mouth_h / 2 + rim * 0.6, cx + mouth_w / 2 - rim, top + mouth_h / 2 - rim * 0.6],
              fill=(*LACQUER_EDGE, 255))
    lw, lh = mouth_w * 0.80, mouth_h * 0.62
    ly = top + mouth_h * 0.10
    d.ellipse([cx - lw / 2, ly - lh / 2, cx + lw / 2, ly + lh / 2], fill=(*AMBER, 255))
    # 酒面一点高光
    d.ellipse([cx - lw * 0.30, ly - lh * 0.28, cx - lw * 0.06, ly + lh * 0.02], fill=(*lerp(AMBER, IVORY, 0.55), 255))
    # 投影
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([cx - S * 0.11, stem_bottom + S * 0.026, cx + S * 0.11, stem_bottom + S * 0.050], fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.008))
    img.alpha_composite(shadow)
    img.alpha_composite(layer)


def seal(img, font_path, cx, cy):
    """朱砂方印，白文「停」，略带倾侧与斑驳。"""
    size = int(S * 0.165)
    pad = int(size * 0.25)
    tile = Image.new("RGBA", (size + pad * 2, size + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    radius = size * 0.08
    d.rounded_rectangle([pad, pad, pad + size, pad + size], radius=radius, fill=(*CINNABAR, 255))
    inner = size * 0.075
    d.rounded_rectangle([pad + inner, pad + inner, pad + size - inner, pad + size - inner],
                        radius=radius * 0.6, outline=(*IVORY, 235), width=int(size * 0.022))
    font = ImageFont.truetype(font_path, int(size * 0.66))
    bb = d.textbbox((0, 0), "停", font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    d.text((pad + (size - tw) / 2 - bb[0], pad + (size - th) / 2 - bb[1]), "停", font=font, fill=(*IVORY, 245))
    # 印泥斑驳：随机擦去少许
    import random
    rnd = random.Random(7)
    wear = Image.new("L", tile.size, 255)
    wd = ImageDraw.Draw(wear)
    for _ in range(140):
        x = rnd.uniform(pad, pad + size)
        y = rnd.uniform(pad, pad + size)
        r = rnd.uniform(size * 0.003, size * 0.012)
        wd.ellipse([x - r, y - r, x + r, y + r], fill=rnd.randint(150, 215))
    a = tile.getchannel("A")
    a = Image.composite(a, Image.new("L", tile.size, 0), wear)
    tile.putalpha(a)
    tile = tile.rotate(-5, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(tile, (int(cx - tile.width / 2), int(cy - tile.height / 2)))


def main():
    font_path = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "TingBei/Assets.xcassets/AppIcon.appiconset/icon.png"
    img = background().convert("RGBA")
    cx, cy = S / 2, S / 2
    dial(ImageDraw.Draw(img), cx, cy)
    pace_arc(img, cx, cy)
    cup(img, cx, cy - S * 0.012)
    seal(img, font_path, S * 0.735, S * 0.735)
    img.convert("RGB").resize((OUT, OUT), Image.LANCZOS).save(out, optimize=True)


if __name__ == "__main__":
    main()
