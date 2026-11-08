#!/usr/bin/env python3
"""Render the 1080x1440 poster layout reference for the Huayan Assistant kit.

Requires Pillow and macOS PingFang (or edit FONT_PATH). Assets are relative to
the repository root. This is a layout reference, not the final AI render.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "poster-kit" / "poster-layout-reference.png"
W, H = 1080, 1440
BG, INK, BLUE = (247, 244, 236), (16, 24, 40), (47, 107, 255)
MUTED, LINE, AMBER = (91, 98, 115), (217, 212, 199), (231, 179, 74)
FONT_PATH = "/System/Library/AssetsV2/com_apple_MobileAsset_Font8/86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc"


def font(index, size):
    return ImageFont.truetype(FONT_PATH, size, index=index)


def text(draw, xy, value, fnt, fill=INK, anchor=None):
    draw.text(xy, value, font=fnt, fill=fill, anchor=anchor)


def phone(canvas, path, x, y, width, pad=12, radius=42):
    im = Image.open(path).convert("RGB")
    im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    h = im.height
    frame = Image.new("RGBA", (width + pad * 2, h + pad * 2), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([0, 0, width + pad * 2, h + pad * 2], radius=radius + pad, fill=(16, 24, 40, 255))
    mask = Image.new("L", (width, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width, h], radius=radius, fill=255)
    frame.paste(im, (pad, pad), mask)
    fd.rounded_rectangle([width * 0.40 + pad, pad + 2, width * 0.60 + pad, pad + 14], radius=7, fill=(16, 24, 40, 255))
    shadow = Image.new("RGBA", (frame.width + 60, frame.height + 60), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [30, 36, 30 + frame.width, 36 + frame.height], radius=radius + pad, fill=(16, 24, 40, 45)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.paste(shadow, (x - 30, y - 26), shadow)
    canvas.paste(frame, (x, y), frame)


def main():
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)

    for r, alpha in [(470, 8), (560, 5), (650, 3)]:
        d.ellipse([W - 360 - r, 60 - r, W - 360 + r, 60 + r], outline=(47, 107, 255, alpha), width=2)
    d.rectangle([0, 0, 12, H], fill=BLUE)

    logo = Image.open(ROOT / "design/brand/icon-1024.png").convert("RGBA")
    logo.thumbnail((76, 76), Image.LANCZOS)
    canvas.paste(logo, (72, 58), logo)
    text(d, (168, 64), "化研助手", font(11, 38))
    text(d, (169, 112), "北化研究生 · 学生自建", font(7, 19), MUTED)
    text(d, (W - 72, 76), "ANDROID  ·  1.7.0", font(7, 20), BLUE, anchor="ra")
    d.line([72, 170, W - 72, 170], fill=LINE, width=1)

    d.rounded_rectangle([72, 220, 392, 260], radius=20, fill=BLUE)
    text(d, (88, 228), "给北化研究生的第二块屏幕", font(7, 20), (255, 255, 255))

    text(d, (70, 298), "研究生生活", font(11, 88))
    text(d, (70, 400), "一个 App", font(11, 88), BLUE)
    text(d, (70, 502), "就够了", font(11, 88))
    text(d, (74, 620), "课表 · 成绩 · 培养进度 · 49 项服务", font(7, 31), MUTED)
    text(d, (74, 666), "真实 GMIS 数据，一部手机全搞定", font(7, 31), MUTED)
    text(d, (74, 730), "统一身份认证  ·  短信二次认证  ·  安全存储", font(7, 19), MUTED)

    d.rounded_rectangle([74, 786, 330, 824], radius=19, fill=INK)
    text(d, (94, 793), "真实截图 · 不是概念稿", font(7, 17), (255, 255, 255))

    phone(canvas, ROOT / "docs/images/timetable.jpg", 596, 345, 300, pad=10, radius=34)
    phone(canvas, ROOT / "poster-kit/assets/screen-home.png", 690, 265, 360, pad=11, radius=36)

    d.line([72, 1030, W - 72, 1030], fill=LINE, width=1)
    cols = [
        (72, "01", "真实 GMIS 数据", "课表、成绩、培养进度"),
        (420, "02", "49 项服务", "一个入口，全部原生"),
        (760, "03", "自动提醒", "学术报告 / 劳动实践"),
    ]
    for x, num, title, desc in cols:
        text(d, (x, 1070), num, font(7, 20), BLUE)
        text(d, (x, 1102), title, font(11, 30))
        text(d, (x, 1148), desc, font(7, 19), MUTED)

    d.rounded_rectangle([72, 1230, W - 72, 1322], radius=20, fill=INK)
    text(d, (104, 1250), "下载最新 Android 测试版", font(11, 26), (255, 255, 255))
    text(d, (104, 1290), "github.com/JackWPP/buct-graduate-helper", font(7, 16), (201, 209, 225))
    text(d, (W - 104, 1256), "v1.7.0", font(11, 28), AMBER, anchor="ra")
    text(d, (W - 104, 1292), "测试版 · Android 8.0+", font(7, 16), (201, 209, 225), anchor="ra")
    text(d, (74, 1372), "化研助手  ·  不是学校官方产品，学业数据以 GMIS 为准", font(7, 16), MUTED)
    canvas.save(OUT)


if __name__ == "__main__":
    main()
