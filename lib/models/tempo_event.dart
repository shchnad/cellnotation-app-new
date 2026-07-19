class TempoEvent {
  int tick;
  int bpm;

  TempoEvent({
    required this.tick,
    required this.bpm,
  });

  Map<String, dynamic> toJson() => {'tick': tick, 'bpm': bpm};

  factory TempoEvent.fromJson(Map<String, dynamic> json) {
    return TempoEvent(
      tick: json['tick'] as int,
      bpm: json['bpm'] as int,
    );
  }
}