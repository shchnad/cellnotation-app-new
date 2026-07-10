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

import 'noteValues_dialog.dart';


class NoteDialog extends StatelessWidget {

  final Note note;
  final CompositionController controller;

  const NoteDialog({
    super.key,
    required this.note,
    required this.controller,
  });

  static const Size _buttonSize = Size(150, 44);

  Note get currentNote {
    return controller.notes.firstWhere(
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
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          title: Text(
            textAlign: TextAlign.center,
            'Note C${editedNote.startTick + 1} / R${editedNote.row + 1}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const Divider(height: 8, thickness: 0.5),
                Row(
                  children: [

                    Expanded(
                      child: _infoRow(
                        'Measure',
                        controller.getMeasureNumber(editedNote).toString(),
                      ),
                    ),

                    Expanded(
                      child: _infoRow(
                        'Beat',
                        controller.getBeatNumber(editedNote).toString(),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 8, thickness: 0.5),


                Row(
                  children: [

                    Expanded(
                      child: _octaveInfo(
                        'Octave',
                        controller.getOctave(editedNote).toString(),
                        controller.getOctaveName(
                          controller.getOctave(editedNote),
                        ),
                      ),
                    ),

                    const SizedBox(width: 50),

                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _infoRow(
                          'Pitch',
                          controller.getDegree(editedNote.row),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: null,
                        foregroundColor: Colors.blue,
                        minimumSize: const Size(48, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        noteValuesDialog<Accidental>(
                          context: context,
                          currentValue: editedNote.accidental,
                          title: 'Accidental',
                          values: Accidental.values,
                          numberOfColumns: 4,
                          labelBuilder: (a) => a.label,
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
                      child: Text(
                        editedNote.accidental?.sign ?? 'None',
                        style: const TextStyle(
                          fontSize: 22,
                        ),
                      ),
                    ),

                  ],
                ),

                const Divider(height: 8, thickness: 0.5),

                _editButton(
                  'Duration',
                  controller.durationLabel(editedNote),
                      () {
                    final duration = NoteDuration.values.firstWhere(
                          (d) => d.ticks == editedNote.durationTicks,
                      orElse: () => NoteDuration.quarter,
                    );
                    noteValuesDialog<NoteDuration>(
                      context: context,
                      currentValue:
                      duration,
                      title: 'Set Duration',
                      values: NoteDuration.values,
                      numberOfColumns: 3,
                      labelBuilder: (d) => d.label,
                      onSelected: (d) {
                        controller.setNoteDuration(editedNote, d);
                      },
                    );
                  },
                ),

                _editButton(
                  'Hand',
                  editedNote.hand.name,
                      () {
                    noteValuesDialog<Hand>(
                      context: context,
                      currentValue:
                      editedNote.hand,
                      title: 'Set Hand',
                      values: Hand.values,
                      numberOfColumns: 2,
                      labelBuilder: (h) => h.name,
                      onSelected: (hand) {
                        controller.setNoteHand(
                          editedNote,
                          hand,
                        );
                      },
                    );
                  },
                ),

                _editButton(
                  'Finger',
                  editedNote.finger?.value.toString() ?? 'none',
                      () {
                    noteValuesDialog<Finger>(
                      context: context,
                      currentValue:
                      editedNote.finger,
                      title: 'Set Finger',
                      values: Finger.values,
                      numberOfColumns: 5,
                      labelBuilder: (f) => f.value.toString(),
                      onSelected:(finger) {
                        controller.setNoteFinger(editedNote, finger);
                      },
                      onClear: () {
                        controller.setNoteFinger(editedNote, null);
                      },
                    );
                  },
                ),

                _editButton(
                  'Articulation',
                  editedNote.articulation?.label ?? 'None',
                      () {
                    noteValuesDialog<Articulation>(
                      context: context,
                      currentValue: editedNote.articulation,
                      title: 'Set Articulation',
                      values: Articulation.values,
                      numberOfColumns: 3,
                      labelBuilder: (o) => o.label,
                      onSelected: (articulation) {
                        controller.setNoteArticulation(
                          editedNote,
                          articulation,
                        );
                      },
                      onClear: () {
                        controller.setNoteArticulation(
                          editedNote,
                          null,
                        );
                      },
                    );
                  },
                ),

                _editButton(
                  'Ornament',
                  editedNote.ornament?.label ?? 'None',
                      () {
                    noteValuesDialog<Ornament>(
                      context: context,
                      currentValue: editedNote.ornament,
                      title: 'Set Ornament',
                      values: Ornament.values,
                      numberOfColumns: 2,
                      labelBuilder: (o) => o.label,
                      onSelected: (ornament) {
                        controller.setNoteOrnament(
                          editedNote,
                          ornament,
                        );
                      },
                      onClear: () {
                        controller.setNoteOrnament(
                          editedNote,
                          null,
                        );
                      },
                    );
                  },
                ),

                _editButton(
                  'Technique',
                  editedNote.playingTechnique?.label ?? 'None',
                      () {
                    noteValuesDialog<PlayingTechnique>(
                      context: context,
                      currentValue: editedNote.playingTechnique,
                      title: 'Set Technique',
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
                        controller.setNotePlayingTechnique(
                          editedNote,
                          null,
                        );
                      },
                    );
                  },
                ),

              ],
            ),
          ),

          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Close',
                style:
                TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],

        );
      },
    );
  }


  Widget _infoRow(
      String title,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: Row(
        children: [
          Text(
            '$title: ',
            style: const TextStyle(
              fontSize: 22,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }


  Widget _editButton(
      String title,
      String value,
      VoidCallback onTap,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(
              fontSize: 22,
              // fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: null,
              foregroundColor: Colors.blue,
              // minimumSize: const Size(110, 36),
              fixedSize: _buttonSize,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed:
            onTap,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                // fontWeight: FontWeight.bold,
                // color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _octaveInfo(
      String title,
      String value,
      String subLabel,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '$title: ',
                style: const TextStyle(
                  fontSize: 22,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Text(
            subLabel.toLowerCase(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }



}