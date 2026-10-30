/// Whether [text] reads right to left: the first letter decides, as in the
/// Unicode bidi algorithm's paragraph level.
bool isRtlText(String text) {
  for (final r in text.runes) {
    // Hebrew, Arabic (incl. supplements), Syriac, Thaana, NKo, Arabic presentation forms.
    if ((r >= 0x0590 && r <= 0x08FF) || (r >= 0xFB1D && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)) return true;
    // The first letter of any other script decides it.
    if (_isLetter(r)) return false;
  }
  return false;
}

bool _isLetter(int r) => (r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || r >= 0xC0;
