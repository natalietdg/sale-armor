# Sale Armor — audit log

Append-only. Corrections are new entries referencing the earlier one, never edits.

| # | Date | Type | Actor | What | Evidence / file |
|---|---|---|---|---|---|
| 1 | 2026-08-14 | DECISION | Natalie | Rebuild Pawse as **Sale Armor**, 8-bit, app blocking over date ranges | verbal brief |
| 2 | 2026-08-14 | DECISION | Natalie | Scope = two features only: armor windows (date range / daily / weekly / monthly) + wishlist links with "$ saved". No goals. | verbal brief |
| 3 | 2026-08-14 | ACTION | Claude | Built `ArmorWindow`, `ArmorStore`, `Shield`, `ArmorSchedule`, monitor extension | `Shared/ArmorWindow.swift` |
| 4 | 2026-08-14 | ACTION | Claude | Built the 8-bit render layer: palette, brick wall, sword sprite, Bayer-dithered glow | `SaleArmor/Pixels.swift` |
| 5 | 2026-08-14 | DECISION | Natalie | Guard tab shows **sale categories**, not "what is it" — late-night scroll, payday, Black Friday, double dates, retail therapy | verbal |
| 6 | 2026-08-14 | DECISION | Natalie | Double dates are **1.1 through 12.12, every month** — not just 9.9/11.11 | corrects Claude's earlier assumption |
| 7 | 2026-08-14 | ACTION | Claude | 23 unit tests pass, covering midnight wrap and weekday attribution | `SaleArmorTests/` |
| 8 | 2026-08-15 | ACTION | Natalie | Created Apple Distribution certificate | Xcode signing pane |
| 9 | 2026-08-15 | ACTION | Natalie | Enabled Family Controls (Distribution) on both App IDs | screenshot, developer.apple.com |
| 10 | 2026-08-15 | DECISION | Claude | Diagnosed the archive failure as unregistered App IDs | **WRONG — superseded by #12** |
| 11 | 2026-08-15 | DECISION | Claude | Diagnosed it as the Family Controls capability being unticked | **WRONG — superseded by #12** |
| 12 | 2026-08-15 | ACTION | Claude | Ran `xcodebuild -showBuildSettings`; found `CODE_SIGN_IDENTITY = "iPhone Developer"` written by XcodeGen at **target** level, forcing every build to request a development profile. Supersedes #10 and #11 — the Apple account was correct throughout. | `project.yml`, pbxproj lines 305–518 |
| 13 | 2026-08-15 | ACTION | Claude | Blanked `CODE_SIGN_IDENTITY` per target, set `CODE_SIGN_STYLE: Automatic` | `project.yml` |
| 14 | 2026-08-15 | ACTION | Claude | **ARCHIVE SUCCEEDED**, exported signed `SaleArmor.ipa` (426 KB, monitor extension embedded) | `scratchpad/export/SaleArmor.ipa` |
| 15 | 2026-08-15 | ACTION | Claude | Copied archive into `~/Library/Developer/Xcode/Archives/2026-08-15/` so Organizer can upload it | filesystem |

## Open

- Upload to App Store Connect — blocked on the app record existing there. Natalie's action.
- No git remote. All commits local.

## Session continued — 2026-08-15, upload attempt

