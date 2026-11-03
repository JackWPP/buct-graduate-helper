#!/usr/bin/env python3
"""化研助手标志。苯环加三节不同颜色的课，不使用校徽。

运行：python3 design/brand/render_logo.py
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
BRAND = Path(__file__).resolve().parent
DOCS = ROOT / "docs" / "images"

BLUE = (0x2F, 0x6B, 0xFF, 255)
WHITE = (255, 255, 255, 255)
VIOLET = (0x7C, 0x5C, 0xFF, 255)
GREEN = (0x12, 0xA0, 0x5C, 255)
INK = (0x14, 0x17, 0x1F, 255)
MUTED = (0x5B, 0x62, 0x73, 255)
LINE = (0xE6, 0xE9, 0xF0, 255)
PAPER = (0xF5, 0xF7, 0xFA, 255)
FONT = "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"


def hex_points(cx: float, cy: float, radius: float) -> list[tuple[float, float]]:
    return [
        (
            cx + radius * math.cos(math.radians(60 * i)),
            cy + radius * math.sin(math.radians(60 * i)),
        )
        for i in range(6)
    ]


def round_line(draw: ImageDraw.ImageDraw, start, end, width: int, color) -> None:
    draw.line([start, end], fill=color, width=width)
    cap = width / 2
    for x, y in (start, end):
        draw.ellipse((x - cap, y - cap, x + cap, y + cap), fill=color)


def draw_mark(draw: ImageDraw.ImageDraw, size: int, *, bleed: bool, content: float) -> None:
    if bleed:
        draw.rectangle((0, 0, size, size), fill=BLUE)
    else:
        draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.224), fill=BLUE)

    def xp(value: float) -> float:
        return (size - size * content) / 2 + value * size * content / 1024

    cx = xp(512)
    cy = xp(512)
    radius = 348 * size * content / 1024
    points = hex_points(cx, cy, radius)
    draw.polygon(points, fill=WHITE)

    # 交替双键放在下半圈，避开中间的课表色条。
    inset = 26 * size * content / 1024
    bond = max(2, int(16 * size * content / 1024))
    for index in (0, 1, 2):
        x1, y1 = points[index]
        x2, y2 = points[(index + 1) % 6]
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        vx, vy = cx - mx, cy - my
        norm = math.hypot(vx, vy) or 1
        ox, oy = vx / norm * inset, vy / norm * inset
        start = (x1 + (x2 - x1) * 0.36 + ox, y1 + (y2 - y1) * 0.36 + oy)
        end = (x1 + (x2 - x1) * 0.64 + ox, y1 + (y2 - y1) * 0.64 + oy)
        round_line(draw, start, end, bond, BLUE)

    colors = [BLUE, VIOLET, GREEN]
    widths = [236, 318, 196]
    bar_h = 48 * size * content / 1024
    gap = 22 * size * content / 1024
    total = bar_h * 3 + gap * 2
    top = cy - total / 2 - 8 * size * content / 1024
    left = cx - 168 * size * content / 1024
    curve = 20 * size * content / 1024
    for index, (width, color) in enumerate(zip(widths, colors)):
        y = top + index * (bar_h + gap)
        bar_w = width * size * content / 1024
        draw.rounded_rectangle((left, y, left + bar_w, y + bar_h), radius=curve, fill=color)


def raster(size: int, *, bleed: bool = False, content: float = 1.0) -> Image.Image:
    scale = 4
    canvas = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw_mark(ImageDraw.Draw(canvas), size * scale, bleed=bleed, content=content)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def save_png(image: Image.Image, path: Path, *, opaque: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if opaque:
        image.convert("RGB").save(path, "PNG", optimize=True)
    else:
        image.save(path, "PNG", optimize=True)


def write_svg(path: Path) -> None:
    points = hex_points(512, 512, 348)
    poly = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    bonds = []
    for index in (0, 1, 2):
        x1, y1 = points[index]
        x2, y2 = points[(index + 1) % 6]
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        vx, vy = 512 - mx, 512 - my
        norm = math.hypot(vx, vy) or 1
        ox, oy = vx / norm * 26, vy / norm * 26
        sx, sy = x1 + (x2 - x1) * 0.36 + ox, y1 + (y2 - y1) * 0.36 + oy
        ex, ey = x1 + (x2 - x1) * 0.64 + ox, y1 + (y2 - y1) * 0.64 + oy
        bonds.append(
            f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" '
            'stroke="#2F6BFF" stroke-width="16" stroke-linecap="round"/>'
        )
    bars = []
    colors = ["#2F6BFF", "#7C5CFF", "#12A05C"]
    widths = [236, 318, 196]
    bar_h, gap = 48, 22
    total = bar_h * 3 + gap * 2
    top = 512 - total / 2 - 8
    left = 512 - 168
    for index, (width, color) in enumerate(zip(widths, colors)):
        y = top + index * (bar_h + gap)
        bars.append(
            f'<rect x="{left:.1f}" y="{y:.1f}" width="{width}" height="{bar_h}" rx="20" fill="{color}"/>'
        )
    path.write_text(
        "\n".join(
            [
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="化研助手">',
                '  <rect width="1024" height="1024" rx="230" fill="#2F6BFF"/>',
                f'  <polygon points="{poly}" fill="#FFFFFF"/>',
                *[f"  {bond}" for bond in bonds],
                *[f"  {bar}" for bar in bars],
                "</svg>",
                "",
            ]
        ),
        encoding="utf-8",
    )


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, size)


def render_layers() -> None:
    width, height = 1440, 470
    image = Image.new("RGB", (width, height), PAPER)
    draw = ImageDraw.Draw(image)
    title = font(28)
    body = font(22)
    small = font(18)
    cards = [
        (BLUE, "网页预览", "web/", "引导、登录、周课表。\n服务和培养进度。\n浏览器打开 8899。"),
        (VIOLET, "Flutter 壳", "app/", "同一套周次和节次。\n可以打 Web，\n也能打 Android 包。"),
        (GREEN, "学校接口", "gmis_cli.py", "验证码用手填。\n密码只从环境变量\n或交互输入读取。"),
    ]
    gap = 28
    card_w = (width - 80 - gap * 2) // 3
    card_h = 250
    top = 36
    for index, (color, name, path, text) in enumerate(cards):
        x = 40 + index * (card_w + gap)
        draw.rounded_rectangle((x, top, x + card_w, top + card_h), radius=28, fill=WHITE, outline=LINE, width=2)
        draw.rounded_rectangle((x + 28, top + 28, x + 76, top + 76), radius=14, fill=color)
        draw.text((x + 96, top + 36), name, font=title, fill=INK)
        draw.text((x + 28, top + 108), path, font=small, fill=color)
        # wrap roughly by characters
        y = top + 150
        for paragraph in text.split("\n"):
            line = ""
            for char in paragraph:
                trial = line + char
                if draw.textlength(trial, font=body) > card_w - 56:
                    draw.text((x + 28, y), line, font=body, fill=MUTED)
                    y += 34
                    line = char
                else:
                    line = trial
            if line:
                draw.text((x + 28, y), line, font=body, fill=MUTED)
                y += 34

    bar_top = top + card_h + 36
    draw.rounded_rectangle((40, bar_top, width - 40, bar_top + 132), radius=22, fill=WHITE, outline=LINE, width=2)
    draw.text((68, bar_top + 28), "课表快照", font=title, fill=INK)
    draw.text((68, bar_top + 74), "web/data/snapshot.json", font=body, fill=BLUE)
    draw.text(
        (420, bar_top + 48),
        "网页和 Flutter 都读这一份。live.json 可以覆盖，且不提交。",
        font=body,
        fill=MUTED,
    )
    save_png(image, DOCS / "layers.png", opaque=True)


def export_icons() -> None:
    squircle = raster(1024)
    save_png(squircle, BRAND / "icon-1024.png")
    save_png(squircle.resize((512, 512), Image.Resampling.LANCZOS), BRAND / "icon-512.png")
    save_png(squircle.resize((256, 256), Image.Resampling.LANCZOS), BRAND / "icon-256.png")
    write_svg(BRAND / "icon.svg")

    bleed = raster(1024, bleed=True)
    save_png(bleed, BRAND / "icon-ios-1024.png", opaque=True)
    maskable = raster(1024, bleed=True, content=0.8)
    save_png(maskable, BRAND / "icon-maskable-1024.png", opaque=True)

    web = ROOT / "web"
    save_png(squircle.resize((32, 32), Image.Resampling.LANCZOS), web / "favicon.png")
    save_png(squircle.resize((180, 180), Image.Resampling.LANCZOS), web / "apple-touch-icon.png")

    flutter_web = ROOT / "app" / "web"
    save_png(squircle.resize((32, 32), Image.Resampling.LANCZOS), flutter_web / "favicon.png")
    save_png(bleed.resize((192, 192), Image.Resampling.LANCZOS), flutter_web / "icons" / "Icon-192.png", opaque=True)
    save_png(bleed.resize((512, 512), Image.Resampling.LANCZOS), flutter_web / "icons" / "Icon-512.png", opaque=True)
    save_png(maskable.resize((192, 192), Image.Resampling.LANCZOS), flutter_web / "icons" / "Icon-maskable-192.png", opaque=True)
    save_png(maskable.resize((512, 512), Image.Resampling.LANCZOS), flutter_web / "icons" / "Icon-maskable-512.png", opaque=True)

    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    android_res = ROOT / "app" / "android" / "app" / "src" / "main" / "res"
    for name, pixels in densities.items():
        save_png(bleed.resize((pixels, pixels), Image.Resampling.LANCZOS), android_res / f"mipmap-{name}" / "ic_launcher.png", opaque=True)

    iconset = ROOT / "app" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    spec = json.loads((iconset / "Contents.json").read_text(encoding="utf-8"))
    seen = set()
    for item in spec["images"]:
        filename = item.get("filename")
        if not filename or filename in seen:
            continue
        seen.add(filename)
        pixels = int(round(float(item["size"].split("x")[0]) * int(item["scale"].replace("x", ""))))
        save_png(bleed.resize((pixels, pixels), Image.Resampling.LANCZOS), iconset / filename, opaque=True)


def main() -> None:
    export_icons()
    render_layers()
    print("wrote brand icons and docs/images/layers.png")


if __name__ == "__main__":
    main()
