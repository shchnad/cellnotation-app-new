import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../models/time_signature.dart';
import '../utils/cellnotation_transcription_parser.dart';

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

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void runImport() {
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
              textController.text,
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
                        hintText: 'do major\nt3/4\nm1\nhr b1 rd4 b3 2d8 b3.5 2d8\nm2\nhr b1 2/3d4 b2 2d4 b3 3/4d4\nhl b1 (-4/-3, -3/-2, -2/-1)d2d4\n...',
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
                      't3/4\n'
                      'm1\n'
                      'hr b1 rd4 b3 2d8 b3.5 2d8\n'
                      'm2\n'
                      'hr b1 2/3d4 b2 2d4 b3 3/4d4\n'
                      'hl b1 (-4/-3, -3/-2, -2/-1)d2d4\n'
                      'm3\n'
                      'hr b1 3d2 b3 2d8 b3.5 2d8\n'
                      'hl (-4, -3, -2/-1)d2d4\n'
                      'm4\n'
                      'hr b1 2/3d4 b2 2d4 b3 4d4\n'
                      'hl (-4, -3, -2/-1)d2d4\n\n'
                      'Whitespace and line breaks are for readability only — the parser treats them all the same way.'),
              _HelpSection(
                  title: 'Scale and time signature',
                  body:
                  'The scale and time signature must be specified, so that empty measures with the correct '
                      'scale and time signature can be created before the import:\n'
                      '"do major" specifies the scale of the piece.\n'
                      '"t3/4" specifies the time signature — in this case, each measure contains 3 quarter-note beats.'),
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
                      'If a note starts partway through a beat, the beat number includes a decimal fraction:\n'
                      '"b1.25" marks a note starting one quarter of the way through beat 1.\n'
                      '"b1.5" marks a note starting halfway through beat 1.\n'
                      '"b1.75" marks a note starting three quarters of the way through beat 1.'),
              _HelpSection(
                  title: 'Note',
                  body:
                  'Because notes on a music sheet are represented by their position relative to horizontal lines, '
                      'they are transcribed in Cellnotation using line numbers.\n\n'
                      'Ten of the 27 lines are always visible, divided into 5 lines for the "Sol" clef '
                      'and 5 lines for the "Fa" clef. Midway between the "Sol" and "Fa" clefs lies an invisible '
                      'horizontal line numbered 0, which becomes visible only when a note is written in that space.\n\n'
                      'Lines are numbered starting from line 0:\n'
                      '- counting upward, lines are numbered positively: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14;\n'
                      '- counting downward, lines are numbered negatively: -1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12.\n\n'
                      'A note is transcribed:\n'
                      '- by a single line number, if the note sits on a line;\n'
                      '- by two line numbers joined by "/", if the note sits between two lines.\n\n'
                      'Full correspondence, line position to note name:\n'
                      '"-12" transcripts Sol0.\n'
                      '"-12/-11" transcripts La0.\n'
                      '"-11" transcripts Si0.\n'
                      '"-11/-10" transcripts Do1.\n'
                      '"-10" transcripts Re1.\n'
                      '"-10/-9" transcripts Mi1.\n'
                      '"-9" transcripts Fa1.\n'
                      '"-9/-8" transcripts Sol1.\n'
                      '"-8" transcripts La1.\n'
                      '"-8/-7" transcripts Si1.\n'
                      '"-7" transcripts Do2.\n'
                      '"-7/-6" transcripts Re2.\n'
                      '"-6" transcripts Mi2.\n'
                      '"-6/-5" transcripts Fa2.\n'
                      '"-5" transcripts Sol2.\n'
                      '"-5/-4" transcripts La2.\n'
                      '"-4" transcripts Si2.\n'
                      '"-4/-3" transcripts Do3.\n'
                      '"-3" transcripts Re3.\n'
                      '"-3/-2" transcripts Mi3.\n'
                      '"-2" transcripts Fa3.\n'
                      '"-2/-1" transcripts Sol3.\n'
                      '"-1" transcripts La3.\n'
                      '"-1/0" transcripts Si3.\n'
                      '"0" transcripts Do4.\n'
                      '"0/1" transcripts Re4.\n'
                      '"1" transcripts Mi4.\n'
                      '"1/2" transcripts Fa4.\n'
                      '"2" transcripts Sol4.\n'
                      '"2/3" transcripts La4.\n'
                      '"3" transcripts Si4.\n'
                      '"3/4" transcripts Do5.\n'
                      '"4" transcripts Re5.\n'
                      '"4/5" transcripts Mi5.\n'
                      '"5" transcripts Fa5.\n'
                      '"5/6" transcripts Sol5.\n'
                      '"6" transcripts La5.\n'
                      '"6/7" transcripts Si5.\n'
                      '"7" transcripts Do6.\n'
                      '"7/8" transcripts Re6.\n'
                      '"8" transcripts Mi6.\n'
                      '"8/9" transcripts Fa6.\n'
                      '"9" transcripts Sol6.\n'
                      '"9/10" transcripts La6.\n'
                      '"10" transcripts Si6.\n'
                      '"10/11" transcripts Do7.\n'
                      '"11" transcripts Re7.\n'
                      '"11/12" transcripts Mi7.\n'
                      '"12" transcripts Fa7.\n'
                      '"12/13" transcripts Sol7.\n'
                      '"13" transcripts La7.\n'
                      '"13/14" transcripts Si7.\n'
                      '"14" transcripts Do8.\n'
              ),
              _HelpSection(
                  title: 'Duration',
                  body:
                  'Note duration is represented by "d" followed by the note value (1, 2, 4, 8, 16, 32, or 64):\n'
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
                  'An accidental is written after the line position and before the duration, using the following signs:\n'
                      '"+" represents a sharp.\n'
                      '"-" represents a flat.\n'
                      '"++" represents a double sharp.\n'
                      '"--" represents a double flat.\n'
                      '"x" represents a natural.\n\n'
                      'Example:\n'
                      '"6-d2" represents the note on line 6 with a flat (6-) and a half-note duration (d2) — '
                      'a half-note La-flat in octave 5.\n'
                      '"1/2+d8" represents the note between lines 1 and 2 with a sharp (1/2+) '
                      'and an eighth-note duration (d8) — an eighth-note Fa-sharp in octave 4.\n'
                      '"-1/-2+d4" represents the note between lines -1 and -2 '
                      'with a sharp (-1/-2+) and a quarter-note duration (d4) — a quarter-note Sol-sharp in octave 3.\n'
                      '"0xd1" represents the note on line 0 with a natural (0x) and a whole-note duration (d1) — '
                      'a whole-note Do in octave 4.'
              ),
              _HelpSection(
                  title: 'Rests',
                  body:
                  'A rest is represented by "r" followed by "d" and the duration:\n'
                      '"rd1" — a whole rest.\n'
                      '"rd2" — a half rest.\n'
                      '"rd4" — a quarter rest.\n'
                      '"rd8" — an eighth rest.\n'
                      '"rd16" — a sixteenth rest.\n'
                      '"rd32" — a thirty-second rest.\n'
                      '"rd64" — a sixty-fourth rest.\n'
              ),
              _HelpSection(
                title: 'Chords',
                body:
                'Notes played together are wrapped in parentheses and separated by commas to represent a chord, '
                    'for example:\n'
                    '"(-5/-4, -1, 0)d4" represents a quarter-note chord of three notes.',
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