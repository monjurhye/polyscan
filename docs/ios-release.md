# Polyscan iOS: release checklist

Polyscan is **free**, with every feature and no scan limit, and shows **Google AdMob ads**
(banners on the document screens; interstitials after a scan is saved or a share
finishes; app open ads when coming back to the app; at most one full-screen ad per
90 s). One in-app purchase, **Remove ads** ($9.99, non-consumable, product ID
`com.pickixo.polyscan.removeads`), removes all ads forever. No subscription.

App icon: `assets/icon/icon.png` (1024 px) is the source for every iOS and Android size.

## 1. App Store Connect: getting paid (do this first)

> **Blocking (2026-10-30):** App Store Connect shows "Review the updated Paid Applications Schedule". The Account Holder must accept it in **Business** (after accepting the latest Apple Developer Program License Agreement on developer.apple.com). Until then Apple blocks new in-app purchases from going live and new app submissions.

You can't set a price until these are done. Approval can take a few days.

- [ ] **Business › Agreements:** accept the **Paid Apps Agreement**. In-app purchases need it; the free-apps agreement isn't enough.
- [ ] **Business › Tax forms:** fill in the US tax form (W-8BEN for an individual outside the US). Bangladesh has a tax treaty question; answer it honestly.
- [ ] **Business › Banking:** add a bank account that can receive USD (SWIFT). Payouts arrive about 33 days after the end of each month once the minimum is reached.
- [ ] Wait until the Paid Apps Agreement shows **Active**.

## 1b. AdMob (do this before the first TestFlight build)

- [x] AdMob app **Polyscan** (iOS, not listed yet), in the AdMob account of monjurhai@gmail.com (2026-10-30). The monjurhye@gmail.com AdMob account is closed; don't use it.
  - `ADMOB_IOS_APP_ID` = `ca-app-pub-8399549130025066~6002983673`
  - `ADMOB_IOS_BANNER` = `ca-app-pub-8399549130025066/8437575325` (Polyscan Banner)
  - `ADMOB_IOS_INTERSTITIAL` = `ca-app-pub-8399549130025066/2090612642` (Polyscan Interstitial)
  - `ADMOB_IOS_APP_OPEN` = `ca-app-pub-8399549130025066/4971926854` (Polyscan App Open)
- [ ] After the App Store release, AdMob › Polyscan › **Add store**, so "Limited ad serving" is lifted.
- [x] (Done 2026-10-30.) In Codemagic › polyscan › Environment variables, make the group **`admob`** with `ADMOB_IOS_APP_ID`, `ADMOB_IOS_BANNER`, `ADMOB_IOS_INTERSTITIAL`, `ADMOB_IOS_APP_OPEN`. The `ios-release` workflow refuses to build without them, or with Google's test IDs.
- [ ] AdMob › Privacy & messaging: create a **GDPR (European regulations) message** for the app, and an **IDFA explainer** if you want one. The app shows them through Google's UMP SDK.
- [ ] **app-ads.txt:** AdMob asks for it on the developer website. Put the line AdMob shows you at `https://<your site>/app-ads.txt`, and use that site as the app's **Marketing URL** in App Store Connect (ArchiveX lesson).
- [ ] Never tap your own real ads. Debug and Appetize builds use Google's test ads, which are safe.

## 2. The app record

