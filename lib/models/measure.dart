import 'time_signature.dart';


class Measure {

  int id;

  int startTick;


  TimeSignature timeSignature;


  // Example:
  // major G
  // minor A
  String scaleName;


  // Used by global scale up/down buttons
  int pitchOffsetSemitones;



  Measure({

    required this.id,

    required this.startTick,

    required this.timeSignature,

    required this.scaleName,

    this.pitchOffsetSemitones = 0,

  });



  /// Length of this measure in timeline ticks
  int get durationTicks =>
      timeSignature.durationTicks;



  /// Last occupied tick
  int get endTick =>
      startTick + durationTicks;



  // -------------------------------
  // Beat editing
  // -------------------------------


  void addBeat(){

    timeSignature.addBeat();
  }



  void removeBeat(){

    timeSignature.removeBeat();
  }



  void changeBeatDuration(
      TimeSignature newSignature,
      ){

    timeSignature = newSignature;
  }



  // -------------------------------
  // Scale editing
  // -------------------------------


  void transposeUp(){

    pitchOffsetSemitones++;
  }



  void transposeDown(){

    pitchOffsetSemitones--;
  }



  // -------------------------------
  // Copy
  // -------------------------------


  Measure copyWith({

    int? id,

    int? startTick,

    TimeSignature? timeSignature,

    String? scaleName,

    int? pitchOffsetSemitones,

  }){

    return Measure(

      id:
      id ?? this.id,

      startTick:
      startTick ?? this.startTick,

      timeSignature:
      timeSignature ?? this.timeSignature,

      scaleName:
      scaleName ?? this.scaleName,

      pitchOffsetSemitones:
      pitchOffsetSemitones ??
          this.pitchOffsetSemitones,

    );
  }
}