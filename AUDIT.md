# Sale Armor — audit log

Append-only. Corrections go in as new entries referencing the earlier one; nothing is rewritten.

`#n | date | ACTION|DECISION | actor | what | evidence`

## 18–19 August 2026

| # | Date | Type | Actor | What | Evidence |
|---|---|---|---|---|---|
| 1 | 18 Aug | ACTION | Claude | Built `SaleArmorShield`, a ShieldConfigurationExtension. Blocked apps previously showed iOS's grey "Restricted" panel — `ShieldConfiguration` appeared nowhere in the project | `SaleArmorShield/ShieldConfig.swift` |
| 2 | 18 Aug | DECISION | Natalie | Shield screen concept — "ARMED" + the guard's name — came from her own editorial note; Claude implemented it | her message, quoted verbatim in the source |
| 3 | 18 Aug | ACTION | Claude | Moved `Pixels.swift` to `Shared/` so app and extension draw one sprite | `project.yml` sources |
| 4 | 18 Aug | ACTION | Natalie | Ticked Family Controls + Family Controls (Distribution) on the shield App ID | portal; API cannot set these |
| 5 | 18 Aug | ACTION | Claude | Registered `com.natalieleong.salearmor.shield` (`34755594CQ`), enabled App Groups, cut profile `564BR834R8` | `tools/register_shield.py` |
| 6 | 18 Aug | ACTION | Claude | Uploaded build 7 | Delivery `ee445875-…`, state VALID |
| 7 | 19 Aug | DECISION | Natalie | Sign the W-8BEN with the old Malaysian address rather than wait for Apple | see #8 |
| 8 | 19 Aug | ACTION | Claude | **Supersedes earlier advice.** Claude first said "don't sign it". IRS instructions state a change of address within/between foreign countries is not a change in circumstances; only a US address, or leaving a treaty country, is. Malaysia has no US treaty | irs.gov/instructions/iw8ben |
| 9 | 19 Aug | ACTION | Claude | Regenerated the app icon from `Pixels.swift`. Old icon predated emeralds, ruby catchlight and shading | `tools/make_icon.py` |
| 10 | 19 Aug | DECISION | Claude | Generate the icon from the sprite rather than maintain a drawn file — the two had already drifted | same |
| 11 | 19 Aug | ACTION | Claude | Built and uploaded build 8 (new icon), attached to version 1.0 | Delivery `36c31e81-…`, VALID |
| 12 | 19 Aug | ACTION | Claude | Replaced all 4 App Store screenshots. Old set showed the pre-emerald sword and contained a duplicate; paywall now fills slot 4 | verified by re-downloading from Apple |
| 13 | 19 Aug | ACTION | Claude | Added a clear step to `upload_screenshots.py` — it appended, so re-runs would have left 8 screenshots, superseded ones first | `tools/upload_screenshots.py` |
| 14 | 19 Aug | ACTION | Natalie | Removed iOS App 1.0 from review submission `b1dbd0ea`, which emptied and locked it | ASC |
| 15 | 19 Aug | ACTION | Claude | Created submission `5d1a2cc1` and added version 1.0; the old one refused new items | API 409 `STATE_ERROR.ENTITY_STATE_INVALID` |
| 16 | 19 Aug | ACTION | Natalie | Submitted `5d1a2cc1` for review | state WAITING_FOR_REVIEW, build 8 |
| 17 | 19 Aug | ACTION | Claude | Verified Family Controls + App Group entitlements inside the archive **and** the IPA, on app and both extensions | `codesign -d --entitlements` |

## Open

- **Paid Apps Agreement status unconfirmed.** Not exposed in the API. If it is not Active, StoreKit returns no products, the reviewer cannot pass the paywall, and this is a repeat 2.1.0 rejection.
- **The shield screen has never been seen rendering.** It is in builds 7 and 8. `ImageRenderer` captures a frame of a `TimelineView`; if it catches a blank one the sword is missing. Run the `SaleArmor (Demo)` scheme on a device to check.
- Xcode signing account was rejected mid-session and re-linked by Natalie.

