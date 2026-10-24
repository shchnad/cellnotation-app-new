import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

/// Sends one page image to the "transcribeSheetMusic" Cloud Function
/// (functions/index.js), which asks Claude to read the page and write
/// it in the line-position transcription. The API key stays on the
/// server — the app never sees it.
///
/// [firstMeasure] is the number the page's first measure should get
/// (continuing from earlier pages); [timeSignature] (e.g. "6/8") keeps
/// later pages consistent with the first one; [draft] is the
/// on-device result for this page, given to the AI as a rough hint.
Future<String> transcribePageWithAi({
  required Uint8List png,
  required String scaleName,
  required int firstMeasure,
  String? timeSignature,
  String? draft,
}) async {
  final callable = FirebaseFunctions.instance.httpsCallable(
    'transcribeSheetMusic',
    options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
  );
  final result = await callable.call(<String, dynamic>{
    'image': base64Encode(png),
    'mediaType': 'image/png',
    'scale': scaleName,
    'firstMeasure': firstMeasure,
    if (timeSignature != null) 'timeSignature': timeSignature,
    if (draft != null && draft.isNotEmpty) 'draft': draft,
  });
  final data = result.data;
  if (data is Map && data['text'] is String) {
    return (data['text'] as String).trim();
  }
  throw Exception('The AI service returned no transcription.');
}

/// Joins page transcriptions (each with its own scale and "t" lines)
/// into one text: the header lines are kept from the first page only.
String joinPageTranscriptions(List<String> pages) {
  final out = <String>[];
  for (int p = 0; p < pages.length; p++) {
    for (final raw in const LineSplitter().convert(pages[p])) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final isHeader = RegExp(r'^t\d+/\d+$').hasMatch(line) ||
          RegExp(r'^\S.*\s(major|minor)$', caseSensitive: false).hasMatch(line);
      if (isHeader && p > 0) continue;
      out.add(line);
    }
  }
  return out.join('\n');
}

/// Highest "m<n>" measure number in a transcription (0 if none).
int lastMeasureNumber(String transcription) {
  int last = 0;
  for (final m in RegExp(r'(^|\s)m(\d+)(?=\s|$)', multiLine: true)
      .allMatches(transcription)) {
    final n = int.parse(m.group(2)!);
    if (n > last) last = n;
  }
  return last;
}

/// The "t<beats>/<den>" of a transcription, e.g. "6/8" (null if none).
String? timeSignatureOf(String transcription) {
  final m = RegExp(r'(^|\s)t(\d+/\d+)(?=\s|$)', multiLine: true)
      .firstMatch(transcription);
  return m?.group(2);
}