# Sale Armor

**Shut the shopping apps for the hours you'd regret.** Pick apps, pick when, arm it. The shield
goes up on its own and drops on its own.

Two features, and nothing else:

1. **A guard on a schedule** — once (a date range), every day, chosen weekdays, or days of the month.
2. **A wishlist** — park what you wanted, then mark it *didn't buy* or *bought it*. The top of the
   screen shows what you did not spend.

No goals, no targets, no streaks.

Formerly Pawse. Rebuilt to do one thing.

## Why patterns and not a daily limit

Impulse buying isn't an hour a day. It's **11.11, the 11pm scroll, Friday night, and payday**. A
daily screen-time budget is the wrong shape for all four, and every existing blocker ships that
shape.

You arm it while calm and it enforces the decision while you aren't.

## Why the wishlist

A blocker only ever takes things away. The wishlist is the half that gives something back: when the
shield stops a purchase, the money isn't gone — it's counted.

**Buying it anyway is recorded without judgement.** An app that punishes honesty gets lied to, and
then its total is fiction.

## How it works

| Piece | Job |
|---|---|
| `FamilyControls` | Permission, and the app picker |
| `ManagedSettings` | Raises and drops the shield |
| `DeviceActivity` | Wakes the extension at the two edges of the window |
| `SaleArmorMonitor` | The extension that does it while the app is closed |
| `SaleArmorShield` | The block screen itself, drawn in the app's own pixel art |
| `SaleArmorTests` | 20 tests over the schedule and wishlist logic |

**One pattern can need several monitored intervals**, because `DeviceActivitySchedule` carries
exactly one. Three chosen weekdays is three activities, all sharing a name prefix so they can be
cancelled together.

The hardest part is windows that cross midnight: a Friday 21:00→02:00 guard is still *Friday's*
window at 1am on Saturday. That is pinned by tests, because getting it wrong either never locks or
leaves apps shut the morning after — and there's no quick way for a user to undo the second one.

### Privacy

**The app never learns which apps you picked.** `FamilyActivityPicker` hands back opaque tokens
that only the system can resolve. That's a property worth keeping, not a limitation to work around.
Nothing leaves the device, and there is no account.

### Disarming is one tap, never confirmed twice

A blocker that makes itself hard to switch off is a blocker people delete. What this sells is a
date you set while calm, not a cage.

## ⚠️ It cannot ship without Apple's approval

`FamilyControls` requires the **Family Controls (Distribution)** entitlement, requested per bundle
ID. **You cannot reach TestFlight or the App Store until it's approved.** Development builds work
now.

Request at `developer.apple.com/contact/request/family-controls-distribution`, once for **each** of:

- `com.natalieleong.salearmor`
- `com.natalieleong.salearmor.monitor`

Approval runs from a few business days to a few weeks. After approval, enable Family Controls
(Distribution) under Additional Capabilities for each bundle ID, regenerate the distribution
profile, and rebuild.

**Draft justification for the form:**

> Sale Armor is a digital-wellbeing app for adults who overspend online. The user selects their own
> shopping apps with FamilyActivityPicker and chooses when those apps should be unavailable: a one-off
> date range such as the 11.11 sale, a nightly time window, chosen weekdays, or particular days of the
> month such as payday. DeviceActivity schedules the corresponding intervals and a DeviceActivityMonitor
> extension raises the shield through ManagedSettings when an interval starts and clears it when the
> interval ends. The app also keeps a private local list of items the user was tempted to buy, so they
> can record what they chose not to purchase.
>
> The app is self-directed: it uses `.individual` authorization, has no parent or child roles and
> no account. It never resolves the application tokens, and stores nothing about which apps were
> chosen — no Screen Time data of any kind leaves the device. The only network call it makes is
> to RevenueCat, to check whether the subscription is active.

## Build

```bash
xcodegen
xcodebuild -project SaleArmor.xcodeproj -scheme SaleArmor \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## What is verified, and what isn't

**Verified:** builds, installs, launches, renders. **20 unit tests pass** over the schedule and
wishlist logic. `FamilyControlsAgent` connects in the Simulator and registers for authorization
changes with no error. Every API used was read from the iOS 26.2 SDK interface files rather than
from memory.

**Not verified:** that authorization actually succeeds, and that a shield actually blocks an app.
**Both need a physical device with Screen Time.** The Simulator has no real Screen Time backend, so
nothing here proves the block works.

## Not done yet

- **The wishlist is local only.** No sync, no export.
- **No payday setting.** Payday exists as a day-of-month pattern, but the app cannot work out
  a last-working-day or fortnightly payday, and never offers to guard it. See `BACKLOG-payday.md`.

## The icon

Generated by `swift icon/make-icon.swift` from the **same pixel art the app draws**, so the icon and
the in-app sprite cannot drift. 1024×1024, no anti-aliasing, no rounded corners.
