"""Rasterize the native Chagok SVG mark into web and Android launcher icons.

Requirements: Pillow. Run from any directory with ``python tools/generate_icons.py``.
The renderer samples the SVG's own M/L/Q paths at 4x resolution; icon geometry,
colors, gradients, and shadow settings remain defined in assets/branding/logo.svg.
The 512px canvas is opaque and the mark stays inside the maskable safe circle.
"""

from __future__ import annotations

import re
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageColor, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "logo.svg"
SCALE = 4
CANVAS = 512
SVG = "{http://www.w3.org/2000/svg}"


def rgb(value: str) -> tuple[int, int, int]:
    return ImageColor.getrgb(value)


def coordinates(path_data: str) -> list[tuple[float, float]]:
    """Sample the mark's absolute quadratic SVG curves without a Cairo runtime."""
    tokens = re.findall(r"[MLQZ]|[-+]?(?:\d*\.)?\d+", path_data)
    points: list[tuple[float, float]] = []
    position = 0
    cursor = (0.0, 0.0)
    while position < len(tokens):
        command = tokens[position]
        position += 1
        if command in ("M", "L"):
            cursor = (float(tokens[position]), float(tokens[position + 1]))
            points.append(cursor)
            position += 2
        elif command == "Q":
            control = (float(tokens[position]), float(tokens[position + 1]))
            end = (float(tokens[position + 2]), float(tokens[position + 3]))
            for step in range(1, 25):
                t = step / 24
                points.append(tuple(
                    (1 - t) ** 2 * cursor[axis]
                    + 2 * (1 - t) * t * control[axis]
                    + t ** 2 * end[axis]
                    for axis in (0, 1)
                ))
            cursor = end
            position += 4
        elif command == "Z":
            points.append(points[0])
        else:
            raise ValueError(f"Unsupported SVG path command: {command}")
    return [(x * SCALE, y * SCALE) for x, y in points]


def render_svg() -> Image.Image:
    svg = ET.parse(SOURCE).getroot()
    background = svg.find(f"{SVG}rect[@id='background']")
    tile = svg.find(f"{SVG}rect[@id='tile']")
    symbol = svg.find(f"{SVG}g[@id='symbol']")
    assert background is not None and tile is not None and symbol is not None
    resolution = CANVAS * SCALE
    image = Image.new("RGBA", (resolution, resolution), rgb(background.attrib["fill"]))
    x, y = float(tile.attrib["x"]), float(tile.attrib["y"])
    width, height = float(tile.attrib["width"]), float(tile.attrib["height"])
    rectangle = (x * SCALE, y * SCALE, (x + width) * SCALE, (y + height) * SCALE)
    radius = float(tile.attrib["rx"]) * SCALE

    # Render the two SVG drop shadows from the same rounded tile geometry.
    for shadow in svg.findall(f"{SVG}defs/{SVG}filter[@id='raised']/{SVG}feDropShadow"):
        dx, dy = float(shadow.attrib["dx"]) * SCALE, float(shadow.attrib["dy"]) * SCALE
        mask = Image.new("L", image.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (rectangle[0] + dx, rectangle[1] + dy, rectangle[2] + dx, rectangle[3] + dy),
            radius=radius,
            fill=round(255 * float(shadow.attrib["flood-opacity"])),
        )
        mask = mask.filter(ImageFilter.GaussianBlur(float(shadow.attrib["stdDeviation"]) * SCALE))
        layer = Image.new("RGBA", image.size, rgb(shadow.attrib["flood-color"]))
        layer.putalpha(mask)
        image = Image.alpha_composite(image, layer)

    stops = svg.findall(f"{SVG}defs/{SVG}linearGradient[@id='tileFace']/{SVG}stop")
    first, last = rgb(stops[0].attrib["stop-color"]), rgb(stops[-1].attrib["stop-color"])
    gradient = Image.new("RGB", (resolution, resolution))
    pixels = gradient.load()
    for row in range(resolution):
        for column in range(resolution):
            fraction = min(1, max(0, ((column / SCALE - x) + (row / SCALE - y)) / (width + height)))
            pixels[column, row] = tuple(round(a + (b - a) * fraction) for a, b in zip(first, last))
    tile_mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(tile_mask).rounded_rectangle(rectangle, radius=radius, fill=255)
    image.paste(gradient, mask=tile_mask)
    painter = ImageDraw.Draw(image)
    painter.rounded_rectangle(
        rectangle,
        radius=radius,
        outline=rgb(tile.attrib["stroke"]),
        width=max(1, round(float(tile.attrib["stroke-width"]) * SCALE)),
    )

    for path in symbol.findall(f"{SVG}path"):
        points = coordinates(path.attrib["d"])
        fill = path.attrib.get("fill", symbol.attrib.get("fill", "none"))
        stroke = path.attrib.get("stroke", symbol.attrib.get("stroke", "none"))
        if fill != "none":
            painter.polygon(points, fill=rgb(fill))
        if stroke != "none":
            line_width = round(float(path.attrib.get("stroke-width", symbol.attrib["stroke-width"])) * SCALE)
            color = rgb(stroke)
            painter.line(points, fill=color, width=line_width, joint="curve")
            cap_radius = line_width / 2
            # Fill each sampled join to match SVG's continuous round stroke.
            for px, py in points:
                painter.ellipse((px - cap_radius, py - cap_radius, px + cap_radius, py + cap_radius), fill=color)
    return image.convert("RGB")


def main() -> None:
    master = render_svg()
    outputs = {
        "web/favicon.png": 32,
        "web/icons/Icon-192.png": 192,
        "web/icons/Icon-512.png": 512,
        "web/icons/Icon-maskable-192.png": 192,
        "web/icons/Icon-maskable-512.png": 512,
        "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
        "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
        "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
        "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for relative_path, size in outputs.items():
        target = ROOT / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.Resampling.LANCZOS).save(target, optimize=True)
        print(f"{relative_path}: {size} x {size}")


if __name__ == "__main__":
    main()
