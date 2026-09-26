import 'package:flutter/material.dart';
import 'package:music_composer/enums/articulation.dart';

import '../controllers/composition_controller.dart';
import '../enums/accidental.dart';
import '../enums/finger.dart';
import '../enums/glissando_direction.dart';
import '../enums/grace_note_type.dart';
import '../enums/note_duration.dart';
import '../enums/ornament.dart';
import '../enums/playing_technique.dart';
import '../models/note.dart';
import '../utils/default_values.dart';
import 'combined_duration_dialog.dart';
import '../models/note_import.dart';
import 'note_values_dialog.dart';
import 'hand_dialog.dart';

class NoteDialog extends StatelessWidget {
  final Note note;
  final CompositionController controller;

  const NoteDialog({super.key, required this.note, required this.controller});

//the latest version of the note
  Note get currentNote {
    return controller.composition.notes.firstWhere(
          (n) => n.id == note.id,
      orElse: () => note,
    );
  }

  /// Measures [text] at a bold 22px style (the widest style used
  /// anywhere in this dialog's rows, so this is always a safe upper
  /// bound even for the few rows that aren't actually bold) and
  /// returns its rendered width in logical pixels. Plain
  /// TextPainter measurement rather than IntrinsicWidth — Flutter's
  /// intrinsic-dimension protocol is unreliable with ListTile (it can
  /// throw "Cannot hit test a render box with no size"), so the width
  /// this dialog needs is computed directly here instead of asking
  /// the render tree to figure it out.
  double _textWidth(String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  /// Extra width reserved for each ListTile field row — its leading
  /// icon, the gap between icon and title (ListTile's default
  /// horizontalTitleGap is 16, not accounted for by minLeadingWidth),
  /// and its horizontal content padding (see the ListTileThemeData
  /// override below) — none of which [_textWidth] accounts for on
  /// its own. Generous on purpose: too little here causes visible
  /// text wrapping (seen with both 56 and 96 in
  /// edit_measure_beat_dialog.dart, which uses the identical
  /// ListTileThemeData), which is far worse than the dialog being a
  /// little wider than strictly necessary.
  static const double _listTileChrome = 140;

  /// The gap between two info values sharing one row (Measure/Beat,
  /// Octave/Degree) — matches DefaultValues.widthBetweenWidgets.
  double get _rowGap => DefaultValues.widthBetweenWidgets;

  /// Renders [note] in the same line-position transcription notation
  /// cellnotation_transcription_parser.dart parses on the way IN —
  /// the exact inverse of that file's own row -> (degree, octave)
  /// conversion, solved back to a staff line position: `row - 28`
  /// even means the note sits ON line `(row-28)/2`; odd means it
  /// sits BETWEEN lines `(row-29)/2` and that line + 1 (see that
  /// file's own top-level doc comment for the full derivation this
  /// mirrors). Accidental and duration are read directly off [note]
  /// itself — [Accidental.sign] already matches the parser's own
  /// +/++/-/--/x signs exactly, and each duration part becomes one
  /// "d<n>" code, concatenated for a dotted/tied note (e.g. "d4d8").
  /// Prefixed with "m<measure> b<beat>" (matching the parser's own
  /// `m`/`b` markers), so the whole string can be read back directly
  /// against the original transcription text, not just the isolated
  /// note token.
  String _transcriptionFor(Note note) {
    final offset = note.row - 28;
    final String position;
    if (offset % 2 == 0) {
      position = (offset ~/ 2).toString();
    } else {
      // Dart's `%` can return a negative remainder for a negative
      // dividend (e.g. -1 % 2 == -1, not 1) — floor-dividing instead
      // of truncating keeps the "between lines" case correct for
      // notes below line 0 too.
      final lower = ((offset - 1) / 2).floor();
      position = '$lower/${lower + 1}';
    }

    final accidentalSign = note.accidental?.sign ?? '';

    final durationParts = decomposeDurationTicks(note.durationTicks);
    final durationCode = durationParts.map((d) {
      final denominator = NoteDuration.whole.ticks ~/ d.ticks;
      return 'd$denominator';
    }).join();

    final measureNumber = controller.getMeasureNumber(note);
    // getBeatNumber truncates to a whole beat, losing any fractional
    // offset a note starting mid-beat actually has — computed
    // directly here instead, in the parser's own decimal notation
    // (b1.25/b1.5/b1.75 for a quarter/eighth-note-and/three-quarter
    // offset within the beat).
    final measure = controller.getMeasureAtTick(note.startTick);
    final tickInsideMeasure = note.startTick - measure.startTick;
    final ticksPerBeat = measure.timeSignature.ticksPerBeat;
    final wholeBeatIndex = tickInsideMeasure ~/ ticksPerBeat;
    final remainderTicks = tickInsideMeasure - wholeBeatIndex * ticksPerBeat;
    final fraction = remainderTicks / ticksPerBeat;
    final beatNumber = wholeBeatIndex + 1;
    // Only the three quarter-beat fractions the parser itself
    // recognizes are ever shown — anything else (a note that doesn't
    // land on a quarter-beat boundary at all) is rounded to the
    // nearest of those rather than showing an unparseable decimal.
    final beatSuffix = switch ((fraction * 4).round() % 4) {
      1 => '.25',
      2 => '.5',
      3 => '.75',
      _ => '',
    };

    return 'm$measureNumber b$beatNumber$beatSuffix $position$accidentalSign$durationCode';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final editedNote = currentNote;
        final measure = controller.getMeasureAtTick(editedNote.startTick);
        final timeSignature =
            '${measure.timeSignature.beats} * '
            '${measure.timeSignature.beatDuration.label}';
        final activeTempo =
        controller.getActiveTempoAtTick(editedNote.startTick);
        final tempoLabel = activeTempo == null
            ? 'none'
            : '${activeTempo.tempo.label} = ${activeTempo.tempo.value}';

        // Shows the note's duration as a readable combination (e.g.
        // "Half + Eighth" for a tie across a barline set via
        // combinedDurationDialog) rather than a single label — most
        // ordinary notes decompose into just one entry, which reads
        // identically to how a plain single duration always did.
        // Falls back to durationLabel's own "closest match" behavior
        // for the rare case decomposition finds nothing (shouldn't
        // normally happen for an ordinary note).
        final durationParts = decomposeDurationTicks(editedNote.durationTicks);
        final durationDisplay = durationParts.isEmpty
            ? controller.durationLabel(editedNote)
            : durationParts.map((d) => d.label).join(' + ');

        // Every row's own text, measured to find the single widest
        // one — combined rows (Measure+Beat, Octave+Degree) sum both
        // halves plus the gap between them; ListTile field rows add
        // _listTileChrome for their icon/padding.
        final graceNotes = controller.notes
            .where((n) => n.graceOfNoteId == editedNote.id)
            .toList();
        final graceType =
        graceNotes.isNotEmpty ? graceNotes.first.graceNoteType : null;

        final rowWidths = <double>[
          _textWidth(
            'Pitch: ${controller.getNotePitchName(editedNote)}${editedNote.accidental?.sign ?? ''}',
          ),
          _textWidth('Measure: ${controller.getMeasureNumber(editedNote)}') +
              _rowGap +
              _textWidth('Beat: ${controller.getBeatNumber(editedNote)}'),
          _textWidth('Tempo: $tempoLabel'),
          _textWidth('Time Signature: $timeSignature'),
          _textWidth(
            'Scale: ${measure.scaleName} (${controller.getScaleAsTextArray(measure.scaleName)})',
          ),
          _textWidth(
            'Octave: ${controller.getOctave(editedNote)} '
                '(${controller.getOctaveName(controller.getOctave(editedNote))})',
          ) +
              _rowGap +
              _textWidth('Degree: ${controller.getDegree(editedNote)}'),
          _textWidth('Transcription: ${_transcriptionFor(editedNote)}'),
          _textWidth('Accidental: ${editedNote.accidental?.label ?? 'none'}') +
              _listTileChrome,
          _textWidth(
            (editedNote.graceOfNoteId != null ||
                editedNote.graceOriginalDurationTicks != null)
                ? 'Duration: ${editedNote.durationTicks} ticks (auto)'
                : 'Duration: $durationDisplay',
          ) +
              _listTileChrome,
          _textWidth('Hand: ${editedNote.hand.name}') + _listTileChrome,
          _textWidth(
            'Finger: ${editedNote.finger?.value.toString() ?? 'none'}',
          ) +
              _listTileChrome,
          _textWidth(
            'Articulation: ${editedNote.articulation?.label ?? 'none'}',
          ) +
              _listTileChrome,
          _textWidth('Ornament: ${editedNote.ornament?.label ?? 'none'}') +
              _listTileChrome,
          _textWidth(
            'Playing Technique: ${editedNote.playingTechnique?.label ?? 'none'}',
          ) +
              _listTileChrome,
          _textWidth('Glissando: ${editedNote.glissando?.label ?? 'none'}') +
              _listTileChrome,
          _textWidth(
            graceNotes.isEmpty
                ? 'Grace Notes: none'
                : 'Grace Notes: ${graceNotes.length} (${graceType?.label ?? '?'})',
          ) +
              _listTileChrome,
        ];
        final contentWidth = rowWidths.reduce((a, b) => a > b ? a : b);

        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(
            DefaultValues.dialogPaddingRightLeft,
            DefaultValues.dialogPaddingBottomTop,
            DefaultValues.dialogPaddingRightLeft,
            DefaultValues.dialogPaddingBottomTop,
          ),
          title: Text(
            textAlign: TextAlign.center,
            // 'Note',
            // 'Note ${note.id}',
            // 'Note (tick ${editedNote.startTick + 1}, row ${editedNote.row + 1})',
            'Note ${controller.noteNumber(note)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          // No SingleChildScrollView here (unlike before) — every
          // field must be visible without scrolling, in any
          // orientation. All 9 fields stay in a single column (per
          // request — a two-column layout was tried but reverted);
          // fitting without scroll instead relies on the ListTile
          // Theme override below, pushed to its most compact settings
          // (zero vertical padding, maximally negative
          // VisualDensity), to keep each row as short as possible.
          // IntrinsicWidth sizes the dialog to exactly as wide as its
          // widest field's text needs, rather than a fixed fraction of
          // screen width — no wasted space on shorter rows.
          content: SizedBox(
            width: contentWidth,
            child: Theme(
              data: Theme.of(context).copyWith(
                listTileTheme: const ListTileThemeData(
                  dense: true,
                  visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  minVerticalPadding: 0,
                  minLeadingWidth: 24,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Pitch: ',
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: '${controller.getNotePitchName(editedNote)}${editedNote.accidental?.sign ?? ''}',
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      _infoRow(
                        'Measure:',
                        controller.getMeasureNumber(editedNote).toString(),
                      ),
                      SizedBox(
                        width: DefaultValues.widthBetweenWidgets,
                      ),
                      _infoRow(
                        'Beat:',
                        controller.getBeatNumber(editedNote).toString(),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      _infoRow(
                        'Tempo:',
                        tempoLabel,
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      _infoRow(
                        'Time Signature:',
                        timeSignature,
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      _infoRow(
                        'Scale:',
                        '${measure.scaleName} (${controller.getScaleAsTextArray(measure.scaleName)})',
                      ),
                    ],
                  ),

                  Column(
                    children: [
                      Row(
                        children: [
                          _infoRow(
                            'Octave:',
                            '${controller.getOctave(editedNote).toString()} '
                                '(${controller.getOctaveName(controller.getOctave(editedNote))})',
                          ),
                          SizedBox(
                            width: DefaultValues.widthBetweenWidgets,
                          ),
                          Text.rich(
                            // 'Scale Pitch: ${controller.getNotePitchName(editedNote)}',
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Degree: ',
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: '${controller.getDegree(editedNote)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),


                  Row(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Transcription: ',
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: _transcriptionFor(editedNote),
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(thickness: 1.0),

                  ListTile(
                    // leading: const Icon(Icons.swap_vertical_circle_sharp),
                    leading: const Icon(Icons.open_in_full_sharp),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Accidental: ',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: editedNote.accidental?.label ?? 'none',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      noteValuesDialog<Accidental>(
                        context: context,
                        allowToCloseNextWindow: true,
                        currentValue: editedNote.accidental,
                        title: 'Accidental',
                        values: Accidental.values,
                        numberOfColumns: 2,
                        labelBuilder: (a) => a.sign,
                        onSelected: (accidental) {
                          controller.setNoteAccidental(
                            editedNote,
                            accidental,
                          );
                        },
                        onClear: () {
                          controller.setNoteAccidental(
                            editedNote,
                            null,
                          );
                        },
                      );
                    },
                  ),

                  ListTile(
                    // leading: const Icon(Icons.timelapse),
                    leading: const Icon(Icons.av_timer),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Duration: ',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            // A grace note's own duration, and its anchor's once
                            // it has grace notes, is computed automatically (see
                            // CompositionController._redistributeGraceNotes) from
                            // an arbitrary tick count — never one of the standard
                            // NoteDuration values. durationLabel would otherwise
                            // silently fall back to showing "Quarter" for any
                            // non-matching tick count, which is misleading here,
                            // so the raw tick count is shown directly instead.
                            // graceOfNoteId marks a grace note itself; a note
                            // that instead HAS grace notes (the anchor) is marked
                            // by graceOriginalDurationTicks — graceNoteType is
                            // only ever set on grace notes, never the anchor.
                            text: (editedNote.graceOfNoteId != null ||
                                editedNote.graceOriginalDurationTicks != null)
                                ? '${editedNote.durationTicks} ticks (auto)'
                                : durationDisplay,
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      // Setting a grace note's (or its anchor's) duration
                      // directly to a standard NoteDuration value would
                      // silently corrupt the whole group — the anchor and
                      // its grace notes only stay consistent with each
                      // other via CompositionController.
                      // _redistributeGraceNotes, which this picker knows
                      // nothing about. Duration for these notes is only
                      // ever changed by adding/removing grace notes (see
                      // the Grace Notes field), never set directly.
                      if (editedNote.graceOfNoteId != null ||
                          editedNote.graceOriginalDurationTicks != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            duration: const Duration(seconds: 2),
                            content: Text(
                              "Grace note durations are set automatically "
                                  "and can't be edited directly here.",
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                        return;
                      }
                      // combinedDurationDialog IS the Duration
                      // picker now — picking just one duration
                      // and hitting Apply works exactly like
                      // the old single-select dialog did, but
                      // it also supports adding more than one
                      // duration before applying (e.g. a tie
                      // across a barline, written as an eighth
                      // then a half — see that dialog's own
                      // doc). Pre-seeded with the note's
                      // current duration if it matches a
                      // single standard NoteDuration exactly,
                      // so reopening this shows what's already
                      // set, same as every other field's
                      // picker does via currentValue.
                      combinedDurationDialog(
                        context: context,
                        controller: controller,
                        note: editedNote,
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.back_hand),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Hand: ',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: editedNote.hand.name,
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      // handDialog now — styled to match
                      // noteValuesDialog (see that file's own doc),
                      // and reused directly here (rather than the
                      // generic noteValuesDialog<Hand>) so it can
                      // offer the 3rd "Additional" hand and its own
                      // per-hand color coding. Passing `note:
                      // editedNote` tells it to edit THIS note's hand
                      // (via CompositionController.setNoteHand) and
                      // close this whole NoteDialog on selection too
                      // — matching every other field's picker here.
                      handDialog(
                        context: context,
                        controller: controller,
                        note: editedNote,
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.touch_app),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Finger: ',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: editedNote.finger?.value.toString() ?? 'none',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      noteValuesDialog<Finger>(
                        context: context,
                        allowToCloseNextWindow: true,
                        currentValue: editedNote.finger,
                        title: 'Finger',
                        values: Finger.values,
                        numberOfColumns: 5,
                        labelBuilder: (f) => f.value.toString(),
                        onSelected: (finger) {
                          controller.setNoteFinger(editedNote, finger);
                        },
                        onClear: () {
                          controller.setNoteFinger(editedNote, null);
                        },
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.graphic_eq),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Articulation: ',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: editedNote.articulation?.label ?? 'none',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      noteValuesDialog<Articulation>(
                        context: context,
                        allowToCloseNextWindow: true,
                        currentValue: editedNote.articulation,
                        title: 'Articulation',
                        values: Articulation.values,
                        numberOfColumns: 2,
                        labelBuilder: (o) => o.label,
                        onSelected: (articulation) {
                          controller.setNoteArticulation(
                            editedNote,
                            articulation,
                          );
                        },
                        onClear: () {
                          controller.setNoteArticulation(editedNote, null);
                        },
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Ornament: ',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: editedNote.ornament?.label ?? 'none',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      noteValuesDialog<Ornament>(
                        context: context,
                        allowToCloseNextWindow: true,
                        currentValue: editedNote.ornament,
                        title: 'Ornament',
                        values: Ornament.values,
                        numberOfColumns: 2,
                        labelBuilder: (o) => o.label,
                        onSelected: (ornament) {
                          controller.setNoteOrnament(editedNote, ornament);
                        },
                        onClear: () {
                          controller.setNoteOrnament(editedNote, null);
                        },
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.piano),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Playing Technique: ',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: editedNote.playingTechnique?.label ?? 'none',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      noteValuesDialog<PlayingTechnique>(
                        context: context,
                        allowToCloseNextWindow: true,
                        currentValue: editedNote.playingTechnique,
                        title: 'Playing Technique',
                        values: PlayingTechnique.values,
                        numberOfColumns: 3,
                        labelBuilder: (t) => t.label,
                        onSelected: (technique) {
                          controller.setNotePlayingTechnique(
                            editedNote,
                            technique,
                          );
                        },
                        onClear: () {
                          controller.setNotePlayingTechnique(editedNote, null);
                        },
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.trending_up),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Glissando: ',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: editedNote.glissando?.label ?? 'none',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      noteValuesDialog<GlissandoDirection>(
                        context: context,
                        allowToCloseNextWindow: true,
                        currentValue: editedNote.glissando,
                        title: 'Glissando',
                        values: GlissandoDirection.values,
                        numberOfColumns: 1,
                        labelBuilder: (d) => d.label,
                        onSelected: (direction) {
                          // Closes this dialog too (allowToCloseNextWindow) so
                          // the grid is ready for the end-row tap that
                          // completes it — see
                          // CompositionController.startGlissandoPick /
                          // GridWidget's onTapUp.
                          controller.startGlissandoPick(editedNote, direction);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              duration: const Duration(seconds: 2),
                              content: Text(
                                'Tap the grid to set the glissando end row',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                        onClear: () {
                          // Removes the glissando flag AND every generated
                          // run note belonging to it — see
                          // CompositionController.clearNoteGlissando.
                          controller.clearNoteGlissando(editedNote);
                        },
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.speed),
                    title: Builder(
                      builder: (context) {
                        final graceNotes = controller.notes
                            .where((n) => n.graceOfNoteId == editedNote.id)
                            .toList();
                        // Only one type is ever active on a note at a time
                        // (see CompositionController.startAddingGraceNotes),
                        // so every entry here shares the same graceNoteType.
                        final currentType =
                        graceNotes.isNotEmpty ? graceNotes.first.graceNoteType : null;
                        return Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Grace Notes: ',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: graceNotes.isEmpty
                                    ? 'none'
                                    : '${graceNotes.length} '
                                    '(${currentType?.label ?? '?'})',
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      final graceNotes = controller.notes
                          .where((n) => n.graceOfNoteId == editedNote.id)
                          .toList();
                      final currentType =
                      graceNotes.isNotEmpty ? graceNotes.first.graceNoteType : null;
                      noteValuesDialog<GraceNoteType>(
                        context: context,
                        allowToCloseNextWindow: true,
                        currentValue: currentType,
                        title: 'Add Grace Note',
                        values: GraceNoteType.values,
                        numberOfColumns: 1,
                        labelBuilder: (t) => t.label,
                        onSelected: (type) {
                          // Closes this dialog too (allowToCloseNextWindow) so
                          // the grid is ready for tapping — every tap adds one
                          // more grace note of this type, up to
                          // CompositionController.maxGraceNotesForType (which
                          // depends on this note's own duration — shorter
                          // notes allow fewer), until the mode is turned off
                          // from the app bar — see CompositionController.
                          // startAddingGraceNotes / GridWidget's onTapUp. A
                          // note can only have ONE type of grace note active
                          // at a time — picking a DIFFERENT type than
                          // whatever's already there deletes the existing
                          // ones first.
                          final maxForType =
                          controller.maxGraceNotesForType(editedNote, type);
                          controller.startAddingGraceNotes(editedNote, type);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 2),
                              content: Text(
                                maxForType == 0
                                    ? 'This note is too short for ${type.label}'
                                    : 'Tap the grid to add ${type.label}'
                                    ' (max $maxForType for this note), '
                                    'to stop click lighted button on app bar.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                        onClear: () {
                          // Removes every grace note belonging to this note
                          // and reverts it back to its original duration —
                          // see CompositionController.clearAllGraceNotes.
                          controller.clearAllGraceNotes(editedNote);
                        },
                      );
                    },
                  ),

                ],
              ),
            ),
          ),

          actionsPadding: const EdgeInsets.fromLTRB(
            DefaultValues.dialogPaddingRightLeft,
            DefaultValues.dialogPaddingBottomTop,
            DefaultValues.dialogPaddingRightLeft,
            DefaultValues.dialogPaddingBottomTop,
          ),
          actions: [
            const Divider(thickness: 1.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    controller.removeNote(editedNote);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    controller.copyNote(editedNote);
                    controller.enterPasteMode();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text('Note ${controller.noteNumber(editedNote)} is copied'),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Copy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
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
          ],
        );
      },
    );
  }



  Widget _infoRow(String title, String value) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Text(
              '$title ',
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black,
              )
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              // fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }


}