import 'dart:ui' show Offset;

import 'package:music_composer/models/time_signature.dart';
import 'beat_event_model.dart';
import '../enums/note_duration.dart';
import '../enums/hand.dart';

/// An arpeggio sign (wavy vertical line) before the chord at one beat
/// of a measure. In playback mode the chord's notes of [hands] are
/// played one after another (lowest first), each for an equal share of
/// the chord's duration.
class Arpeggio {
  /// Ticks from the start of the measure to the chord.
  final int offset;

  /// Which hands' notes are arpeggiated (left, right, or both).
  final Set<Hand> hands;

  const Arpeggio(this.offset, this.hands);

  Map<String, dynamic> toJson() => {
    'o': offset,
    'h': [for (final h in hands) h.name],
  };

  factory Arpeggio.fromJson(Map<String, dynamic> json) => Arpeggio(
    (json['o'] as num).toInt(),
    {
      for (final name in (json['h'] as List<dynamic>? ?? const []))
        for (final h in Hand.values)
          if (h.name == name) h
    },
  );
}

/// Reprise (repeat) signs that can be put on a measure in edit mode.
/// During playback the reprise is played by temporarily inserting the
/// repeated measures (see CompositionController.expandReprises).
enum RepriseMark {
  /// 𝄆 at the start of the measure: the reprise starts here.
  start,

  /// 𝄇 at the end of the measure: go back to the 𝄆 (or to the start
  /// of the piece when there is none).
  end,

  /// The measure belongs to the 1st ending (volta 1).
  volta1,

  /// The measure belongs to the 2nd ending (volta 2).
  volta2,

  /// 𝄋 Segno at the start of the measure.
  segno,

  /// "Fine" at the end of the measure.
  fine,

  /// "D.S. al Fine" at the end of the measure.
  dalSegnoAlFine,

  /// "To Coda" at the end of the measure.
  toCoda,

  /// "D.S. al Coda" at the end of the measure.
  dalSegnoAlCoda,

  /// Coda sign at the start of the measure.
  coda,
}

class Measure {

  int id;
  int startTick;
  TimeSignature timeSignature;
  String scaleName;
  // The scale this measure was created with (or last deliberately set
  // to via the scale picker) — untouched by raiseAllScales/
  // lowerAllScales, so "Reset Scales" can restore it.
  String originalScaleName;
  int pitchOffsetSemitones;
  final List<BeatEvent> beatEvents;

  // Extra ticks added to this measure's own duration by any fermata
  // stretches applied to its beats (see
  // CompositionController.applyFermataToBeat/deleteFermata) — folded
  // into [durationTicks] below so [endTick] and, via
  // Timeline.rebuild(), every LATER measure's own startTick correctly
  // account for the extra time, rather than a stretched beat silently
  // overflowing into (or being clipped by) the measure's original,
  // un-stretched boundary. Zero for a measure with no fermatas.
  int fermataExtraTicks;

  /// The note value the TEMPO counts, when it differs from this
  /// measure's own beat. Set when the measure's beats are split or
  /// united (see CompositionController.doubleSubdivisionForMeasureRange
  /// / halveSubdivisionForMeasureRange): splitting 6/8 into 12/16 makes
  /// each grid beat a sixteenth, but the tempo still counts the
  /// ORIGINAL eighth — otherwise splitting beats would silently halve
  /// the playback speed. Null means "the tempo counts this measure's
  /// own beat" (the normal case).
  NoteDuration? tempoBeatDuration;

  /// The note value one tempo beat lasts — what playback speed is
  /// computed from: seconds per tempo beat = 60 / bpm.
  NoteDuration get effectiveTempoBeat =>
      tempoBeatDuration ?? timeSignature.beatDuration;

  /// Red-pen marks that START in this measure (see InkStroke), so they
  /// move together with the measure.
  final List<InkStroke> inkStrokes;

  /// Reprise signs on this measure (see [RepriseMark]).
  final Set<RepriseMark> repriseMarks;

  /// True for a measure inserted only for playback — a copy of a
  /// measure that a reprise plays again. Removed when going back to
  /// edit mode and never saved.
  bool isTemporary;

  /// For a temporary copy: the number of the measure it copies, shown
  /// (in red) instead of its own position.
  int? copiedNumber;

