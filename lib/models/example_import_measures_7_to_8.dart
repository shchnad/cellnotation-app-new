// EXAMPLE — not part of the app itself. Measures 7-8 continuing on
// from example_import_measures_1_to_6.dart (kept in a separate file
// so either batch can be imported independently, or both together,
// into a composition that already has enough measures).
//
// UNVERIFIED — unlike measures 1-6 (which were corrected
// measure-by-measure), these pitches are still my own best-guess
// reading of the image and have not been checked. Articulation
// (staccato/accent) is deliberately left off entirely for now, per
// request — every note here is plain, with no Articulation set.

import '../models/note_import.dart';
import '../enums/accidental.dart';
import '../enums/hand.dart';
import '../enums/note_duration.dart';

final List<ImportMeasure> exampleMeasures7to8 = [

  // MEASURE 7 (index 6) — dynamic f, RH descending run; LH repeats
  // the same chord pattern as Measure 6.
  ImportMeasure(
    measureIndex: 6,
    events: [
      ImportEvent(beat: 1, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 5, octave: 5, hand: Hand.right)]), // Sol5
      ImportEvent(beat: 1.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 4, octave: 5, hand: Hand.right)]), // Fa5
      ImportEvent(beat: 2, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 3, octave: 5, hand: Hand.right)]), // Mi5
      ImportEvent(beat: 2.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 2, octave: 5, hand: Hand.right)]), // Re5
      ImportEvent(beat: 3, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 1, octave: 5, hand: Hand.right)]), // Do5
      ImportEvent(beat: 3.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 7, octave: 4, hand: Hand.right)]), // Si4
      ImportEvent(beat: 4, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 6, octave: 4, hand: Hand.right)]), // La4

      ImportEvent(beat: 1, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 1, octave: 3, hand: Hand.left)]), // Do3
      ImportEvent(
        beat: 2,
        durationParts: [NoteDuration.quarter],
        pitches: [
          ImportNoteSpec(degree: 4, octave: 3, hand: Hand.left), // Fa3
          ImportNoteSpec(degree: 6, octave: 3, hand: Hand.left), // La3
        ],
      ),
      ImportEvent(
        beat: 3,
        durationParts: [NoteDuration.quarter],
        pitches: [
          ImportNoteSpec(degree: 3, octave: 3, hand: Hand.left), // Mi3
          ImportNoteSpec(degree: 5, octave: 3, hand: Hand.left), // Sol3
        ],
      ),
      // beat 4: LH quarter rest — no event.
    ],
  ),

  // MEASURE 8 (index 7) — diminuendo hairpin; RH is a tied dotted
  // half (combined duration) into two closing eighths. LH repeats the
  // same chord pattern once more.
  ImportMeasure(
    measureIndex: 7,
    events: [
      ImportEvent(
        beat: 1,
        // dotted half = quarter + quarter + quarter, expressed here
        // as a combined duration the same way a tie is elsewhere.
        durationParts: [
          NoteDuration.quarter,
          NoteDuration.quarter,
          NoteDuration.quarter,
        ],
        pitches: [ImportNoteSpec(degree: 1, octave: 5, hand: Hand.right)], // Do5
      ),
      ImportEvent(beat: 4, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 2, octave: 5, hand: Hand.right)]), // Re5
      ImportEvent(beat: 4.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(
              degree: 4, octave: 5, accidental: Accidental.sharp,
              hand: Hand.right)]), // Fa5 sharp

      ImportEvent(beat: 1, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 1, octave: 3, hand: Hand.left)]), // Do3
      ImportEvent(
        beat: 2,
        durationParts: [NoteDuration.quarter],
        pitches: [
          ImportNoteSpec(degree: 4, octave: 3, hand: Hand.left), // Fa3
          ImportNoteSpec(degree: 6, octave: 3, hand: Hand.left), // La3
        ],
      ),
      ImportEvent(
        beat: 3,
        durationParts: [NoteDuration.quarter],
        pitches: [
          ImportNoteSpec(degree: 3, octave: 3, hand: Hand.left), // Mi3
          ImportNoteSpec(degree: 5, octave: 3, hand: Hand.left), // Sol3
        ],
      ),
      // beat 4: LH quarter rest — no event.
    ],
  ),
];

// Usage — importing just this batch:
//
//   final warnings = controller.importTranscribedMeasures(exampleMeasures7to8);
//
// Importing both batches together (measures 1-8):
//
//   final warnings = controller.importTranscribedMeasures([
//     ...exampleMeasures1to6,
//     ...exampleMeasures7to8,
//   ]);