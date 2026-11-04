# Polyscan Android: Play Console checklist

Same product as iOS: free with AdMob ads, one one-time **Remove ads** purchase ($9.99), product ID
`com.pickixo.polyscan.removeads`, package `com.pickixo.polyscan`. Listing text: [play-store-listing.md](play-store-listing.md).

## 1. Upload key

- Key and passwords: `C:\Users\Administrator\Desktop\Polyscan-Play-keys\` (outside the repo, which is public). `android/key.properties` points to it and is git-ignored.
- Keep a copy of that folder somewhere safe, off this server. Lost upload keys can be reset through Play support, but that takes days.
- Enrol in **Play App Signing** at the first upload (the default): Google holds the app signing key, this one is only the upload key.

## 2. AdMob (before the release build)

In the AdMob account of **monjurhai@gmail.com** (never monjurhye@gmail.com, whose AdMob is closed), add an Android app "Polyscan" with Banner, Interstitial and App Open units, then fill in:

- `ADMOB_ANDROID_APP_ID` =
- `ADMOB_ANDROID_BANNER` =
- `ADMOB_ANDROID_INTERSTITIAL` =
- `ADMOB_ANDROID_APP_OPEN` =

After the Play release, link the store in AdMob. `https://pickixo.com/app-ads.txt` already has this publisher.

## 3. Build

```
scripts\build_play_release.ps1 -BuildNumber 1 -AppId <..> -Banner <..> -Interstitial <..> -AppOpen <..>
```

Raise the build number on every upload. This server has 4 GB of RAM, so `~/.gradle/gradle.properties` caps the Gradle heap at 2.5 GB; the build takes a long time.

## 4. Order in Play Console

1. Create the app: name, English (United States), App, Free. Free can't later be changed to paid.
2. Upload the AAB to **Closed testing**. Console only offers in-app products after a build with the billing permission is uploaded.
3. Monetize › In-app products: create `com.pickixo.polyscan.removeads`, "Remove ads", "Pay once and remove all ads forever.", $9.99. It needs a merchant payments profile (Bangladesh is supported, payouts in USD).
4. Fill in the answers below and the store listing.
5. **New personal accounts:** at least 12 testers opted in for the last 14 days continuously before you can apply for production. Organization accounts don't have this rule.
6. Apply for production access, then release.

## 5. App content answers

| Section | Answer |
|---|---|
| Privacy policy | https://pickixo.com/polyscan/privacy |
| App access | All functionality available without special access |
| Ads | Yes, contains ads |
| Advertising ID | Yes; purpose: Advertising (and Analytics, Fraud prevention) |
| Content rating | Category: Utility/Productivity. No violence, sexual content, profanity, drugs, gambling. Users can't interact or exchange content with each other; shares no location with other users. |
| Target audience | 13 and over (13–15, 16–17, 18+). Not designed for children under 13, matching the privacy policy. |
| News app | No |
| COVID-19 tracing | No |
| Government app | No |
| Financial features | None |
| Health features | None |

## 6. Data safety

Google's [AdMob disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure) lists what the SDK collects and shares; it doesn't name Play's categories, so the mapping below is ours. Re-check it against that page when upgrading the SDK.

- Collects or shares data: **Yes**. Encrypted in transit: **Yes** (TLS).
- Account creation: **No accounts**. Deletion request: there is no developer-held data. Uninstalling removes all documents; buying Remove ads stops ad collection.

| Play category | Data type | Collected | Shared | Optional | Purposes |
|---|---|---|---|---|---|
| Location | Approximate location (from IP) | Yes | Yes | No | Advertising, Analytics, Fraud prevention |
| App activity | App interactions | Yes | Yes | No | Advertising, Analytics, Fraud prevention |
| App info and performance | Diagnostics | Yes | Yes | No | Advertising, Analytics, Fraud prevention |
| Device or other IDs | Device or other IDs (Advertising ID, app set ID) | Yes | Yes | No | Advertising, Analytics, Fraud prevention |

**Not declared, because they don't leave the phone:** photos, files, scans and recognized text.
Text recognition is on-device, and Google's page says the [document scanner flow is on-device](https://developers.google.com/ml-kit/vision/doc-scanner) too. Language files are plain downloads with nothing sent. Payments are handled by Google Play.

## 7. Before production

- [ ] Run the `Play screenshots` workflow; put the PNGs in `store/play/screenshots/`.
- [ ] Test on a real phone through the closed test: Scan (needs Play services), import, OCR download, PDF and Word share, a real ad, buying and restoring Remove ads. None of this has run on a real Android phone yet, and CI only tests debug builds, so this is also the first run of the shrunk (R8) release code.
- [ ] Privacy policy: mention that Google Play services delivers the scanner on Android (`docs/privacy.md` and the live copy in the Pickixo repo).
- [ ] AdMob › Privacy & messaging: GDPR message covers the Android app.