  /// Arpeggio signs on chords of this measure (see [Arpeggio]).
  final List<Arpeggio> arpeggios;

  /// Beats split into equal columns (triplets, quintuplets…): beat
  /// index → number of columns (2–13). A beat not in the map is one
  /// column, as before.
  final Map<int, int> beatDivisions;

  Measure({
    required this.id,
    required this.startTick,
    required this.timeSignature,
    required this.scaleName,
    String? originalScaleName,
    this.pitchOffsetSemitones = 0,
    List<BeatEvent>? beatEvents,
    this.fermataExtraTicks = 0,
    this.tempoBeatDuration,
    List<InkStroke>? inkStrokes,
    Set<RepriseMark>? repriseMarks,
    this.isTemporary = false,
    this.copiedNumber,
    List<Arpeggio>? arpeggios,
    Map<int, int>? beatDivisions,
  }) :
        beatDivisions = beatDivisions ?? <int, int>{},
        arpeggios = arpeggios ?? <Arpeggio>[],
        repriseMarks = repriseMarks ?? <RepriseMark>{},
        originalScaleName = originalScaleName ?? scaleName,
        beatEvents = beatEvents ?? [],
        inkStrokes = inkStrokes ?? [];


  int get durationTicks =>
      timeSignature.durationTicks + fermataExtraTicks;

  int get endTick =>
      startTick + durationTicks;

  void addBeat() {
    timeSignature = timeSignature.addBeat();
  }

  void removeBeat() {
    timeSignature = timeSignature.removeBeat();
  }

  void changeBeatDuration(
      TimeSignature newSignature,
      ){
    timeSignature = newSignature;
  }

  void transposeUp(){
    pitchOffsetSemitones++;
  }

  void transposeDown(){
    pitchOffsetSemitones--;
  }


  void addBeatEvent(BeatEvent event){
    beatEvents.removeWhere(
            (e)=>e.tick == event.tick
    );
    beatEvents.add(event);
    beatEvents.sort(
            (a,b)=>a.tick.compareTo(b.tick)
    );
  }


  void removeBeatEvent(int tick){
    beatEvents.removeWhere(
            (e)=>e.tick == tick
    );
  }


  Measure copyWith({
    int? id,
    int? startTick,
    TimeSignature? timeSignature,
    String? scaleName,
    String? originalScaleName,
    int? pitchOffsetSemitones,
    List<BeatEvent>? beatEvents,
    int? fermataExtraTicks,
    Object? tempoBeatDuration = _keep,
    List<InkStroke>? inkStrokes,
    Set<RepriseMark>? repriseMarks,
    bool? isTemporary,
    Object? copiedNumber = _keep,
    List<Arpeggio>? arpeggios,
    Map<int, int>? beatDivisions,
  }) {
    return Measure(
      id: id ?? this.id,
      startTick: startTick ?? this.startTick,
      timeSignature: timeSignature ?? this.timeSignature,
      scaleName: scaleName ?? this.scaleName,
      originalScaleName: originalScaleName ?? this.originalScaleName,
      pitchOffsetSemitones:
      pitchOffsetSemitones ?? this.pitchOffsetSemitones,
      beatEvents:
      beatEvents ?? List<BeatEvent>.from(this.beatEvents),
      fermataExtraTicks: fermataExtraTicks ?? this.fermataExtraTicks,
      tempoBeatDuration: tempoBeatDuration == _keep
          ? this.tempoBeatDuration
          : tempoBeatDuration as NoteDuration?,
      inkStrokes: inkStrokes ?? List<InkStroke>.from(this.inkStrokes),
      repriseMarks: repriseMarks ?? Set<RepriseMark>.from(this.repriseMarks),
      isTemporary: isTemporary ?? this.isTemporary,
      copiedNumber:
      copiedNumber == _keep ? this.copiedNumber : copiedNumber as int?,
      arpeggios: arpeggios ?? List<Arpeggio>.from(this.arpeggios),
      beatDivisions: beatDivisions ?? Map<int, int>.from(this.beatDivisions),
    );
  }

  static const Object _keep = Object();