## 19 August 2026 — the paywall investigation

| # | Date | Type | Actor | What | Evidence |
|---|---|---|---|---|---|
| 18 | 19 Aug | ACTION | Natalie | Reported "Couldn't load the prices" on TestFlight build 8 | device |
| 19 | 19 Aug | ACTION | Claude | **Wrong call, superseded by #22.** Read RevenueCat products as `(0)` and concluded misconfiguration. It was a 403 the error handler swallowed into an empty list | API `project_configuration:products:read` denied |
| 20 | 19 Aug | ACTION | Claude | **Wrong call, superseded by #22.** Read the RevenueCat UI as showing no entitlement on weekly/lifetime. The API showed all four attached; the dashboard was mid-load | `/entitlements/entl6be0ad5915/products` |
| 21 | 19 Aug | ACTION | Claude | **Wrong call, superseded by #23.** Said the Paid Apps Agreement was the only remaining cause. It was Active | Agreements page |
| 22 | 19 Aug | ACTION | Claude | Verified against source of truth, not the RevenueCat dashboard: 4 products IN_REVIEW with names, prices and review screenshots; entitlement holds all 4; offering `default` current; ASC API key and subscription key configured; bundle id correct | ASC + RevenueCat v2 APIs |
| 23 | 19 Aug | ACTION | Natalie | Found and accepted the updated **Apple Developer Program License Agreement** — an unaccepted PLA blocks submissions and StoreKit product delivery. This was the actual blocker | banner on the Business page |
| 24 | 19 Aug | ACTION | Natalie | Confirmed all 4 offering packages point at Sale Armor (App Store), Test Store empty | RevenueCat Offerings |
| 25 | 19 Aug | DECISION | Claude | Remaining failure attributed to Apple-side propagation after PLA acceptance; nothing left to change in either configuration | #22, #24 |
| 26 | 19 Aug | ACTION | Claude | Added `-unlocked` flag and `SaleArmor (Unlocked)` scheme. `-demo` fakes Screen Time approval and never raises a shield, so it could not be used to view the shield screen. Inert in Release (`#else static let isUnlocked = false`), verified by a Release compile | `ArmorController.swift`, `project.yml` |
| 27 | 19 Aug | ACTION | Claude | Installed RevenueCat's StoreKit config as `SaleArmor.storekit` | file replaced |

## Decide tomorrow

If prices still fail in TestFlight, **withdraw review submission `5d1a2cc1`** before a reviewer picks it up — a second 2.1.0 rejection on the same guideline is worse than resubmitting a day later.

