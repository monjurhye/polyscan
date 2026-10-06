import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan_ocr_example/ocr_samples.dart';

void main() {
  test('accuracy is 1 − character error rate, ignoring whitespace', () {
    expect(accuracy('abc def', 'abcdef'), 1.0);
    expect(accuracy('abxdef', 'abcdef'), closeTo(5 / 6, 1e-9));
    expect(accuracy('বাংলা', 'বাংলা'), 1.0);
  });
}
