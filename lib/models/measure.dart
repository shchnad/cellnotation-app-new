import 'package:music_composer/models/time_signature.dart';

class Measure {
  int id;
  int startTick;
  TimeSignature timeSignature;

  Measure({
    required this.id,
    required this.startTick,
    required this.timeSignature,
  });

  int get lengthTicks => timeSignature.totalTicks;
}