**The "Open" block above is superseded.** The Paid Apps Agreement is Active (#21); the blocker was
the Program License Agreement (#23). Use `SaleArmor (Unlocked)`, not `SaleArmor (Demo)`, to view
the shield (#26). Still true: nobody has seen the shield screen render.

## 21 August 2026 — locked guards, and a promise the app had not kept

| # | Date | Type | Actor | What | Evidence |
|---|---|---|---|---|---|
| 28 | 21 Aug | DECISION | Natalie | Build LOCKED rather than a Witness. A witness needs a server storing a third party's number and guard events, which would trade away the no-account/nothing-leaves-the-phone positioning to patch the disarm hole | app has no networking beyond RevenueCat |
| 29 | 21 Aug | ACTION | Claude | **Withdrew an unverified claim.** Had said a witness could hold the Screen Time passcode to prevent override. Never checked; our ManagedSettingsStore is not governed by the system passcode. Dropped from the design | flagged by Natalie |
| 30 | 21 Aug | ACTION | Claude | Added `GuardMode.standard/.locked`, `canDisarm()`, a 72-hour cap refused before anything is written, and the mode picker, confirmation and locked notice | 48 tests |
| 31 | 21 Aug | ACTION | Claude | Caught in self-review: nothing stopped arming a new guard over a locked one — a one-tap bypass. `arm()` now refuses. The UI happened to prevent it, which is a property of one screen, not of the model | `LockedReplacementTests` |
| 32 | 21 Aug | ACTION | Claude | Caught in self-review: adding `mode` to a `Codable` struct would have made every saved window fail to decode, silently losing an armed guard on upgrade. Decodes with a default | `testWindowSavedBeforeModeExistedStillDecodes` |
| 33 | 21 Aug | ACTION | Claude | Share is now an image card rather than text, drawn from the same sprite as the shield | `ShareCardTests` writes it to /tmp for review |
| 34 | 21 Aug | ACTION | Claude | **Refused as impossible:** naming which apps were opened. iOS supplies opaque `ApplicationToken`s with no resolution path, and the privacy claim on the site rests on exactly that | ManagedSettingsUI API |
| 35 | 21 Aug | ACTION | Claude | "Standard didn't block" traced to a real gap, not a bug: every pattern scheduled for later. The website has promised "arm it now, for tonight or the next 24 hours" since launch and the app never had it. Added a NOW guard — 3 hours / tonight / 24 hours, shield raised on arming | `ImmediateGuardTests` |
| 36 | 21 Aug | ACTION | Claude | Armed-but-inactive state said "Armed / Waiting for the next window", which reads as protection. Now "Not yet / Your apps are open right now. This guard shuts them at 21:00" | ContentView |
| 37 | 21 Aug | ACTION | Claude | Builds 15-18 uploaded to TestFlight. Review remains on build 14 throughout — uploading does not attach | verified after each upload |

## Roadmap — deferred, in-app when built

| # | Date | Type | Actor | What | Evidence |
|---|---|---|---|---|---|
| 38 | 21 Aug | DECISION | Natalie | The roadmap vote belongs **in the app**, not on the landing page. Deferred — she will decide later whether to build it | — |
| 39 | 21 Aug | DECISION | Natalie | Options to vote on: spending report · website blocking · avatar · buy things for the avatar · up the stakes with a stake | — |

### Notes for whenever this is picked up

- **"Up the stakes with a stake" has an external constraint worth checking before any design work.**
  Money a user forfeits is not an in-app purchase, and App Review treats stake/forfeit mechanics as
  adjacent to gambling. It would also mean holding funds, which means a payment processor, a legal
  entity relationship and a refund policy — the opposite of the current no-account architecture.
  A non-monetary stake (a streak, a locked cosmetic, an avatar that visibly suffers) carries the
  same psychology with none of that. Worth settling before it is designed, not after.
- **Avatar and buying things for it** compose well with **Not Spent**: the money you turned down is
  already counted, and spending that number on something that is not a purchase is the joke the
  whole app is built on. No real currency needs to change hands.
- **Website blocking** is the one item that is straightforwardly buildable today — Screen Time can
  restrict web domains as well as apps, through the same authorization already granted.
- **Spending report** needs no new permissions either: the wishlist already records what was
  turned down, when, and under which guard.

## 22 August 2026 — the rejection was a submission-plumbing fault, not the app

| # | Date | Type | Actor | What | Evidence |
|---|---|---|---|---|---|
| 40 | 22 Aug | ACTION | external | App Review rejected 1.0 (14) under **Guideline 2.1(b)** — "one or more of the In-App Purchase products have not been submitted for review". Reviewed on iPad Air (5th gen) | submission `6d915c72` |
| 41 | 22 Aug | ACTION | Claude | Traced the cause via the ASC API. Submission `6d915c72` (20 Aug, rejected) carried **one item — the app version, no purchases**. The four purchases were still attached to submission `b1dbd0ea` (16 Aug), which never cleared and still sits at UNRESOLVED_ISSUES with 5 items READY_FOR_REVIEW. A product held by an open submission reads IN_REVIEW and cannot be attached to a second one | all four products IN_REVIEW; `/v1/apps/6801819669/reviewSubmissions` |
| 42 | 22 Aug | ACTION | Claude | **Ruled out the metadata reading of Apple's message.** All four App Review screenshots are attached and delivered (assetDeliveryState COMPLETE), so the missing-screenshot path in the rejection text does not apply here | `/v1/subscriptions/{id}/appStoreReviewScreenshot` ×3, `/v2/inAppPurchases/{id}/appStoreReviewScreenshot` |
| 43 | 22 Aug | ACTION | Claude | Wrote `tools/resubmit.py` — cancels both stale submissions, waits for the products to leave IN_REVIEW, attaches build 19, then creates one submission holding the version **and** all four purchases. Dry-run by default; `--go` executes. Dry run printed, nothing sent | `tools/resubmit.py` |
| 44 | 22 Aug | DECISION | Claude recommended | Submit build 19 (VALID, uploaded 20 Aug 22:12 PT) rather than 14, since Apple asked for a new binary and 19 is the build carrying the NOW guard and the locked-guard fixes (#30–#36). **Awaiting Natalie's go before anything reaches Apple** | build list from `/v1/apps/6801819669/builds` |
| 45 | 22 Aug | ACTION | Claude | Ran `resubmit.py --go`. Steps 1–3 worked: both stale submissions cancelled, **all four products released from IN_REVIEW to READY_TO_SUBMIT**, build 19 attached to version 1.0 | states read back after each call |
| 46 | 22 Aug | ACTION | Claude | **My script was wrong and it sent a bad submission.** The four product items failed 409 `RELATIONSHIP.UNKNOWN`, but step 5 submitted regardless — so `ece1f563` went to Apple carrying the app version alone, the exact fault that caused #40. Caught it in WAITING_FOR_REVIEW and cancelled before a reviewer opened it. No script guard existed between "items failed" and "submit" | `ece1f563` → CANCELING |
| 47 | 22 Aug | ACTION | Claude | **Two hypotheses tested and both wrong**, recorded rather than quietly dropped: (a) products auto-attach when a submission is created — no, item count stayed 1; (b) they attach at submit time — no, submitted `e907be7f` and the count stayed 1. Cancelled that one too | item listings before and after submit |
| 48 | 22 Aug | ACTION | Claude | Probed the relationship name against the live API: `subscription`, `subscriptions`, `subscriptionV2`, `inAppPurchase`, `inAppPurchases`, `inAppPurchaseV2` **all return RELATIONSHIP.UNKNOWN on reviewSubmissionItems**. `appStoreVersion` is accepted. `appStoreVersions` exposes no purchase relationship either. `subscriptionSubmissions` / `inAppPurchaseSubmissions` exist but refuse a first-time product: "has no pending version for submission" | five-key probe, submission `a8d6ba02` |
| 49 | 22 Aug | DECISION | Claude | **Conclusion: the public ASC API cannot attach a first-time purchase to an app-version submission.** The 16 Aug submission had 6 items because the dashboard put them there. This last step is a dashboard action, not an API one. Corrects the plan in #43, which assumed the API could do it | probes in #48 |
| 50 | 22 Aug | ACTION | Claude | Left a clean staging state: no submission with Apple, version 1.0 DEVELOPER_REJECTED with build 19 attached, four products READY_TO_SUBMIT with review screenshots delivered, and one **unsubmitted** draft `a8d6ba02` already holding version 1.0 for her to tick the products into | final state read |
| 51 | 22 Aug | ACTION | Claude | Corrected `resubmit.py` after the code-quality pass: it no longer submits at all, resolves the newest VALID build instead of a hardcoded UUID that would go stale on the next upload, and the dry run now names the submissions it would cancel rather than a placeholder | dry run output |
| 52 | 22 Aug | ACTION | Claude | Answered "why an iPad?": the app is **iPhone-only** and was reviewed on iPad in compatibility mode. `TARGETED_DEVICE_FAMILY: "1"` on every target since commit 2bb42c9 (15 Aug 20:50), which predates build 14 (20 Aug); ASC holds only `APP_IPHONE_67` screenshots, which it would not accept if the binary claimed iPad. Unrelated to the 2.1(b) rejection | project.yml:56, git log -S, appScreenshotSets |
| 53 | 22 Aug | ACTION | Claude | Noted the one archive on this machine (15 Aug 19:08, CFBundleVersion 1) **does** declare `UIDeviceFamily {1,2}` — it predates the fix commit by 100 minutes. Not the reviewed binary; build 14's own plist is not readable locally | PlistBuddy on the xcarchive |
| 54 | 22 Aug | DECISION | Natalie | **Support iPad.** Reverses the 15 Aug decision recorded in project.yml:56 ("Shielding is a phone habit, not an iPad one"). Supersedes that comment, now rewritten | project.yml |
| 55 | 22 Aug | ACTION | Claude | `TARGETED_DEVICE_FAMILY: "1,2"` on the app, both extensions and the test bundle; added `UISupportedInterfaceOrientations~ipad` with all four orientations; CFBundleVersion 19 → 20 on all three bundles. iPhone stays portrait-only — only the iPad key carries the extra three | project.yml, 8 occurrences in the regenerated pbxproj |
| 56 | 22 Aug | ACTION | Claude | Built and ran on the iPad Air 13-inch simulator. BUILD SUCCEEDED, binary declares `UIDeviceFamily {1,2}` and build 20, app launches and renders natively in portrait — not letterboxed. The paywall read "Loading…" because the simulator launch had no StoreKit config attached, so **prices are unverified on iPad** | /tmp/ipad-portrait.png |
| 57 | 22 Aug | ACTION | Claude | Flagged a new gate this creates: ASC currently holds only `APP_IPHONE_67` screenshots. An iPad-capable binary needs an iPad screenshot set before the version can be submitted | appScreenshotSets |
| 58 | 22 Aug | ACTION | Claude | Captured four iPad screenshots at 2048x2732 using the app's own `-demo` flags (`-seed`, `-wishlist`, `-paywall`). First pass produced blanks — 5s was not enough for launch, and a blank white frame is not obviously wrong at a glance; added a stddev check so a blank is caught rather than uploaded | screenshots/ipad/, PIL stddev 27–38 |
| 59 | 22 Aug | ACTION | Claude | Generalised `upload_screenshots.py` to take a device (`iphone` default, `ipad`) rather than duplicating it, and made a failed set creation raise instead of returning None | tools/upload_screenshots.py |
| 60 | 22 Aug | ACTION | Claude | **Hit a self-inflicted block:** the draft submission staged in #50 locked the version's metadata — "Can't Create Screenshot Set while Ready For Review". Unstaged the version item, uploaded, and left the draft empty. Lesson: stage the version LAST, after metadata is final | 409 STATE_ERROR, then 204 on delete |
| 61 | 22 Aug | ACTION | Claude | iPad set `APP_IPAD_PRO_3GEN_129` created, all four delivered COMPLETE. Version 1.0 now carries both an iPad and an iPhone set | appScreenshotSets |
| 62 | 22 Aug | ACTION | Claude | Archived Release build 20 from the CLI (no archive tooling existed; this was a GUI step before). Verified the archive declares build 20, `UIDeviceFamily {1,2}`, all four iPad orientations, and still carries `family-controls` — the entitlement an unsigned archive silently drops | PlistBuddy + codesign on the xcarchive |
| 63 | 22 Aug | ACTION | Claude | **`xcrun altool --validate-app`: VERIFY SUCCEEDED with no errors.** This is the authoritative answer to the multitasking question — an iPad-capable build with all four iPad orientations passes Apple's validator | altool output |
| 64 | 22 Aug | ACTION | Claude | Uploaded build 20 (delivery cb3ef86c), waited for VALID, attached it to version 1.0. Version moved DEVELOPER_REJECTED → PREPARE_FOR_SUBMISSION | altool, appStoreVersions |
| 65 | 22 Aug | DECISION | Claude | Left the version **unstaged** this time. The dashboard offers the four purchases at Submit, and staging early is what caused #60 | draft a8d6ba02 holds 0 items |
