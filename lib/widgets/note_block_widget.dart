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
    final fontSize = cellHeight * 0.6;

    return Positioned(
      left: note.startTick * cellWidth,
      top: note.row * cellHeight,
      width: note.durationTicks * cellWidth,
      height: cellHeight,

      child: GestureDetector(
        onTap: () => controller.removeNote(note),

        onPanUpdate: (details) {
          final dxTicks = (details.delta.dx / cellWidth).round();
          final dyRows = (details.delta.dy / cellHeight).round();

          controller.updateNote(
            note,
            note.startTick + dxTicks,
            note.row + dyRows,
          );
        },

        child: Container(
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: note.hand == Hand.left
                ? Colors.blue
                : Colors.black,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            controller.getDegree(note.row),
            textAlign: TextAlign.left,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}