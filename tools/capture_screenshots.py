#!/usr/bin/env python3
"""
Capture the App Store listing screenshots from a simulator.

The companion to `upload_screenshots.py`, and deliberately shaped like it: one set per device
family, the same four filenames in the same order, the device chosen on the command line.

    python3 tools/capture_screenshots.py              # iPhone
    python3 tools/capture_screenshots.py ipad

Every shot is a cold launch of the real binary under the flags in `enum Demo`, so the listing
cannot drift from the app the way it did in August 2026 — the shipped iPhone set was still showing
a five-segment schedule picker the binary no longer had, which is a Guideline 2.3.3 rejection.

Two things go wrong when this is done by hand, and both are measured here rather than trusted:

  * **A blank frame.** The app takes longer to draw than any fixed sleep, and a flat rectangle at
    2048x2732 does not look wrong at a glance — one was nearly uploaded on 22 Aug. Readiness is
    therefore measured: the frame is re-captured until its pixel standard deviation clears
    `MIN_STDDEV` *and* it is dark enough to be this app, and a shot that never does raises instead
    of being written.
  * **The wrong size.** Apple rejects anything but the exact pixel size for the display type, so
    the frame is brought to it here and asserted afterwards.

What it cannot check is whether the pixels say the right thing. Open the written files and look —
in particular at the guard and armed screens, where the padlock and play marks live.

Build first; this script only installs what is already built:

    xcodebuild -project SaleArmor.xcodeproj -scheme SaleArmor -configuration Debug \\
               -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
"""
import json
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageStat

REPO = Path(__file__).resolve().parent.parent
BUNDLE_ID = "com.natalieleong.salearmor"

# Simulators whose native frame is at or above the target, so every resize is a downscale. The app
# is pixel art end to end and an upscale would soften every edge in it.
DEVICES = {
    "iphone": ("iPhone 17 Pro Max", (1320, 2868), "screenshots"),
    "ipad": ("iPad Pro 13-inch (M5)", (2048, 2732), "screenshots/ipad"),
}

# Which launch flags land on which screen, read off `enum Demo` in ArmorController.swift. `-demo`
# alone gives the unarmed guard form: it stubs Screen Time to approved and opens as a subscriber,
# but seeds no window, so ContentView falls through to `ArmView`.
SHOTS = [
    ("01-guard.png", ["-demo"]),
    ("02-armed.png", ["-demo", "-seed"]),
    ("03-wishlist.png", ["-demo", "-seed", "-wishlist"]),
    ("04-paywall.png", ["-demo", "-paywall"]),
]

# A drawn frame measured 27–38 on the August 2026 pass; a black launch screen measures under 1.
# The threshold sits well below the drawn range so a legitimately flat screen still passes, and
# well above blank so a blank never does.
MIN_STDDEV = 5.0

# **Standard deviation alone does not catch a WHITE blank.** The first launch after an install
# shows a white surface, and against the black status bar and home indicator that frame measures a
# stddev of 27.8 — inside the drawn range, so it sailed through the guard and wrote a blank
# 01-guard.png on 26 Aug. Brightness catches what spread cannot: every real screen in this app is
# brick-dark and measured a mean of 25–50 across both device sets, the white surface measures 252.
MAX_MEAN = 120.0

# Long enough for the slowest cold launch on a cold simulator, and for the frame to stop moving
# once something is on it. The app fades its brick background in, so the first non-blank frame is
# not yet the final one.
DRAW_TIMEOUT = 60
SETTLE = 3


def simctl(*arguments):
    return subprocess.run(["xcrun", "simctl", *arguments],
                          check=True, capture_output=True, text=True).stdout


def udid_for(name):
    devices = json.loads(simctl("list", "devices", "available", "-j"))["devices"]
    for runtime in devices.values():
        for device in runtime:
            if device["name"] == name:
                return device["udid"]
    raise SystemExit(f"no available simulator named {name!r} — check `xcrun simctl list devices available`")


def built_app():
    """
    Where xcodebuild put the .app.

    Asked of xcodebuild rather than guessed from a DerivedData glob: the repo has leftover
    directories from earlier builds that used an explicit -derivedDataPath, and picking the wrong
    one silently captures stale UI, which is the exact failure this script exists to prevent.
    """
    settings = subprocess.run(
        ["xcodebuild", "-project", str(REPO / "SaleArmor.xcodeproj"), "-scheme", "SaleArmor",
         "-configuration", "Debug", "-sdk", "iphonesimulator", "-showBuildSettings", "-json"],
        check=True, capture_output=True, text=True).stdout
    # -showBuildSettings prints one block per target; the app is the one named SaleArmor.
    for block in json.loads(settings[settings.index("["):]):
        if block["target"] == "SaleArmor":
            path = Path(block["buildSettings"]["BUILT_PRODUCTS_DIR"]) / "SaleArmor.app"
            if not path.exists():
                raise SystemExit(f"{path} does not exist — build before capturing")
            return path
    raise SystemExit("no SaleArmor target in the build settings")


