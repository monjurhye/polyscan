import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/text_direction.dart';

/// Builds a minimal Word document: one paragraph per text line, a page break
/// between scanned pages. Right-to-left lines (Arabic, Urdu, Hebrew, Dhivehi)
/// are marked so Word lays them out from the right.
class DocxBuilder {
  Uint8List build(List<String> pages, {required String title}) {
    final body = StringBuffer();
    for (var p = 0; p < pages.length; p++) {
      final lines = pages[p].trim().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final pageBreak = p > 0 && i == 0;
        body.write(_paragraph(lines[i].trimRight(), pageBreak: pageBreak));
      }
    }

    final archive = Archive()
      ..addFile(_file('[Content_Types].xml', _contentTypes))
      ..addFile(_file('_rels/.rels', _rels))
      ..addFile(_file('docProps/core.xml', _core(title)))
      ..addFile(_file('word/document.xml', _document(body.toString())));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static bool isRtl(String text) => isRtlText(text);

  String _paragraph(String text, {required bool pageBreak}) {
    final rtl = isRtl(text);
    final pPr = rtl ? '<w:pPr><w:bidi/></w:pPr>' : '';
    final rPr = rtl ? '<w:rPr><w:rtl/></w:rPr>' : '';
    final br = pageBreak ? '<w:r><w:br w:type="page"/></w:r>' : '';
    final run = text.isEmpty ? '' : '<w:r>$rPr<w:t xml:space="preserve">${_escape(text)}</w:t></w:r>';
    return '<w:p>$pPr$br$run</w:p>';
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      // Control characters other than tab are not allowed in XML 1.0.
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  ArchiveFile _file(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static const _contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '</Types>';

  static const _rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '</Relationships>';

  static String _core(String title) => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/">'
      '<dc:title>${_escape(title)}</dc:title><dc:creator>Polyscan</dc:creator>'
      '</cp:coreProperties>';

  static String _document(String body) => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$body</w:body></w:document>';
}