| # | Date | Type | Actor | What | Evidence / file |
|---|---|---|---|---|---|
| 16 | 2026-08-15 | ACTION | Natalie | Generated App Store Connect API key `KG84U74QGJ` | appstoreconnect.apple.com → Integrations |
| 17 | 2026-08-15 | ACTION | Claude | Moved key to `~/.appstoreconnect/private_keys/`, chmod 600 | filesystem |
| 18 | 2026-08-15 | ACTION | Claude | Wrote a minimal ASC API client; ES256 JWT signed via openssl since pyjwt/cryptography absent | `scratchpad/asc.py` |
| 19 | 2026-08-15 | ACTION | Claude | Confirmed via API: **0 app records**, and both Sale Armor bundle IDs registered (`H4WK3A9838`, `KQHGK74HYN`) — confirms entry #12, the account was never the problem | `GET /v1/apps`, `GET /v1/bundleIds` |
| 20 | 2026-08-15 | ACTION | Claude | Attempted `POST /v1/apps` → **403**, Apple does not permit app-record creation via API | API response `c29fd24d` |
| 21 | 2026-08-15 | DECISION | Claude | App record must be created by Natalie in the web UI; upload automatable after that | — |
| 22 | 2026-08-15 | ACTION | Claude | Noted `com.natalieleong.baoyitalk` is not a registered bundle ID — BaoYiTalk cannot archive yet | `GET /v1/bundleIds`, total 2 |
| 23 | 2026-08-15 | ACTION | Claude | Created explicit App Store profiles via `POST /v1/profiles` after Xcode-managed profiles proved unusable under manual signing | `SaleArmor AppStore`, `SaleArmorMonitor AppStore` |
| 24 | 2026-08-15 | ACTION | Claude | Verified `family-controls` + App Group present in both signed binaries **before** uploading | `codesign -d --entitlements` on the ipa |
| 25 | 2026-08-15 | ACTION | Claude | **Build 2 uploaded clean**, no errors or warnings | Delivery UUID `f50dfc0b-dc38-454e-905d-5beebfec9ad1` |
| 26 | 2026-08-15 | ACTION | Claude | Added `Demo` screenshot flags, compiled out of Release via `#if DEBUG`; captured 4 screenshots at 1320×2868 | `SaleArmor/ArmorController.swift`, `screenshots/` |
| 27 | 2026-08-15 | ACTION | Claude | 23 unit tests pass; Debug and Release both build | `xcodebuild test` |
| 28 | 2026-08-15 | DECISION | Natalie | Sale Armor is **entirely** paywalled — no free tier | verbal: "I WANT THE ENTIRE THING PAYWALLED" |
| 29 | 2026-08-15 | DECISION | Natalie | Use RevenueCat. Claude noted StoreKit 2 needs no account, key or revenue share; Natalie chose RevenueCat | Claude recommended, Natalie decided |
| 30 | 2026-08-15 | ACTION | Claude | Added RevenueCat SPM package, `Subscription.swift`, `PaywallView.swift`, gate above the Screen Time prompt | `SaleArmor/` |
| 31 | 2026-08-15 | ACTION | Claude | Created subscription group `22311485` and both products via ASC API | `com.natalieleong.salearmor.annual` / `.monthly` |
| 32 | 2026-08-15 | ACTION | Natalie | Pasted a RevenueCat **secret** key (`sk_`) into chat | Claude refused to store it; advised immediate rotation |
| 33 | 2026-08-15 | DECISION | Natalie | Rejected $29.99/yr as too low; chose $79.99 in the picker, then signalled higher again | supersedes the $29.99 recommendation in #31 |
| 34 | 2026-08-15 | DECISION | Claude | Set Opal-parity $99.99/yr and $19.99/mo, on verified competitor pricing. Changeable until submission | web search: Opal $99.99/yr, Freedom $39.99/yr, one sec $19.99/yr |
| 35 | 2026-08-15 | ACTION | Claude | Set worldwide availability (175 territories), prices, and localisations on both products | ASC API |
| 36 | 2026-08-15 | ACTION | Claude | Corrected own earlier figure: one sec is $19.99/yr, not $15.99 as stated in the price picker | supersedes that preview text |

## Session continued — 2026-08-16, submission prep

| # | Date | Type | Actor | What | Evidence / file |
|---|---|---|---|---|---|
| 37 | 2026-08-16 | ACTION | Claude | Rebuilt Wishlist as a cooling-off vault: 3-day wait, one question, "about to buy" not "want" | `ContentView.swift`, 5 new tests |
| 38 | 2026-08-16 | ACTION | Claude | Added local notification fired when a parked item cools; cancelled on decision | `SaleArmor/Reminders.swift` |
| 39 | 2026-08-16 | ACTION | Natalie | Supplied RevenueCat `appl_` SDK key | pasted; public by design, ships in binary |
| 40 | 2026-08-16 | ACTION | Claude | Found RevenueCat packages bound to **Test Store** placeholders; attached the four real App Store products | RevenueCat v2 API |
| 41 | 2026-08-16 | ACTION | Claude | Found app had **no territory availability at all**; set 175 | `POST /v2/appAvailabilities` |
| 42 | 2026-08-16 | ACTION | Claude | Found subscriptions priced in **USA only** while sold in 175 territories — the real cause of "must add a subscription price". Added 522 prices via price-point equalizations | `tools/price_all_territories.py` |
| 43 | 2026-08-16 | ACTION | Claude | Uploaded App Review screenshot to 3 subscriptions; 4 listing screenshots at 1320×2868 | `tools/upload_*.py` |
| 44 | 2026-08-16 | ACTION | Claude | Wrote description, promo text, keywords (91/100), support + marketing URLs | ASC API |
| 45 | 2026-08-16 | ACTION | Claude | **Build 3 uploaded and attached to version 1.0** | Delivery UUID `c812e32f` |
| 46 | 2026-08-16 | ACTION | Claude | Set age rating 4+, categories Finance/Productivity, review contact and notes | ASC API |
| 47 | 2026-08-16 | ACTION | Claude | **Deployed salearmor.pages.dev** — all four pages verified 200 | wrangler |
| 48 | 2026-08-16 | ACTION | Claude | Set copyright, content rights, privacy policy URL, subtitle, and free app price schedule | ASC API |
| 49 | 2026-08-16 | DECISION | Claude | Corrected own claim: subscription availability was never broken; the 400 was a malformed query. App-level availability was the real gap | supersedes that statement |

## Open

- **App Privacy questionnaire** — Admin-only, dashboard only. Natalie's action.
- Lifetime IAP price schedule returns 400; needs the same territory treatment as the subscriptions.
- No git remote. All commits local.
