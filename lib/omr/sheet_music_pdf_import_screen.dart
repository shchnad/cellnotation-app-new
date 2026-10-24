import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'omr_ai_service.dart';
import 'omr_service.dart';
import 'sheet_music_recognizer.dart';

/// Reads piano sheet music from a PDF and turns it into the
/// line-position transcription.
///
/// 1. Choose a PDF, the pages to read and the key (scale).
/// 2. "Recognize" reads the pages on the tablet itself (offline, free;
///    best on clean digital PDFs).
/// 3. If the result is poor — e.g. a scanned page — "Use AI" sends the
///    pages to Claude through the app's Cloud Function instead.
/// 4. The text can be corrected by hand, then "Use transcription"
///    returns it (Navigator.pop) to the import dialog.
class SheetMusicPdfImportScreen extends StatefulWidget {
  /// Scale names to offer (CompositionController.availableScales).
  final List<String> scales;

  const SheetMusicPdfImportScreen({super.key, required this.scales});

  @override
  State<SheetMusicPdfImportScreen> createState() =>
      _SheetMusicPdfImportScreenState();
}

class _SheetMusicPdfImportScreenState extends State<SheetMusicPdfImportScreen> {
  Uint8List? _pdf;
  String _fileName = '';
  int _pageCount = 0;

  /// Page sizes in inches, to pick a safe resolution per page.
  List<List<double>> _pageSizes = const [];
  int _fromPage = 1;
  int _toPage = 1;
  late String _scale = widget.scales.contains('do major')
      ? 'do major'
      : (widget.scales.isNotEmpty ? widget.scales.first : 'do major');

  /// Rendered pages, kept so the AI can reuse them.
  List<OmrPdfPage> _pages = const [];

  /// On-device text per page (given to the AI as a hint).
  final Map<int, String> _draftByPage = {};

  bool _busy = false;
  String _status = '';
  final List<String> _warnings = [];
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// 'Auto' or a time signature like '3/4'.
  String _meter = 'Auto';
  static const _meters = ['Auto', '2/4', '3/4', '4/4', '2/2', '3/8', '6/8', '9/8', '12/8'];

  List<int>? get _meterOverride {
    if (_meter == 'Auto') return null;
    final p = _meter.split('/');
    return [int.parse(p[0]), int.parse(p[1])];
  }

  bool get _scaleHasAccidentals =>
      _scale != 'do major' && _scale != 'la minor';

