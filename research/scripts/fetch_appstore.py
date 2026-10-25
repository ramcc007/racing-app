#!/usr/bin/env python3
"""Fetch App Store metrics and written reviews for the racing long list.

Needs network access to itunes.apple.com (blocked in the 25 Oct 2026 research
session, so the report used web-search snippets instead). Re-run this once the
host is allowed to refresh research/data with first-party numbers.

    python3 research/scripts/fetch_appstore.py            # metrics + reviews
    python3 research/scripts/fetch_appstore.py --metrics  # metrics only
"""
import json
import sys
import time
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
COUNTRIES = ["us", "gb", "in", "de"]
REVIEW_COUNTRIES = ["us", "gb"]
REVIEW_PAGES = 10  # the RSS feed serves at most 10 pages of 50


def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "racing-research/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def app_ids():
    """Collect every iOS id recorded in apps.json (falls back to the batch files)."""
    src = DATA / "apps.json"
    apps = json.loads(src.read_text())["apps"] if src.exists() else []
    return {a["name"]: str(a["ios_app_id"]) for a in apps if a.get("ios_app_id")}


def fetch_metrics(ids):
    out = {"fetched": date.today().isoformat(), "apps": {}}
    for name, app_id in ids.items():
        out["apps"][name] = {}
        for cc in COUNTRIES:
            res = get_json(f"https://itunes.apple.com/lookup?id={app_id}&country={cc}")
            r = (res.get("results") or [{}])[0]
            out["apps"][name][cc] = {
                "userRatingCount": r.get("userRatingCount"),
                "averageUserRating": r.get("averageUserRating"),
                "fileSizeBytes": r.get("fileSizeBytes"),
                "minimumOsVersion": r.get("minimumOsVersion"),
                "currentVersionReleaseDate": r.get("currentVersionReleaseDate"),
            }
            time.sleep(0.5)
    (DATA / "appstore_lookup.json").write_text(json.dumps(out, indent=2))


def fetch_reviews(ids):
    (DATA / "reviews").mkdir(exist_ok=True)
    for name, app_id in ids.items():
        reviews = []
        for cc in REVIEW_COUNTRIES:
            for page in range(1, REVIEW_PAGES + 1):
                url = (f"https://itunes.apple.com/{cc}/rss/customerreviews/"
                       f"page={page}/id={app_id}/sortby=mostrecent/json")
                entries = get_json(url).get("feed", {}).get("entry", [])
                if isinstance(entries, dict):
                    entries = [entries]
                for e in entries:
                    if "im:rating" not in e:
                        continue  # first entry on page 1 is the app itself
                    reviews.append({
                        "country": cc,
                        "rating": int(e["im:rating"]["label"]),
                        "title": e["title"]["label"],
                        "body": e["content"]["label"],
                        "version": e.get("im:version", {}).get("label"),
                        "updated": e.get("updated", {}).get("label"),
                    })
                if not entries:
                    break
                time.sleep(0.5)
        slug = "".join(c if c.isalnum() else "-" for c in name.lower()).strip("-")
        (DATA / "reviews" / f"{slug}.json").write_text(json.dumps(reviews, indent=1))
        print(f"{name}: {len(reviews)} reviews")


if __name__ == "__main__":
    ids = app_ids()
    fetch_metrics(ids)
    if "--metrics" not in sys.argv:
        fetch_reviews(ids)
