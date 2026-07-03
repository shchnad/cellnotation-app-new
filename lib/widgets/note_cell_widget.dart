import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

class NoteCellWidget extends StatelessWidget {
  final CompositionController controller;
  final int beatIndex;
  final int row;
  final double width;
  final double height;

  const NoteCellWidget({
    super.key,
    required this.controller,
    required this.beatIndex,
    required this.row,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {

    final notes = controller.getNotesAtBeat(beatIndex);

    final isActive = notes.any((n) => n.row == row);

    return GestureDetector(
      onTap: () {
      final existing = controller.notes
          .where((n) => n.startBeat == beatIndex && n.row == row)
          .toList();
      if (existing.isEmpty) {
        controller.addNote(
          beat: beatIndex,
          row: row,
        );
      } else {
        controller.removeNote(existing.first);
      }
    },
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.grey[200],
          border: Border.all(color: Colors.black12),
        ),
      ),
    );
  }
}