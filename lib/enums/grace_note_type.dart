import '../enums/note_duration.dart';

/// Grace note types. Every type takes a fixed PART of the duration of
/// the note it is added to (its ORIGINAL duration — see
/// Note.graceOriginalDurationTicks), and each type allows only as many
/// grace notes as leave the main note some of its time:
///
///  - Appoggiatura:        1/2 of the note — at most 1 per note;
///  - Acciaccatura Long:   1/4 of the note — at most 3 per note;
///  - Acciaccatura Medium: 1/6 of the note — at most 4 per note;
///  - Acciaccatura Short:  1/8 of the note — at most 6 per note.
///
/// See [durationTicksFor] for the length in ticks, and
/// CompositionController.maxGraceNotesForType for how many fit.
enum GraceNoteType {
  appoggiatura('Appoggiatura', null, durationDivisor: 2, maxCountOverride: 1),
  long('Acciaccatura Long', null, durationDivisor: 4, maxCountOverride: 3),
  medium('Acciaccatura Medium', null, durationDivisor: 6, maxCountOverride: 4),
  short('Acciaccatura Short', null, durationDivisor: 8, maxCountOverride: 6);

  final String label;

  /// Not used any more (every type is now a part of the note); kept so
  /// code that reads it keeps compiling. Always null.
  final NoteDuration? noteDuration;

  /// Which part of the note one grace note of this type takes: 2 = a
  /// half, 4 = a quarter, 6 = a sixth, 8 = an eighth.
  final int? durationDivisor;

  /// How many grace notes of this type one note can have.
  final int? maxCountOverride;

  const GraceNoteType(
      this.label,
      this.noteDuration, {
        this.durationDivisor,
        this.maxCountOverride,
      });

  /// The length in ticks of one grace note of this type on a note whose
  /// ORIGINAL duration is [originalDurationTicks]: that duration divided
  /// by [durationDivisor], rounded to whole ticks (at least 1).
  int durationTicksFor(int originalDurationTicks) {
    final divisor = durationDivisor ?? 2;
    return ((originalDurationTicks / divisor).round()).clamp(1, 1 << 30);
  }
}