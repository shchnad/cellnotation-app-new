import '../enums/note_duration.dart';

class TimeSignature {
  final int beats;
  final NoteDuration beatDuration;

  const TimeSignature({
    required this.beats, //numerator
    required this.beatDuration, //denominator
  });

  int get ticksPerBeat => beatDuration.ticks;

  int get durationTicks => beats * ticksPerBeat;

  TimeSignature copyWith({
    int? beats,
    NoteDuration? beatDuration,
  }) {
    return TimeSignature(
      beats: beats ?? this.beats,
      beatDuration: beatDuration ?? this.beatDuration,
    );
  }

  TimeSignature addBeat() {
    return copyWith(
      beats: beats + 1,
    );
  }


  TimeSignature removeBeat() {
    if (beats <= 1) {
      return this;
    }

    return copyWith(
      beats: beats - 1,
    );
  }


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TimeSignature &&
            beats == other.beats &&
            beatDuration == other.beatDuration;
  }


  @override
  int get hashCode =>
      Object.hash(
        beats,
        beatDuration,
      );


  @override
  String toString() {
    return '$beats/${beatDuration.label}';
  }
}