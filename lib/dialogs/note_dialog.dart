import 'package:flutter/material.dart';
import 'package:music_composer/enums/articulation.dart';

import '../controllers/composition_controller.dart';
import '../enums/accidental.dart';
import '../enums/finger.dart';
import '../enums/glissando_direction.dart';
import '../enums/grace_note_type.dart';
import '../enums/hand.dart';
import '../enums/note_duration.dart';
import '../enums/ornament.dart';
import '../enums/playing_technique.dart';
import '../models/note.dart';
import '../utils/default_values.dart';
import 'note_values_dialog.dart';

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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Pitch: ${controller.getNotePitchName(editedNote)}${editedNote.accidental?.sign ?? ''}',
                      style: TextStyle(
                        fontSize: 22,
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
                        Text(
                          // 'Scale Pitch: ${controller.getNotePitchName(editedNote)}',
                          'Degree: ${controller.getDegree(editedNote)}',
                          style: TextStyle(
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),


                const Divider(thickness: 1.0),

                ListTile(
                  // leading: const Icon(Icons.swap_vertical_circle_sharp),
                  leading: const Icon(Icons.open_in_full_sharp),
                  title: Text(
                    // 'Accidental: ${editedNote.accidental?.sign ?? 'none'}',
                    'Accidental: ${editedNote.accidental?.label ?? 'none'}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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
                  title: Text(
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
                    (editedNote.graceOfNoteId != null ||
                        editedNote.graceOriginalDurationTicks != null)
                        ? 'Duration: ${editedNote.durationTicks} ticks (auto)'
                        : 'Duration: ${controller.durationLabel(editedNote)}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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
                    // the Grace Notes field below), never set directly.
                    if (editedNote.graceOfNoteId != null ||
                        editedNote.graceOriginalDurationTicks != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Grace note durations are set automatically "
                                "and can't be edited directly here.",
                            style: TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                      return;
                    }
                    final duration = NoteDuration.values.firstWhere(
                          (d) => d.ticks == editedNote.durationTicks,
                      orElse: () => NoteDuration.quarter,
                    );
                    noteValuesDialog<NoteDuration>(
                      context: context,
                      allowToCloseNextWindow: true,
                      currentValue: duration,
                      title: 'Duration',
                      values: NoteDuration.values,
                      numberOfColumns: 3,
                      labelBuilder: (d) => d.label,
                      onSelected: (d) {
                        controller.setNoteDuration(editedNote, d);
                      },
                    );
                  },
                ),


                ListTile(
                  leading: const Icon(Icons.back_hand),
                  title: Text(
                    'Hand: ${editedNote.hand.name}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    noteValuesDialog<Hand>(
                      context: context,
                      allowToCloseNextWindow: true,
                      currentValue: editedNote.hand,
                      title: 'Hand',
                      values: Hand.values,
                      numberOfColumns: 2,
                      labelBuilder: (h) => h.name,
                      onSelected: (hand) {
                        controller.setNoteHand(editedNote, hand);
                      },
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.touch_app),
                  title: Text(
                    'Finger: ${ editedNote.finger?.value.toString() ?? 'none'}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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
                  title: Text(
                    'Articulation: ${editedNote.articulation?.label ?? 'none'}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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
                  title: Text(
                    'Ornament: ${editedNote.ornament?.label ?? 'none'}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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
                  title: Text(
                    'Playing Technique: ${editedNote.playingTechnique?.label ?? 'none'}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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
                  title: Text(
                    'Glissando: ${editedNote.glissando?.label ?? 'none'}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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
                      return Text(
                        graceNotes.isEmpty
                            ? 'Grace Notes: none'
                            : 'Grace Notes: ${graceNotes.length} '
                            '(${currentType?.label ?? '?'})',
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
              '$title ',
              style: const TextStyle(
                fontSize: 22,
              )
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              // fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }


}