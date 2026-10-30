"""汉印篆白文朱砂印：笔画数据与渲染。

字形按汉印缪篆的方折写法手绘为折线（单位坐标 0…1，原点左上），
不依赖任何字体文件。App 内 SealGlyphs.swift 使用同一份笔画数据。
"""
import math
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

# 每个字是若干条折线；每条折线是 (x, y) 顶点序列
GLYPHS = {
    # 停：亻 + 亭（亠、口、冂中含丁）
    "停": [
        [(0.12, 0.96), (0.12, 0.24), (0.27, 0.04)],
        [(0.66, 0.03), (0.66, 0.14)],
        [(0.38, 0.14), (0.97, 0.14)],
        [(0.50, 0.25), (0.83, 0.25), (0.83, 0.39), (0.50, 0.39), (0.50, 0.25)],
        [(0.38, 0.96), (0.38, 0.50), (0.97, 0.50), (0.97, 0.96)],
        [(0.52, 0.65), (0.83, 0.65)],
        [(0.67, 0.65), (0.67, 0.92), (0.57, 0.92)],
    ],
    # 当（當）：尚 + 田
    "当": [
        [(0.50, 0.03), (0.50, 0.17)],
        [(0.24, 0.05), (0.24, 0.17)],
        [(0.76, 0.05), (0.76, 0.17)],
        [(0.06, 0.49), (0.06, 0.21), (0.94, 0.21), (0.94, 0.49)],
        [(0.34, 0.30), (0.66, 0.30), (0.66, 0.42), (0.34, 0.42), (0.34, 0.30)],
        [(0.06, 0.56), (0.94, 0.56), (0.94, 0.96), (0.06, 0.96), (0.06, 0.56)],
        [(0.06, 0.76), (0.94, 0.76)],
        [(0.50, 0.56), (0.50, 0.96)],
    ],
    # 止：中竖贯通，左短竖，右枝上折，底横
    "止": [
        [(0.50, 0.04), (0.50, 0.94)],
        [(0.14, 0.44), (0.14, 0.94)],
        [(0.50, 0.42), (0.86, 0.42), (0.86, 0.14)],
        [(0.04, 0.94), (0.96, 0.94)],
    ],
    # 杯：木（十下接冂形两脚）+ 不
    "杯": [
        [(0.21, 0.04), (0.21, 0.96)],
        [(0.02, 0.30), (0.40, 0.30)],
        [(0.03, 0.78), (0.03, 0.56), (0.39, 0.56), (0.39, 0.78)],
        [(0.50, 0.08), (0.97, 0.08)],
        [(0.735, 0.08), (0.735, 0.96)],
        [(0.735, 0.34), (0.55, 0.34), (0.55, 0.78)],
        [(0.735, 0.34), (0.92, 0.34), (0.92, 0.78)],
    ],
}


def _cells(text):
    """单字占满印面；两字按传统印式自右向左分作两列（首字在右）。返回每字的 (x0, y0, x1, y1)，单位坐标。"""
    if len(text) == 1:
        return [(0.0, 0.0, 1.0, 1.0)]
    gap = 0.08
    w = (1 - gap) / 2
    return [(w + gap, 0.0, 1.0, 1.0), (0.0, 0.0, w, 1.0)]


def _noise(size, scale, rnd):
    """低频噪声：小随机图放大后模糊。"""
    n = max(2, int(size / scale))
    small = Image.new("L", (n, n))
    small.putdata([rnd.randint(0, 255) for _ in range(n * n)])
    return small.resize((size, size), Image.BICUBIC).filter(ImageFilter.GaussianBlur(size / n * 0.5))


