"""Measures the specimens pages of the WinUI 3 reference app and ThemeDemo.

Both pages put one of each control at the same place on a canvas whose top
left is marked by an 8x8 magenta square (Reference/WinUI3ReferenceApp,
BuildSpecimensPage; Examples/ThemeDemo, -specimensPageViewForPage:). This
finds the square in each capture, measures each control in its slot (its
size, fills, strokes and corner, where its text sits) and compares the
theme's numbers with WinUI's. Run by Tests/Scripts/Compare-Reference.ps1.

usage: measure_specimens.py --reference PNG --theme PNG [--mode light|dark]
                            [--report MD] [--sheet PNG]

The exit code is the number of measurements out of tolerance.
"""

import argparse
import sys

from PIL import Image

# Slots on the canvas (x, y, width, height), each holding one control.
# Keep in step with the two specimens pages.
SPECIMENS = [
    ("button", "control", (12, 20, 128, 44)),
    ("accent-button", "control", (148, 20, 128, 44)),
    ("text-box", "control", (284, 20, 208, 44)),
    ("combo-box", "control", (500, 20, 168, 44)),
    ("check-box", "box", (12, 84, 30, 40)),
    ("toggle-switch", "track", (148, 84, 52, 40)),
    ("slider", "slider", (284, 84, 208, 40)),
    ("progress-bar", "progress", (500, 84, 168, 40)),
    ("body-text", "text", (12, 146, 560, 34)),
    # The rest of WinUI's type ramp: Caption, BodyStrong, Subtitle, Title.
    ("caption-text", "text", (12, 190, 560, 26)),
    ("body-strong-text", "text", (12, 222, 560, 30)),
    ("subtitle-text", "text", (12, 256, 700, 40)),
    ("title-text", "text", (12, 298, 700, 54)),
]

INK = 4                 # a channel this far from the background is ink
SIZE_TOLERANCE = 1      # px
COLOR_TOLERANCE = 6     # per channel, 0-255
TEXT_WIDTH_TOLERANCE = 0.02


def find_origin(image):
    """The magenta square's top left."""
    width, height = image.size
    pixels = image.load()
    for y in range(height - 8):
        for x in range(width - 8):
            r, g, b = pixels[x, y][:3]
            if r > 240 and g < 30 and b > 240:
                r2, g2, b2 = pixels[x + 7, y + 7][:3]
                if r2 > 240 and g2 < 30 and b2 > 240:
                    return x, y
    raise SystemExit("no magenta marker in the capture")


class Canvas:
    def __init__(self, path):
        self.image = Image.open(path).convert("RGB")
        self.pixels = self.image.load()
        self.ox, self.oy = find_origin(self.image)
        # The page background: the most common colour along the band
        # between the marker and the first row of controls.
        counts = {}
        for x in range(20, 700):
            colour = self.at(x, 13)
            counts[colour] = counts.get(colour, 0) + 1
        self.background = max(counts, key=counts.get)

    def at(self, x, y):
        return self.pixels[self.ox + x, self.oy + y][:3]

    def ink(self, x, y, against=None):
        colour = self.at(x, y)
        base = against if against is not None else self.background
        return max(abs(a - b) for a, b in zip(colour, base)) > INK

    def bbox(self, slot, against=None):
        sx, sy, sw, sh = slot
        xs, ys = [], []
        for y in range(sy, sy + sh):
            for x in range(sx, sx + sw):
                if self.ink(x, y, against):
                    xs.append(x)
                    ys.append(y)
        if not xs:
            return None
        return min(xs), min(ys), max(xs), max(ys)

    def run(self, x, y0, y1):
        """How many pixels in column x, rows y0 to y1, are ink."""
        return sum(1 for y in range(y0, y1 + 1) if self.ink(x, y))


