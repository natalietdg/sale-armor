#!/usr/bin/env python3
"""
Give every territory a price.

Setting one USD price through the API prices exactly one country. The dashboard does more than
that — picking a base country there fills in the other 174 from Apple's equivalence tables — so a
subscription priced only in USA is available in 175 territories with a price in one, and App Store
Connect refuses it with "You must add a subscription price".

Apple exposes those same tables: every price point has an `equalizations` relationship listing the
matching point in each other territory. This walks them and posts a price per territory.

    python3 tools/price_all_territories.py
"""
import asc

# The base price in each product's own currency terms, as decided: weekly is the plan meant to
# sell, and the ladder above it does the anchoring.
BASE = {"weekly": 3.99, "monthly": 9.99, "annual": 99.99}


def usa_price_point(subscription_id, target):
    path = f"/v1/subscriptions/{subscription_id}/pricePoints?filter%5Bterritory%5D=USA&limit=200"
    while path:
        status, data = asc.call("GET", path)
        if status != 200:
            return None
        for point in data["data"]:
            if abs(float(point["attributes"]["customerPrice"]) - target) < 0.001:
                return point["id"]
        nxt = data.get("links", {}).get("next")
        path = nxt.replace("https://api.appstoreconnect.apple.com", "") if nxt else None
    return None


def price_everywhere(name, subscription_id, target):
    point = usa_price_point(subscription_id, target)
    if not point:
        print(f"{name}: no USA price point for {target}")
        return

    equalizations = asc.paged(
        f"/v1/subscriptionPricePoints/{point}/equalizations?limit=200")
    print(f"{name}: {len(equalizations)} equivalent price points")

    priced = asc.paged(f"/v1/subscriptions/{subscription_id}/prices?include=territory&limit=200")
    done = len(priced)

    added = failed = 0
    for equalization in equalizations:
        status, _ = asc.call("POST", "/v1/subscriptionPrices", {
            "data": {
                "type": "subscriptionPrices",
                "attributes": {"preserveCurrentPrice": False},
                "relationships": {
                    "subscription": {"data": {"type": "subscriptions", "id": subscription_id}},
                    "subscriptionPricePoint": {
                        "data": {"type": "subscriptionPricePoints", "id": equalization["id"]}},
                },
            }
        })
        if status == 201:
            added += 1
        else:
            failed += 1

    total = asc.paged(f"/v1/subscriptions/{subscription_id}/prices?limit=200")
    print(f"{name}: started at {done}, added {added}, {failed} refused, now {len(total)}")


if __name__ == "__main__":
    for name, target in BASE.items():
        price_everywhere(name, asc.SUBSCRIPTIONS[name], target)
