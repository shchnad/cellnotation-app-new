import '../enums/note_duration.dart';

class TimeSignature {
  final int beats;
  final NoteDuration beatUnit;

  const TimeSignature({
    required this.beats,
    required this.beatUnit,
  });

  /// ticks in one beat
  int get ticksPerBeat => beatUnit.ticks;

  /// total ticks in one measure
  int get totalTicks => beats * beatUnit.ticks;
}