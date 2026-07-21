import '../enums/tempo.dart';

class TempoEvent {

  final int tick;
  final Tempo tempo;

  TempoEvent({
    required this.tick,
    required this.tempo,
  });


  TempoEvent copyWith({
    int? tick,
    Tempo? tempo,
  }) {
    return TempoEvent(
      tick: tick ?? this.tick,
      tempo: tempo ?? this.tempo,
    );
  }


  Map<String,dynamic> toJson(){
    return {
      'tick': tick,
      'tempo': tempo.name,
    };
  }


  factory TempoEvent.fromJson(Map<String,dynamic> json){
    return TempoEvent(
      tick: json['tick'],
      tempo: Tempo.values.firstWhere(
            (e)=>e.name == json['tempo'],
      ),
    );
  }

}