#!/usr/bin/env python3
"""生成停杯 App 图标（1024×1024）。

设计：玄漆描金主题——乌黑漆地、泥金表盘刻度与节奏弧、白瓷小酒盅，
右下钤一方汉印篆白文「停」字朱砂印（字形见 seal.py，不依赖字体）。

用法：python3 scripts/make_icon.py [输出路径]
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

from seal import render_seal

S = 4096  # 超采样画布，最后缩到 1024
OUT = 1024

LACQUER_EDGE = (10, 9, 8)       # 玄漆 #0A0908
LACQUER_CENTER = (34, 30, 26)   # 退光漆面
GOLD = (200, 164, 110)          # 泥金 #C8A46E
GOLD_BRIGHT = (230, 198, 144)   # 描金高光 #E6C690
GOLD_DEEP = (150, 116, 70)
CINNABAR = (198, 59, 52)        # 朱漆 #C63B34
IVORY = (241, 234, 224)         # 象牙白 #F1EAE0
PORCELAIN = (246, 241, 230)     # 白瓷
PORCELAIN_SHADOW = (196, 186, 168)
LIQUOR = (214, 226, 224)        # 清酒


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
    # 只留 12 道主刻度并加粗：细分刻度缩到主屏尺寸会糊成一圈虚线
    for i in range(12):
        deg = i * 30
        cardinal = i % 3 == 0
        length = S * (0.052 if cardinal else 0.040)
        width = int(S * (0.013 if cardinal else 0.010))
        color = GOLD if cardinal else lerp(GOLD, LACQUER_EDGE, 0.25)
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
    w = int(S * 0.026)
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
    """白瓷小酒盅：微撇口、斜直腹、矮圈足，口沿描金一线，盏中清冽白酒。"""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    k = 1.65  # 放大为画面主体：原尺寸只占图标宽度约 23%，主屏上偏小
    mouth_w = S * 0.230 * k
    mouth_h = S * 0.044 * k
    top = cy - S * 0.085 * k
    belly_bottom = cy + S * 0.100 * k
    foot_w = S * 0.082 * k
    foot_bottom = cy + S * 0.122 * k

    # 盏身轮廓：口沿微撇，腹壁近直斜收，近足处圆转
    pts = []
    n = 90
    for i in range(n + 1):
        t = i / n
        y = top + (belly_bottom - top) * t
        half = foot_w / 2 + (mouth_w / 2 - foot_w / 2) * (1 - t ** 1.25) ** 1.15
        pts.append((cx + half, y))
    pts.append((cx + foot_w * 0.47, belly_bottom))
    pts.append((cx + foot_w * 0.52, foot_bottom))
    pts.append((cx - foot_w * 0.52, foot_bottom))
    pts.append((cx - foot_w * 0.47, belly_bottom))
    pts += [(2 * cx - x, y) for x, y in reversed(pts[: n + 1])]
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)

    # 白瓷釉面：左侧受光、右侧渐暗
    glaze = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glaze)
    x0, x1 = int(cx - mouth_w / 2), int(cx + mouth_w / 2)
    for x in range(x0, x1):
        t = (x - x0) / (x1 - x0)
        shade = 1 - 0.55 * max(0, t - 0.38) ** 1.1 - 0.35 * max(0, 0.12 - t)
        gd.line([(x, 0), (x, S)], fill=(*lerp(PORCELAIN_SHADOW, PORCELAIN, max(0, min(1, shade))), 255))
    # 近足处釉色稍沉
    dusk = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dusk)
    y0 = belly_bottom - S * 0.05 * k
    for y in range(int(y0), int(foot_bottom) + 1):
        t = (y - y0) / (foot_bottom - y0)
        dd.line([(x0, y), (x1, y)], fill=(0, 0, 0, int(80 * t)))
    glaze.alpha_composite(dusk)
    layer.paste(glaze, (0, 0), mask)
    d = ImageDraw.Draw(layer)
    # 足墙一线描金
    d.line([(cx - foot_w * 0.47, belly_bottom), (cx + foot_w * 0.47, belly_bottom)], fill=(*GOLD, 255), width=int(S * 0.004 * k))

    # 口沿：描金外圈，内壁白瓷，盛清酒
    d.ellipse([cx - mouth_w / 2, top - mouth_h / 2, cx + mouth_w / 2, top + mouth_h / 2], fill=(*GOLD_BRIGHT, 255))
    rim = S * 0.006 * k
    d.ellipse([cx - mouth_w / 2 + rim, top - mouth_h / 2 + rim * 0.6, cx + mouth_w / 2 - rim, top + mouth_h / 2 - rim * 0.6],
              fill=(*PORCELAIN, 255))
    lw, lh = mouth_w * 0.84, mouth_h * 0.62
    ly = top + mouth_h * 0.10
    d.ellipse([cx - lw / 2, ly - lh / 2, cx + lw / 2, ly + lh / 2], fill=(*LIQUOR, 255))
    d.ellipse([cx - lw * 0.30, ly - lh * 0.26, cx - lw * 0.02, ly + lh * 0.04], fill=(255, 255, 255, 255))

    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([cx - S * 0.10 * k, foot_bottom - S * 0.010 * k, cx + S * 0.10 * k, foot_bottom + S * 0.014 * k],
                                   fill=(0, 0, 0, 170))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(S * 0.008 * k)))
    img.alpha_composite(layer)


def seal(img, cx, cy):
    """汉印篆白文「停」字朱砂印，略带倾侧。"""
    tile = render_seal("停", int(S * 0.25), CINNABAR, paper=IVORY, seed=11)
    pad = tile.width // 4
    canvas = Image.new("RGBA", (tile.width + pad * 2,) * 2, (0, 0, 0, 0))
    canvas.alpha_composite(tile, (pad, pad))
    canvas = canvas.rotate(-4, resample=Image.BICUBIC)
    img.alpha_composite(canvas, (int(cx - canvas.width / 2), int(cy - canvas.height / 2)))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "TingBei/Assets.xcassets/AppIcon.appiconset/icon.png"
    img = background().convert("RGBA")
    cx, cy = S / 2, S / 2
    dial(ImageDraw.Draw(img), cx, cy)
    pace_arc(img, cx, cy)
    cup(img, cx, cy - S * 0.030)
    seal(img, S * 0.745, S * 0.745)
    img.convert("RGB").resize((OUT, OUT), Image.LANCZOS).save(out, optimize=True)


if __name__ == "__main__":
    main()
