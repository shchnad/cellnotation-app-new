import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import 'note_block_widget.dart';

class GridWidget extends StatelessWidget {
  final CompositionController controller;

  const GridWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final beats =
        controller.composition.numberOfMeasures *
            controller.composition.beatsPerMeasure;

    final rows = controller.composition.numberOfOctaves * 12;

    final cellWidth = (size.width / beats) * controller.zoomX;
    final cellHeight = (size.height / rows) * controller.zoomY;

    return GestureDetector(
      onScaleUpdate: (details) {
        controller.applyGestureZoom(details.scale);
      },
      onScaleEnd: (_) {
        controller.commitZoom();
      },
      child: Stack(
        children: [
          // =====================================================
          // GRID BACKGROUND (LIGHTWEIGHT - NO WIDGET EXPLOSION)
          // =====================================================
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                beats: beats,
                rows: rows,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
              ),
            ),
          ),

          // =====================================================
          // NOTES LAYER (DAW OBJECTS)
          // =====================================================
          ...controller.notes
              .map((note) => NoteBlockWidget(
            note: note,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            controller: controller,
          ))
              .toList(),
        ],
      ),
    );
  }
}



// Grid Painter

class _GridPainter extends CustomPainter {
  final int beats;
  final int rows;
  final double cellWidth;
  final double cellHeight;

  _GridPainter({
    required this.beats,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    // vertical lines (beats)
    for (int i = 0; i <= beats; i++) {
      final x = i * cellWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, rows * cellHeight),
        paint,
      );
    }

    // horizontal lines (rows)
    for (int i = 0; i <= rows; i++) {
      final y = i * cellHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(beats * cellWidth, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}