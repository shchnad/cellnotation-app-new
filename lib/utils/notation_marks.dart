import '../enums/hand.dart';
import '../models/measure.dart';

/// Repeat and arpeggio signs in a transcription.
///
/// These words can be written anywhere inside a measure (after its
/// "m<n>" line); they are taken out before the notes are parsed and put
/// on the measures after the import:
///
///   |:       𝄆 reprise starts at this measure
///   :|       𝄇 reprise ends at this measure
///   v1  v2   this measure is in volta 1 / volta 2
///   segno    𝄋 Segno on this measure
///   fine     Fine on this measure
///   dsfine   D.S. al Fine on this measure
///   tocoda   To Coda on this measure
///   dscoda   D.S. al Coda on this measure
///   coda     Coda sign on this measure
///   arp      (right after a beat, in an hr / hl line) arpeggio on the
///            chord at that beat for that hand, e.g. "hl b1 arp (…)d4"
///
/// A scale line ("re major", "fa sharp minor"…) inside a measure is a
/// key change: that measure and the ones after it get the new scale.
class NotationMarks {
  /// (0-based measure index, sign).
  final List<(int, RepriseMark)> reprise;

  /// (0-based measure index, beat as written e.g. 1 or 2.5, hand).
  final List<(int, double, Hand)> arpeggios;

  /// Key changes: (0-based measure index, scale name), in order.
  final List<(int, String)> scales;

  /// The transcription without these words, ready for the parser.
  final String cleanedText;

  NotationMarks(this.reprise, this.arpeggios, this.scales, this.cleanedText);

  bool get isEmpty => reprise.isEmpty && arpeggios.isEmpty && scales.isEmpty;
}

const Map<String, RepriseMark> _repriseWords = {
  '|:': RepriseMark.start,
  ':|': RepriseMark.end,
  'v1': RepriseMark.volta1,
  'v2': RepriseMark.volta2,
  'segno': RepriseMark.segno,
  'fine': RepriseMark.fine,
  'dsfine': RepriseMark.dalSegnoAlFine,
  'tocoda': RepriseMark.toCoda,
  'dscoda': RepriseMark.dalSegnoAlCoda,
  'coda': RepriseMark.coda,
};

final _measureToken = RegExp(r'^m(\d+)$');
final _scaleLine =
RegExp(r'^[a-z]+( (sharp|flat))? (major|minor)$', caseSensitive: false);
// b2, b2&1/2 (and the older b2.5, b2+1/3)
final _beatToken = RegExp(r'^b(\d+(?:\.\d+)?)(?:[&+](\d+)/(\d+))?$');

/// Takes the repeat / arpeggio words out of [text] (see [NotationMarks]).
NotationMarks extractNotationMarks(String text) {
  final reprise = <(int, RepriseMark)>[];
  final arpeggios = <(int, double, Hand)>[];
  final scales = <(int, String)>[];
  final lines = <String>[];
  int? measure; // 0-based
  for (final line in text.split('\n')) {
    // A scale line inside a measure: a key change.
    final trimmed = line.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (measure != null && _scaleLine.hasMatch(trimmed)) {
      scales.add((measure, trimmed.toLowerCase()));
      continue;
    }
    final kept = <String>[];
    Hand? hand;
    double? beat;
    for (final token in line.trim().split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final lower = token.toLowerCase();
      final m = _measureToken.firstMatch(lower);
      if (m != null) {
        measure = int.parse(m.group(1)!) - 1;
        kept.add(token);
        continue;
      }
      if (lower == 'hr') hand = Hand.right;
      if (lower == 'hl') hand = Hand.left;
      if (lower == 'ha') hand = Hand.additional;
      final b = _beatToken.firstMatch(lower);
      if (b != null) {
        beat = double.parse(b.group(1)!);
        if (b.group(2) != null) {
          final c = int.parse(b.group(3)!);
          if (c > 0) beat = beat! + int.parse(b.group(2)!) / c;
        }
      }

      final mark = _repriseWords[lower];
      if (mark != null && measure != null) {
        reprise.add((measure, mark));
        continue; // not passed on to the parser
      }
      if (lower == 'arp') {
        if (measure != null && hand != null && beat != null) {
          arpeggios.add((measure, beat, hand));
        }
        continue;
      }
      kept.add(token);
    }
    // A line that only held signs disappears completely.
    if (kept.isNotEmpty || line.trim().isEmpty) lines.add(kept.join(' '));
  }
  return NotationMarks(reprise, arpeggios, scales, lines.join('\n'));
}

final _measureNumber = RegExp(r'(^|\s)m(\d+)(?=\s|$)', multiLine: true);

/// Adds [offset] to every "m<n>" measure number of [text] — used to
/// import a transcription AFTER the measures a composition already has.
String shiftMeasureNumbers(String text, int offset) {
  if (offset == 0) return text;
  return text.replaceAllMapped(
    _measureNumber,
        (m) => '${m.group(1)}m${int.parse(m.group(2)!) + offset}',
  );
}