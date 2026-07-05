import '../enums/musical_dynamic.dart';

class DynamicEvent {
  int tick;
  MusicalDynamic dynamic;

  DynamicEvent({
    required this.tick,
    required this.dynamic,
  });
}