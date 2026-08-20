import '../enums/accidental.dart';
import '../enums/articulation.dart';
import '../enums/hand.dart';
import '../enums/note_duration.dart';

/// Greedily decomposes [ticks] into a list of NoteDuration values
/// (largest first) summing to it — e.g. an eighth+half combination's
/// ticks decomposes back into [half, eighth]. Used to display a
/// note's duration as a readable combination (see note_dialog.dart),
/// to pre-seed combined_duration_dialog.dart's own combination when
/// reopening it, and to convert a real Note's durationTicks back
/// into an ImportEvent's durationParts when exporting (see
/// CompositionController.exportMeasureRange). Returns an empty list
/// if [ticks] <= 0. Any note whose duration was set either via a
/// single NoteDuration or via combined_duration_dialog.dart
/// decomposes exactly; a genuinely non-standard tick count (which
/// shouldn't normally reach here — grace notes use a separate
/// display path) just stops once no remaining standard duration fits
/// the leftover amount, silently dropping that remainder rather than
/// showing an inexact label.
List<NoteDuration> decomposeDurationTicks(int ticks) {
  final result = <NoteDuration>[];
  var remaining = ticks;
  final sortedDesc = NoteDuration.values.toList()
    ..sort((a, b) => b.ticks.compareTo(a.ticks));
  for (final d in sortedDesc) {
    while (d.ticks > 0 && remaining >= d.ticks) {
      result.add(d);
      remaining -= d.ticks;
    }
  }
  return result;
}

/// One pitch's readable label, e.g. "Re6" or "La3♭" — matches the
/// solfège+octave(+accidental) format transcriptions have used
/// throughout this app.
String _pitchLabel(ImportNoteSpec p) {
  const names = {1: 'Do', 2: 'Re', 3: 'Mi', 4: 'Fa', 5: 'Sol', 6: 'La', 7: 'Si'};
  final name = names[p.degree] ?? '?';
  final accidentalSign = switch (p.accidental) {
    null => '',
    Accidental.sharp => '♯',
    Accidental.flat => '♭',
    _ => '',
  };
  // Articulation was captured on ImportNoteSpec all along but never
  // actually shown here — the data was right, only the text display
  // was missing it.
  final articulationSuffix =
  p.articulation == null ? '' : ' (${p.articulation!.name})';
  final legatoSuffix = p.legato ? ' (legato)' : '';
  return '$name${p.octave}$accidentalSign$articulationSuffix$legatoSuffix';
}

/// A combined duration's readable label, e.g. "eighth" or
/// "eighth+half" for a tie.
String _durationLabel(List<NoteDuration> parts) =>
    parts.map((d) => d.label.toLowerCase()).join('+');

/// Formats [importMeasures] as plain, human-readable text in the same
/// "Measure N — RH: ..., LH: ..." style used throughout this
/// conversation's manual transcription — meant for a quick,
/// side-by-side comparison against an earlier transcription (see
/// CompositionController.exportMeasureRange), not for re-importing
/// (that stays structured, via the ImportMeasure list itself).
String formatImportMeasuresAsText(List<ImportMeasure> importMeasures) {
  final buffer = StringBuffer();

  for (final measure in importMeasures) {
    buffer.writeln('Measure ${measure.measureIndex + 1}');

    for (final hand in [Hand.right, Hand.left]) {
      final handEvents = measure.events
          .where((e) => e.pitches.isNotEmpty && e.pitches.first.hand == hand)
          .toList()
        ..sort((a, b) => a.beat.compareTo(b.beat));
      final handLabel = hand == Hand.right ? 'RH' : 'LH';

      if (handEvents.isEmpty) {
        buffer.writeln('  $handLabel: (no notes)');
        continue;
      }

      final eventStrings = handEvents.map((e) {
        final pitchStr = e.pitches.length == 1
            ? _pitchLabel(e.pitches.first)
            : 'chord [${e.pitches.map(_pitchLabel).join(', ')}]';
        return '${_durationLabel(e.durationParts)} $pitchStr';
      }).join(', ');

      buffer.writeln('  $handLabel: $eventStrings');
    }

    buffer.writeln();
  }

  return buffer.toString();
}

