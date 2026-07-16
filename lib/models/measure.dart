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

}