  Future<void> _pickPdf() async {
    // file_picker 11+ : static pickFile(), bytes read with readAsBytes().
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return;
    setState(() {
      _busy = true;
      _status = 'Opening ${file.name}…';
    });
    try {
      final bytes = await file.readAsBytes();
      final sizes = await pdfPageSizes(bytes);
      final count = sizes.length;
      setState(() {
        _pageSizes = sizes;
        _pdf = bytes;
        _fileName = file.name;
        _pageCount = count;
        _fromPage = 1;
        _toPage = count == 0 ? 1 : count;
        _pages = const [];
        _draftByPage.clear();
        _warnings.clear();
        _text.clear();
        _status = count == 0
            ? 'This PDF could not be opened.'
            : '$count page${count == 1 ? '' : 's'}.';
      });
    } catch (e) {
      setState(() => _status = 'This PDF could not be opened: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  List<int> get _selectedIndexes =>
      [for (int p = _fromPage; p <= _toPage; p++) p - 1];

  /// Renders one page at a resolution that is safe for its size.
  Future<OmrPdfPage?> _render(int index) {
    final dpi = index < _pageSizes.length ? dpiForPage(_pageSizes[index]) : 100.0;
    return renderPdfPage(_pdf!, index, dpi: dpi);
  }

  /// The page as a PNG preview, rendering it when not done yet.
  Future<OmrPdfPage> _previewPage(int index) async {
    for (final p in _pages) {
      if (p.index == index) return p;
    }
    final page = await _render(index);
    if (page == null) throw Exception('Page ${index + 1} could not be rendered.');
    final light = withoutPixels(page);
    setState(() => _pages = [..._pages, light]..sort((a, b) => a.index.compareTo(b.index)));
    return light;
  }

  Future<void> _recognizeOnDevice() async {
    if (_pdf == null) return;
    setState(() {
      _busy = true;
      _warnings.clear();
      _pages = const [];
    });
    try {
      final wanted = _selectedIndexes;
      final all = <OmrMeasure>[];
      _draftByPage.clear();
      // One page at a time: render, read, then keep only the preview.
      for (int i = 0; i < wanted.length; i++) {
        final index = wanted[i];
        setState(() => _status =
        'Reading page ${index + 1} (${i + 1} of ${wanted.length})…');
        final page = await _render(index);
        if (page == null) {
          _warnings.add('Page ${index + 1} could not be rendered.');
          continue;
        }
        final result = await recognizePage(page);
        setState(() => _pages = [..._pages, withoutPixels(page)]);
        if (result.systemCount == 0) {
          _warnings.add('Page ${index + 1}: no piano staves found.');
        }
        all.addAll(result.measures);
        _draftByPage[index] = omrMeasuresToTranscription(
          result.measures,
          scaleName: _scale,
          scaleHasAccidentals: _scaleHasAccidentals,
          timeSignature: _meterOverride,
        );
      }
      final text = omrMeasuresToTranscription(
        all,
        scaleName: _scale,
        scaleHasAccidentals: _scaleHasAccidentals,
        timeSignature: _meterOverride,
      );
      setState(() {
        _text.text = text;
        final n = lastMeasureNumber(text);
        _status = 'Recognized $n measure${n == 1 ? '' : 's'}'
            '${timeSignatureOf(text) != null ? ', time ${timeSignatureOf(text)}' : ''}. '
            'Please check the result — or try "Use AI".';
      });
    } catch (e) {
      setState(() => _status = 'Recognition failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _recognizeWithAi() async {
    if (_pdf == null) return;
    setState(() {
      _busy = true;
      _warnings.clear();
    });
    try {
      final wanted = _selectedIndexes;
      final texts = <String>[];
      String? timeSignature = _meter == 'Auto' ? null : _meter;
      int nextMeasure = 1;
      for (int i = 0; i < wanted.length; i++) {
        final index = wanted[i];
        setState(() => _status =
        'AI is reading page ${index + 1} (${i + 1} of ${wanted.length})… '
            'this can take a minute.');
        final page = await _previewPage(index);
        final text = await transcribePageWithAi(
          png: page.png,
          scaleName: _scale,
          firstMeasure: nextMeasure,
          timeSignature: timeSignature,
          draft: _draftByPage[index],
        );
        texts.add(text);
        timeSignature ??= timeSignatureOf(text);
        final last = lastMeasureNumber(text);
        if (last >= nextMeasure) nextMeasure = last + 1;
      }
      final joined = joinPageTranscriptions(texts);
      setState(() {
        _text.text = joined;
        final n = lastMeasureNumber(joined);
        _status = 'AI transcribed $n measure${n == 1 ? '' : 's'}. '
            'Please check the result.';
      });
    } catch (e) {
      setState(() => _status =
      'The AI could not be reached: $e\n'
          '(It needs internet and the "transcribeSheetMusic" Cloud Function — see the setup notes.)');
    } finally {
      setState(() => _busy = false);
    }
  }

  Widget _button(String label, Color color, VoidCallback? onPressed) {
    return TextButton(
      onPressed: _busy ? null : onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _busy || onPressed == null ? Colors.grey : color,
        ),
      ),
    );
  }

  Widget _pageDropdown(int value, ValueChanged<int> onChanged) {
    return DropdownButton<int>(
      value: value,
      style: const TextStyle(fontSize: 20, color: Colors.black),
      items: [
        for (int p = 1; p <= _pageCount; p++)
          DropdownMenuItem(value: p, child: Text('$p')),
      ],
      onChanged: _busy ? null : (v) => onChanged(v!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPdf = _pdf != null && _pageCount > 0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Read Sheet Music from PDF',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _button('Choose PDF', Colors.blue, _pickPdf),
                  if (_fileName.isNotEmpty)
                    Text(_fileName, style: const TextStyle(fontSize: 20)),
                ],
              ),
              if (hasPdf)
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Pages', style: TextStyle(fontSize: 20)),
                    _pageDropdown(_fromPage, (v) => setState(() {
                      _fromPage = v;
                      if (_toPage < v) _toPage = v;
                    })),
                    const Text('to', style: TextStyle(fontSize: 20)),
                    _pageDropdown(_toPage, (v) => setState(() {
                      _toPage = v;
                      if (_fromPage > v) _fromPage = v;
                    })),
                    const SizedBox(width: 16),
                    const Text('Time', style: TextStyle(fontSize: 20)),
                    DropdownButton<String>(
                      value: _meter,
                      style: const TextStyle(fontSize: 20, color: Colors.black),
                      items: [
                        for (final m in _meters)
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _meter = v ?? _meter),
                    ),
                    const SizedBox(width: 16),
                    const Text('Key', style: TextStyle(fontSize: 20)),
                    DropdownButton<String>(
                      value: _scale,
                      style: const TextStyle(fontSize: 20, color: Colors.black),
                      items: [
                        for (final s in widget.scales)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _scale = v ?? _scale),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (hasPdf)
                Wrap(
                  spacing: 16,
                  children: [
                    _button('Recognize', Colors.green, _recognizeOnDevice),
                    _button('Use AI', Colors.blue, _recognizeWithAi),
                  ],
                ),
              if (_busy) const LinearProgressIndicator(),
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _status,
                    style: const TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ),
              for (final w in _warnings)
                Text(w, style: const TextStyle(fontSize: 16, color: Colors.orange)),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_pages.isNotEmpty)
                      SizedBox(
                        width: 220,
                        child: ListView(
                          children: [
                            for (final p in _pages)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, right: 8),
                                child: InkWell(
                                  onTap: () => _showPage(p),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                    ),
                                    child: Image.memory(p.png, fit: BoxFit.contain),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'The transcription will appear here.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _button('Close', Colors.black, () => Navigator.pop(context)),
                  _button(
                    'Use transcription',
                    Colors.green,
                        () {
                      final t = _text.text.trim();
                      if (t.isEmpty) return;
                      Navigator.pop(context, t);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-size page, to compare with the transcription.
  void _showPage(OmrPdfPage page) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.memory(page.png, fit: BoxFit.contain),
        ),
      ),
    );
  }
}