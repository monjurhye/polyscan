# Polyscan iOS: release checklist

Polyscan is **free to download** with **10 free scans**. One in-app purchase
(about $4.99, non-consumable, product ID `com.pickixo.polyscan.unlock`) unlocks
unlimited scans forever. No subscription and no ads. Documents already made can
always be opened, re-read and shared, even after the free scans run out.

## 1. App Store Connect: getting paid (do this first)

You can't set a price until these are done. Approval can take a few days.

- [ ] **Business › Agreements:** accept the **Paid Apps Agreement**. In-app purchases need it; the free-apps agreement isn't enough.
- [ ] **Business › Tax forms:** fill in the US tax form (W-8BEN for an individual outside the US). Bangladesh has a tax treaty question; answer it honestly.
- [ ] **Business › Banking:** add a bank account that can receive USD (SWIFT). Payouts arrive about 33 days after the end of each month once the minimum is reached.
- [ ] Wait until the Paid Apps Agreement shows **Active**.

## 2. The app record

- [ ] Create the app: name `Polyscan: Offline Scanner & OCR`, bundle ID `com.pickixo.polyscan`, SKU `polyscan-ios`.
- [ ] **Pricing and Availability:** the app itself is **Free**, in every country.
- [ ] **In-App Purchases:** create a **Non-Consumable** with product ID `com.pickixo.polyscan.unlock`, reference name `Unlock Polyscan`, price about $4.99 (base country USA; lower it by hand for India, Pakistan and Bangladesh). Add a display name, a description and the **review screenshot** (the unlock screen). Attach it to the first app version, or Apple won't review it.
- [ ] **Small Business Program:** apply, so Apple keeps 15% instead of 30%.
- [ ] Optional: turn on **pre-orders** before launch.

## 3. App Privacy and compliance

- [ ] **App Privacy:** "Data Not Collected". The app has no account, no analytics and no ads. Scans never leave the phone. The only network use is downloading OCR language models from GitHub (`raw.githubusercontent.com`), and no user data is sent.
- [ ] **Export compliance:** the app uses only standard HTTPS. `ITSAppUsesNonExemptEncryption = false` is set in `ios/Runner/Info.plist`, so Apple won't ask on every build.
- [ ] **Age rating:** 4+.
- [ ] **Category:** Productivity (secondary: Business or Utilities).
- [ ] Privacy Policy URL: `https://github.com/monjurhye/polyscan/blob/main/docs/privacy.md`. Support URL: `https://github.com/monjurhye/polyscan/blob/main/docs/support.md`. The app's Settings opens the same pages.

## 4. Store listing

- [ ] Say it clearly in the first screenshots: "10 free scans. Then pay once. No subscription. No ads. No watermark."
- [ ] Screenshots: the scan screen, the OCR text, the searchable PDF, the language list (Bangla, Hindi, Arabic) and the "stays on your phone" message.
- [ ] Note that handwriting is read poorly.
- [ ] No competitor names, and no "best/#1" claims.
- [ ] An **App Preview video** (15–30 s) helps a lot: show a Hindi or Arabic page turning into text.

## 5. App Review notes

- Say: "Free app with 10 free scans. One non-consumable IAP, Unlock Polyscan, unlocks unlimited scans. Settings › Unlock Polyscan, and Settings › Restore purchase. No account, works offline. Sample documents: <link>."
- Reviewers buy the IAP in the sandbox, so no promo code or test account is needed.
- Add the Kobiton screen recording (see the ArchiveX lessons).

## 6. After launch

- **Offer codes** for the unlock, for reviewers, bloggers and TestFlight testers.
- **Refunds** are handled by Apple, not by you.
- **Price changes** can be made at any time, and sales can be scheduled.
- After reinstalling, the free-scan count starts over and the unlock comes back through **Restore purchase**.

## What changed in the code

- 2026-10-28: removed `ProScreen`, `AdBannerPlaceholder`, `isPro` and the 2-language download limit. Every language can be downloaded, with no lock. No AdMob.
- 2026-10-29: free download with 10 free scans, then the one-time unlock (`in_app_purchase`, `lib/services/unlock_store.dart`, `lib/screens/unlock_screen.dart`). A scan counts when a new document is saved; adding pages to a document needs a free scan left or the unlock.
