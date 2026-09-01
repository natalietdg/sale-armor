#!/usr/bin/env python3
"""
Create a one-week free trial on every Sale Armor subscription, in every territory.

App Store Connect stores an introductory offer as **one record per territory**, so a trial that
covers the store is 3 subscriptions x ~175 territories of writes. The shape was not guessed: it was
read off BaoBeiTalk, which already ships exactly this offer.

    duration ONE_WEEK | offerMode FREE_TRIAL | numberOfPeriods 1 | territory <id>

**Dry run is the default.** Pass --commit to write. Nothing here is destructive, but an offer is a
promise about money and 525 of them are tedious to unpick by hand.

**Do not run this while a build that cannot describe the trial is the shipping or in-review build.**
StoreKit will offer the trial the moment these records exist, and a purchase screen that does not
disclose it is a 3.1.2 rejection. Run it once the build carrying TrialOffer is the one under review.

    python3 tools/add_free_trial.py            # dry run
    python3 tools/add_free_trial.py --commit
"""
import sys
from asc import call, paged, APP_ID

DURATION = "ONE_WEEK"
MODE = "FREE_TRIAL"
PERIODS = 1


def subscriptions():
    out = []
    for group in call("GET", f"/v1/apps/{APP_ID}/subscriptionGroups?limit=10")[1].get("data", []):
        for sub in paged(f"/v1/subscriptionGroups/{group['id']}/subscriptions?limit=200"):
            out.append((sub["id"], sub["attributes"]["productId"]))
    return out


def main():
    commit = "--commit" in sys.argv
    territories = [t["id"] for t in paged("/v1/territories?limit=200")]
    subs = subscriptions()
    print(f"{len(subs)} subscriptions x {len(territories)} territories")
    print("MODE:", "COMMIT" if commit else "DRY RUN (pass --commit to write)")

    for sub_id, product in subs:
        # Existing offers are skipped rather than duplicated: re-running must be safe.
        have = {o.get("relationships", {}).get("territory", {}).get("data", {}).get("id")
                for o in paged(f"/v1/subscriptions/{sub_id}/introductoryOffers?limit=200")}
        todo = [t for t in territories if t not in have]
        print(f"\n{product}: {len(have)} already set, {len(todo)} to add")
        if not commit:
            print("  would create:", ", ".join(todo[:6]), "..." if len(todo) > 6 else "")
            continue

        ok = fail = 0
        for territory in todo:
            status, data = call("POST", "/v1/subscriptionIntroductoryOffers", {
                "data": {
                    "type": "subscriptionIntroductoryOffers",
                    "attributes": {"duration": DURATION, "offerMode": MODE,
                                   "numberOfPeriods": PERIODS},
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                        "territory": {"data": {"type": "territories", "id": territory}},
                    },
                },
            })
            if status in (200, 201):
                ok += 1
            else:
                fail += 1
                detail = (data.get("errors") or [{}])[0].get("detail", status)
                print(f"  {territory}: {detail}")
        print(f"  created {ok}, failed {fail}")

        # Read back rather than trusting the write count.
        after = len(paged(f"/v1/subscriptions/{sub_id}/introductoryOffers?limit=200"))
        print(f"  offers on {product} now: {after}")


if __name__ == "__main__":
    main()
