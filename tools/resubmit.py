#!/usr/bin/env python3
"""
Prepare the App Review submission as far as the API can take it, and stop.

Background. The 20 August submission carried the app version alone, because the four purchases
were still held by the 16 August submission that never cleared, and a product held by an open
submission reads IN_REVIEW and cannot be attached anywhere else. App Review returned 2.1(b).

The API can release the products and attach the build. It cannot attach a first-time purchase to
an app-version submission: reviewSubmissionItems accepts only appStoreVersion — every spelling of
subscription and inAppPurchaseV2 returns RELATIONSHIP.UNKNOWN — and subscriptionSubmissions
refuses a product that has never been approved ("has no pending version for submission"). The
16 August submission held six items because the dashboard put them there.

So this script never submits. An earlier version did, and sent a version-only submission to Apple
after the product items had already failed, repeating the very fault it was written to fix. The
last step belongs in the dashboard, where the products can be ticked into the submission.

    python3 tools/resubmit.py           # dry run: prints every call, changes nothing
    python3 tools/resubmit.py --go      # cancel stale submissions, attach newest build, stage draft
"""
import sys
import time

import asc

APP_VERSION = "a5ff4fa6-2495-495e-9a97-350a3a2911b8"

GO = "--go" in sys.argv


def do(method, path, body=None, label=""):
    if not GO:
        print(f"  DRY  {method} {path} {label}")
        return 0, {}
    status, data = asc.call(method, path, body)
    print(f"  {status}  {method} {path} {label}")
    if status >= 300:
        print("       ", str(data)[:300])
    return status, data


def product_states():
    """Every purchase and its state, from the two endpoints Apple splits them across."""
    states = {}
    for name, sid in asc.SUBSCRIPTIONS.items():
        _, data = asc.call("GET", f"/v1/subscriptions/{sid}")
        states[name] = data.get("data", {}).get("attributes", {}).get("state")
    _, data = asc.call("GET", f"/v2/inAppPurchases/{asc.LIFETIME_IAP}")
    states["lifetime"] = data.get("data", {}).get("attributes", {}).get("state")
    return states


def newest_build():
    """The highest build number Apple holds, so this does not go stale on the next upload."""
    builds = asc.paged(f"/v1/apps/{asc.APP_ID}/builds?limit=200")
    usable = [b for b in builds if b["attributes"]["processingState"] == "VALID"
              and not b["attributes"]["expired"]]
    newest = max(usable, key=lambda b: int(b["attributes"]["version"]))
    return newest["id"], newest["attributes"]["version"]


def open_submissions():
    """Submissions Apple still holds. Anything here pins the products."""
    _, data = asc.call("GET", f"/v1/apps/{asc.APP_ID}/reviewSubmissions?limit=20")
    return [s["id"] for s in data.get("data", [])
            if s["attributes"]["state"] in ("UNRESOLVED_ISSUES", "WAITING_FOR_REVIEW", "IN_REVIEW")]


print("products before:", product_states())

open_now = open_submissions()
print(f"\n1. cancel every submission Apple still holds: {open_now or 'none'}")
for sub in open_now:
    do("PATCH", f"/v1/reviewSubmissions/{sub}",
       {"data": {"type": "reviewSubmissions", "id": sub, "attributes": {"canceled": True}}})

if GO:
    # Cancellation releases the products asynchronously.
    for _ in range(12):
        states = product_states()
        if all(s != "IN_REVIEW" for s in states.values()):
            break
        time.sleep(10)
    print("products after cancel:", states)
    if any(s == "IN_REVIEW" for s in states.values()):
        sys.exit("still IN_REVIEW after two minutes — stop and look in the dashboard")

build_id, build_number = newest_build()
print(f"\n2. attach build {build_number} to version 1.0")
do("PATCH", f"/v1/appStoreVersions/{APP_VERSION}/relationships/build",
   {"data": {"type": "builds", "id": build_id}}, f"(build {build_number})")

print("\n3. stage an unsubmitted draft holding the version")
status, created = do("POST", "/v1/reviewSubmissions",
                     {"data": {"type": "reviewSubmissions",
                               "attributes": {"platform": "IOS"},
                               "relationships": {"app": {"data": {"type": "apps",
                                                                  "id": asc.APP_ID}}}}})
draft = created.get("data", {}).get("id") if GO else "<new>"
do("POST", "/v1/reviewSubmissionItems",
   {"data": {"type": "reviewSubmissionItems",
             "relationships": {
                 "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": draft}},
                 "appStoreVersion": {"data": {"type": "appStoreVersions",
                                              "id": APP_VERSION}}}}}, "(version 1.0)")

print(f"""
Draft {draft} is staged and NOT submitted.

Finish in the dashboard — the API cannot do this part:
  App Store Connect -> Sale Armor -> version 1.0
  -> In-App Purchases and Subscriptions -> tick Weekly, Monthly, Yearly, Lifetime
  -> Add for Review -> Submit

Confirm all four read IN_REVIEW afterwards:
  python3 tools/resubmit.py            # the dry run prints the states and changes nothing
""")
if not GO:
    print("dry run — nothing changed. Add --go to run it.")
