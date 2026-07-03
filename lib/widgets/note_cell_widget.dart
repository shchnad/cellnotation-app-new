import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../enums/hand.dart';

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
    final note = controller.getNoteAt(beatIndex, row);
    final isActive = note != null;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          print("beat: $beatIndex row: $row");

          final existing = controller.getNoteAt(beatIndex, row);

          if (existing == null) {
            controller.addNote(
              beat: beatIndex,
              row: row,
            );
          } else {
            controller.removeNote(existing);
          }
        },
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }
}