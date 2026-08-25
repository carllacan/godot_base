#!/usr/bin/env python3
"""Writes a recoloured, resized, padded copy of an icon.

The icons in this folder are shared by every project, so a project that wants
one in its own colour does not edit it: it runs this and keeps the copy in its
own folder.

    ./tint_icon.py WhiteIcons/LinkButtons/steam_logo_white.png \\
        --colour '#1f4266' --height 48 --margin-left 6 \\
        --output ../../GUI/steam_logo_tinted.png

The recolouring multiplies every pixel by the colour, which is what Godot's
`modulate` does: a white icon comes out that colour exactly, and a shaded one
keeps its shading. The alpha is left as it is, so only the drawing is painted.

Margins are transparent padding, in pixels, added around the drawing; the
height is the drawing's own, so the image that comes out is taller and wider
than it by the margin totals. Negative margins crop instead.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops


def parse_colour(value):
    """Returns the (r, g, b) of a #rgb or #rrggbb string, for argparse."""
    digits = value.lstrip("#")
    if len(digits) == 3 and all(c in "0123456789abcdefABCDEF" for c in digits):
        return tuple(int(c * 2, 16) for c in digits)
    if len(digits) == 6 and all(c in "0123456789abcdefABCDEF" for c in digits):
        return tuple(int(digits[i:i + 2], 16) for i in (0, 2, 4))
    raise argparse.ArgumentTypeError("%r is not a #rgb or #rrggbb colour" % value)


def resized(icon, height):
    """Returns the icon scaled to height, its aspect ratio kept.

    Icons are drawn on transparency, and the colour of a fully transparent
    pixel is arbitrary: resampling straight RGBA lets those arbitrary colours
    bleed into the edge. Resampling premultiplied ("RGBa") weights each pixel
    by its own alpha instead, which is what keeps the edge clean.
    """
    if height is None or height == icon.height:
        return icon

    width = max(1, round(icon.width * height / icon.height))
    return icon.convert("RGBa").resize((width, height), Image.LANCZOS).convert("RGBA")


def tinted(icon, rgb):
    """Returns the icon with every pixel multiplied by rgb, alpha untouched.

    The fully transparent pixels are painted rgb as well. Their colour is
    invisible but not harmless: the filtering that scales the texture on screen
    samples them like any other, so leaving them black rings the drawing in a
    dark fringe. This is why the icons here are white right across, transparent
    corners and all.
    """
    colour = Image.new("RGB", icon.size, rgb)
    alpha = icon.getchannel("A")

    copy = ImageChops.multiply(icon.convert("RGB"), colour)
    copy.paste(colour, mask=alpha.point(lambda a: 255 if a == 0 else 0))

    copy = copy.convert("RGBA")
    copy.putalpha(alpha)
    return copy


def padded(icon, rgb, top, right, bottom, left):
    """Returns the icon on a transparent canvas grown by the four margins."""
    if not any((top, right, bottom, left)):
        return icon

    size = (max(1, icon.width + left + right), max(1, icon.height + top + bottom))
    # Transparent, but in the tint rather than in black, for the reason above:
    # the padding is what the drawing's outermost pixels blend against.
    copy = Image.new("RGBA", size, rgb + (0,))
    copy.paste(icon, (left, top))
    return copy


def target_for(source, output):
    """Returns the file to write: the output, or a name derived from the source."""
    if output is None:
        return source.with_name(source.stem + "_tinted.png")
    if output.is_dir():
        return output / (source.stem + "_tinted.png")
    return output


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="icon to copy")
    parser.add_argument(
        "-o", "--output", type=Path,
        help="file to write, or a folder to write <name>_tinted.png into "
             "(default: next to the source)")
    parser.add_argument(
        "-c", "--colour", "--color", dest="colour", type=parse_colour,
        default=(255, 255, 255), metavar="#RRGGBB",
        help="colour to multiply the icon by (default: white, i.e. unchanged)")
    parser.add_argument(
        "-H", "--height", type=int,
        help="height in pixels of the drawing, margins excluded "
             "(default: the source's own)")
    parser.add_argument(
        "-m", "--margin", type=int, default=0,
        help="transparent padding in pixels on all four sides (default: 0)")
    # Each defaults to None so that "not given" stays distinguishable from
    # "given as 0", which has to override a --margin on that one side.
    for side in ("top", "right", "bottom", "left"):
        parser.add_argument("--margin-" + side, type=int, default=None,
                            help="padding on the %s only, overriding --margin" % side)
    args = parser.parse_args(argv)

    if not args.source.is_file():
        parser.error("%s is not a file" % args.source)
    if args.height is not None and args.height < 1:
        parser.error("--height must be at least 1")

    margins = [args.margin if given is None else given
               for given in (args.margin_top, args.margin_right,
                             args.margin_bottom, args.margin_left)]

    icon = Image.open(args.source).convert("RGBA")
    copy = padded(tinted(resized(icon, args.height), args.colour),
                  args.colour, *margins)

    target = target_for(args.source, args.output)
    if target.resolve() == args.source.resolve():
        parser.error("that would overwrite the source; pass --output")
    if not target.parent.is_dir():
        parser.error("%s is not a directory" % target.parent)

    copy.save(target)
    print("%s -> %s (%dx%d, #%02x%02x%02x)"
          % ((args.source, target, copy.width, copy.height) + args.colour))
    return 0


if __name__ == "__main__":
    sys.exit(main())
