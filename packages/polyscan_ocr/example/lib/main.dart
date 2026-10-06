import 'package:flutter/material.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';

import 'ocr_samples.dart';

void main() => runApp(const MaterialApp(home: OcrDemo()));

/// Runs every bundled sample and shows accuracy, so the plugin can be checked by eye
/// (e.g. on Appetize) as well as by the integration test.
class OcrDemo extends StatefulWidget {
  const OcrDemo({super.key});

  @override
  State<OcrDemo> createState() => _OcrDemoState();
}

class _OcrDemoState extends State<OcrDemo> {
  String _version = '…';
  final _runs = <SampleRun>[];
  String? _error;
  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _runs.clear();
      _error = null;
    });
    try {
      _version = await PolyscanOcr.tesseractVersion();
      final tessdata = await prepareTessdata();
      for (final sample in ocrSamples) {
        final run = await runSample(sample, tessdata);
        setState(() => _runs.add(run));
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('polyscan_ocr · Tesseract $_version')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _running ? null : _run,
        icon: const Icon(Icons.play_arrow),
        label: Text(_running ? 'Running…' : 'Run samples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          for (final run in _runs)
            Card(
              child: ListTile(
                title: Text('${run.sample.asset.split('/').last} · ${(run.accuracy * 100).toStringAsFixed(1)}%'),
                subtitle: Text(
                  '${run.elapsed.inMilliseconds} ms · conf ${run.result.meanConfidence}\n${run.result.text.trim()}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