def text_box(canvas, x0, y0, x1, y1, fill, exclude_right=0):
    """The bounding box of the text inside a control: pixels well away
    from its fill."""
    xs, ys = [], []
    for y in range(y0 + 3, y1 - 2):
        for x in range(x0 + 3, x1 - 2 - exclude_right):
            colour = canvas.at(x, y)
            if max(abs(a - b) for a, b in zip(colour, fill)) > 60:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def measure(canvas, kind, slot, name):
    m = {}
    box = canvas.bbox(slot)
    if box is None:
        return {"found": ("size", 0)}
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    if kind == "control":
        fill = canvas.at(x0 + 4, cy)
        m["width"] = ("size", x1 - x0 + 1)
        m["height"] = ("size", y1 - y0 + 1)
        m["fill"] = ("colour", fill)
        m["top stroke"] = ("colour", canvas.at(x0 + 10, y0))
        m["bottom stroke"] = ("colour", canvas.at(x0 + 10, y1))
        corner = 0
        while corner < 8 and not canvas.ink(x0 + corner, y0):
            corner += 1
        m["corner inset"] = ("size", corner)
        text = text_box(canvas, x0, y0, x1, y1, fill, 32 if name == "combo-box" else 0)
        if text is not None:
            tx0, ty0, tx1, ty1 = text
            m["text height"] = ("size", ty1 - ty0 + 1)
            m["text centre from control centre"] = ("size", round((ty0 + ty1) / 2 - (y0 + y1) / 2))
            if name in ("text-box", "combo-box"):
                m["text inset"] = ("size", tx0 - x0)
            else:
                m["text offset from centre"] = ("size", round((tx0 + tx1) / 2 - (x0 + x1) / 2))
    elif kind == "box":
        m["width"] = ("size", x1 - x0 + 1)
        m["height"] = ("size", y1 - y0 + 1)
        m["fill"] = ("colour", canvas.at(x0 + 3, cy))
    elif kind == "track":
        m["width"] = ("size", x1 - x0 + 1)
        m["height"] = ("size", y1 - y0 + 1)
        m["fill"] = ("colour", canvas.at(x0 + 5, cy))
    elif kind == "slider":
        m["thumb height"] = ("size", y1 - y0 + 1)
        right = x1 - 8
        left = x0 + 8
        m["track thickness"] = ("size", canvas.run(right, y0, y1))
        m["filled track thickness"] = ("size", canvas.run(left, y0, y1))
        m["track"] = ("colour", canvas.at(right, cy))
        m["filled track"] = ("colour", canvas.at(left, cy))
    elif kind == "progress":
        left = x0 + 8
        right = x1 - 8
        m["indicator thickness"] = ("size", canvas.run(left, y0, y1))
        m["track thickness"] = ("size", canvas.run(right, y0, y1))
        m["indicator"] = ("colour", canvas.at(left, cy))
        m["track"] = ("colour", canvas.at(right, (y0 + y1) // 2))
    elif kind == "text":
        m["width"] = ("text", x1 - x0 + 1)
        m["height"] = ("size", y1 - y0 + 1)
    return m


def compare(kind, reference, theme):
    if kind == "colour":
        delta = max(abs(a - b) for a, b in zip(reference, theme))
        return delta, delta <= COLOR_TOLERANCE
    delta = theme - reference
    if kind == "text":
        return delta, abs(delta) <= max(1, reference * TEXT_WIDTH_TOLERANCE)
    return delta, abs(delta) <= SIZE_TOLERANCE


def show(kind, value):
    if kind == "colour":
        return "#%02X%02X%02X" % tuple(value)
    return str(value)


def contact_sheet(reference, theme, path):
    scale = 2
    rows = []
    for name, kind, (x, y, w, h) in SPECIMENS:
        pair = []
        for canvas in (reference, theme):
            box = (canvas.ox + x, canvas.oy + y, canvas.ox + x + w, canvas.oy + y + h)
            pair.append(canvas.image.crop(box).resize((w * scale, h * scale), Image.NEAREST))
        rows.append(pair)
    width = max(a.width + b.width for a, b in rows) + 24
    height = sum(a.height for a, _ in rows) + 8 * len(rows)
    sheet = Image.new("RGB", (width, height), (255, 0, 255))
    y = 0
    for a, b in rows:
        sheet.paste(a, (0, y))
        sheet.paste(b, (a.width + 24, y))
        y += a.height + 8
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", required=True)
    parser.add_argument("--theme", required=True)
    parser.add_argument("--mode", default="light")
    parser.add_argument("--report")
    parser.add_argument("--sheet")
    args = parser.parse_args()

    reference = Canvas(args.reference)
    theme = Canvas(args.theme)
    lines = [
        "# WinUI 3 reference vs. the theme (%s)" % args.mode,
        "",
        "Colours within %d per channel, sizes within %dpx, text width within %d%%."
        % (COLOR_TOLERANCE, SIZE_TOLERANCE, TEXT_WIDTH_TOLERANCE * 100),
        "",
        "| Specimen | Measure | WinUI | Theme | Delta | |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    failures = 0
    background_delta, background_ok = compare("colour", reference.background, theme.background)
    lines.append("| page | background | %s | %s | %d | %s |" % (
        show("colour", reference.background), show("colour", theme.background),
        background_delta, "ok" if background_ok else "**off**"))
    failures += 0 if background_ok else 1

    for name, kind, slot in SPECIMENS:
        ours = measure(theme, kind, slot, name)
        theirs = measure(reference, kind, slot, name)
        for key in theirs:
            measure_kind, value = theirs[key]
            if key not in ours:
                lines.append("| %s | %s | %s | (none) | | **off** |" % (name, key, show(measure_kind, value)))
                failures += 1
                continue
            delta, ok = compare(measure_kind, value, ours[key][1])
            lines.append("| %s | %s | %s | %s | %s | %s |" % (
                name, key, show(measure_kind, value), show(measure_kind, ours[key][1]),
                delta, "ok" if ok else "**off**"))
            failures += 0 if ok else 1

    lines.append("")
    lines.append("%d measurement(s) out of tolerance." % failures)
    report = "\n".join(lines) + "\n"
    print(report)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as handle:
            handle.write(report)
    if args.sheet:
        contact_sheet(reference, theme, args.sheet)
    return min(failures, 255)


if __name__ == "__main__":
    sys.exit(main())
