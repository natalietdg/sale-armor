# Sale Armor — ASO rewrite proposal

**Proposal only. Nothing here has been applied to App Store Connect.**

**The headline problem: the app name is doing no search work.** `Sale Armor` uses 10 of 30 characters and neither word is a term anyone searches. Name is the **highest-weighted** field in Apple's index, and 20 characters of it are empty.

Status at time of writing: **version 1.0, build 20, WAITING_FOR_REVIEW**, submitted 22 Aug 2026 04:38 UTC. Not live.

---

## 1. Audit — what's wrong now, per field

### How Apple indexes (the model this proposal assumes)

Apple builds **one search pool** from `name` + `subtitle` + `keywords`, then composes phrases across them. A token in the name does **not** need repeating in keywords. `description` and `promotionalText` are **not** search-indexed on iOS.

> Flagged: the indexing model above is established ASO convention, not something Apple publishes or that the ASC API exposes. Treat it as a strong prior, not a verified fact. Every *current-state* fact below is read from the live API.

### `name` — "Sale Armor" (10 / 30)

| Issue | Detail |
|---|---|
| **20 characters wasted** | The single biggest miss in the listing. Highest-weight field, two-thirds empty. |
| **Zero search value** | Pool contribution is `sale` + `armor`. "Armor" is not a query. "Sale" only helps for "sale events", which is not the buying intent. |
| Brand recognition | Nil — the app isn't live. There's no equity to protect, so there's no cost to appending a descriptor. |

### `subtitle` — "Stop impulse buying" (19 / 30)

| Issue | Detail |
|---|---|
| **11 characters wasted** | Second-highest-weight field. |
| Content is good | `stop` + `impulse` + `buying` is the right head term, and it matches the site's flagship page `stop-impulse-buying.html`. **Keep these three tokens.** |
| Missing | Nothing added beyond that one phrase. 11 free characters can buy one more indexed token. |

### `keywords` — 99 / 100

Current: `blocker,shopping,app,overspending,spending,save,money,self,control,spend,payday,retail,therapy,night`

| Issue | Detail |
|---|---|
| **`app` is dead weight** | Apple's own guidance is not to use "app" or "apps" — it's redundant on the App Store. Costs **4 characters** (`app,`) and returns nothing. |
| **Morphological pile-up** | `overspending` + `spending` + `spend` are three tokens for one concept, **27 characters**. Once `spending` is in the pool, "stop spending money" already composes from `stop` + `spending` + `money`. `spend` (6 chars incl. comma) is redundant. |
| **Duplication check: clean** | No keyword duplicates a token in name or subtitle. `sale`, `armor`, `stop`, `impulse`, `buying` appear nowhere in the keyword string. This field is not currently wasting characters on duplication — but it *will* the moment the name changes, which is why §2 re-cuts it. |
| **`screen` and `time` are absent** | The app runs on Apple Screen Time. "screen time" is a high-volume, high-intent query for this exact category and it is not in the pool at all. |
| **`block` is absent** | `blocker` is present; `block` is a different token (Apple does not substring-match). "block shopping apps" is the site's #2 landing page and it can't compose today. |
| **`late` is absent** | `night` alone is there. "late night shopping" — a committed landing page — can't compose. |
| Good calls already made | Splitting `self,control` and `retail,therapy` into separate tokens is correct technique. Keep it. |

### `promotionalText` — 116 / 170

**54 characters unused.** Copy is strong but under-length, and it repeats the description's opening beat rather than adding the two objection-killers (no account, no bank connection).

Also relevant: promo text can be updated **without a new version or review** once live (Apple-documented; not verified from the API here). It's the cheapest field to iterate on, so it should not be the timid one.

### `description`

Strong — do not rewrite. **One structural fault:** a blank line sits between the 35-character hook and the payload paragraph, burning roughly a third of the pre-"more" fold on the hook alone. See §4.

### Everything else

- **`marketingUrl` / `supportUrl`** — both set, both fine.
- **Localizations** — only `en-US` exists. Adding locales is a genuine growth lever but is out of scope here and should not be touched pre-approval.

---

## 2. Proposed rewrite — exact strings

### Name (≤30)

