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
