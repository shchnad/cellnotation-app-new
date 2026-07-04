import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../enums/hand.dart';
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
    final label = controller.getDegree(note.row);

    final fontSize = cellHeight * 0.7;

    return Positioned(
      left: note.startBeat * cellWidth,
      top: note.row * cellHeight,
      width: note.duration.beats * cellWidth,
      height: cellHeight,
      child: GestureDetector(
        onTap: () => controller.removeNote(note),

        onPanUpdate: (details) {
          controller.updateNote(
            note,
            (note.startBeat + details.delta.dx / cellWidth).round(),
            (note.row + details.delta.dy / cellHeight).round(),
          );
        },

        child: Container(
          decoration: BoxDecoration(
            color: note.hand == Hand.left ? Colors.blue : Colors.black,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              controller.getDegree(note.row),
              style: TextStyle(
                color: Colors.white,
                fontSize: cellHeight * 0.7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}