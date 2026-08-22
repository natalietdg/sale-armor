#!/usr/bin/env python3
"""
Upload the App Store listing screenshots.

Same three-step reservation as the review screenshot, but into a *set* — Apple groups screenshots
by display size. Order matters: the first two are what people see without swiping, so the guard
screen and the money-not-spent screen lead.

One set per device family the binary claims. The app went iPad-capable in build 20, and a version
cannot be submitted without a screenshot set for every family it supports, so both are listed
below and the device is chosen on the command line.

    python3 tools/upload_screenshots.py              # iPhone
    python3 tools/upload_screenshots.py ipad
"""
import hashlib
import sys
import urllib.error
import urllib.request

import asc

LOCALIZATION = "5692efd7-5d27-495e-b48e-ede174ea0ec7"

# Apple's display type per family, with the pixel size each one accepts.
DEVICES = {
    "iphone": ("APP_IPHONE_67", "screenshots"),            # 1320x2868
    "ipad": ("APP_IPAD_PRO_3GEN_129", "screenshots/ipad"),  # 2048x2732
}

# Ordered as they will appear, and re-shot in August 2026 after the sword gained emeralds,
# a ruby catchlight and one-light-source shading — the previous set showed artwork the app
# no longer ships. The paywall is last: it is the ask, not the pitch.
SHOTS = ["01-guard.png", "02-armed.png", "03-wishlist.png", "04-paywall.png"]


def reserve_set(display_type):
    status, data = asc.call("GET", f"/v1/appStoreVersionLocalizations/{LOCALIZATION}/appScreenshotSets")
    for existing in data.get("data", []):
        if existing["attributes"]["screenshotDisplayType"] == display_type:
            return existing["id"]

    status, data = asc.call("POST", "/v1/appScreenshotSets", {
        "data": {"type": "appScreenshotSets",
                 "attributes": {"screenshotDisplayType": display_type},
                 "relationships": {"appStoreVersionLocalization": {
                     "data": {"type": "appStoreVersionLocalizations", "id": LOCALIZATION}}}}
    })
    if status != 201:
        raise SystemExit(f"could not create the {display_type} set: {status} {data}")
    return data["data"]["id"]


def upload(set_id, path):
    data = open(path, "rb").read()
    status, created = asc.call("POST", "/v1/appScreenshots", {
        "data": {"type": "appScreenshots",
                 "attributes": {"fileName": path.split("/")[-1], "fileSize": len(data)},
                 "relationships": {"appScreenshotSet": {
                     "data": {"type": "appScreenshotSets", "id": set_id}}}}
    })
    if status != 201:
        return f"reserve failed {status}"

    screenshot_id = created["data"]["id"]
    for operation in created["data"]["attributes"]["uploadOperations"]:
        chunk = data[operation["offset"]:operation["offset"] + operation["length"]]
        request = urllib.request.Request(operation["url"], method=operation["method"], data=chunk)
        for header in operation["requestHeaders"]:
            request.add_header(header["name"], header["value"])
        try:
            urllib.request.urlopen(request)
        except urllib.error.HTTPError as error:
            return f"upload failed {error.code}"

    status, _ = asc.call("PATCH", f"/v1/appScreenshots/{screenshot_id}", {
        "data": {"type": "appScreenshots", "id": screenshot_id,
                 "attributes": {"uploaded": True,
                                "sourceFileChecksum": hashlib.md5(data).hexdigest()}}
    })
    return "uploaded" if status == 200 else f"commit failed {status}"


def clear(set_id):
    """
    Empty the set before refilling it.

    Uploading alone appends, so re-running this script used to leave the superseded shots sitting
    in front of the new ones — the listing would have shown eight screenshots, oldest first. The
    order of a set is the order it was filled in, so the only way to reorder or replace is to
    start from empty.
    """
    status, data = asc.call("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")
    for existing in data.get("data", []):
        code, _ = asc.call("DELETE", f"/v1/appScreenshots/{existing['id']}")
        print(f"  removed {existing['attributes'].get('fileName'):<20} {code}")


if __name__ == "__main__":
    device = sys.argv[1] if len(sys.argv) > 1 else "iphone"
    display_type, folder = DEVICES[device]

    set_id = reserve_set(display_type)
    print(f"{device} set ({display_type}):", set_id)
    clear(set_id)
    for name in SHOTS:
        print(f"  {name:20}", upload(set_id, f"{folder}/{name}"))