| # | String | Chars | Pool tokens added |
|---|---|---|---|
| **A ✅** | `Sale Armor: Shopping Blocker` | **28** | sale, armor, **shopping, blocker** |
| B | `Sale Armor: Stop Overspending` | 29 | sale, armor, stop, overspending |
| C | `Sale Armor - Block Shopping` | 27 | sale, armor, block, shopping |

**Recommend A.**

- `shopping` + `blocker` are the two highest-value **nouns** in this category and they compose the exact head query **"shopping blocker"** in the top-weighted field.
- Moving them out of `keywords` frees **17 characters** (`shopping,` = 9, `blocker,` = 8) to spend on tokens that have no other home.
- **B is worse**: it puts a verb phrase in the name and forces `shopping` + `blocker` back into keywords (17 chars) to free `overspending,` (13). Net loss of 4 characters *and* the weaker field placement.
- **C is worse than A**: `block` is a cheap 6-char keyword; `blocker` in the name is not, and C spends the name slot to save 6 characters.

### Subtitle (≤30)

| # | String | Chars | Pool tokens added |
|---|---|---|---|
| **A ✅** | `Stop impulse buying & spending` | **30** | stop, impulse, buying, **spending** |
| B | `Stop impulse buying on payday` | 29 | stop, impulse, buying, payday |
| C | `Screen Time for overspending` | 28 | screen, time, overspending |

**Recommend A.** Uses all 30 characters, keeps the flagship phrase intact, and adds `spending` — which composes "stop spending money", "spending blocker" and "stop overspending" (with `overspending` in keywords).

- **B** frees only `payday,` (7 chars) and drops `spending`. Worse trade.
- **C** frees 25 characters — the best raw trade — but **destroys "stop impulse buying"**, the app's single strongest exact-match query and the site's flagship page. Reject.

### Keywords (≤100)

```
screen,time,block,overspending,money,save,payday,retail,therapy,night,self,control,budget,limit,late
```

**100 / 100 — exactly full.**

Changes from current:
- **Removed:** `shopping`, `blocker` (now in name), `app` (dead), `spending` (now in subtitle), `spend` (redundant with `spending` + `overspending`).
- **Added:** `screen`, `time`, `block`, `budget`, `limit`, `late`.
- **Kept:** `overspending`, `money`, `save`, `payday`, `retail`, `therapy`, `night`, `self`, `control`.

### Promotional text (≤170)

```
Payday. 2am. 11.11. Black Friday. Sale Armor shuts your shopping apps in those exact windows, holds what you still want for three days, and totals what you didn't spend.
```

**169 / 170.** Adds Black Friday (the highest-recognition trigger), makes the 3-day hold explicit, and lands the "Not Spent" payoff — where the current version only gestures at it.

Alternate, if the objection-killers matter more than the trigger list (160 chars):

```
Payday. 2am. 11.11. Sale Armor shuts your shopping apps in those exact windows and holds anything you still want for three days. No account, no bank connection.
```

---

## 3. Keyword pool table

Full deduplicated token set the proposal indexes for, and which field carries each.

| Token | Carried by | Why it's in the pool |
|---|---|---|
| sale | name | brand; also "sale events" |
| armor | name | brand |
| **shopping** | **name** | category head noun |
| **blocker** | **name** | category head noun; "shopping blocker" |
| stop | subtitle | verb head for every intent query |
| impulse | subtitle | `stop-impulse-buying` — flagship page |
| buying | subtitle | "stop buying clothes" |
| **spending** | **subtitle** | "stop spending money", "spending blocker" |
| screen | keywords | Apple Screen Time — high volume, currently absent |
| time | keywords | pairs into "screen time" |
| block | keywords | `block-shopping-apps` page; distinct token from `blocker` |
| overspending | keywords | `payday-overspending` page |
| money | keywords | "save money", "stop spending money" |
| save | keywords | "save money" |
| payday | keywords | `payday-overspending` page |
| retail | keywords | `retail-therapy` page |
| therapy | keywords | pairs into "retail therapy" |
| night | keywords | `late-night-shopping` page |
| late | keywords | pairs into "late night" |
| self | keywords | "self control" |
| control | keywords | "self control app" cohort |
| budget | keywords | `vs-budget-apps` page — capture the comparison shopper |
| limit | keywords | "screen time limit", "spending limit" |

