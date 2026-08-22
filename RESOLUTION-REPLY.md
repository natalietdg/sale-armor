# Resolution Center reply — 20 August 2026

Paste this into App Store Connect → Resolution Center as a single reply, then resubmit.

---

Thank you for the review. Responding to all three items.

**Guideline 3.1.2 — Terms of Use (EULA) link**

Fixed. The App Description now contains a functional link to the standard Apple Terms of Use, alongside the privacy policy, together with the title, length and price of every subscription:

- Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- Privacy Policy: https://salearmor.pages.dev/privacy

We use the standard Apple Terms of Use and have not supplied a custom EULA.

**Guideline 3 — confirmation of the Lifetime price**

Confirmed. **Sale Armor Lifetime is intentionally priced at USD 299.99.** It is a one-time, non-renewing purchase that replaces the subscription permanently, offered for people who prefer not to hold a subscription at all. The auto-renewing options are USD 3.99 per week, USD 9.99 per month and USD 99.99 per year. All four unlock exactly the same functionality and differ only in duration.

**Guideline 2.5.1 — Family Controls entitlement**

The Family Controls entitlement is requested, approved and present on the app and on both of its Screen Time extensions in the submitted build (1.0, build 9). Specifically:

| Target | Bundle ID | Provisioning profile |
| --- | --- | --- |
| App | com.natalieleong.salearmor | SaleArmor AppStore |
| DeviceActivity monitor | com.natalieleong.salearmor.monitor | SaleArmorMonitor AppStore |
| Shield configuration | com.natalieleong.salearmor.shield | SaleArmorShield AppStore |

All three App IDs have **Family Controls** and **Family Controls (Distribution)** enabled, and all three embedded provisioning profiles in build 9 carry `com.apple.developer.family-controls`, as does each signed binary.

`com.natalieleong.salearmor.shield` is new in this build. It is a `ShieldConfigurationExtension` that only customises the appearance of the screen shown when a shielded app is opened; it performs no blocking of its own. It was registered with the entitlement before the build was produced.

Sale Armor uses Screen Time APIs for their intended purpose: the user authorises Family Controls for their own device, chooses their own apps through `FamilyActivityPicker`, and sets the times those apps are shielded. The app receives only opaque `ApplicationToken` values and never learns which apps were selected.

If any part of the entitlement configuration still appears incorrect from your side, please let us know which target it concerns and we will correct it immediately.

---

## Then

1. Resubmit version 1.0 with build 8.
2. **Before resubmitting**, confirm prices load in TestFlight. The Apple Developer Program License Agreement was accepted on 19 August; until it propagated, the paywall showed "Couldn't load the prices", and a reviewer who cannot pass the paywall cannot test the app.
