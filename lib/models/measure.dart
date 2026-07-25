import 'package:music_composer/models/time_signature.dart';
import 'beat_event_model.dart';

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

  Measure({
    required this.id,
    required this.startTick,
    required this.timeSignature,
    required this.scaleName,
    String? originalScaleName,
    this.pitchOffsetSemitones = 0,
    List<BeatEvent>? beatEvents,
  }) :
        originalScaleName = originalScaleName ?? scaleName,
        beatEvents = beatEvents ?? [];


  int get durationTicks =>
      timeSignature.durationTicks;

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
    );
  }

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
    );
  }

}