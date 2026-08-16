#!/usr/bin/env python3
"""
Minimal App Store Connect API client.

Lives in the repo rather than a temp folder because it is the only way this project talks to App
Store Connect — creating products, setting prices, reading build state. A scratch copy was lost
once mid-task and had to be rewritten.

The ES256 token is signed by shelling out to openssl: this machine has neither pyjwt nor
cryptography, and adding either for one signature is not worth the dependency. openssl emits a
DER signature; JWT wants the raw r||s pair, so the DER is unwrapped below.

The private key is read from ~/.appstoreconnect/private_keys/ and never copied into the repo.

    python3 tools/asc.py GET /v1/apps
"""
import base64
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request

KEY_ID = "KG84U74QGJ"
ISSUER = "a6b925f4-bc55-4a31-81c6-990425706140"
KEY = f"/Users/natalieleong/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"

APP_ID = "6801819669"
SUBSCRIPTION_GROUP = "22311485"
SUBSCRIPTIONS = {"weekly": "6801840099", "monthly": "6801835527", "annual": "6801835293"}
LIFETIME_IAP = "6801842653"


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def der_to_raw(der: bytes) -> bytes:
    """DER SEQUENCE{INTEGER r, INTEGER s} -> 32-byte r || 32-byte s."""
    rlen = der[3]
    r = der[4:4 + rlen]
    slen = der[5 + rlen]
    s = der[6 + rlen:6 + rlen + slen]
    strip = lambda n: n.lstrip(b"\x00").rjust(32, b"\x00")
    return strip(r) + strip(s)


def token() -> str:
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 600,
               "aud": "appstoreconnect-v1"}
    signing_input = f"{b64(json.dumps(header).encode())}.{b64(json.dumps(payload).encode())}"
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY],
                         input=signing_input.encode(), capture_output=True, check=True).stdout
    return f"{signing_input}.{b64(der_to_raw(der))}"


def call(method, path, body=None):
    request = urllib.request.Request(
        "https://api.appstoreconnect.apple.com" + path, method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"{}")


def paged(path):
    """Every page of a collection, for endpoints that cap at 200 per request."""
    items = []
    while path:
        status, data = call("GET", path)
        if status != 200:
            return items
        items += data.get("data", [])
        nxt = data.get("links", {}).get("next")
        path = nxt.replace("https://api.appstoreconnect.apple.com", "") if nxt else None
    return items


if __name__ == "__main__":
    status, data = call(sys.argv[1], sys.argv[2],
                        json.loads(sys.argv[3]) if len(sys.argv) > 3 else None)
    print(status, json.dumps(data, indent=2))
