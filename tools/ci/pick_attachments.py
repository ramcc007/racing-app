#!/usr/bin/env python3
"""Copies the named screenshots out of an `xcresulttool export attachments` folder.

  pick_attachments.py <export folder> <output folder>

The export names files by UUID and lists the readable names in manifest.json. Only PNGs that the UI tests named
themselves ("01-intro", "02-race", ...) are kept; XCTest's automatic debug attachments are skipped.
"""
import json, os, re, shutil, sys

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
manifest = os.path.join(src, "manifest.json")
if not os.path.exists(manifest):
    sys.exit(0)

def walk(node):
    if isinstance(node, dict):
        if "exportedFileName" in node:
            yield node
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for value in node:
            yield from walk(value)

kept = 0
for item in walk(json.load(open(manifest))):
    name = item.get("suggestedHumanReadableName", "")
    exported = item["exportedFileName"]
    match = re.match(r"(\d\d[a-z]?-[a-z-]+)", name)
    if match and exported.endswith(".png"):
        shutil.copy(os.path.join(src, exported), os.path.join(out, "uitest_" + match.group(1) + ".png"))
        kept += 1
print(f"kept {kept} UI test screenshots")
