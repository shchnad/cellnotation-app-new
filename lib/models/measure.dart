import 'package:music_composer/models/time_signature.dart';
import 'beat_event_model.dart';
import '../enums/note_duration.dart';

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
  }) :
        originalScaleName = originalScaleName ?? scaleName,
        beatEvents = beatEvents ?? [];


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