#!/usr/bin/env python3
"""Pixel-diff prototype screenshots against Flutter captures.

Usage: python3 diff_shots.py <proto_dir> <flutter_dir> <out_dir>
Produces PROTO|FLUTTER|DIFF composites per screen + a ranked %diff table.
"""
import os, sys
from PIL import Image, ImageChops, ImageDraw

P, F, D = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(D, exist_ok=True)
rows = []
for f in sorted(set(os.listdir(P)) & set(os.listdir(F))):
    a, b = Image.open(f'{P}/{f}').convert('RGB'), Image.open(f'{F}/{f}').convert('RGB')
    if a.size != b.size:
        b = b.resize(a.size, Image.LANCZOS)
    diff = ImageChops.difference(a, b)
    hist = diff.convert('L').histogram()
    pct = 100 * sum(hist[16:]) / sum(hist)  # >6% channel delta counts as "different"
    rows.append((pct, f))
    w, h = a.size
    comp = Image.new('RGB', (w * 3 + 40, h + 60), (24, 24, 28))
    comp.paste(a, (0, 60)); comp.paste(b, (w + 20, 60)); comp.paste(diff, (2 * w + 40, 60))
    ImageDraw.Draw(comp).text((10, 15), f"{f} PROTO|FLUTTER|DIFF %diff={pct:.1f}", fill=(255, 255, 255))
    comp.save(f'{D}/{f}')
for pct, f in sorted(rows, reverse=True):
    print(f"  {pct:5.1f}%  {f}")
