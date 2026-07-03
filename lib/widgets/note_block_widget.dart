import 'package:flutter/material.dart';
import '../models/note.dart';
import '../controllers/composition_controller.dart';

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
        onTap: () => controller.removeNote(note),
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