#!/usr/bin/env python3
"""
Upload the App Store listing screenshots.

Same three-step reservation as the review screenshot, but into a *set* — Apple groups screenshots
by display size, and the 6.9-inch set is the only one required now that it covers every current
iPhone. Order matters: the first two are what people see without swiping, so the guard screen and
the money-not-spent screen lead.

    python3 tools/upload_screenshots.py
"""
import hashlib
import urllib.error
import urllib.request

import asc

LOCALIZATION = "5692efd7-5d27-495e-b48e-ede174ea0ec7"
DISPLAY_TYPE = "APP_IPHONE_67"   # 6.7/6.9-inch, which 1320x2868 belongs to

# Ordered as they will appear. The paywall is last: it is the ask, not the pitch.
SCREENSHOTS = [
    "screenshots/02-arm.png",
    "screenshots/04-wishlist.png",
    "screenshots/03-armed.png",
    "screenshots/01-guard.png",
]


def reserve_set():
    status, data = asc.call("GET", f"/v1/appStoreVersionLocalizations/{LOCALIZATION}/appScreenshotSets")
    for existing in data.get("data", []):
        if existing["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE:
            return existing["id"]

    status, data = asc.call("POST", "/v1/appScreenshotSets", {
        "data": {"type": "appScreenshotSets",
                 "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
                 "relationships": {"appStoreVersionLocalization": {
                     "data": {"type": "appStoreVersionLocalizations", "id": LOCALIZATION}}}}
    })
    return data["data"]["id"] if status == 201 else None


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


if __name__ == "__main__":
    set_id = reserve_set()
    print("set:", set_id)
    for path in SCREENSHOTS:
        print(f"  {path.split('/')[-1]:20}", upload(set_id, path))