def measure(image):
    """Greyscale spread and brightness. Together they say whether the app drew its own screen."""
    statistics = ImageStat.Stat(image.convert("L"))
    return statistics.stddev[0], statistics.mean[0]


def is_drawn(deviation, mean):
    return deviation >= MIN_STDDEV and mean <= MAX_MEAN


def why_not_drawn(deviation, mean):
    return f"stddev {deviation:.2f} (needed {MIN_STDDEV}), mean {mean:.2f} (needed at most {MAX_MEAN})"


def capture_drawn(udid, scratch):
    """Screenshot the simulator repeatedly until the app has actually drawn something."""
    deadline = time.time() + DRAW_TIMEOUT
    last = (0.0, 0.0)
    while time.time() < deadline:
        simctl("io", udid, "screenshot", "--type=png", str(scratch))
        image = Image.open(scratch)
        image.load()
        last = measure(image)
        if is_drawn(*last):
            # Re-read after the settle: the first drawn frame is mid-fade, not the final one.
            time.sleep(SETTLE)
            simctl("io", udid, "screenshot", "--type=png", str(scratch))
            settled = Image.open(scratch)
            settled.load()
            last = measure(settled)
            if is_drawn(*last):
                return settled
        time.sleep(1)
    raise SystemExit(f"nothing drew within {DRAW_TIMEOUT}s — last {why_not_drawn(*last)}")


def fit(image, target):
    """
    Bring a native simulator frame to Apple's exact pixel size.

    Scaled to cover and then centre-cropped rather than stretched: the iPad Pro 13-inch frame is
    2064x2752 against a 2048x2732 target, which is not quite the same aspect ratio, and pulling
    pixel art off its own grid shows. Cropping gives up a pixel of margin instead.
    """
    if image.size == target:
        return image, "native, no resize"
    if image.width < target[0] or image.height < target[1]:
        raise SystemExit(f"{image.size} is below {target}; choose a larger simulator, never upscale")

    scale = max(target[0] / image.width, target[1] / image.height)
    covered = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left, top = (covered.width - target[0]) // 2, (covered.height - target[1]) // 2
    return (covered.crop((left, top, left + target[0], top + target[1])),
            f"{image.width}x{image.height} downscaled and centre-cropped")


def main(device):
    name, target, folder = DEVICES[device]
    udid = udid_for(name)
    app = built_app()

    print(f"{device}: {name} ({udid})")
    # Booting an already-booted device is an error, not a no-op, so the result is ignored and
    # bootstatus is what decides the device is ready.
    subprocess.run(["xcrun", "simctl", "boot", udid], capture_output=True)
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, capture_output=True)
    # Asked again after bootstatus, because a device booted with nothing holding it open shuts
    # straight back down and the next command fails as an opaque exit 204.
    if "(Booted)" not in simctl("list", "devices", udid):
        raise SystemExit(f"{name} would not stay booted — open Simulator.app and try again")
    simctl("install", udid, str(app))

    scratch = REPO / "screenshots" / ".capture.png"
    destination = REPO / folder
    destination.mkdir(parents=True, exist_ok=True)
    try:
        for filename, flags in SHOTS:
            # Cold launch every time: the flags are read once, in `ArmorController.init`, so a
            # still-running process would keep the previous shot's state.
            subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], capture_output=True)
            simctl("launch", udid, BUNDLE_ID, *flags)

            image = capture_drawn(udid, scratch)
            image, how = fit(image, target)
            deviation, mean = measure(image)
            if image.size != target:
                raise SystemExit(f"{filename} came out {image.size}, not {target}")
            if not is_drawn(deviation, mean):
                raise SystemExit(f"{filename} is blank after resizing — {why_not_drawn(deviation, mean)}")

            image.save(destination / filename)
            print(f"  {filename:15} {image.width}x{image.height}  "
                  f"stddev {deviation:5.2f}  mean {mean:5.2f}  {how}")
    finally:
        scratch.unlink(missing_ok=True)

    print("Now open the four files and look at them — a correct size and a live stddev still say "
          "nothing about whether the right screen was captured.")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "iphone")
