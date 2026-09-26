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
                      'hl b1 (-4, -3, -2/-1)d2d4\n'
                      'm4\n'
                      'hr b1 2/3d4 b2 2d4 b3 4d4\n'
                      'hl b1 (-4, -3, -2/-1)d2d4\n\n'
                      'whitespace and line breaks are just for readability, the parser treats them the same way.'),
              _HelpSection(
                  title: 'scale and time signature',
                  body:
                  'scale amd time signature must be indicated, '
                      'so empty measures of correct scale and time signature can be created before the import:\n'
                      '"do major" means the scale of the music,\n'
                      '"t3/4" means the time signature, in this case each measure contains 3 beats of duration quarter;'),
              _HelpSection(
                  title: 'measure',
                  body: 'transcription of each measure starts with "m" followed by measure number:\n'
                      '"m1" means that the transcription of measure 1 started,\n'
                      '"m2" means that the transcription of measure 2 started and etc.;'),
              _HelpSection(
                  title: 'hand',
                  body:
                  '"hr" means that the transcription is of the music for the right hand,\n'
                      '"hl" means that the transcription is of the music for left hand,\n'
                      '"ha" means that the transcription is of the music for additional hand;'),
              _HelpSection(
                  title: 'beat',
                  body:
                  'time position inside measure is indicated by "b" followed by beat number:\n'
                      '"b1" means that the transcription of beat 1 started,\n'
                      '"b2" means that the transcription of beat 2 started;\n\n'
                      'if note is shorter than the beat and it starts later than the beat starts, than the beat number is decimal:\n'
                      '"b1.25" means that the note of beat 1 starts one quarter of the beat later,\n'
                      '"b1.5" means that the note of beat 1 starts from the middle of the beat,\n'
                      '"b1.75" means that the note of beat 1 starts three quarters of the beat later;'),
              _HelpSection(
                  title: 'note',
                  body:
                  'because notes in music sheets are presented with the help of horizontal lines '
                      'they are transcript in cellnotation by line numbers;\n\n'
                      '10 lines of 27 are always visible and separated to 5 lines of clef "Sol" '
                      'and 5 lines of clef "Fa". In the middle of the space between lines of clef "Sol" and "Fa" there is an invisible '
                      'horizontal line with the number 0, it becomes visible only when notes are written in this space;\n\n'
                      'lines get their numbers counting from line 0: \n'
                      '- counting up lines get positive numbers: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,\n'
                      '- counting down lines get negative numbers: -1,-2,-3,-4,-5,-6,-7,-8,-9,-10,-11,-12;\n\n'

                      'note is transcript\n'
                      '- by one line number, if note is sitting on line,\n'
                      '- by two line numbers joined by "/", if note is sitting between lines;\n\n'
                      'example:\n'
                      '"0" transcripts the note sitting on the line 0 ("Do" of octave 4),\n'
                      '"3/4" or "4/3" transcripts the note sitting between lines 3 and 4 ("Do" of octave 5),\n'
                      '"7" transcripts the note sitting on the line 7 ("Do" of octave 6),\n'
                      '"-3/-4" or "-4/-3" transcripts the note sitting between lines -3 and -4 ("Do" of octave 3),\n'
                      '"-7" transcripts the note sitting on the line -7 ("Do" of octave 2).\n'
              ),
              _HelpSection(
                  title: 'duration',
                  body:
                  'note duration is transcript by "d" followed by note value: 1, 2, 4, 8, 16, 32, 64): \n'
                      '"d1" transcripts whole,\n'
                      '"d2" transcripts half,\n'
                      '"d4" transcripts quarter,\n'
                      '"d8" transcripts eighth,\n'
                      '"d16" transcripts sixteenth,\n'
                      '"d32" transcripts thirty-second,\n'
                      '"d64" transcripts sixty-fourth,\n\n'
                      'a dotted note repeats the duration code:\n'
                      '"d2d4" transcripts a dotted half which is a half tied to a quarter),\n'
                      '"d4d8" transcripts a dotted quarter which is a quarter tied to an eighth),\n'
                      '"d8d16" transcripts a dotted eighth which is a eighth tied to a sixteenth)\n'
                      'and etc.'
              ),
              _HelpSection(
                  title: 'accidentals',
                  body:
                  'accidental is written after the line position before the duration with signs:\n'
                      '"+" transcripts sharp,\n'
                      '"-" transcripts flat,\n '
                      '"++" transcripts double sharp,\n'
                      '"--" transcripts double flat,\n'
                      '"x" transcripts natural;\n\n'
                      'example:\n'
                      '"6-d2" transcripts the note sitting on line 6 with a flat (6-) of duration half (d2), so '
                      'the note "La-flat" of octave 5 of value half,\n'
                      '"1/2+d8" transcripts the note sitting between lines 1 and 2 with a sharp (1/2+) '
                      'of duration eighth (d8), so the note "Fa-sharp" of octave 4 of value eighth,\n'
                      '"-1/-2+d4" transcripts the note sitting between lines -1 and -2 '
                      'with a sharp (-1/-2+) of duration quarter (d4), so the note "Sol-sharp" of octave 3 of value quarter,\n'
                      '"0xd1" transcripts the note sitting on line 0 with a natural (0x) of duration whole (d1), so the note "Do" '
                      'of octave 4 of value whole;'
              ),
              _HelpSection(
                  title: 'rests',
                  body:
                  '"r" followed by "d" and the duration transcripts the rest:\n'
                      '"rd1" - rest of whole,\n'
                      '"rd2" - rest of half,\n'
                      '"rd4" - rest of quarter,\n'
                      '"rd8" - rest of eighth,\n'
                      '"rd16" - rest of sixteenth,\n'
                      '"rd32" - rest of thirty-second,\n'
                      '"rd64" - rest of sixty-fourth;\n'
              ),
              _HelpSection(
                title: 'chords',
                body:
                'the notes played together are wrapped in parentheses, separated by a comma and '
                    'represent a chord, example:\n'
                    '(-5/-4, -1, 0)d4 transcripts a chord of three notes of duration quarter;',
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