**Head queries this pool composes:** shopping blocker · stop impulse buying · stop shopping · stop overspending · stop spending money · save money · screen time limit · block shopping · retail therapy · late night shopping · payday budget · self control · impulse buying blocker

**Knowingly not covered** (and why): `apps` plural — Apple advises against it and it would cost 5 of 100. `no buy year`, `mindful`, `buy now pay later`, `wishlist` — either too low-volume for a 100-char budget, or wrong intent (a "buy now pay later" searcher wants a BNPL app, not a blocker). All four keep their landing pages for organic web search, where the character budget is unlimited.

---

## 4. Description tweaks — surgical only

**The description is strong. It is also not search-indexed, so nothing below is keyword-driven — these are conversion edits only.**

### The fold (this is the change that matters)

Roughly the first three lines show before "more". Today, line 1 is a 35-character hook followed by a **blank line**, so the fold spends about a third of itself on white space and the reader may never see the mechanism.

**Current:**
```
You already know when you overspend.

Payday. Two in the morning. 11.11. Black Friday. Sale Armor shuts your shopping apps during those exact windows, then holds whatever you were about to buy until the urge has passed.
```

**Proposed — one paragraph, blank line removed, "during" → "in":**
```
You already know when you overspend. Payday. Two in the morning. 11.11. Black Friday. Sale Armor shuts your shopping apps in those exact windows, then holds whatever you were about to buy until the urge has passed.
```

That change alone puts **hook + trigger list + the blocking mechanism** all above the fold. Nothing else in the paragraph moves.

### Two smaller edits

1. **`NOT A BUDGETING APP`** — this is the sharpest differentiator in the whole listing and it currently sits below three other sections. Consider moving it **directly under the fold paragraph**, above `HOW IT WORKS`. A reader deciding between this and YNAB resolves it in one line instead of scrolling. *Optional — it changes section order, which is a bigger diff than the fold fix.*

2. **`HOW IT WORKS` step 2** currently reads "Choose your shopping apps through Apple's own Screen Time picker." Consider naming Screen Time one beat earlier so it appears in the first screenful of the expanded description — it is the credibility anchor for "how can an app block another app".

**Do not touch:** the subscription block, the price lines (verified correct against ASC — weekly $3.99, monthly $9.99, annual $99.99, lifetime $299.99, USA), the renewal-terms paragraph, or the two policy URLs. All are compliance-load-bearing.

---

## 5. Risk — read this before applying anything

**The two field groups live on different resources and carry different, unequal risk.**

### Group 1 — `keywords`, `promotionalText`, `description` → **appStoreVersionLocalizations**

**Proven safe to PATCH while WAITING_FOR_REVIEW.**

- Resource id: `5692efd7-5d27-495e-b48e-ede174ea0ec7` (on version `a5ff4fa6-2495-495e-9a97-350a3a2911b8`)
- Evidence: **AUDIT.md entry #76, 22 Aug** — description and review-notes edits were PATCHed during WAITING_FOR_REVIEW; submission, version and all four products stayed WAITING_FOR_REVIEW, `submittedDate` unchanged at 04:38.
- Caveat: #76 covers `description` and review notes specifically. `keywords` and `promotionalText` are sibling attributes on the **same resource and same PATCH endpoint**, so the same mechanism applies — but they were not individually exercised on 22 Aug. Read the version state back immediately after each PATCH, as #76 did.

### Group 2 — `name`, `subtitle` → **appInfoLocalizations**

**UNVERIFIED. Do not assume either way.**

- Verified now, from the live API: appInfo `8786341f-c8a6-49c4-871e-35b9efa6e06b` is in **`state: WAITING_FOR_REVIEW`** (`appStoreState` likewise). Its en-US localization is `9ea16f5f-a994-48de-a689-c82ff58eedb9`, currently `name: "Sale Armor"`, `subtitle: "Stop impulse buying"`.
- **Whether ASC accepts a PATCH to appInfoLocalizations in that state is unverified.** No entry in AUDIT.md covers it. Apple treats `name` and `subtitle` as review-gated metadata distinct from version localizations, so #76 does **not** transfer.
- Two plausible outcomes, neither established: the PATCH is rejected with a 409/403 (harmless — nothing changes), **or** it is accepted and mutates the listing under review. The second is the one that could draw a metadata-mismatch look from the reviewer, or worse, disturb the submission.
- **This is the highest-value change in the whole proposal and the only one with unquantified downside.** That combination is exactly why it should not be done on a guess.

