import '../enums/musical_dynamic.dart';

class DynamicEvent {
  int tick;
  MusicalDynamic musical_dynamic;

  DynamicEvent({
    required this.tick,
    required this.musical_dynamic,
  });

  Map<String, dynamic> toJson() => {
    'tick': tick,
    'dynamic': musical_dynamic.name
  };

  factory DynamicEvent.fromJson(Map<String, dynamic> json) {
    return DynamicEvent(
      tick: json['tick'] as int,
      musical_dynamic: MusicalDynamic.values.byName(json['dynamic'] as String),
    );
  }
}