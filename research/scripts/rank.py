#!/usr/bin/env python3
"""Rank the racing long list and write research/data/apps.json + ranking.json.

Inputs: research/data/metrics_batch_a.json and metrics_batch_b.json (every raw
figure there carries its source URL). The figures below are the ones picked
from those files for scoring, with the reason for each pick.

Score = 60% ratings + 40% downloads.
Each part is min-max normalised on a log10 scale across the eligible apps,
because the numbers span 3K to 1.1M ratings and 0.1M to 912M downloads.
A missing figure scores 0 for that part (and is flagged), so gaps push an app
down rather than up.

    python3 research/scripts/rank.py
"""
import json
import math
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "data"

# name -> (ratings, ratings_basis, downloads, downloads_basis, eligible, note)
# ratings: US App Store count where found; otherwise the smallest aggregator
# total (conservative). downloads: all-platform lifetime estimate where found;
# otherwise the Google Play install floor (e.g. "100M+" -> 100M).
PICKS = {
    "Hill Climb Racing": (135e3, "US", 912e6, "all platforms (Udonis 2026)", True, ""),
    "Hill Climb Racing 2": (180e3, "US", 426e6, "all platforms (Udonis 2026)", True, ""),
    "Asphalt Legends": (1.1e6, "US", 100e6, "Google Play floor 100M+", True,
                        "Downloads figure is only a floor; real lifetime total is very likely far higher."),
    "Asphalt 8: Airborne": (225.3e3, "global iOS (AppGoblin), no US figure found", 561e6, "all platforms (Udonis 2026)", True, ""),
    "Real Racing 3": (454e3, "global iOS (AppGoblin)", 413e6, "all platforms (Udonis 2026)", False,
                      "Removed from the App Store on 18 Dec 2025; servers off 19 Mar 2026."),
    "CSR Racing 2": (882e3, "aggregator total (apppricinglab), no US figure found", 50e6, "Google Play floor 50M+", True, ""),
    "Need for Speed No Limits": (394e3, "US", 383e6, "all platforms (Udonis 2026)", True, ""),
    "Traffic Rider": (47e3, "US", 770e6, "all platforms (Udonis 2026)", True, ""),
    "Traffic Racer": (7.1e3, "US", 100e6, "Google Play floor 100M+", True, ""),
    "Beach Buggy Racing": (6.6e3, "US (AppFollow)", 100e6, "Google Play floor 100M+", True, ""),
    "Beach Buggy Racing 2": (33e3, "US", 100e6, "Google Play floor 100M+", True, ""),
    "Race Master 3D": (570e3, "US", 457e6, "all platforms (Udonis 2026, via search summary)", True, ""),
    "Bike Race": (1.0e6, "US (Apptopia estimate)", 73e6, "iOS only (AppGoblin estimate)", True,
                  "Downloads are iOS-only, so the score understates it."),
    "Mario Kart Tour": (1.0e6, "US", None, "not found", True,
                        "No download figure found; Nintendo has wound the game down (no new content)."),
    "Street Racing 3D": (None, "not found", 454e6, "all platforms (Udonis 2026, via search summary)", False,
                         "iOS listing could not be confirmed as the same game."),
    "Extreme Car Driving Simulator": (69.9e3, "aggregator (apppricinglab)", 643e6, "all platforms (Udonis 2026)", False,
                                      "Free-roam driving sim; racing is not the core mode."),
    "Rush Rally 3": (3e3, "US*", 0.5e6, "Google Play 500K", True, ""),
    "CarX Drift Racing 2": (37e3, "US*", 50e6, "Google Play floor 50M+", True, ""),
    "CarX Street": (137e3, "US*", 10e6, "Google Play floor 10M+", True, ""),
    "Mad Skills Motocross 3": (112e3, "US", 50e6, "Google Play floor 50M+", True, ""),
    "Drive Ahead!": (149e3, "US", 100e6, "Google Play floor 100M+", True, "Car combat arena more than racing."),
    "Horizon Chase": (11e3, "US", 10e6, "Google Play 10M", True, ""),
    "GRID Autosport": (2.8e3, "US*", 0.1e6, "iOS sales (2018)", True, "Premium game, so downloads are paid sales."),
    "Smashy Road: Wanted": (11e3, "US*", None, "not found", True, "No update since 2021."),
    "Rider": (116e3, "US*", 150e6, "all platforms (Mobidictum)", True, ""),
    "Drag Racing Classic": (5.8e3, "US*", None, "only a franchise-wide claim (not used)", True, ""),
    "Rebel Racing": (211e3, "US", 50e6, "Google Play floor 50M+", True, ""),
    "Car Parking Multiplayer": (49e3, "US", 100e6, "Google Play floor 100M+", False,
                                "Open-world parking/driving sim; racing is not the core mode."),
    "Dr. Driving": (6.3e3, "aggregator (apppricinglab)", 692.8e6, "Google Play (AppGoblin)", False,
                    "Driving missions, not racing; App Store status unclear."),
    "Hot Wheels Unlimited": (140e3, "US*", None, "not found (weekly US figures only)", True, ""),
    "Moto X3M": (98e3, "US", None, "not found", True, ""),
    "Pocket Champs": (None, "not found", None, "not found (weekly US figures only)", True, ""),
    "aquapark.io": (None, "not found", None, "not found", False, "Water-slide hyper-casual, not vehicle racing."),
}


def norm(values):
    logs = [math.log10(v) for v in values if v]
    lo, hi = min(logs), max(logs)
    return lambda v: 0.0 if not v else (math.log10(v) - lo) / (hi - lo)


def main():
    raw = {}
    for f in ("metrics_batch_a.json", "metrics_batch_b.json"):
        for a in json.loads((DATA / f).read_text()):
            raw[a["name"]] = a

    eligible = {k: v for k, v in PICKS.items() if v[4]}
    nr = norm([v[0] for v in eligible.values()])
    nd = norm([v[2] for v in eligible.values()])

    rows = []
    for name, (r, rb, d, db, ok, note) in PICKS.items():
        score = round(100 * (0.6 * nr(r) + 0.4 * nd(d)), 1) if ok else None
        rows.append({"name": name, "ratings": r, "ratings_basis": rb, "downloads": d,
                     "downloads_basis": db, "eligible": ok, "score": score, "note": note})
    rows.sort(key=lambda x: (x["score"] is None, -(x["score"] or 0)))
    for i, row in enumerate([x for x in rows if x["eligible"]], 1):
        row["rank"] = i

    (DATA / "ranking.json").write_text(json.dumps({
        "method": "score = 60% ratings + 40% downloads, each min-max normalised on log10 across eligible apps; missing = 0",
        "accessed": "2026-10-25",
        "rows": rows,
    }, indent=2))
    (DATA / "apps.json").write_text(json.dumps({
        "accessed": "2026-10-25",
        "note": "Raw per-app metrics with sources, merged from the two search batches.",
        "apps": list(raw.values()),
    }, indent=2))

    for row in rows:
        print(f"{row.get('rank', '-'):>2}  {row['score'] if row['score'] is not None else 'excl':>5}  {row['name']}")


if __name__ == "__main__":
    main()
