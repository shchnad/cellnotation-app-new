import '../enums/dynamic_change.dart';
import '../enums/musical_dynamic.dart';
import '../enums/tempo.dart';

class BeatEvent {
  final int tick;
  final Tempo? tempo;
  final MusicalDynamic? musicalDynamic;
  final DynamicChange? dynamicChange;

  const BeatEvent({
    required this.tick,
    this.tempo,
    this.musicalDynamic,
    this.dynamicChange,
  });

  BeatEvent copyWith({
    int? tick,
    Tempo? tempo,
    MusicalDynamic? musicalDynamic,
    DynamicChange? dynamicChange,
  }) {

    return BeatEvent(
      tick: tick ?? this.tick,
      tempo: tempo ?? this.tempo,
      musicalDynamic:
      musicalDynamic ?? this.musicalDynamic,
      dynamicChange:
      dynamicChange ?? this.dynamicChange,
    );
  }

  // ================= JSON =================

  Map<String, dynamic> toJson() {
    return {
      'tick': tick,
      if (tempo != null) 'tempo': tempo!.name,
      if (musicalDynamic != null) 'musicalDynamic': musicalDynamic!.name,
      if (dynamicChange != null) 'dynamicChange': dynamicChange!.name,
    };
  }

  factory BeatEvent.fromJson(Map<String, dynamic> json) {
    return BeatEvent(
      tick: json['tick'] as int,
      tempo: json['tempo'] == null ? null : Tempo.values.byName(json['tempo']),
      musicalDynamic: json['musicalDynamic'] == null
          ? null
          : MusicalDynamic.values.byName(json['musicalDynamic']),
      dynamicChange: json['dynamicChange'] == null
          ? null
          : DynamicChange.values.byName(json['dynamicChange']),
    );
  }

}