#!/usr/bin/env python3
"""Count review themes in research/data/reviews/*.json with a fixed keyword list.

A review counts once per theme if any of the theme's phrases appears in its
title or body (case-insensitive). The keyword list is the method: edit it here,
re-run, and the numbers in the report can be checked again.

    python3 research/scripts/theme_reviews.py > research/data/review_themes.json
"""
import json
from pathlib import Path

REVIEWS = Path(__file__).resolve().parents[1] / "data" / "reviews"

LOVE = {
    "fun / addictive": ["addictive", "so fun", "really fun", "very fun", "love this game", "best game"],
    "physics / feel": ["physics", "handling", "drift", "feels good", "smooth"],
    "graphics": ["graphics", "beautiful", "looks amazing", "visuals"],
    "offline play": ["offline", "no wifi", "without internet", "on a plane"],
    "variety of cars/tracks": ["so many cars", "lots of cars", "variety", "many tracks", "new maps"],
    "quick sessions": ["quick", "kill time", "short", "pick up"],
}
HATE = {
    "too many ads": ["ads", "advert", "commercial"],
    "pay to win / greedy": ["pay to win", "p2w", "greedy", "money grab", "cash grab", "too expensive", "spend money"],
    "grind / progression wall": ["grind", "grinding", "stuck", "impossible to", "can't progress", "wall"],
    "energy / fuel timers": ["fuel", "energy", "wait", "timer", "refill"],
    "unfair AI / rubber-banding": ["rubber band", "rubberband", "cheat", "unfair", "rigged"],
    "bugs / crashes": ["crash", "bug", "glitch", "freez", "won't load", "doesn't load"],
    "connection required": ["internet", "connection", "online only", "server"],
    "controls": ["controls", "steering", "tilt", "touch"],
    "repetitive": ["repetitive", "boring", "same tracks", "same thing"],
    "battery / heat / size": ["battery", "hot", "overheat", "storage", "gb"],
}


def count(reviews, themes):
    out = {}
    for theme, words in themes.items():
        hits = [r for r in reviews
                if any(w in (r["title"] + " " + r["body"]).lower() for w in words)]
        out[theme] = {"count": len(hits), "share": round(len(hits) / max(len(reviews), 1), 3)}
    return out


if __name__ == "__main__":
    result = {}
    for f in sorted(REVIEWS.glob("*.json")):
        reviews = json.loads(f.read_text())
        pos = [r for r in reviews if r["rating"] >= 4]
        neg = [r for r in reviews if r["rating"] <= 2]
        result[f.stem] = {
            "total": len(reviews),
            "love (4-5 stars)": count(pos, LOVE),
            "complaints (1-2 stars)": count(neg, HATE),
        }
    print(json.dumps(result, indent=2))
