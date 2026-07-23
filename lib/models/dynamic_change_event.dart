import '../enums/dynamic_change.dart';

class DynamicChangeEvent {
  int tick;
  DynamicChange dynamic_change;

  DynamicChangeEvent({
    required this.tick,
    required this.dynamic_change,
  });

  Map<String, dynamic> toJson() => {
    'tick': tick,
    'dynamic_change': dynamic_change.name
  };

  factory DynamicChangeEvent.fromJson(Map<String, dynamic> json) {
    return DynamicChangeEvent(
      tick: json['tick'] as int,
      dynamic_change: DynamicChange.values.byName(json['dynamic_change'] as String),
    );
  }
}