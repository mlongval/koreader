#!/usr/bin/env python3
"""Build fonts/kobo/koboicons.ttf, "Kobo Icons": KOReader's Wi-Fi icons
(U+ECA8 on, U+ECA9 off, from fonts/nerdfonts/symbols.ttf) plus ASCII from
Noto Sans, which crengine needs before it accepts a font. It is the last
crengine fallback font (frontend/document/credocument.lua), so the top bar
can show the Wi-Fi icon (plugins/mykobo.koplugin); it is kept out of the
font menus.

  kobo/make-koboicons.py KOREADER_FONTS_DIR   (needs fontTools)

KOREADER_FONTS_DIR: the fonts/ folder of the official release.
"""
import sys
from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem

KEEP = {"head", "hhea", "maxp", "OS/2", "hmtx", "cmap", "glyf", "loca", "name", "post"}


def part(src, unicodes, out, upem=None):
    f = TTFont(src)
    o = subset.Options()
    o.name_IDs = ["*"]
    o.layout_features = []
    s = subset.Subsetter(o)
    s.populate(unicodes=unicodes)
    s.subset(f)
    if upem and f["head"].unitsPerEm != upem:
        scale_upem(f, upem)
    for k in [k for k in f.keys() if k not in KEEP]:
        del f[k]
    f.save(out)
    return f["head"].unitsPerEm


fonts = sys.argv[1]
upem = part(f"{fonts}/noto/NotoSans-Regular.ttf", range(0x20, 0x7F), "/tmp/koboicons-a.ttf")
part(f"{fonts}/nerdfonts/symbols.ttf", [0xECA8, 0xECA9], "/tmp/koboicons-b.ttf", upem)
m = Merger().merge(["/tmp/koboicons-a.ttf", "/tmp/koboicons-b.ttf"])
for rec in m["name"].names:
    if rec.nameID in (1, 4, 16):
        rec.string = "Kobo Icons"
    elif rec.nameID == 6:
        rec.string = "KoboIcons"
    elif rec.nameID in (2, 17):
        rec.string = "Regular"
m.save("fonts/kobo/koboicons.ttf")
print("fonts/kobo/koboicons.ttf")
