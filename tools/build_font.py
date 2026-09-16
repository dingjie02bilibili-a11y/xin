#!/usr/bin/env python3
"""Build the single font the game ships with.

Godot's web export has no system font fallback, so every glyph the game draws
has to be inside one file we ship (see issue #78921). This scans the project for
every non-ASCII character, then subsets and merges the OFL fonts that cover
them into fonts/game_font.ttf.

Sources (all SIL Open Font License 1.1, redistributable):
  - Noto Sans SC          CJK + CJK punctuation          (local Windows copy)
  - Noto Sans Symbols 2   dingbats, misc symbols         (downloaded)
  - Noto Sans Symbols     electric arrow, moon, flag     (downloaded)
  - Noto Sans Math        the four arrows / sine wave    (downloaded)

Usage:  python tools/build_font.py [--cache DIR]
"""
import argparse
import os
import sys
import urllib.request

from fontTools import merge
from fontTools.subset import Subsetter, Options
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "fonts", "game_font.ttf")
SCAN_EXT = (".gd", ".tscn", ".godot")
SKIP_DIRS = {".git", ".godot", "work", "tools"}

NOTO_SC = r"C:\Windows\Fonts\NotoSansSC-VF.ttf"
NOTO_BASE = "https://raw.githubusercontent.com/notofonts/notofonts.github.io/main/fonts"
REMOTE = {
    "NotoSansSymbols2-Regular.ttf": f"{NOTO_BASE}/NotoSansSymbols2/hinted/ttf/NotoSansSymbols2-Regular.ttf",
    "NotoSansSymbols-Regular.ttf": f"{NOTO_BASE}/NotoSansSymbols/hinted/ttf/NotoSansSymbols-Regular.ttf",
    "NotoSansMath-Regular.ttf": f"{NOTO_BASE}/NotoSansMath/hinted/ttf/NotoSansMath-Regular.ttf",
}
# Weight 500 reads better than 400 against the dark background.
SC_WEIGHT = 500


def scan_chars():
    """Every non-ASCII character the project can draw, plus printable ASCII."""
    chars = set(chr(c) for c in range(0x20, 0x7F))
    for root, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if not name.endswith(SCAN_EXT):
                continue
            with open(os.path.join(root, name), encoding="utf-8") as fh:
                chars.update(fh.read())
    # Keep the private/control range out of the subset.
    return set(c for c in chars if ord(c) >= 0x20)


def codepoints(path):
    font = TTFont(path)
    cps = set()
    for table in font["cmap"].tables:
        cps |= set(table.cmap.keys())
    font.close()
    return cps


def subset_to(src, wanted, dest):
    font = TTFont(src)
    if "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": SC_WEIGHT}, inplace=True)
    opts = Options()
    opts.desubroutinize = True
    # Variation and layout tables survive instancing and break the merge below
    # (VarStore inside GDEF). The game draws plain runs of CJK and symbols, so
    # dropping shaping tables costs nothing and shrinks the file.
    opts.drop_tables += ["DSIG", "HVAR", "VVAR", "MVAR", "STAT", "fvar", "gvar",
                         "avar", "cvar", "GDEF", "GSUB", "GPOS", "BASE", "MATH", "vhea", "vmtx", "VORG"]
    opts.name_IDs = ["*"]
    opts.name_legacy = True
    opts.layout_features = []
    sub = Subsetter(options=opts)
    sub.populate(unicodes=[ord(c) for c in wanted])
    sub.subset(font)
    font.save(dest)
    font.close()
    return len(wanted)


def fetch(cache, name):
    path = os.path.join(cache, name)
    if not os.path.exists(path):
        print(f"  downloading {name} ...")
        urllib.request.urlretrieve(REMOTE[name], path)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=os.path.join(ROOT, "work", "fontcache"))
    args = ap.parse_args()
    os.makedirs(args.cache, exist_ok=True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    wanted = scan_chars()
    print(f"project needs {len(wanted)} characters")

    # Noto SC first: it covers CJK plus everything ASCII, so it decides the metrics.
    sources = [(NOTO_SC, "Noto Sans SC")]
    remaining = wanted - codepoints_as_chars(NOTO_SC, wanted)
    for name in ("NotoSansSymbols2-Regular.ttf", "NotoSansSymbols-Regular.ttf", "NotoSansMath-Regular.ttf"):
        if not remaining:
            break
        path = fetch(args.cache, name)
        covered = codepoints_as_chars(path, remaining)
        if covered:
            sources.append((path, name))
            remaining -= covered
    if remaining:
        listing = " ".join(f"U+{ord(c):04X}" for c in sorted(remaining))
        sys.exit(f"no OFL source covers: {listing}")

    parts = []
    claimed = set()
    for index, (path, label) in enumerate(sources):
        slice_ = codepoints_as_chars(path, wanted) - claimed
        claimed |= slice_
        part = os.path.join(args.cache, f"part{index}.ttf")
        count = subset_to(path, slice_, part)
        print(f"  {label}: {count} glyphs -> {os.path.getsize(part) // 1024} KB")
        parts.append(part)

    if len(parts) == 1:
        os.replace(parts[0], OUT)
    else:
        merger = merge.Merger()
        merged = merger.merge(parts)
        merged.save(OUT)
        merged.close()
    print(f"wrote {OUT} ({os.path.getsize(OUT) // 1024} KB)")

    have = codepoints(OUT)
    gap = [c for c in wanted if ord(c) not in have]
    if gap:
        sys.exit("merge lost: " + " ".join(f"U+{ord(c):04X}" for c in sorted(gap)))
    print(f"verified: all {len(wanted)} characters present")


def codepoints_as_chars(path, wanted):
    cps = codepoints(path)
    return set(c for c in wanted if ord(c) in cps)


if __name__ == "__main__":
    main()