- [x] App ID (bundle) `com.pickixo.polyscan` registered, and the App Store Connect app created 2026-10-30: name **`Polyscan: Offline Scanner OCR`** (Apple's 30-character limit ruled out "& OCR"), SKU `polyscan-ios`, Apple ID **6828965979**, primary language English (U.S.).
- [ ] **Pricing and Availability:** the app itself is **Free**, in every country.
- [x] (Created 2026-10-30, Apple ID 6828966619: $9.99 base USA, all 175 countries, English display name "Remove ads" / "Pay once and remove all ads forever.". Still missing: the review screenshot.) **In-App Purchases:** create a **Non-Consumable** with product ID `com.pickixo.polyscan.removeads`, reference name `Remove ads`, price **$9.99** (base country USA; consider lowering it by hand for India, Pakistan and Bangladesh). Add a display name, a description and the **review screenshot** (the Remove ads screen). Attach it to the first app version, or Apple won't review it.
- [ ] **Small Business Program:** apply, so Apple keeps 15% instead of 30%.
- [ ] Optional: turn on **pre-orders** before launch.

## 3. App Privacy and compliance

- [ ] **App Privacy** (because of AdMob; follow Google's "Data disclosure for Apple's App Store" page for the current list): **Data used to track you:** Identifiers › Device ID; Usage Data › Advertising Data. **Data linked/not linked to you, for Third-Party Advertising and Analytics:** Location › Coarse Location; Identifiers › Device ID; Usage Data › Product Interaction, Advertising Data; Diagnostics › Crash Data, Performance Data, Other Diagnostic Data. Scans, photos and text are **not** collected.
- [ ] **Export compliance:** the app uses only standard HTTPS. `ITSAppUsesNonExemptEncryption = false` is set in `ios/Runner/Info.plist`, so Apple won't ask on every build.
- [ ] **Age rating:** 4+ is still possible with ads, but check "Advertising" honestly in the questionnaire. Do not mark the app as "Made for Kids" (that would forbid personalized ads).
- [ ] **Category:** Productivity (secondary: Business or Utilities).
- [ ] Privacy Policy URL: `https://github.com/monjurhye/polyscan/blob/main/docs/privacy.md`. Support URL: `https://github.com/monjurhye/polyscan/blob/main/docs/support.md`. The app's Settings opens the same pages.

## 4. Store listing

- [ ] Say it clearly in the first screenshots: "Free. No scan limit. No watermark. No subscription." Don't promise "no ads".
- [ ] Screenshots: the scan screen, the OCR text, the searchable PDF, the language list (Bangla, Hindi, Arabic) and the "stays on your phone" message.
- [ ] Note that handwriting is read poorly.
- [ ] No competitor names, and no "best/#1" claims.
- [ ] An **App Preview video** (15–30 s) helps a lot: show a Hindi or Arabic page turning into text.

## 4b. Building on Codemagic

- [ ] In Codemagic, add this repo (`monjurhye/polyscan`) to the same team as ArchiveX, so it can use the **App Store Connect API key integration `app_store_key`** and the **Apple Distribution certificate** already uploaded under Code signing identities.
- [ ] The Apple Developer account needs the App ID `com.pickixo.polyscan` (Codemagic can register it, or add it at developer.apple.com › Identifiers). In-App Purchase is on by default.
- [ ] Run **iOS simulator build (Appetize)** first (`ios-simulator`). Upload `Polyscan-simulator.zip` to Appetize and click through: import a photo, read text, share as PDF and Word.
- [ ] Run **iOS release (TestFlight)** (`ios-release`). It builds Tesseract, signs with an App Store profile for `com.pickixo.polyscan`, checks the IPA and uploads it to App Store Connect. The build number is Codemagic's counter; the version (1.0.0) is in `pubspec.yaml`.
- [ ] In App Store Connect › TestFlight, add yourself as an internal tester. Test the Remove ads purchase there (it needs the Paid Apps Agreement to be Active).

## 5. App Review notes

- Say: "Free app with ads (Google AdMob, UMP consent, App Tracking Transparency). One non-consumable IAP, Remove ads, removes all ads. Settings › Remove ads, and Settings › Restore purchase. No account, works offline. Sample documents: <link>."
- Part 4 (external services): Google AdMob for ads, Google UMP for consent, StoreKit for the purchase.
- Reviewers buy the IAP in the sandbox, so no promo code or test account is needed.
- Add the Kobiton screen recording (see the ArchiveX lessons).
- **Say plainly where the screenshots come from** (paste into App Review Information › Notes):

  > About the screenshots: all App Store screenshots were captured from the real Polyscan app build running in the iOS Simulator (Xcode, on a Codemagic cloud Mac): iPhone 17 Pro Max (6.9"), iPhone 11 Pro Max (6.5") and iPad Pro 13-inch. Nothing was drawn or edited apart from the status bar, which was set to 9:41 with the standard simulator tool. The documents shown are sample documents (an English bill, a Bangla rental agreement, an Arabic certificate and a Hindi receipt) loaded by a debug-only screenshot mode; the text shown is what the app displays for them. Ads are switched off in that mode so they don't appear in the screenshots. The App Store build doesn't contain screenshot mode.

  Check the device names against the Codemagic log ("Using …" lines) before pasting, and change them if Codemagic used other simulators.

## 6. After launch

- **Offer codes** for Remove ads, for reviewers, bloggers and TestFlight testers.
- **Refunds** are handled by Apple, not by you.
- **Price changes** can be made at any time, and sales can be scheduled.
- After reinstalling, Remove ads comes back through **Restore purchase**.

## What changed in the code

- 2026-10-28: removed `ProScreen`, `AdBannerPlaceholder`, `isPro` and the 2-language download limit. Every language can be downloaded, with no lock. No AdMob.
- 2026-10-29: free download with 10 free scans, then the one-time unlock (`in_app_purchase`, `lib/services/unlock_store.dart`, `lib/screens/unlock_screen.dart`). A scan counts when a new document is saved; adding pages to a document needs a free scan left or the unlock.
- 2026-10-30: Word (.docx) export; privacy and support pages; licenses page; Tools tab hidden for v1; own app icon; Codemagic `ios-release` and `ios-simulator` workflows.
- 2026-10-30 (later): back to free with ads. AdMob banner, interstitial and app open ads (`lib/services/ad_service.dart`, `lib/screens/ad_banner.dart`), UMP consent and App Tracking Transparency; the 10-scan limit is gone; the purchase became Remove ads, $9.99, `com.pickixo.polyscan.removeads`.
