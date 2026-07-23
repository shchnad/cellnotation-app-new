import 'package:flutter/material.dart';
import 'package:music_composer/enums/articulation.dart';

import '../controllers/composition_controller.dart';
import '../enums/accidental.dart';
import '../enums/finger.dart';
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
                          'Pitch: ${controller.getNotePitchName(editedNote)} ${editedNote.accidental?.sign ?? ''}',
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
                'Accidental: ${editedNote.accidental?.sign ?? 'none'}',
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                noteValuesDialog<Accidental>(
                  context: context,
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
                'Duration: ${controller.durationLabel(editedNote)}',
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
              ),
              onTap: () {
                final duration = NoteDuration.values.firstWhere(
                      (d) => d.ticks == editedNote.durationTicks,
                  orElse: () => NoteDuration.quarter,
                );
                noteValuesDialog<NoteDuration>(
                  context: context,
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
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              noteValuesDialog<Hand>(
                context: context,
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
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              noteValuesDialog<Finger>(
                context: context,
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
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              noteValuesDialog<Articulation>(
                context: context,
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
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              noteValuesDialog<Ornament>(
                context: context,
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
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              noteValuesDialog<PlayingTechnique>(
                context: context,
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
