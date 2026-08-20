// EXAMPLE — not part of the app itself. Shows how the verified
// measures 1-6 transcription from earlier in this conversation maps
// onto ImportMeasure/ImportEvent/ImportNoteSpec, and how you'd call
// CompositionController.importTranscribedMeasures with it.
//
// KNOWN LIMITATION surfaced by this example: Note has a single
// `articulation` field, so a chord transcribed with BOTH accent and
// staccato (Measure 4, LH beat 3) can't be represented exactly here
// — accent is kept (the more structurally important of the two) and
// staccato is dropped. If you need both simultaneously, Note's
// model would need a second, independent articulation-style flag
// the same way `legato` was split out from Articulation.

import '../models/note_import.dart';
import '../enums/accidental.dart';
import '../enums/articulation.dart';
import '../enums/hand.dart';
import '../enums/note_duration.dart';

final List<ImportMeasure> exampleMeasures1to6 = [

  // MEASURE 1 — RH descending-octave run, LH silent whole measure.
  ImportMeasure(
    measureIndex: 0,
    events: [
      ImportEvent(
        beat: 1,
        durationParts: [NoteDuration.eighth],
        pitches: [ImportNoteSpec(degree: 2, octave: 6, hand: Hand.right)], // Re6
      ),
      ImportEvent(
        beat: 1.5,
        durationParts: [NoteDuration.eighth],
        pitches: [ImportNoteSpec(degree: 3, octave: 6, hand: Hand.right)], // Mi6
      ),
      ImportEvent(
        beat: 2,
        durationParts: [NoteDuration.eighth],
        pitches: [ImportNoteSpec(degree: 1, octave: 6, hand: Hand.right)], // Do6
      ),
      ImportEvent(
        beat: 2.5,
        durationParts: [NoteDuration.quarter],
        pitches: [ImportNoteSpec(degree: 6, octave: 5, hand: Hand.right)], // La5
      ),
      ImportEvent(
        beat: 3.5,
        durationParts: [NoteDuration.eighth],
        pitches: [ImportNoteSpec(degree: 7, octave: 5, hand: Hand.right)], // Si5
      ),
      ImportEvent(
        beat: 4,
        durationParts: [NoteDuration.quarter],
        pitches: [ImportNoteSpec(degree: 5, octave: 5, hand: Hand.right)], // Sol5
      ),
      // LH: rest, whole measure — no events needed at all.
    ],
  ),

  // MEASURE 2 — same shape as Measure 1, one octave down.
  ImportMeasure(
    measureIndex: 1,
    events: [
      ImportEvent(beat: 1, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 2, octave: 5, hand: Hand.right)]), // Re5
      ImportEvent(beat: 1.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 3, octave: 5, hand: Hand.right)]), // Mi5
      ImportEvent(beat: 2, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 1, octave: 5, hand: Hand.right)]), // Do5
      ImportEvent(beat: 2.5, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 6, octave: 4, hand: Hand.right)]), // La4
      ImportEvent(beat: 3.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 7, octave: 4, hand: Hand.right)]), // Si4
      ImportEvent(beat: 4, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 5, octave: 4, hand: Hand.right)]), // Sol4
    ],
  ),

  // MEASURE 3 — same RH shape again, but beat 4 is a rest instead of
  // Sol; LH enters with two eighths (La3, La3 flat) at beats 3.5-4.
  ImportMeasure(
    measureIndex: 2,
    events: [
      ImportEvent(beat: 1, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 2, octave: 4, hand: Hand.right)]), // Re4
      ImportEvent(beat: 1.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 3, octave: 4, hand: Hand.right)]), // Mi4
      ImportEvent(beat: 2, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 1, octave: 4, hand: Hand.right)]), // Do4
      ImportEvent(beat: 2.5, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 6, octave: 3, hand: Hand.right)]), // La3
      ImportEvent(beat: 3.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 7, octave: 3, hand: Hand.right)]), // Si3
      // beat 4: RH quarter rest — no event.

      // LH: beats 1-3 are quarter rests (no events); enters at 3.5.
      ImportEvent(beat: 3.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 6, octave: 3, hand: Hand.left)]), // La3
      ImportEvent(beat: 4, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(
              degree: 6, octave: 3, accidental: Accidental.flat,
              hand: Hand.left)]), // La3 flat
    ],
  ),

  // MEASURE 4 — RH: half rest, then an accented 3-note chord, then
  // two eighths. LH: staccato quarter, rest, accented staccato
  // chord (accent kept, staccato dropped — see file-level note),
  // rest.
  ImportMeasure(
    measureIndex: 3,
    events: [
      // beats 1-2: RH half rest — no event.
      ImportEvent(
        beat: 3,
        durationParts: [NoteDuration.quarter],
        pitches: [
          ImportNoteSpec(degree: 6, octave: 3, hand: Hand.right,
              articulation: Articulation.accent), // La3
          ImportNoteSpec(degree: 4, octave: 4, hand: Hand.right,
              articulation: Articulation.accent), // Fa4
          ImportNoteSpec(degree: 5, octave: 4, hand: Hand.right,
              articulation: Articulation.accent), // Sol4
        ],
      ),
      ImportEvent(beat: 4, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 2, octave: 4, hand: Hand.right)]), // Re4
      ImportEvent(beat: 4.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(
              degree: 2, octave: 4, accidental: Accidental.sharp,
              hand: Hand.right)]), // Re4 sharp

      ImportEvent(
        beat: 1,
        durationParts: [NoteDuration.quarter],
        pitches: [ImportNoteSpec(degree: 5, octave: 3, hand: Hand.left,
            articulation: Articulation.staccato)], // Sol3, staccato
      ),
      // beat 2: LH quarter rest — no event.
      ImportEvent(
        beat: 3,
        durationParts: [NoteDuration.quarter],
        pitches: [
          ImportNoteSpec(degree: 5, octave: 2, hand: Hand.left,
              articulation: Articulation.accent), // Sol2
          ImportNoteSpec(degree: 5, octave: 3, hand: Hand.left,
              articulation: Articulation.accent), // Sol3
        ],
      ),
      // beat 4: LH quarter rest — no event.
    ],
  ),

  // MEASURE 5 — repeat starts here (dynamic p, not represented in
  // this data model — dynamics are separate DynamicEvent objects,
  // set via CompositionController.updateDynamicEvent, not part of a
  // Note). RH beat 4.5's Do5 uses a COMBINED duration (eighth+half)
  // for the tie that continues sounding into Measure 6 — see
  // CombinedDurationDialog for why this is one Note, not two tied
  // ones.
  ImportMeasure(
    measureIndex: 4,
    events: [
      ImportEvent(beat: 1, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 3, octave: 4, hand: Hand.right)]), // Mi4
      ImportEvent(beat: 1.5, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 1, octave: 5, hand: Hand.right)]), // Do5
      ImportEvent(beat: 2.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 3, octave: 4, hand: Hand.right)]), // Mi4
      ImportEvent(beat: 3, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 1, octave: 5, hand: Hand.right)]), // Do5
      ImportEvent(beat: 4, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 3, octave: 4, hand: Hand.right)]), // Mi4
      ImportEvent(
        beat: 4.5,
        durationParts: [NoteDuration.eighth, NoteDuration.half], // combined — sustains into m6
        pitches: [ImportNoteSpec(degree: 1, octave: 5, hand: Hand.right)], // Do5
      ),

      ImportEvent(beat: 1, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 1, octave: 3, hand: Hand.left)]), // Do3
      ImportEvent(
        beat: 2,
        durationParts: [NoteDuration.quarter],
        pitches: [
          ImportNoteSpec(degree: 3, octave: 3, hand: Hand.left), // Mi3
          ImportNoteSpec(degree: 5, octave: 3, hand: Hand.left), // Sol3
        ],
      ),
      ImportEvent(beat: 3, durationParts: [NoteDuration.quarter],
          pitches: [ImportNoteSpec(degree: 1, octave: 3, hand: Hand.left)]), // Do3
      ImportEvent(
        beat: 4,
        durationParts: [NoteDuration.quarter],
        pitches: [
          ImportNoteSpec(degree: 3, octave: 3, hand: Hand.left), // Mi3
          ImportNoteSpec(degree: 7, octave: 3, accidental: Accidental.flat,
              hand: Hand.left), // Si3 flat
        ],
      ),
    ],
  ),

  // MEASURE 6 — beats 1-2 RH are already covered by the Do5 note
  // sustaining over from Measure 5 (its 2.5-beat duration runs
  // exactly through here), so no RH event starts until beat 3.
  ImportMeasure(
    measureIndex: 5,
    events: [
      ImportEvent(beat: 3, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 1, octave: 5, hand: Hand.right)]), // Do5
      ImportEvent(beat: 3.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 1, octave: 5, hand: Hand.right)]), // Do5
      ImportEvent(beat: 4, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(degree: 2, octave: 5, hand: Hand.right)]), // Re5
      ImportEvent(beat: 4.5, durationParts: [NoteDuration.eighth],
          pitches: [ImportNoteSpec(
              degree: 2, octave: 5, accidental: Accidental.sharp,
              hand: Hand.right)]), // Re5 sharp

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

// Usage:
//
//   final warnings = controller.importTranscribedMeasures(exampleMeasures1to6);
//   if (warnings.isNotEmpty) {
//     for (final w in warnings) {
//       print(w); // "Measure 3, beat 3.5: ..." etc.
//     }
//   }