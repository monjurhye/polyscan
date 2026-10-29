# Polyscan iOS: paid app release checklist

Polyscan is sold as a **paid app** on the App Store (for example $4.99). You pay once
to download it, and everything is unlocked. The app has no free tier, no in-app
purchase, no subscription and no ads. Apple takes the payment, so the app has no
payment code.

## 1. App Store Connect: getting paid (do this first)

You can't set a price until these are done. Approval can take a few days.

- [ ] **Business › Agreements:** accept the **Paid Apps Agreement**. The free-apps agreement isn't enough.
- [ ] **Business › Tax forms:** fill in the US tax form (W-8BEN for an individual outside the US). Bangladesh has a tax treaty question; answer it honestly.
- [ ] **Business › Banking:** add a bank account that can receive USD (SWIFT). Payouts arrive about 33 days after the end of each month once the minimum is reached.
- [ ] Wait until the Paid Apps Agreement shows **Active**.

## 2. The app record

- [ ] Create the app: name `Polyscan: Offline Scanner & OCR`, bundle ID `com.pickixo.polyscan`, SKU `polyscan-ios`.
- [ ] **Pricing and Availability:** pick the price (base country USA). Apple sets the other countries' prices; you can lower individual ones (India, Bangladesh) by hand.
- [ ] Availability: every country. **Don't** choose "Free".
- [ ] Optional: turn on **pre-orders** before launch.

## 3. App Privacy and compliance

- [ ] **App Privacy:** "Data Not Collected". The app has no account, no analytics and no ads. Scans never leave the phone. The only network use is downloading OCR language models from GitHub (`raw.githubusercontent.com`), and no user data is sent.
- [ ] **Export compliance:** the app uses only standard HTTPS. `ITSAppUsesNonExemptEncryption = false` is set in `ios/Runner/Info.plist`, so Apple won't ask on every build.
- [ ] **Age rating:** 4+.
- [ ] **Category:** Productivity (secondary: Business or Utilities).
- [ ] Privacy Policy URL and Support URL are live. The app's Settings links to them still say "opens here" and need the real URLs.

## 4. Store listing for a paid app

People can't try a paid app first, so the listing has to sell it.

- [ ] Say it clearly in the first screenshots: "One price. No subscription. No ads. No watermark."
- [ ] Screenshots: the scan screen, the OCR text, the searchable PDF, the language list (Bangla, Hindi, Arabic) and the "stays on your phone" message.
- [ ] Note that handwriting is read poorly.
- [ ] No competitor names, and no "best/#1" claims.
- [ ] An **App Preview video** (15–30 s) helps paid apps a lot.

## 5. App Review notes for a paid app

- Reviewers get paid apps for free, so a promo code or test account isn't needed.
- Say: "Paid app, no in-app purchases, no account, works offline. Sample documents: <link>."
- Add the Kobiton screen recording (see the ArchiveX lessons).

## 6. After launch

- **Promo codes:** App Store Connect › the app › Promo Codes. 100 codes per version, for reviewers and bloggers.
- **Refunds** are handled by Apple, not by you.
- **Price changes** can be made at any time, and sales can be scheduled.
- Moving later to "free + in-app purchase" is possible, but people who already paid must keep everything. Plan that before changing.

## What changed in the code (2026-10-28)

- Removed `ProScreen`, `AdBannerPlaceholder`, `isPro`, the free download limit (2 languages) and the "Restore purchases" item.
- Every language can be downloaded, with no lock.
- No AdMob or StoreKit packages are needed.