**The exact check that settles it — read-only, run this first:**

```bash
cd ~/sale-armor && python3 tools/asc.py GET \
  "/v1/appInfoLocalizations/9ea16f5f-a994-48de-a689-c82ff58eedb9"
```

That confirms the resource is readable and gives the current ETag/state. It does **not** answer whether a PATCH is accepted. The only thing that answers that is either:

- **(a) The dashboard.** Open App Store Connect → Sale Armor → App Information. If the Name and Subtitle fields render **editable** while the app is in review, PATCH is permitted. If they render **locked/greyed**, it is not. Zero risk, and it is the answer. **Do this one.**
- **(b) A no-op PATCH** sending the *identical* current values (`name: "Sale Armor"`, `subtitle: "Stop impulse buying"`). A 200 proves writes are accepted; a 409/403 proves they aren't; and either way the stored values are unchanged. Riskier than (a) — it still touches the resource under review — so only use it if the dashboard is ambiguous.

### Non-risk, worth stating

- No change proposed here alters the binary, the IAPs, the prices, the URLs, or the review notes.
- Nothing proposed here needs a new build.
- If v1.0 is **rejected**, all of this becomes free to apply — a rejected version returns to PREPARE_FOR_SUBMISSION where every field is editable.

---

## 6. Apply order

### Now — while WAITING_FOR_REVIEW

| # | Change | Field | Risk |
|---|---|---|---|
| 1 | Description fold fix (§4) | `description` | Proven safe (#76) |
| 2 | New promotional text (§2) | `promotionalText` | Same resource as #76 |
| 3 | New keyword string (§2) | `keywords` | Same resource as #76 |

Do these as **three separate PATCHes**, and after each one read the version + submission state back and confirm `submittedDate` is still `2026-08-22T04:38`. That is the #76 discipline; it is what makes the claim safe rather than assumed.

**Caveat on #3:** the proposed keyword string assumes the name changes to `Sale Armor: Shopping Blocker`. If the name **cannot** change (see below), the keyword string must keep `shopping` and `blocker` and give up two of `budget` / `limit` / `late` / `block` to pay for them. Sequence this **after** the name question is settled, or apply an interim string that keeps `shopping,blocker`.

### Gate — before touching name or subtitle

Run the dashboard check in §5(a). Report the result.

### After the gate

- **If Name/Subtitle are editable in review:** apply the name and subtitle from §2, then re-apply the final keyword string. Verify the submission state after each.
- **If they are locked:** hold both until v1.0 is **approved**, then submit them with the 1.0.1 metadata update. They will go through a metadata review, which is fast, and they do not need a new binary.

### Later — not now

- Additional locales beyond `en-US`.
- The optional `NOT A BUDGETING APP` section reorder (§4.1) — bundle it with the next description change rather than spending a separate PATCH on it.

---

## Sources for every current-state claim in this document

| Claim | Read from |
|---|---|
| description, keywords, promotionalText, marketingUrl, supportUrl, only `en-US` | `GET /v1/appStoreVersions/a5ff4fa6-.../appStoreVersionLocalizations`, live |
| appInfo state = WAITING_FOR_REVIEW; appInfoLocalization id, name, subtitle | `GET /v1/apps/6801819669/appInfos` and `.../appInfoLocalizations`, live |
| #76 metadata-edit safety, submittedDate 04:38 | `/Users/natalieleong/sale-armor/AUDIT.md`, entries #71 and #76 |
| Landing-page vocabulary and positioning | `/Users/natalieleong/landing/salearmor/*.html` — `<title>`, `<h1>`, `<meta description>` of all 16 SEO pages plus `index.html` |
| All character counts | counted programmatically, not estimated |
