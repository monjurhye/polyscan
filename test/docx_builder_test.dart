import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan/services/docx_builder.dart';

void main() {
  String part(List<int> docx, String name) =>
      utf8.decode(ZipDecoder().decodeBytes(docx).findFile(name)!.content as List<int>);

  test('docx has the parts Word needs, one paragraph per line, page breaks between pages', () {
    final docx = DocxBuilder().build(['Hello <world> & you\nবিদ্যুৎ বিল', 'سلام دنیا'], title: 'Bill "Sept"');
    final archive = ZipDecoder().decodeBytes(docx);
    expect(archive.files.map((f) => f.name),
        containsAll(['[Content_Types].xml', '_rels/.rels', 'docProps/core.xml', 'word/document.xml']));

    final body = part(docx, 'word/document.xml');
    expect('<w:p>'.allMatches(body).length + '<w:p '.allMatches(body).length, 3);
    expect(body, contains('Hello &lt;world&gt; &amp; you'));
    expect(body, contains('বিদ্যুৎ বিল'));
    expect('w:type="page"'.allMatches(body).length, 1);
    // Only the Persian line is right-to-left.
    expect('<w:bidi/>'.allMatches(body).length, 1);
    expect(body, contains('<w:pPr><w:bidi/></w:pPr><w:r><w:br w:type="page"/></w:r>'));
    expect(part(docx, 'docProps/core.xml'), contains('Bill &quot;Sept&quot;'));
  });

  test('script direction follows the first letter', () {
    expect(DocxBuilder.isRtl('123 سلام'), isTrue);
    expect(DocxBuilder.isRtl('ދިވެހި'), isTrue);
    expect(DocxBuilder.isRtl('PDF فایل'), isFalse);
    expect(DocxBuilder.isRtl('हिन्दी'), isFalse);
  });
}