/// One pitch within an [ImportEvent] — a single note, or one note of
/// a chord when an event carries more than one. Expressed as scale
/// degree (1=Do, 2=Re, 3=Mi, 4=Fa, 5=Sol, 6=La, 7=Si) + octave,
/// matching how notes are dictated/transcribed throughout this app
/// (e.g. "Re6" = degree 2, octave 6). [row] mirrors exactly how the
/// rest of the app derives a row from degree+octave
/// (CompositionController.getDegree does the reverse:
/// `row % 7 + 1`), so an imported note lands on the same row a
/// manually-placed one at that degree/octave would.
class ImportNoteSpec {
  final int degree; // 1-7
  final int octave;
  final Accidental? accidental;
  final Hand hand;
  final Articulation? articulation;
  final bool legato;

  const ImportNoteSpec({
    required this.degree,
    required this.octave,
    this.accidental,
    required this.hand,
    this.articulation,
    this.legato = false,
  });

  int get row => octave * 7 + (degree - 1);
}

/// One musical event at a given beat within a measure — either a
/// rest ([pitches] empty) or one or more simultaneous notes (a
/// chord, when [pitches].length > 1), all sharing the same start
/// beat and duration.
///
/// [beat] is 1-based, matching how beats are dictated/transcribed
/// throughout this app: beat 1 is the first beat of the measure,
/// 1.5 is an eighth-note subdivision after it, 2 is the second beat,
/// and so on. Only halves are supported (matching eighth-note
/// subdivisions of a quarter-note beat) — finer subdivisions
/// (sixteenth-note offsets, triplets) aren't representable this way.
///
/// [durationParts] is a list rather than a single NoteDuration so a
/// tie across a barline (or any other combined duration) can be
/// expressed the same way CombinedDurationDialog builds one — e.g.
/// [NoteDuration.eighth, NoteDuration.half] for an eighth tied into a
/// half note. The list is summed when the actual Note is created
/// (see CompositionController.importTranscribedMeasures).
class ImportEvent {
  final double beat;
  final List<NoteDuration> durationParts;
  final List<ImportNoteSpec> pitches;

  const ImportEvent({
    required this.beat,
    required this.durationParts,
    this.pitches = const [],
  });

  int get durationTicks =>
      durationParts.fold<int>(0, (sum, d) => sum + d.ticks);
}

/// One measure's worth of transcribed events — [measureIndex] is
/// 0-based, matching every other 0-based measure index used
/// throughout this app (e.g. CompositionController.measures).
class ImportMeasure {
  final int measureIndex;
  final List<ImportEvent> events;

  const ImportMeasure({
    required this.measureIndex,
    required this.events,
  });
}

/// One problem encountered while importing — the event that couldn't
/// be created, and why. Collected rather than thrown, so one bad
/// event doesn't abort the whole import; see
/// CompositionController.importTranscribedMeasures's return value.
/// [measureIndex]/[beat] are null for a batch-level warning (e.g.
/// "this batch was already imported") that isn't about any one
/// specific event.
class ImportWarning {
  final int? measureIndex;
  final double? beat;
  final String message;

  const ImportWarning({
    this.measureIndex,
    this.beat,
    required this.message,
  });

  @override
  String toString() => measureIndex == null
      ? message
      : 'Measure ${measureIndex! + 1}, beat $beat: $message';
}

/// A named, orderable group of measures to import — see
/// import_batches.dart for the actual registry, kept in the order
/// batches should be imported in (earlier batches first). [label] is
/// also the key CompositionController uses to track which batches
/// have already been imported into the current composition (see
/// CompositionController.importedBatchLabels /
/// CompositionController.importBatch), so it should be unique and
/// stable — don't rename an existing batch's label once it might
/// already have been imported somewhere.
class ImportBatch {
  final String label;
  final List<ImportMeasure> measures;

  const ImportBatch({
    required this.label,
    required this.measures,
  });
}