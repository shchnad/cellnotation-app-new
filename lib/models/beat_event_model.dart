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


}