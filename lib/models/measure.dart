import 'package:music_composer/models/time_signature.dart';
import 'beat_event_model.dart';

class Measure {

  int id;
  int startTick;
  TimeSignature timeSignature;
  String scaleName;
  int pitchOffsetSemitones;
  final List<BeatEvent> beatEvents;

  Measure({
    required this.id,
    required this.startTick,
    required this.timeSignature,
    required this.scaleName,
    this.pitchOffsetSemitones = 0,
    List<BeatEvent>? beatEvents,
  }) :
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
    int? pitchOffsetSemitones,
    List<BeatEvent>? beatEvents,
  }) {
    return Measure(
      id: id ?? this.id,
      startTick: startTick ?? this.startTick,
      timeSignature: timeSignature ?? this.timeSignature,
      scaleName: scaleName ?? this.scaleName,
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
      pitchOffsetSemitones: json['pitchOffsetSemitones'] as int,
      beatEvents: (json['beatEvents'] as List<dynamic>)
          .map((e) => BeatEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

}