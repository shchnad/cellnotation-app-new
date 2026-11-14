import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../models/time_signature.dart';
import '../utils/cellnotation_transcription_parser.dart';
import '../utils/notation_marks.dart';
import '../omr/sheet_music_pdf_import_screen.dart';

/// Lets the person paste/type a transcription in the line-position
/// notation worked out for reading directly off traditional sheet
/// music (see cellnotation_transcription_parser.dart for the full
/// syntax), parses it, and imports it into [controller] — the same
/// underlying CompositionController.importBatch used by the existing
/// word-based dictation import, just fed from free-form pasted text
/// instead of a fixed registry of pre-written batches.
///
/// Parse errors (malformed tokens — the text didn't match the
/// notation's own syntax) are shown separately from import warnings
/// (valid tokens that still couldn't be placed, e.g. because they'd
/// overlap an existing note) — see TranscriptionParseResult's own
/// doc for why these are kept distinct.
void sheetMusicTranscriptionDialog({
  required BuildContext context,
  required CompositionController controller,
}) {
  final textController = TextEditingController();
  // Declared HERE, outside StatefulBuilder's own builder callback —
  // that callback re-runs on every setDialogState() call, which was
  // silently re-declaring (and resetting) these back to their
  // initial null/null/false values immediately after each update,
  // making the Import button look like it did nothing at all.
  // Living at this outer scope (same as textController) means they
  // persist across rebuilds instead.
  List<TranscriptionParseError>? parseErrors;
  List<String>? importWarnings;
  bool imported = false;
  // When the composition already has measures: false = add the new
  // measures after them, true = replace them all.
  bool replaceExisting = false;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> runImport() async {
            // Imports change the measures, so only in edit mode (not
            // while repeats are played out / arpeggios spread).
            if (controller.playbackExpanded) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Go back to edit mode first (pen icon).',
                      style: TextStyle(fontSize: 22)),
                ),
              );
              return;
            }
            var text = textController.text;
            final existing = controller.measures.length;
            if (existing > 0 && replaceExisting) {
              final sure = await showDialog<bool>(
                context: dialogContext,
                builder: (c) => AlertDialog(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  title: const Text('Replace all measures?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  content: Text(
                    'All $existing measures and their notes will be deleted '
                        'and replaced by the transcription.',
                    style: const TextStyle(fontSize: 22),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Close',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Replace',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (sure != true) return;
              controller.clearAllMeasures();
            } else if (existing > 0) {
              // Add after the existing measures: the transcription's
              // measure 1 becomes measure existing + 1, and so on.
              text = shiftMeasureNumbers(text, existing);
            }
            // Repeat signs and arpeggios ("|:", ":|", "v1", "arp"…) are
            // taken out here and put on the measures after the import.
            final marks = extractNotationMarks(text);

            // A fresh label each time — this dialog's whole point is
            // one-off pasted text, not a fixed named batch someone
            // might reopen and expect CompositionController's own
            // "already imported" dedupe (importedBatchLabels) to
            // recognize a second time, so a timestamp keeps every
            // paste unique rather than colliding with (or silently
            // skipping as a duplicate of) an earlier one.
            final label =
                'Pasted transcription ${DateTime.now().millisecondsSinceEpoch}';
            final result = parseCellnotationTranscription(
              marks.cleanedText,
              label: label,
            );

            // Creates whatever empty measures the transcription needs
            // but the composition doesn't have YET — per request, so
            // a transcription can be pasted straight into a brand new
            // (empty) composition without a separate "Add Measures"
            // step first. Only APPENDS measures beyond however many
            // already exist (addMeasure only ever appends at the end
            // anyway) — an existing measure's own scale/time
            // signature is never touched, so re-pasting a
            // transcription into a composition that already has all
            // its measures is a no-op here.
            if (result.scaleName != null &&
                result.timeSignatureBeats != null &&
                result.timeSignatureDenominator != null) {
              final beatDuration = noteDurationForDenominator(
                result.timeSignatureDenominator!,
              );
              if (beatDuration != null) {
                final signature = TimeSignature(
                  beats: result.timeSignatureBeats!,
                  beatDuration: beatDuration,
                );
                while (controller.measures.length < result.measuresNeeded) {
                  controller.addMeasure(signature, result.scaleName!);
                }
              }
            }

            // Key changes: each measure from a scale line on gets that
            // scale, up to the next key change (set before the notes go
            // in, like the measures' own scale).
            for (int k = 0; k < marks.scales.length; k++) {
              final (from, scale) = marks.scales[k];
              final to = k + 1 < marks.scales.length
                  ? marks.scales[k + 1].$1
                  : result.measuresNeeded;
              for (int i = from; i < to && i < controller.measures.length; i++) {
                controller.updateMeasureScale(i, scale);
              }
            }

            // Always import result.batch, even when result.hasErrors
            // — a parse error only means ONE bad token was skipped
            // (see TranscriptionParseResult's own doc: every other
            // token still parsed normally into result.batch), so
            // refusing to import the rest just because one token
            // failed would silently throw away everything that DID
            // parse correctly. Both the parse errors and the import
            // warnings are shown together now, rather than the
            // warnings only ever appearing on a fully error-free
            // paste.
            final warnings = controller.importBatch(result.batch);
            controller.applyNotationMarks(marks.reprise, marks.arpeggios);
            setDialogState(() {
              parseErrors = result.hasErrors ? result.errors : null;
              importWarnings = warnings.map((w) => w.toString()).toList();
              imported = true;
            });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            actionsAlignment: MainAxisAlignment.center,
            title: const Text(
              'Import Sheet Music Transcription',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 500,
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          "Paste or type a transcription using the line-position notation.",
                          style: TextStyle(fontSize: 22, color: Colors.black54),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showTranscriptionHelp(context),
                        child: const Text(
                          'Help',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (controller.measures.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        for (final replace in const [false, true])
                          ChoiceChip(
                            label: Text(
                              replace
                                  ? 'Replace all measures'
                                  : 'Add after measure ${controller.measures.length}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: replaceExisting == replace
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            selected: replaceExisting == replace,
                            selectedColor: replace ? Colors.red : Colors.blue,
                            backgroundColor: Colors.white,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setDialogState(() => replaceExisting = replace),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'do major\nt3/4\nm1\nhr b3 l2 d8 b3&1/2 l2 d8\nm2\nhr b1 l2/3 d4 b2 l2 d4 b3 l3/4 d4\nhl b1 (l-4/-3, l-3/-2, l-2/-1) d2d4\n...',
                      ),
                    ),
                  ),
                  if (parseErrors != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${parseErrors!.length} token'
                          '${parseErrors!.length == 1 ? '' : 's'} could not be '
                          'read and ${parseErrors!.length == 1 ? 'was' : 'were'} '
                          'skipped — everything else below was still imported:',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(
                      height: 120,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final e in parseErrors!)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  e.toString(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (imported) ...[
                    const SizedBox(height: 12),
                    Text(
                      importWarnings!.isEmpty
                          ? 'Imported successfully.'
                          : 'Imported with ${importWarnings!.length} '
                          'warning${importWarnings!.length == 1 ? '' : 's'}:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: importWarnings!.isEmpty
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    if (importWarnings!.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final w in importWarnings!)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    w,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              // Reads the notes from a PDF of the sheet music (on the
              // tablet, or with AI) and puts the result in the box
              // above, to check and then Import as usual.
              TextButton(
                onPressed: () async {
                  final text = await Navigator.of(dialogContext).push<String>(
                    MaterialPageRoute(
                      builder: (_) => SheetMusicPdfImportScreen(
                        scales: controller.availableScales,
                      ),
                    ),
                  );
                  if (text == null || text.isEmpty) return;
                  setDialogState(() {
                    textController.text = text;
                    parseErrors = null;
                    importWarnings = null;
                    imported = false;
                  });
                },
                child: const Text(
                  'From PDF',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    textController.clear();
                    // Wiped alongside the text, per request — an
                    // old error/warning list left over from a
                    // PREVIOUS paste would otherwise still be shown
                    // underneath the now-empty text box, which reads
                    // as stale/confusing rather than a clean slate.
                    parseErrors = null;
                    importWarnings = null;
                    imported = false;
                  });
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: runImport,
                child: const Text(
                  'Import',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Shows a scrollable explanation of the line-position transcription
/// notation — opened from the Help button next to the description
/// text above the paste box. Kept in plain, example-led language
/// (rather than reproducing cellnotation_transcription_parser.dart's
/// own doc comment verbatim, which is written for a Dart reader, not
/// someone transcribing a piece of sheet music).
void _showTranscriptionHelp(BuildContext context) {
  showDialog(
    context: context,
    builder: (helpContext) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actionsAlignment: MainAxisAlignment.center,
      title: const Text(
        'How to Transcribe',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 500,
        height: 800,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _HelpSection(
                  title: 'Example of transcription',
                  body:
                  'do major\n'
                      't6/8\n'
                      'm1\n'
                      'hr b6 l1 d8\n'
                      'm2\n'
                      'hr b1 l2/3 d4 b3 l2/3 d8 b4 l2/3 d4 b6 l2/3 d8\n'
                      'hl b1 l-4/-5 d8 b2 l-2/-3 d8 b3 l-1 d8 b4 l-4/-5 d8 b5 l-2/-3 d8 b6 l-1 d8\n\n'

                      'Whitespace and line breaks are for readability only — the parser treats them all the same way.'),
              _HelpSection(
                  title: 'Scale and time signature',
                  body:
                  'The scale and time signature must be specified, so that empty measures with the correct '
                      'scale and time signature can be created before the import.\n'
                      'When the scale changes, write the new scale on its own line inside the first measure in the new key.\n'
                      'Example:\n'
                      '"do major" \n'
                      '"t6/8".'
              ),
              _HelpSection(
                  title: 'Measure',
                  body: 'The transcription of each measure begins with "m" followed by the measure number:\n'
                      '"m1" marks the start of measure 1.\n'
                      '"m2" marks the start of measure 2, and so on.'),
              _HelpSection(
                  title: 'Hand',
                  body:
                  '"hr" indicates that the following notes are for the right hand.\n'
                      '"hl" indicates that the following notes are for the left hand.\n'
                      '"ha" indicates that the following notes are for an additional hand.'),
              _HelpSection(
                  title: 'Beat',
                  body:
                  'The position within a measure is indicated by "b" followed by the beat number:\n'
                      '"b1" marks the start of beat 1.\n'
                      '"b2" marks the start of beat 2.\n\n'
                      'If a note starts partway through a beat, "&" and the part of the beat follow the beat number:\n'
                      '"b1&1/2" marks a note starting halfway through beat 1.\n'
                      '"b1&1/4" marks a note starting one quarter of the way through beat 1.\n'
                      '"b1&3/4" marks a note starting three quarters of the way through beat 1.\n'
                      '"b2&1/3" marks a note starting one third of the way through beat 2.'
              ),
              _HelpSection(
                  title: 'Note',
                  body:
                  'Note pitch is represented by "l" followed by a number because notes on music sheets '
                      'are represented by their position relative to horizontal lines, '
                      'so the line numbers are used.\n\n'
                      '5 lines for the "Sol" clef are numbered upward as 1, 2, 3, 4, 5.\n'
                      '5 lines for the "Fa" clef are numbered downward as -1, -2, -3, -4, -5.\n'
                      'Midway between the lines of clef "Sol" and lines of clef "Fa" lies an invisible horizontal '
                      'line numbered 0, which becomes visible only when a note is written in that space.\n'
                      'Every additional line, over and under those lines continuing the count.\n\n'
                      'A note is transcribed:\n'
                      '- by a single line number, if it sits on a line;\n'
                      '- by two line numbers joined by "/", if it sits between two lines.\n\n'
                      'Full correspondence of transcription to note name is the following:\n'
                      '"l14"       transcripts Do8.\n'
                      '"l13/14"    transcripts Si7.\n'
                      '"l13"       transcripts La7.\n'
                      '"l12/13"    transcripts Sol7.\n'
                      '"l12"       transcripts Fa7.\n'
                      '"l11/12"    transcripts Mi7.\n'
                      '"l11"       transcripts Re7.\n'
                      '"l10/11"    transcripts Do7.\n'
                      '"l10"       transcripts Si6.\n'
                      '"l9/10"     transcripts La6.\n'
                      '"l9"        transcripts Sol6.\n'
                      '"l8/9"      transcripts Fa6.\n'
                      '"l8"        transcripts Mi6.\n'
                      '"l7/8"      transcripts Re6.\n'
                      '"l7"        transcripts Do6.\n'
                      '"l6/7"      transcripts Si5.\n'
                      '"l6"        transcripts La5.\n'
                      '"l5/6"      transcripts Sol5.\n'
                      '"l5"        transcripts Fa5.\n'
                      '"l4/5"      transcripts Mi5.\n'
                      '"l4"        transcripts Re5.\n'
                      '"l3/4"      transcripts Do5.\n'
                      '"l3"        transcripts Si4.\n'
                      '"l2/3"      transcripts La4.\n'
                      '"l2"        transcripts Sol4.\n'
                      '"l1/2"      transcripts Fa4.\n'
                      '"l1"        transcripts Mi4.\n'
                      '"l0/1"      transcripts Re4.\n'
                      '"l0"        transcripts Do4.\n'
                      '"l0/-1"     transcripts Si3.\n'
                      '"l-1"       transcripts La3.\n'
                      '"l-1/-2"    transcripts Sol3.\n'
                      '"l-2"       transcripts Fa3.\n'
                      '"l-2/-3"    transcripts Mi3.\n'
                      '"l-3"       transcripts Re3.\n'
                      '"l-3/-4"    transcripts Do3.\n'
                      '"l-4"       transcripts Si2.\n'
                      '"l-4/-5"    transcripts La2.\n'
                      '"l-5"       transcripts Sol2.\n'
                      '"l-5/-6"    transcripts Fa2.\n'
                      '"l-6"       transcripts Mi2.\n'
                      '"l-6/-7"    transcripts Re2.\n'
                      '"l-7"       transcripts Do2.\n'
                      '"l-7/-8"    transcripts Si1.\n'
                      '"l-8"       transcripts La1.\n'
                      '"l-8/-9"    transcripts Sol1.\n'
                      '"l-9"       transcripts Fa1.\n'
                      '"l-9/-10"   transcripts Mi1.\n'
                      '"l-10"      transcripts Re1.\n'
                      '"l-10/-11"  transcripts Do1.\n'
                      '"l-11"      transcripts Si0.\n'
                      '"l-11/-12"  transcripts La0.\n'
                      '"l-12"      transcripts Sol0.'
              ),
              _HelpSection(
                  title: 'Duration',
                  body:
                  'Note duration is represented by "d" followed by the number 1, 2, 4, 8, 16, 32, or 64:\n'
                      '"d1" represents a whole note.\n'
                      '"d2" represents a half note.\n'
                      '"d4" represents a quarter note.\n'
                      '"d8" represents an eighth note.\n'
                      '"d16" represents a sixteenth note.\n'
                      '"d32" represents a thirty-second note.\n'
                      '"d64" represents a sixty-fourth note.\n\n'
                      'A dotted note is represented by repeating the duration code:\n'
                      '"d2d4" represents a dotted half note (a half note tied to a quarter note).\n'
                      '"d4d8" represents a dotted quarter note (a quarter note tied to an eighth note).\n'
                      '"d8d16" represents a dotted eighth note (an eighth note tied to a sixteenth note),\n'
                      'and so on.'
              ),
              _HelpSection(
                  title: 'Accidentals',
                  body:
                  'An accidental is written after the pitch and before the duration, using the following signs:\n'
                      '"+" represents a sharp.\n'
                      '"-" represents a flat.\n'
                      '"++" represents a double sharp.\n'
                      '"--" represents a double flat.\n'
                      '"x" represents a natural.\n'
                      'Example:\n'
                      '"l2+d2" represents Sol4 (l2) sharp (+) of a half-note duration (d2),\n'
                      '"l-2/-3-d8" represents Mi3 (l-2/-3) flat (-) of an eighth-note duration (d8),\n'
                      '"l0xd2d4" represents Do4 (l0) natural (x) of a dotted half-note duration (d2d4).\n'
              ),
              // _HelpSection(
              //     title: 'Rests',
              //     body:
              //     'A rest is represented by "r" followed by duration transcription:\n'
              //         '"rd1" — a whole rest,\n'
              //         '"rd2" — a half rest,\n'
              //         '"rd4" — a quarter rest,\n'
              //         '"rd8" — an eighth rest,\n'
              //         '"rd16" — a sixteenth rest,\n'
              //         '"rd32" — a thirty-second rest,\n'
              //         '"rd64" — a sixty-fourth rest,\n'
              // ),
              _HelpSection(
                title: 'Repeats',
                body:
                'Repeat signs are written as words inside the measure they belong to:\n'
                    '"|:" — reprise starts,\n'
                    '":|" — reprise ends,\n'
                    '"v1" and "v2" — volta 1 and volta 2,\n'
                    '"𝄋" — Segno,\n'
                    '"fine" — Fine,\n'
                    '"dsfine" — D.S. al Fine,\n'
                    '"tocoda" — To Coda,\n'
                    '"dscoda" — D.S. al Coda,\n'
                    '"coda" — Coda.\n'
                    'Example:\n'
                    'm1\n|:\nhr b1 l2 d4 …\nm4\n:|\nhr b1 l3 d2d4',
              ),
              _HelpSection(
                title: 'Chords',
                body:
                'Notes played together are wrapped in parentheses to represent a chord.\n'
                    'Example:\n'
                    '"(l-5/-4 l-1 l0) d4" represents a quarter-note chord of three notes.',
              ),
              _HelpSection(
                  title: 'Arpeggio',
                  body:
                  'Write "arp" before a chord to put an arpeggio on it.\n'
                      'Example:\n'
                      '"hl b1 arp (l-5, l-3, l-1) d4" — left-hand arpeggio on beat 1.\n\n'
              ),
              _HelpSection(
                  title: 'Triplets and tuplets',
                  body:
                  'A note of a triplet (3 notes in the time of 2) is written with its printed duration followed by ":3",\n'
                      'a note of a quintuplet (5 notes in the time of 4) is written with its printed duration followed by ":5",\n'
                      'a note of a sextuplet (6 notes in the time of 4) is written with its printed duration followed by ":6",\n'
                      'a note of a septuplet (7 notes in the time of 4) is written with its printed duration followed by ":7",\n'
                      'Its beat is written with the exact part of the beat.\n'
                      'Examples in 4/4:\n'
                      '"b1 l2 d4:3    b1&2/3 l3 d4:3    b2&1/3 l4 d4:3" — a triplet of quarters on beats 1 and 2,\n'
                      '"b3 (l-1, l0) d8:3     b3&1/3 (l-1, l1) d8:3     b3&2/3 (l0, l1) d8:3" — triplet chords on beat 3.\n\n'
              ),
              _HelpSection(
                title: 'Grace notes',
                body:
                'Grace notes are small notes printed just before (or just after) a main note. They are played quickly, '
                    'taking a little of the time of the main note.\n'
                    '- Appoggiatura: a small note without a slash. It takes half of the main note.\n'
                    '- Acciaccatura: a small note with a slash through its stem. It is very short:\n'
                    '     - Long = a sixteenth,\n'
                    '     - Medium = a thirty-second,\n'
                    '     - Short = a sixty-fourth.\n\n'
                    'They are written with "g", a letter for the type and the pitch of the grace notes in brackets:\n'
                    '"a" — Appoggiatura.\n'
                    '"l" — Acciaccatura Long.\n'
                    '"m" — Acciaccatura Medium.\n'
                    '"s" — Acciaccatura Short.\n\n'
                    'Grace notes BEFORE the main note are written just before it, on the same beat:\n'
                    '"b1 gs(l5) l4 d4" — one short acciaccatura of pitch l5 before the quarter note of pitch l4.\n'
                    '"b2 gm(l5, l6+) l4 d2" — two medium acciaccaturas of pitch l5 and l6+ before the half note of pitch l4.\n'
                    '"b3 ga(l4/5) l4 d4" — an appoggiatura of pitch l4/5 before the note of pitch l4.\n\n'
                    'Grace notes AFTER the main note are written right after it (after its duration and ornament):\n'
                    '"b1 l4 d2 gs(l3, l4)" — two short acciaccaturas at the end of the half note of pitch l4.\n\n'
                    'Grace notes have no duration of their own: it is taken from their type and the main note.',
              ),
              _HelpSection(
                title: 'Ornaments',
                body:
                'An ornament is written right after the duration of the note:\n\n'
                    'Mordent\n'
                    '- "mord+" and "mord-" represent upper mordent and lower mordent;\n'
                    '- "rmord+" and "rmord-" represent reversed upper mordent and reversed lower mordent;\n'
                    '- an accidental printed with the sign is written in brackets: "(+)" sharp, "(-)" flat. \n'
                    'Example:\n'
                    'l1/2 d4 mord+(+).\n\n'
                    'Grupetto\n'
                    '- "turn+" and "turn-" represent upper grupetto and lower grupetto;\n'
                    '- "rturn+" and "rturn-" represent reversed upper grupetto and reversed lower grupetto;\n'
                    '- "bturn+" and "bturn-" represent between upper grupetto and between lower grupetto.\n'
                    'Because there are two auxiliary notes, there are two signs in the brackets: the first is for the first one, the second '
                    'for the second one, "x" when it has none.\n'
                    'Example:\n'
                    '"l-1/-2 d4 rturn-(x+)"\n\n'
                    'Trill\n'
                    '"trill" — trill,\n'
                    '"trill-" — chromatic trill with a flat,\n'
                    '"trill+" — chromatic trill with a sharp.\n'
                    'Example:\n'
                    '"l4 d4 trill".\n\n'
                    'Tremolo\n'
                    '"trem" - tremolo,\n'
                    'Example:\n'
                    '"l0 d2 trem".\n'
                ,
              ),

            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(helpContext),
          child: const Text(
            'Close',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ],
    ),
  );
}

/// One titled paragraph within the help dialog above.
class _HelpSection extends StatelessWidget {
  final String title;
  final String body;

  const _HelpSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(fontSize: 22, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}