#!/usr/bin/env python3
"""Removes the alpha channel from the app icon (App Store Connect rejects icons with transparency or alpha)."""
from pathlib import Path
from PIL import Image
icon = Path(__file__).resolve().parents[2] / "ios/EchoLap/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
img = Image.open(icon).convert("RGB")
assert img.size == (1024, 1024), img.size
img.save(icon, "PNG", optimize=True)
print("flattened", icon, img.mode, img.size)
