#!/usr/bin/env python3
"""
Register the shield extension's App ID and cut its App Store provisioning profile.

WHY THIS IS A SCRIPT AND NOT A CLICK PATH
-----------------------------------------
The other two App IDs were set up by hand and nothing recorded what was enabled on them, which
meant the only way to find out was to query the API and read it back. This does the third one in
writing, so the next person (or the next extension) does not have to guess.

WHAT IT MIRRORS
---------------
The capability set already on com.natalieleong.salearmor.monitor:

    FAMILY_CONTROLS               lets a process touch ManagedSettings at all   — PORTAL ONLY
    FAMILY_CONTROLS_DISTRIBUTION  the one Apple grants separately for the Store — PORTAL ONLY
    APP_GROUPS                    the shared box the shield reads the window from

**Only the last one can be set here.** Family Controls is absent from the API's `capabilityType`
enum entirely, so the API answers a request for it with a 409 listing the 28 types it does accept.
Both have to be ticked by hand in the developer portal. This script does everything else and says
plainly which two it cannot do, because the first version of it looked like it had succeeded.

IN_APP_PURCHASE is on the monitor too, but only because Apple turns it on by default. It is not
added here — an extension that sells nothing has no business declaring it.

Xcode-managed profiles are rejected under manual signing, which is why the Release configs name
explicit profiles. This creates the one project.yml already expects: "SaleArmorShield AppStore".

    python3 tools/register_shield.py --dry-run
    python3 tools/register_shield.py
    python3 tools/register_shield.py --recreate   # after ticking the two boxes
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

BUNDLE_ID = "com.natalieleong.salearmor.shield"
BUNDLE_NAME = "Sale Armor Shield"
PROFILE_NAME = "SaleArmorShield AppStore"
CAPABILITIES = ["APP_GROUPS"]

# Family Controls is NOT in the API's capabilityType enum — Apple exposes it only in the web
# portal, so both of these have to be ticked by hand at
#   developer.apple.com/account/resources/identifiers → Sale Armor Shield
# A profile is a snapshot of the App ID at the moment it is cut, so the profile must be
# re-created AFTER they are ticked or the archive exports without the entitlement and the
# shield silently never raises. That failure mode has already cost this project one release.
PORTAL_ONLY = ["Family Controls", "Family Controls (Distribution)"]


def find_bundle_id():
    """The registered id for our identifier, or None. Idempotent re-runs depend on this."""
    _, body = asc.call("GET", "/v1/bundleIds?limit=200")
    for b in body.get("data", []):
        if b["attributes"]["identifier"] == BUNDLE_ID:
            return b["id"]
    return None


def distribution_certificate():
    """The Apple Distribution certificate the profile has to be built against."""
    _, body = asc.call("GET", "/v1/certificates?limit=200")
    for c in body.get("data", []):
        if c["attributes"]["certificateType"] in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
            return c["id"], c["attributes"].get("name", "")
    sys.exit("no Apple Distribution certificate found — create one before running this")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--recreate", action="store_true",
                        help="delete and re-cut the profile, after enabling Family Controls in the portal")
    args = parser.parse_args()

    existing = find_bundle_id()
    cert_id, cert_name = distribution_certificate()

    print(f"identifier   {BUNDLE_ID}")
    print(f"already registered  {existing or 'no'}")
    print(f"certificate  {cert_id}  {cert_name}")
    print(f"capabilities {', '.join(CAPABILITIES)}  (API)")
    print(f"by hand     {', '.join(PORTAL_ONLY)}  (web portal only)")
    print(f"profile      {PROFILE_NAME}")
    if args.dry_run:
        print("\ndry run — nothing written")
        return

    bundle = existing
    if bundle is None:
        status, body = asc.call("POST", "/v1/bundleIds", {
            "data": {"type": "bundleIds", "attributes": {
                "identifier": BUNDLE_ID, "name": BUNDLE_NAME, "platform": "IOS"}}})
        if status not in (200, 201):
            sys.exit(f"could not register the App ID: {body}")
        bundle = body["data"]["id"]
        print(f"\nregistered  {bundle}")

    # Capabilities are additive and a repeat is an error rather than a no-op, so each is reported
    # individually instead of failing the whole run on a re-run.
    _, current = asc.call("GET", f"/v1/bundleIds/{bundle}/bundleIdCapabilities")
    have = {c["attributes"]["capabilityType"] for c in current.get("data", [])}
    for capability in CAPABILITIES:
        if capability in have:
            print(f"  {capability}: already on")
            continue
        status, body = asc.call("POST", "/v1/bundleIdCapabilities", {
            "data": {"type": "bundleIdCapabilities",
                     "attributes": {"capabilityType": capability},
                     "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle}}}}})
        print(f"  {capability}: {'enabled' if status in (200, 201) else body}")

    _, profiles = asc.call("GET", "/v1/profiles?limit=200")
    for p in profiles.get("data", []):
        if p["attributes"]["name"] == PROFILE_NAME:
            if not args.recreate:
                print(f"\nprofile already exists: {p['id']} ({p['attributes']['profileState']})")
                print("a profile is a SNAPSHOT of the App ID's capabilities at the moment it was cut —")
                print("if you have just enabled Family Controls, re-run with --recreate")
                return
            asc.call("DELETE", f"/v1/profiles/{p['id']}")
            print(f"\ndeleted stale profile {p['id']}")
            break

    status, body = asc.call("POST", "/v1/profiles", {
        "data": {"type": "profiles",
                 "attributes": {"name": PROFILE_NAME, "profileType": "IOS_APP_STORE"},
                 "relationships": {
                     "bundleId": {"data": {"type": "bundleIds", "id": bundle}},
                     "certificates": {"data": [{"type": "certificates", "id": cert_id}]}}}})
    if status in (200, 201):
        print(f"\nprofile created: {body['data']['id']}")
    else:
        sys.exit(f"\ncould not create the profile: {body}")


if __name__ == "__main__":
    main()
