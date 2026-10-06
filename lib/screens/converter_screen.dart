import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _Direction { bijoyToUnicode, unicodeToBijoy }

/// UI for the Bijoy ↔ Unicode converter. The conversion itself is not built yet.
class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  _Direction _direction = _Direction.bijoyToUnicode;
  final _input = TextEditingController();
  String _output = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _convert() {
    // TODO: plug in the Bijoy <-> Unicode mapping.
    setState(() => _output = _input.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preview only — the converter engine is not built yet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bijoy ↔ Unicode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Direction>(
            segments: const [
              ButtonSegment(value: _Direction.bijoyToUnicode, label: Text('Bijoy → Unicode')),
              ButtonSegment(value: _Direction.unicodeToBijoy, label: Text('Unicode → Bijoy')),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() {
              _direction = s.first;
              _output = '';
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: _direction == _Direction.bijoyToUnicode ? 'Paste Bijoy text' : 'Paste Unicode text',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _convert,
            icon: const Icon(Icons.swap_vert),
            label: const Text('Convert'),
          ),
          const SizedBox(height: 16),
          if (_output.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(_output, style: theme.textTheme.bodyLarge),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: () => Clipboard.setData(ClipboardData(text: _output)),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
