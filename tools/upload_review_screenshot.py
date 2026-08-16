#!/usr/bin/env python3
"""
Attach the App Review screenshot to every subscription and to the lifetime purchase.

Products sit in MISSING_METADATA until Apple has a screenshot showing where the purchase is
presented, and a product in that state cannot be submitted with the app. This is the only piece
the API can supply that the dashboard otherwise demands by hand.

Apple's asset upload is a three-step reservation:

    1. POST the file name and size, and get back one or more upload operations
    2. PUT the bytes to each operation's URL, at the given offset and length
    3. PATCH with an MD5 of the whole file and uploaded: true, so Apple can verify it

    python3 tools/upload_review_screenshot.py <path-to-png>
"""
import hashlib
import json
import sys
import urllib.error
import urllib.request

import asc


def upload(reservation_type, relationship, target_id, path):
    data = open(path, "rb").read()
    name = path.split("/")[-1]

    status, created = asc.call("POST", f"/v1/{reservation_type}", {
        "data": {
            "type": reservation_type,
            "attributes": {"fileName": name, "fileSize": len(data)},
            "relationships": {relationship: {"data": {"type": relationship + "s"
                                                      if not relationship.endswith("s") else relationship,
                                                      "id": target_id}}},
        }
    })
    if status != 201:
        return f"reserve failed {status}: {json.dumps(created)[:200]}"

    asset_id = created["data"]["id"]
    for operation in created["data"]["attributes"]["uploadOperations"]:
        chunk = data[operation["offset"]:operation["offset"] + operation["length"]]
        request = urllib.request.Request(operation["url"], method=operation["method"], data=chunk)
        for header in operation["requestHeaders"]:
            request.add_header(header["name"], header["value"])
        try:
            urllib.request.urlopen(request)
        except urllib.error.HTTPError as error:
            return f"upload failed {error.code}"

    status, done = asc.call("PATCH", f"/v1/{reservation_type}/{asset_id}", {
        "data": {"type": reservation_type, "id": asset_id,
                 "attributes": {"uploaded": True,
                                "sourceFileChecksum": hashlib.md5(data).hexdigest()}}
    })
    return "attached" if status == 200 else f"commit failed {status}: {json.dumps(done)[:200]}"


if __name__ == "__main__":
    screenshot = sys.argv[1]

    for name, sub_id in asc.SUBSCRIPTIONS.items():
        print(f"{name:9}", upload("subscriptionAppStoreReviewScreenshots", "subscription",
                                  sub_id, screenshot))

    print("lifetime ", upload("inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseV2",
                              asc.LIFETIME_IAP, screenshot))

    print("\nstates now:")
    for name, sub_id in asc.SUBSCRIPTIONS.items():
        _, data = asc.call("GET", f"/v1/subscriptions/{sub_id}")
        print(f"  {name:9} {data['data']['attributes']['state']}")
    _, data = asc.call("GET", f"/v2/inAppPurchases/{asc.LIFETIME_IAP}")
    print(f"  lifetime  {data['data']['attributes']['state']}")
