import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../models/note.dart';

class NoteBlockWidget extends StatelessWidget {
  final Note note;
  final double cellWidth;
  final double cellHeight;
  final CompositionController controller;

  const NoteBlockWidget({
    super.key,
    required this.note,
    required this.cellWidth,
    required this.cellHeight,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {

    return Positioned(
      left: note.startBeat * cellWidth,
      top: note.row * cellHeight,
      width: note.duration * cellWidth,
      height: cellHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onTap: () {
          controller.removeNote(note);
        },

        onPanUpdate: (details) {
          final dx = details.delta.dx;
          final dy = details.delta.dy;

          final beatChange = dx / cellWidth;
          final rowChange = dy / cellHeight;

          final newBeat = (note.startBeat + beatChange).round();
          final newRow = (note.row + rowChange).round();

          controller.updateNote(note, newBeat, newRow);
        },

        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}