def render_seal(text, size, color, paper=None, seed=3):
    """渲染白文朱砂印，返回 RGBA。size 为印面边长（像素）。
    paper 为纸色：给定时字口与漏白处透出纸色，否则透明。"""
    rnd = random.Random(seed)
    # 印面：略不规则的方形
    face = Image.new("L", (size, size), 0)
    fd = ImageDraw.Draw(face)
    m = size * 0.015
    pts = []
    for side in range(4):
        for i in range(24):
            t = i / 24
            j = rnd.uniform(-size * 0.008, size * 0.008)
            if side == 0:
                pts.append((m + t * (size - 2 * m), m + j))
            elif side == 1:
                pts.append((size - m + j, m + t * (size - 2 * m)))
            elif side == 2:
                pts.append((size - m - t * (size - 2 * m), size - m + j))
            else:
                pts.append((m + j, size - m - t * (size - 2 * m)))
    fd.polygon(pts, fill=255)

    # 刻字：白文即从印面挖去笔画
    strokes = Image.new("L", (size, size), 0)
    sd = ImageDraw.Draw(strokes)
    border = size * 0.11
    inner = size - 2 * border
    sw = size * (0.072 if len(text) == 1 else 0.052)
    for ch, (cx0, cy0, cx1, cy1) in zip(text, _cells(text)):
        for line in GLYPHS[ch]:
            xy = [
                (border + (cx0 + x * (cx1 - cx0)) * inner,
                 border + (cy0 + y * (cy1 - cy0)) * inner)
                for x, y in line
            ]
            sd.line(xy, fill=255, width=int(sw), joint="curve")
            r = sw / 2
            for x, y in (xy[0], xy[-1]):
                sd.rectangle([x - r, y - r, x + r, y + r], fill=255)
    # 刀口：笔画边缘略有起伏
    edge = _noise(size, size * 0.012, rnd)
    strokes = ImageChops.add(strokes.filter(ImageFilter.GaussianBlur(size * 0.004)),
                             edge.point(lambda v: (v - 128) * 0.55 + 0), scale=1.0)
    strokes = strokes.point(lambda v: 255 if v > 140 else 0)

    red = ImageChops.subtract(face, strokes)
    # 边栏崩口：印面外缘按噪声缺损
    wear = _noise(size, size * 0.03, rnd)
    rim = Image.new("L", (size, size), 0)
    rd = ImageDraw.Draw(rim)
    rd.rectangle([0, 0, size, size], fill=255)
    rd.rectangle([size * 0.06, size * 0.06, size * 0.94, size * 0.94], fill=0)
    rim = rim.filter(ImageFilter.GaussianBlur(size * 0.03))
    chip = ImageChops.multiply(rim, wear.point(lambda v: 255 if v > 150 else 0))
    red = ImageChops.subtract(red, chip.point(lambda v: 255 if v > 90 else 0))

    # 印泥：细小漏白与颗粒
    dots = Image.new("L", (size, size), 0)
    dd = ImageDraw.Draw(dots)
    for _ in range(int(size * 0.35)):
        x, y = rnd.uniform(0, size), rnd.uniform(0, size)
        r = rnd.uniform(size * 0.0015, size * 0.006)
        dd.ellipse([x - r, y - r, x + r, y + r], fill=255)
    red = ImageChops.subtract(red, dots)
    red = red.filter(ImageFilter.GaussianBlur(size * 0.0012))

    # 印泥浓淡：按压不均
    density = _noise(size, size * 0.08, rnd).point(lambda v: int(215 + v * 40 / 255))
    grain = _noise(size, size * 0.004, rnd).point(lambda v: int(232 + v * 23 / 255))
    alpha = ImageChops.multiply(ImageChops.multiply(red, density), grain)

    ink = Image.new("RGBA", (size, size), (*color, 0))
    ink.putalpha(alpha)
    if paper is None:
        return ink
    # 纸底：只铺在印面范围内（崩口处同样露出纸色以外的底）
    out = Image.new("RGBA", (size, size), (*paper, 0))
    out.putalpha(face.filter(ImageFilter.GaussianBlur(size * 0.002)))
    out.alpha_composite(ink)
    return out
