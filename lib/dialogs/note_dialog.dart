import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../models/note.dart';
import 'duration_dialog.dart';
import 'hand_dialog.dart';


class NoteDialog extends StatelessWidget {

  final Note note;
  final CompositionController controller;


  const NoteDialog({
    super.key,
    required this.note,
    required this.controller,
  });


  @override
  Widget build(BuildContext context) {

    return AlertDialog(

      title: Text(
        'Note #${note.id}',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),


      content: SingleChildScrollView(

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ================= NOTE INFO =================

            const Divider(),

            Column(
              children: [

              Row(
                children: [
                _infoRow(
                  'Measure: ',
                  controller.getMeasureNumber(note).toString(),
                ),
                SizedBox(width: 10),
                _infoRow(
                  'Beat: ',
                  controller.getBeatNumber(note).toString(),
                ),
               ],
              ),

              const Divider(),

              Row(
                children: [
              _infoRow(
                'Octave: ',
                controller.getOctave(note).toString(),
              ),
              SizedBox(width: 10),
              _infoRow(
                'Pitch: ',
                controller.getDegree(note.row),
              ),
              SizedBox(width: 10),
              _editButton(
                'Accidental',
                note.accidental.name,
                    () {
                  showHandDialog(
                    context,
                    note,
                    controller,
                  );
                },
              ),
              ],
              )


              //
              // _infoRow(
              //   'Accidental: ',
              //   note.accidental.value ?? '',
              // ),

            ],
            ),

            const Divider(),

            // ================= EDITABLE =================

            _editButton(
              'Hand',
              note.hand.name,
                  () {

                showHandDialog(
                  context,
                  note,
                  controller,
                );

              },
            ),

            _editButton(
              'Duration',
              controller.durationLabel(note),
                  () {
                    showDurationDialog(context, controller);
                  },
            ),


            _editButton(
              'Finger',
              note.finger?.value.toString() ?? '',
                  () {

                // TODO finger dialog

              },
            ),


            _editButton(
              'Ornament',
              note.ornament.name,
                  () {

                // TODO ornament dialog

              },
            ),


            _editButton(
              'Articulation',
              note.articulation.name,
                  () {

                // TODO articulation dialog

              },
            ),


            _editButton(
              'Technique',
              note.playingTechnique.abbreviation,
                  () {

                // TODO technique dialog

              },
            ),


          ],

        ),

      ),



      actions: [


        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Close',
            style: TextStyle(
              fontSize: 22,
            ),
          ),
        ),
      ],
    );
  }



  // ================= COMPACT INFORMATION =================

  Widget _infoRow(
      String title,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
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


  // ================= EDIT BUTTON =================

  Widget _editButton(
      String title,
      String value,
      VoidCallback onTap,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(130, 48),
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(8),
              ),
            ),
            onPressed: onTap,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }


}