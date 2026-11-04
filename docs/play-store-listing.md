# Polyscan: Google Play listing (English, United States)

Paste each block into Play Console › Polyscan › Grow users › Store presence › Main store listing.
Written from the Android code on 2026-11-04. No competitor names, no "best/#1".
Play discourages promotional words in the title, so "free" stays out of it.

## App name (30 max)

```
Polyscan: Offline Scanner OCR
```

## Short description (80 max)

```
Scan paper and read its text on your phone, in 100+ languages. PDF and Word.
```

## Full description (4000 max)

```
Polyscan turns paper into text you can search, copy and share, in more than 100 languages, right on your phone. No account, no cloud, no subscription.

Scan
• Tap Scan and hold your phone over the page. Google's document scanner finds the edges, straightens the page and crops it for you.
• Scan several pages in one go; they become one document.
• No paper at hand? Import pictures from your gallery (several at once) or image files from your device.

Tidy up each page
• Choose Color, Grayscale, Black & White or Original for each page.
• Rotate pages, delete the ones you don't need, or add more pages to a document later.
• Pick the page size: Auto, A4, Letter or Legal.
• ID card mode puts the front and back of a card on one A4 page at real size, ready to print.
• Photo mode keeps the original colors and skips text reading.

Read the text (OCR) on your phone
• Tap Recognize text and choose the language of the page. Pick more than one for mixed pages, for example Bangla and English.
• 122 languages, including English, Bangla (Bengali), Hindi, Arabic, Urdu, Persian, Tamil, Telugu, Gujarati, Punjabi, Nepali, Thai, Chinese, Japanese, Korean, Spanish, French, German, Portuguese, Russian, Indonesian, Turkish and many more.
• English is built in. Other languages are small one-time downloads (most under 5 MB); after that they work offline.
• Text recognition runs on your phone with the built-in OCR engine (Tesseract).
• If a page reads poorly, Polyscan automatically tries again with a cleaned-up copy of the image.
• Right-to-left languages such as Arabic and Urdu are shown right to left.
• Copy the text with one tap, or read it again with different languages.

Find anything
• Search finds documents by title and by the text inside your scans.
• Rename documents to keep them organized.

Share
• Searchable PDF: the page image with an invisible text layer, so you can select and search the text in any PDF viewer. The text layer covers Latin, Bangla, Devanagari (Hindi, Marathi, Nepali), Arabic-script and Thai text.
• Word (.docx): the recognized text, page by page, ready to edit.
• Plain text (.txt) and images (.jpg, one per page).
• Send to Gmail, Messages, Drive or any app in the share menu. Set your favorite format as the default.

Private by design
• No account and no sign-in.
• Scans and recognized text are stored only on your phone and are never uploaded.
• Polyscan uses the internet to download the languages you choose and to show ads. Google Play services downloads the scanner once, the first time it is needed.

Free, with ads
• Every feature and every language is free, with no scan limit and no watermark on your PDFs.
• The free version shows ads: a banner on the document screens and an occasional full-screen ad, for example after you share a file or when you come back to the app.
• Remove ads with a single one-time purchase. No subscription. Restore it any time with the same Google account.

Also
• Light, dark or system appearance.

Good to know
• The Scan button needs Google Play services. Importing pictures works without it.
• Printed text reads best. Handwriting is not read reliably.
• Always check important numbers, such as amounts and account numbers, against the original.
• Urdu in the Nastaliq style reads less accurately than Naskh.
```

## Release notes (500 max)

```
First release of Polyscan: scan or import pages, read their text on your phone in 122 languages, and share them as a searchable PDF, Word file, text or images.
```

## Graphics

| Field | File | Rule |
|---|---|---|
| App icon | `store/play/icon-512.png` | 512×512 PNG, up to 1 MB |
| Feature graphic | `store/play/feature-graphic-1024x500.png` | 1024×500, no alpha |
| Phone screenshots | `store/play/screenshots/phone-*.png` (from the `Play screenshots` workflow) | 2–8; longer side at most twice the shorter |
| Tablet screenshots | `store/play/screenshots/tablet-*.png` (same workflow) | optional, 4+ recommended |

The iOS screenshots can't be reused: they show an iPhone, and 1320×2868 is taller than Play's 2:1 limit.
Regenerate the icon and graphic with `python store/make_play_graphics.py`.

## Store settings

- Category: **Productivity**. Tags: pick the closest ones Console offers.
- Email: support@pickixo.com
- Website: https://pickixo.com
- Privacy policy: https://pickixo.com/polyscan/privacy
