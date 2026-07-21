import '../enums/dynamic_change.dart';

class DynamicChangeEvent {

  int tick;

  DynamicChange change;

  int endTick; // where the crescendo/diminuendo ends

  DynamicChangeEvent({
    required this.tick,
    required this.endTick,
    required this.change,
  });

  Map<String, dynamic> toJson() => {
    "tick": tick,
    "endTick": endTick,
    "change": change.name,
  };

  factory DynamicChangeEvent.fromJson(Map<String, dynamic> json) {
    return DynamicChangeEvent(
      tick: json["tick"],
      endTick: json["endTick"],
      change: DynamicChange.values.byName(json["change"]),
    );
  }
}