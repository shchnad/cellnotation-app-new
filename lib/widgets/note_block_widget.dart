import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../enums/hand.dart';
import '../models/note.dart';
import '../dialogs/note_dialog.dart';


class NoteBlockWidget extends StatelessWidget {

  final Note note;
  final double pixelsPerTick;
  final double cellHeight;
  final CompositionController controller;


  const NoteBlockWidget({
    super.key,
    required this.note,
    required this.pixelsPerTick,
    required this.cellHeight,
    required this.controller,
  });


  @override
  Widget build(BuildContext context) {

    final left = note.startTick * pixelsPerTick;

    final width = note.durationTicks * pixelsPerTick;

    final top = note.row * cellHeight;

    final pitch = controller.getNotePitchName(note);



    return Positioned(
      left: left,
      top: top,
      width: width,
      height: cellHeight,
      child: GestureDetector(
        behavior:
        HitTestBehavior.opaque,

        onDoubleTap: (){
          showDialog(
            context: context,
            builder: (_) =>
                NoteDialog(
                  note: note,
                  controller: controller,
                ),
          );
        },

        onTap: (){
          if(!controller.pasteMode){
            controller.removeNote(note);
          }
        },

        onLongPress: (){
          controller.copyNote(note);
          controller.enterPasteMode();
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content:
              Text(
                  "Note copied"
              ),
            ),
          );
        },

        onPanUpdate: (details){
          final tickChange = (details.delta.dx / pixelsPerTick).round();
          final rowChange = (details.delta.dy / cellHeight).round();
          final newTick = controller.snapTick( note.startTick + tickChange);
          final newRow = (note.row + rowChange).clamp(0, controller.totalRows - 1);
          if(
          newTick != note.startTick || newRow != note.row){
            controller.updateNote(
              note,
              newTick,
              newRow,
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: _handColor(
                note.hand
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 5
              ),
              child: Text(
                pitch,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: cellHeight * .75,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );

  }


  Color _handColor(Hand hand){
    return hand == Hand.right
        ? Colors.black
        : Colors.blue;
  }
}