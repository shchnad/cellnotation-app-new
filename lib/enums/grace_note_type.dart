import '../enums/note_duration.dart';

/// Grace note types. Two different ways a type's duration can be
/// determined:
///  - FIXED, absolute (the three Acciaccaturas): always exactly the
///    given [noteDuration]'s ticks, the same real note-duration value
///    regardless of which note it's attached to.
///  - RELATIVE (Appoggiatura): a fraction — [durationDivisor] — of the
///    anchor note's own ORIGINAL duration (see
///    Note.graceOriginalDurationTicks), so it scales with whichever
///    note it's added to rather than being one fixed tick count.
/// See [durationTicksFor] for the actual computation, and
/// CompositionController.maxGraceNotesForType for how many of a given
/// type fit before their total would exceed the anchor's own
/// original duration.
enum GraceNoteType {
  appoggiatura(
    'Appoggiatura',
    null,
    durationDivisor: 2,
    maxCountOverride: 1,
  ),
  long('Acciaccatura Long', NoteDuration.sixteenth),
  medium('Acciaccatura Medium', NoteDuration.thirtySecond),
  short('Acciaccatura Short', NoteDuration.sixtyFourth);

  final String label;

  /// Set for the fixed-duration (Acciaccatura) types; null for
  /// relative types like Appoggiatura, which use [durationDivisor]
  /// instead.
  final NoteDuration? noteDuration;

  /// Set for relative types like Appoggiatura (2 means "half the
  /// note's own original duration"); null for fixed-duration types,
  /// which use [noteDuration] instead.
  final int? durationDivisor;

  /// How many grace notes of THIS type one anchor note can have —
  /// null means the general limit (see
  /// CompositionController.maxGraceNotesPerNote) and the duration-fit
  /// calculation (see CompositionController.maxGraceNotesForType)
  /// apply instead. Only Appoggiatura overrides this, to exactly 1 —
  /// two halves would already consume the entire note, leaving
  /// nothing for the anchor itself.
  final int? maxCountOverride;

  const GraceNoteType(
      this.label,
      this.noteDuration, {
        this.durationDivisor,
        this.maxCountOverride,
      });

  /// This type's actual duration in ticks for a grace note whose
  /// anchor's own ORIGINAL duration (see
  /// Note.graceOriginalDurationTicks) is [originalDurationTicks] —
  /// either the fixed [noteDuration]'s ticks (ignoring
  /// [originalDurationTicks] entirely), or [originalDurationTicks]
  /// divided by [durationDivisor], whichever this type actually has
  /// set.
  int durationTicksFor(int originalDurationTicks) {
    final fixed = noteDuration;
    if (fixed != null) return fixed.ticks;
    final divisor = durationDivisor;
    if (divisor != null) {
      return ((originalDurationTicks / divisor).round()).clamp(1, 1 << 30);
    }
    return 1;
  }
}