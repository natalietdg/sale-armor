# Sale Armor — RevenueCat growth and paid acquisition

**Do Track A. It is free, needs zero code, and the app is already wired for it.** Hold Track B until there is a measured organic conversion rate to buy against — and until the two privacy claims are rewritten, because attribution breaks both.

Written 24 Aug 2026. App status: **v1.0 build 20 waiting for review**, submitted 22 Aug. Zero users, zero revenue, no historical data. Every RevenueCat behaviour below is cited; the source list is at the bottom.

---

## 1. What's already true

| Piece | State today | Where |
|---|---|---|
| RevenueCat SDK | `purchases-ios` from 5.0.0, **main app target only** — not the two extensions | `project.yml:41-43` |
| API key | Public SDK key in `REVENUECAT_API_KEY`, injected as Info.plist `RevenueCatAPIKey` | `project.yml:17` |
| Entitlement | One, lookup key `"Sale Armor Pro"` | `SaleArmor/Subscription.swift:35` |
| Offering fetch | **`offerings.current`, not a hardcoded identifier** | `Subscription.swift:112` |
| Products | weekly $3.99 · monthly $9.99 · annual $99.99 · lifetime $299.99 (USA), 175 territories | ASC; `SaleArmor.storekit` |
| Intro offer / free trial | **None.** `adHocOffers`, `codeOffers`, `winbackOffers` all empty, no `introductoryOffer` key, no trial copy in the paywall | `SaleArmor.storekit`; `PaywallView.swift` |
| Paywall | Custom SwiftUI, **not** a RevenueCat-hosted Paywall. Weekly pre-selected and badged POPULAR | `PaywallView.swift:229` |
| Plan order | Cheapest-first, enforced in code rather than inherited from the offering | `Subscription.swift:118` |
| Privacy manifest | `NSPrivacyTracking false`, no tracking domains, Purchase History declared **App Functionality only** | `SaleArmor/PrivacyInfo.xcprivacy` |
| RevenueCat plan | Pro, free below **$2,500 monthly tracked revenue**, then 1% | [pricing](https://www.revenuecat.com/pricing) |

**The load-bearing line is `offerings.current`.** Because the app asks for the current offering instead of naming one, Experiments and Targeting work on it **with no app update at all**: *"If you meet these requirements, you can start using Experiments without any app changes!"* and *"Everything is done server-side"* ([experiments overview](https://www.revenuecat.com/docs/tools/experiments-v1/experiments-overview-v1)). That was worth getting right and it was got right.

---

## 2. Track A — no-tracking growth (do this first)

Nothing here needs an SDK, an ATT prompt, or a metadata change. All of it is included on the Pro plan, which costs nothing below $2,500 MTR ([pricing](https://www.revenuecat.com/pricing)).

### 2.1 Charts — already on, nothing to set up

RevenueCat charts are generated from purchase data on their servers, independent of any client-side event logging, and are *"available to all users signed up after September '23"* ([charts](https://www.revenuecat.com/docs/dashboard-and-metrics/charts)). Two things to know:

- **Charts show production data only.** TestFlight and sandbox purchases will not appear. Do not panic on day one.
- Segmentation you get for free: **Product, Product Duration, Offering, Country, Offer Type, First Purchase Month, Targeting Rules** ([charts](https://www.revenuecat.com/docs/dashboard-and-metrics/charts)).

**The four numbers that matter in month one:** Initial Conversion, Realized LTV per Customer, Churn Rate, and the product mix (which of the four plans people actually buy).

### 2.2 The one chart the custom paywall costs you

**Paywall Conversion and Paywall Abandonment will be empty.** Both docs say so outright — impressions and conversions from *"paywalls implemented with custom code are not tracked in this chart"* ([conversion](https://www.revenuecat.com/docs/dashboard-and-metrics/charts/paywall-conversion-chart), [abandonment](https://www.revenuecat.com/docs/dashboard-and-metrics/charts/paywall-abandonment-chart)).

**This costs Sale Armor much less than it costs most apps**, and that is a property of the product, not luck. The app is 100% gated: the paywall sits above everything, so **every install is a paywall impression**. App Store Connect already gives you the install count. Installs → purchases *is* the paywall funnel here.

What you genuinely lose: **bounce vs. purchase-cancellation split**, and time-to-convert within the 3-day window. Nice to have. Not worth a rewrite.

### 2.3 Should you move to RevenueCat Paywalls? — **No, not now**

RevenueCat Paywalls let you *"remotely configure your entire paywall view without any code changes or app updates"*, need the **RevenueCatUI** package, **purchases-ios 5.27.1+** and iOS 15+ ([paywalls](https://www.revenuecat.com/docs/tools/paywalls)).

**Reasons to say no here:**

- **Experiments do not require them.** Price and product-mix tests run off Offerings. Confirmed above.
- **The paywall is the product's face** — pixel font, sword sprite, the filled-square selector, the honest per-day unit price computed from the real store price. A template does not reproduce that, and the visual identity is doing real conversion work on a niche self-control app.
- The renewal-terms sentence in `PaywallView.renewalTerms` switches correctly for lifetime vs. subscriptions. That is App Review compliance you have already passed once. Re-earning it on a template is risk with no revenue attached.

**Reason to revisit later:** remote copy iteration without a build. If you find yourself shipping a version purely to change a headline, that is the signal. Not before.

### 2.4 First price experiment — the lifetime gap

**Test: lifetime at $299.99 vs. $149.99. Judge it on revenue per install, not conversion rate.**

Why this one:

| Plan | Price | Annualised | Note |
|---|---|---|---|
| Weekly | $3.99 | **$207.48/yr** | Pre-selected, badged POPULAR |
| Monthly | $9.99 | $119.88/yr | The dead option — 42% *more* than annual |
| Annual | $99.99 | $99.99/yr | Badged BEST VALUE |
| Lifetime | $299.99 | — | **3.0× annual — pays back at year three** |

**$299.99 is priced for someone who is certain.** A person buying a shopping blocker is, by construction, someone who does not trust their own future decisions — three years of certainty is a hard ask from that person on day one. At $149.99 lifetime is **1.5× annual**, which is the ratio most subscription apps land on, and it converts a segment that would otherwise buy nothing rather than a segment that would have bought annual.

**Set it up like this:**
1. Create a second Offering with the same four packages, lifetime swapped to a $149.99 product ([creating offerings to test](https://www.revenuecat.com/docs/tools/experiments-v1/creating-offerings-to-test)).
2. Run it as control vs. treatment. **No app release needed** — the app reads `current`.
3. **Primary metric: realized revenue per new customer.** Conversion rate alone will mislead you, because cheaper lifetime cannibalises annual and total conversion can rise while revenue falls.

**One variable only.** Do not also move weekly in the same experiment; you will not know which change did it.

**Second experiment, later: drop monthly entirely.** At $9.99 it is dominated by annual on every axis and is probably just choice-paralysis tax. Four options on a gated first screen is a lot.

### 2.5 How much data before an experiment means anything

RevenueCat reports **Chance to Win** (*"the probability that a treatment variant is performing better than the control"*) and a **95% credible interval**, and notes that many developers treat 95% Chance to Win as enough *"but the right threshold depends on what you're testing and your risk tolerance"*. Results appear in real time for new-customer-only experiments, within 24 hours otherwise ([results](https://www.revenuecat.com/docs/tools/experiments-v1/experiments-results-v1)).

**RevenueCat publishes no minimum sample size.** So here is the arithmetic — *this is my calculation, not a RevenueCat claim*. Standard two-proportion sizing at 80% power / 95% confidence, assuming a 3% install→paid rate:

| Effect you want to detect | Installs **per arm** | Total installs |
|---|---|---|
| 50% relative lift (3.0% → 4.5%) | ~2,100 | **~4,200** |
| 20% relative lift (3.0% → 3.6%) | ~12,900 | **~25,800** |

**Revenue-per-install needs more than that**, because a $299.99 purchase makes the variance enormous next to a $3.99 one.

**The honest read: an A/B test is not a launch-week tool.** Below roughly **2,000 installs per arm** you are reading noise, and Chance to Win will happily show you 70% on nothing. Until then, price changes are a judgement call made once, not an experiment.

### 2.6 Targeting — useful before experiments are

**Targeting works on custom paywalls too**, on the same current-offering mechanism, and can key on **Country, App Version, Platform, custom attributes, SDK version**. It is *"available on Pro and Enterprise plans"* ([targeting](https://www.revenuecat.com/docs/tools/targeting)).

**Use it for the 175 territories.** $99.99/yr is a different proposition in Malaysia than in the US. Country-tiered offerings are a bigger revenue lever than any A/B test at this stage, and you do not need statistical significance to know that $299.99 lifetime is mispriced outside high-income markets.

### 2.7 Customer Center — later, and it has a privacy cost

A self-service UI for *"cancel active subscriptions"*, refund requests (iOS only), restore, and **automatic win-back promo offers**; Pro and Enterprise ([customer center](https://www.revenuecat.com/docs/tools/customer-center)).

**Worth it once there are subscribers to save.** Note it adds an in-app surface that talks to RevenueCat's servers — same category of claim-conflict as §4, just smaller. Not a day-one item.

### 2.8 The free-trial question

There is **no intro offer configured anywhere** — verified in `SaleArmor.storekit` (empty `adHocOffers`, `codeOffers`, `winbackOffers`, no `introductoryOffer`) and in `PaywallView.swift`, which has no trial copy.

**That is a defensible choice and I would not rush to change it.** A blocker that can be trialled free for a week is a blocker people install on 11.11 and abandon on 11.12. But it is the **single largest untested lever** on this app, far larger than the lifetime price, and RevenueCat's charts carry Trial Conversion metrics ready for it.

**If you ever test it, test it as an experiment, not as a decision.** And note it needs an App Store Connect product change plus a build — unlike the price tests above.

---

## 3. Track B — attribution wiring (GATED on Natalie's explicit go)

### What RevenueCat actually is here

**RevenueCat is not an ad network and does not do attribution.** Verbatim: *"RevenueCat isn't an attribution network. RevenueCat doesn't decide which campaign or ad caused an install; attribution context must come from your attribution provider."* What it does is **forward subscriber lifecycle events server-to-server**: *"RevenueCat sends subscription lifecycle and revenue events to the provider from our servers, including renewals that happen after the customer stops opening your app"* ([attribution](https://www.revenuecat.com/docs/integrations/attribution)).

**That last clause is the whole point.** An ad network optimising on installs buys you installs. Fed renewal events, it optimises on **revenue that arrives months after the app was last opened**. 12 providers are supported: Adjust, Airbridge, Apple Search Ads, AppsFlyer, Appstack, Asapty, Branch, Meta Ads, Kochava, SplitMetrics Acquire, Tenjin, Singular.

**Plan gate:** *"Attribution collection is only available to all users signed up after September '23, the legacy Pro plan, and Enterprise plans"* ([attribution](https://www.revenuecat.com/docs/integrations/attribution)).

### Ascending order of privacy cost

#### Option B1 — Apple Search Ads via AdServices · **lowest cost, no ATT prompt**

| | |
|---|---|
| **Framework** | Apple's **AdServices**. Not SKAdNetwork, not iAd, not AdAttributionKit |
| **Code** | One line after `Purchases.configure`: `Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()` ([apple search ads](https://www.revenuecat.com/docs/integrations/attribution/apple-search-ads)) |
| **ATT prompt** | **Not required for standard attribution.** *"Unlike iAd, AdServices doesn't require the user to opt-in to the App Tracking Transparency prompt"* ([RevenueCat, iAd vs AdServices](https://www.revenuecat.com/blog/engineering/iad-vs-adservices-whats-the-difference)) |
| **What ATT would add** | Only `clickDate` / `impressionDate` in the "detailed" payload. Both payloads *"only provide information that does not identify a user or device"* (same source) |
| **IDFA** | Not used |
| **App Privacy questionnaire** | **No new data type.** Purchase History is already declared. `NSPrivacyTracking` can stay `false` |
| **Charts unlocked** | Attribution Source, and **Apple Search Ads Campaign / Ad Group / Keyword** segmentation ([charts](https://www.revenuecat.com/docs/dashboard-and-metrics/charts)) |

**This is the only attribution option that does not cost the privacy posture anything technically.** It still costs it rhetorically — see §4.

#### Option B2 — Meta Ads · **medium cost, needs IDFA + ATT to work properly**

| | |
|---|---|
| **In-app requirement** | **The Meta SDK must be installed and initialized.** *"Keep the Meta SDK installed and initialized for install, activation, and on-device signals"* ([meta ads](https://www.revenuecat.com/docs/integrations/attribution/meta-ads)) |
| **What RevenueCat does NOT replace** | *"doesn't replace Meta's SDK setup for install campaigns, SKAdNetwork (SKAN), or Aggregated Event Measurement (AEM)"* and *"doesn't configure SKAN or AEM, and it doesn't update SKAN conversion values"* (same) |
| **Identifiers needed** | At least one of `$fbAnonId`, `$idfa` **with `$attConsentStatus == authorized`**, or `$gpsAdId` (same) |
| **ATT prompt** | **Yes in practice.** Without ATT authorisation you fall back to `$fbAnonId` and coverage degrades badly |
| **Path** | Conversions API (recommended — sends renewals when the app is closed) or App Events API |
| **Deduplication** | *"Turn off Meta SDK purchase or revenue tracking for the same subscription events RevenueCat sends"* or you will double-count |
| **App Privacy questionnaire** | **Add `Device ID`** — RevenueCat: *"If you are using integrations that utilize an advertising identifier, like IDFA, you will need to select 'Device ID'"* ([apple app privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy)). **`NSPrivacyTracking` becomes `true`** and Meta's domains go in `NSPrivacyTrackingDomains` |

**This is the line where "No ads" stops being true in any reading.** A third-party advertising SDK ships inside the binary.

#### Option B3 — full MMP (AppsFlyer / Adjust / Branch / Singular) · **highest cost**

- **Their SDK in the app**, their own privacy manifest, their own tracking domains, their own ATT flow.
- RevenueCat's role is unchanged: it forwards subscriber events to them. It never becomes the attribution source.
- **App Privacy: Device ID, Product Interaction, Advertising Data, and `NSPrivacyTracking` true.**
- Recurring cost on top of ad spend.

**Not justifiable for a single-channel indie app.** An MMP earns its keep when you are reconciling four or more paid channels. You have zero.

### Cross-cutting item for all three

**Purchase History purpose is currently under-declared.** RevenueCat states that **all** users must select **both** *App Functionality* **and** *Analytics* for Purchase History ([apple app privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy)). `SaleArmor/PrivacyInfo.xcprivacy` declares `NSPrivacyCollectedDataTypePurposeAppFunctionality` only.

**This is true today, with no attribution and no Track B.** It is worth checking what was actually answered in the App Store Connect questionnaire, which is the binding artefact — the manifest and the questionnaire are separate. **Data Types in the App Privacy section are editable at any time** ([editable properties](https://developer.apple.com/help/app-store-connect/reference/required-localizable-and-editable-properties/)), so this is fixable without a build.

---

## 4. The conflict, stated plainly

**Track B breaks a promise that is currently in three places, and one of those promises is already not quite true.**

### What is claimed where

| Claim | Where | Status today |
|---|---|---|
| "No account. No analytics. No ads." | **Live App Store description** | "No ads" true. **"No analytics" is arguable already** — RevenueCat's charts *are* analytics, and RevenueCat tells you to declare Purchase History for *Analytics* |
| "no parent or child roles, no account, **no analytics and no network calls**" | **Family Controls (Distribution) justification**, submitted per bundle ID for `com.natalieleong.salearmor` and `.monitor` (`README.md:87`) | **"No network calls" is already false.** RevenueCat's SDK calls RevenueCat's servers on every launch — `Subscription.start()` → `Purchases.configure` → `customerInfo()` → `offerings()` |
| "The app has no analytics, no ads and no server" | `PrivacyInfo.xcprivacy` comment | Same problem, in a code comment |

**Read that middle row again.** The network-calls claim did not become wrong when you considered attribution. It was wrong when RevenueCat went in. The app cannot sell a subscription without talking to a server.

**In fairness, the substance of the justification holds:** the entitlement is about Family Controls, `.individual` authorization, no parent/child roles, and never resolving application tokens. Every one of those is still true and verifiable in the code. The network sentence was over-claimed prose in a paragraph that was otherwise accurate.

### If Track B ships, these must change

**1. The App Store description.**
- "No ads" survives **only under B1** (AdServices, no third-party ad SDK). It does not survive B2 or B3.
- "No analytics" should go regardless. Replace with something that is true and still sells the same thing: **"No account. Nothing about which apps you picked ever leaves your phone."** That is the claim people actually care about, it is the one the `FamilyActivityPicker` token design genuinely guarantees, and it stays true under every option here.
- **A description change requires a new version submission.** Apple states Promotional Text *"lets you inform your App Store visitors of any current app features **without requiring an updated submission**"* — Description carries no such exemption and is version-scoped metadata ([platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)). *Partly unverified: Apple's reference page does not state the Description rule in so many words; the exemption is stated only for Promotional Text.*

**2. The Family Controls justification.** Delete "and no network calls". Replace with a sentence that is exactly true: *"The app makes no network calls related to Family Controls. Its only network use is subscription validation through RevenueCat; application tokens are never resolved, transmitted, or stored."* **Do this on the next entitlement touch whether or not Track B happens** — the current wording is a statement to Apple that the shipped code contradicts.

**3. `PrivacyInfo.xcprivacy`.** Under B2/B3: `NSPrivacyTracking` → `true`, add tracking domains, add Device ID to collected types. Under B1: no change needed.

**4. The `PrivacyInfo.xcprivacy` comment** — "no analytics, no ads and no server" is wrong now. One-line fix.

### The re-review risk

**A metadata edit on an approved app is a submission Apple can review.** Changing the description means a new version, which means App Review sees the app again — including a description that now says less about privacy than the version they approved. That is not a rejection risk in itself, but it is **not a silent change**.

**Sharper risk:** the Family Controls (Distribution) entitlement was granted against a written justification. Shipping an advertising SDK into an app whose Family Controls case rested partly on "no analytics and no network calls" is exactly the shape of thing that invites a second look at the entitlement — and **without that entitlement there is no product**. *Unverified: I found no Apple policy stating that entitlement grants are re-reviewed on metadata change. Treat it as asymmetric downside, not a known rule.*

**Conclusion: B1 only, and only after the wording is fixed.** B2 and B3 put the entitlement at risk to buy channels you have no evidence you can afford.

---

## 5. Recommendation — the next 30 days

**Ordered. Everything in 1–5 is free and needs no build.**

1. **Wait for approval.** Nothing below matters until v1.0 is live. Charts show **production data only** — TestFlight will not populate them.

2. **Fix the Family Controls justification wording** in `README.md:87` and the `PrivacyInfo.xcprivacy` comment. **Do this whether or not Track B ever happens.** It is a claim to Apple that the code contradicts, and correcting it costs nothing.

3. **Check the App Store Connect App Privacy answers** against RevenueCat's requirement: Purchase History with **both** App Functionality and Analytics. Editable at any time, no build.

4. **Watch four numbers for 30 days, change nothing.** Initial Conversion · product mix across the four plans · Realized LTV per Customer · country split. **You cannot price against a number you do not have**, and right now you have none.

5. **Set up Targeting for non-US territories** once you see where installs actually come from. Bigger lever than any A/B test at this volume, and it needs no statistical significance to justify.

6. **Do not run an experiment yet.** Below ~2,000 installs per arm the result is noise. Revisit at §2.5's table.

7. **Track B: hold.** Revisit when you know install→paid. See §6 for why that number decides everything.

**One next action: correct the "no network calls" sentence in the Family Controls justification.** It is the only item on this list that is wrong rather than merely unmeasured.

---

## 6. Cost reality

### RevenueCat

| | |
|---|---|
| Free below | **$2,500 monthly tracked revenue** |
| Above that | **1% of tracked revenue** |
| Included on Pro from day one | **Experiments, Targeting, Paywalls, Customer Center, attribution integrations** |
| Enterprise | Custom, for high volume |

Source: [pricing](https://www.revenuecat.com/pricing). **Everything in Track A is free at Sale Armor's current scale — which is zero.** At $2,500 MTR you are paying $25/month, which is not a decision.

### Apple Search Ads — what it takes to learn anything

**2026 US benchmarks** ([Adapty](https://adapty.io/blog/apple-ads-benchmarks-2026/)): CPT **$1.58** · TTR **9.0%** · tap→install **62.71%** · **CPA $2.51**. Nearest categories: Lifestyle $2.04 CPA, Health & Fitness $3.02, Productivity $2.32. *No minimum spend is enforced by Apple; the technical floor is roughly $1/day — unverified against Apple's own docs, which I could not fetch (403).*

**The arithmetic that decides Track B.** Sale Armor is fully gated, so install→paid is the entire funnel. At $2.51 per install:

| install→paid | Cost per paying customer |
|---|---|
| 2% | **$125.50** |
| 3% | **$83.67** |
| 5% | **$50.20** |
| 8% | **$31.38** |

Against that, **net revenue after Apple's cut** (15% under the Small Business Program — *confirm enrolment, I did not verify it*):

- Annual $99.99 → **~$85 net**, once
- Lifetime $299.99 → **~$255 net**, once
- Weekly $3.99 → ~$3.39 net per week; **needs ~25 renewals to reach $85**

**Read the two tables together and the answer is uncomfortable.** At a 3% conversion rate, an annual subscriber costs $84 to acquire and returns $85. **That is break-even before a single renewal, and only if they buy annual.** The weekly plan — the one pre-selected and badged POPULAR — loses money on paid traffic unless people stay about six months.

**So: paid acquisition is unaffordable at 3% and works at 8%.** You do not know which you are. **That is the real gate on Track B, not the privacy question** — the privacy question just means you also cannot find out cheaply.

**Minimum budget to learn, if she goes ahead:**

| Goal | Installs | Spend @ $2.51 CPA |
|---|---|---|
| Rough read: does anything convert at all | 300–500 | **$750–$1,250** (≈ $50/day for 3 weeks) |
| Conversion rate to ±1 percentage point | ~1,120 | **~$2,800** |
| Conversion rate to ±0.5pp | ~4,470 | **~$11,200** |

*Sizing arithmetic is mine, not RevenueCat's — standard proportion confidence intervals at 95%.*

**Below about $750 you buy noise.** And note: **organic installs measure the same thing for free.** Thirty days of App Store traffic against a live listing gives you the install→paid rate with no ad spend and no attribution SDK — which is precisely why Track A comes first.

---

## Sources

**RevenueCat**
- [Attribution providers](https://www.revenuecat.com/docs/integrations/attribution)
- [Apple Search Ads](https://www.revenuecat.com/docs/integrations/attribution/apple-search-ads)
- [Meta Ads](https://www.revenuecat.com/docs/integrations/attribution/meta-ads)
- [Experiments](https://www.revenuecat.com/docs/tools/experiments-v1) · [overview](https://www.revenuecat.com/docs/tools/experiments-v1/experiments-overview-v1) · [creating offerings to test](https://www.revenuecat.com/docs/tools/experiments-v1/creating-offerings-to-test) · [results](https://www.revenuecat.com/docs/tools/experiments-v1/experiments-results-v1)
- [Paywalls](https://www.revenuecat.com/docs/tools/paywalls) · [Targeting](https://www.revenuecat.com/docs/tools/targeting) · [Customer Center](https://www.revenuecat.com/docs/tools/customer-center)
- [Charts](https://www.revenuecat.com/docs/dashboard-and-metrics/charts) · [Paywall Conversion](https://www.revenuecat.com/docs/dashboard-and-metrics/charts/paywall-conversion-chart) · [Paywall Abandonment](https://www.revenuecat.com/docs/dashboard-and-metrics/charts/paywall-abandonment-chart)
- [Apple App Privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy) · [Pricing](https://www.revenuecat.com/pricing) · [iAd vs AdServices](https://www.revenuecat.com/blog/engineering/iad-vs-adservices-whats-the-difference)

**Apple**
- [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/required-localizable-and-editable-properties/)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)

**Benchmarks**
- [Adapty — Apple Ads benchmarks 2026](https://adapty.io/blog/apple-ads-benchmarks-2026/) · [Business of Apps — Apple Search Ads costs 2026](https://www.businessofapps.com/marketplace/apple-search-ads/research/apple-search-ads-costs/)

**Marked unverified in this document:** Apple's own statement of the ASA daily budget floor (403 on `ads.apple.com`); Apple's Description-requires-new-version rule stated verbatim; whether Apple re-reviews entitlement grants on metadata change; Small Business Program enrolment status.
