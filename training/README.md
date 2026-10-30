# OCR model training

Fine-tunes Tesseract's `tessdata_best` model for a language whose stock model reads poorly
and compares it with the `tessdata_fast` model the app downloads today. Run the
**OCR model training** workflow (`.github/workflows/train-ocr.yml`) by hand.

- `prepare_text.py`: Wikipedia sentences from the Leipzig corpora, minus anything that
  overlaps the evaluation text.
- `make_data.py`: renders the text with `text2image` in several sizes, exposures and fonts,
  adds a degraded (phone-photo-like) copy of every page, and makes `.lstmf` files.
- `eval/`: held-out evaluation pages (UDHR articles, rendered with Flutter) and their text.
  `degrade.py` makes phone and shadow copies, `enhance_test.dart` runs the app's OCR
  preprocessing on them, and `evaluate.py` scores each model.
- `fonts/`: Noto Sans Thaana, Noto Nastaliq Urdu, Noto Naskh Arabic and Gulzar (all SIL Open
  Font License 1.1). Gulzar is used only for evaluation, as a Nastaliq font the model never saw.
  The `mvboli` evaluation pages were rendered on Windows with MV Boli; only the images are here.
