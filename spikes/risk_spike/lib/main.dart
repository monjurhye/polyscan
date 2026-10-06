// Minimal app so the Tesseract plugin is compiled into an Android build.
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

void main() => runApp(const MaterialApp(home: _Home()));

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async => debugPrint(await FlutterTesseractOcr.getTessdataPath()),
          child: const Text('Tesseract'),
        ),
      ),
    );
  }
}
