import 'package:music_composer/models/time_signature.dart';

class Measure {
  int id;
  int startTick;
  TimeSignature signature;

  Measure({
    required this.id,
    required this.startTick,
    required this.signature,
  });

  int get lengthTicks => signature.totalTicks;
}