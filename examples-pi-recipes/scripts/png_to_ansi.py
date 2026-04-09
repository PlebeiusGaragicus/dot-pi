"""Convert a PNG image to ANSI true-color half-block art on stdout.

Uses the upper half-block character (▀) with foreground = top pixel and
background = bottom pixel, giving 2x vertical resolution.

Usage: python png_to_ansi.py <image_path> [width]
  width defaults to 80 columns.

Dependencies: Pillow (ships with matplotlib).
"""

import sys
from PIL import Image


def png_to_ansi(path: str, width: int = 80) -> str:
    img = Image.open(path).convert("RGB")

    aspect = img.height / img.width
    height = int(width * aspect)
    if height % 2 != 0:
        height += 1

    img = img.resize((width, height), Image.LANCZOS)

    lines: list[str] = []
    for y in range(0, height, 2):
        row: list[str] = []
        for x in range(width):
            r1, g1, b1 = img.getpixel((x, y))
            if y + 1 < height:
                r2, g2, b2 = img.getpixel((x, y + 1))
            else:
                r2, g2, b2 = 0, 0, 0
            row.append(f"\033[38;2;{r1};{g1};{b1}m\033[48;2;{r2};{g2};{b2}m▀")
        lines.append("".join(row) + "\033[0m")

    return "\n".join(lines)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: png_to_ansi.py <image_path> [width]", file=sys.stderr)
        sys.exit(1)

    image_path = sys.argv[1]
    cols = int(sys.argv[2]) if len(sys.argv) > 2 else 80
    print(png_to_ansi(image_path, cols))