  // ================= JSON =================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTick': startTick,
      'timeSignature': timeSignature.toJson(),
      'scaleName': scaleName,
      'originalScaleName': originalScaleName,
      'pitchOffsetSemitones': pitchOffsetSemitones,
      'beatEvents': beatEvents.map((e) => e.toJson()).toList(),
      'fermataExtraTicks': fermataExtraTicks,
      if (tempoBeatDuration != null)
        'tempoBeatDuration': tempoBeatDuration!.name,
      if (inkStrokes.isNotEmpty)
        'inkStrokes': inkStrokes.map((s) => s.toJson()).toList(),
      if (repriseMarks.isNotEmpty)
        'reprise': [for (final m in repriseMarks) m.name],
      if (arpeggios.isNotEmpty)
        'arpeggios': [for (final a in arpeggios) a.toJson()],
      if (beatDivisions.isNotEmpty)
        'div': {
          for (final e in beatDivisions.entries) '${e.key}': e.value,
        },
    };
  }

  factory Measure.fromJson(Map<String, dynamic> json) {
    return Measure(
      id: json['id'] as int,
      startTick: json['startTick'] as int,
      timeSignature: TimeSignature.fromJson(json['timeSignature'] as Map<String, dynamic>),
      scaleName: json['scaleName'] as String,
      // Older saved compositions won't have this field — fall back to
      // scaleName so "reset" is at least a no-op instead of crashing.
      originalScaleName: json['originalScaleName'] as String? ?? json['scaleName'] as String,
      pitchOffsetSemitones: json['pitchOffsetSemitones'] as int,
      beatEvents: (json['beatEvents'] as List<dynamic>)
          .map((e) => BeatEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      // Older saved compositions won't have this field — default to
      // 0 (no fermata stretch) rather than crashing.
      fermataExtraTicks: json['fermataExtraTicks'] as int? ?? 0,
      // Older saved compositions won't have this — null means the
      // tempo counts the measure's own beat, as before.
      tempoBeatDuration: _noteDurationOrNull(json['tempoBeatDuration']),
      // Older saved compositions have no red-pen marks.
      inkStrokes: (json['inkStrokes'] as List<dynamic>? ?? const [])
          .map((s) => InkStroke.fromJson(s as Map<String, dynamic>))
          .toList(),
      // Older saved compositions have no reprise signs.
      repriseMarks: {
        for (final name in (json['reprise'] as List<dynamic>? ?? const []))
          for (final m in RepriseMark.values)
            if (m.name == name) m
      },
      // Older saved compositions have no arpeggios.
      arpeggios: [
        for (final a in (json['arpeggios'] as List<dynamic>? ?? const []))
          Arpeggio.fromJson(a as Map<String, dynamic>)
      ],
      // Older saved compositions have no split beats.
      beatDivisions: {
        for (final e
        in ((json['div'] as Map<String, dynamic>?) ?? const {}).entries)
          int.parse(e.key): (e.value as num).toInt(),
      },
    );
  }

  static NoteDuration? _noteDurationOrNull(dynamic raw) {
    if (raw == null) return null;
    try {
      return NoteDuration.values.byName(raw as String);
    } catch (_) {
      return null;
    }
  }

}

/// One red-pen mark drawn by finger on the grid (Pen mode — see
/// CompositionController.penMode), used to mark places to check later.
///
/// Stored inside the [Measure] the stroke STARTS in, with each point as
///   dx = ticks from that measure's own startTick (fractional),
///   dy = grid row (fractional),
/// so a mark stays on the same notes when the grid is zoomed, the cell
/// width changes, or measures are inserted/deleted before it.
class InkStroke {
  final List<Offset> points;

  InkStroke(this.points);

  Map<String, dynamic> toJson() => {
    // Flat [x0, y0, x1, y1, ...], rounded to keep saved files small.
    'p': [
      for (final p in points) ...[
        (p.dx * 10).round() / 10,
        (p.dy * 100).round() / 100,
      ],
    ],
  };

  factory InkStroke.fromJson(Map<String, dynamic> json) {
    final raw = (json['p'] as List<dynamic>? ?? const [])
        .map((v) => (v as num).toDouble())
        .toList();
    final points = <Offset>[];
    for (int i = 0; i + 1 < raw.length; i += 2) {
      points.add(Offset(raw[i], raw[i + 1]));
    }
    return InkStroke(points);
  }
}