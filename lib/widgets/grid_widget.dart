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


    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final beats = controller.maxBeats;
        final rows = controller.maxRows;

        final cellWidth = (width / beats) * controller.zoomX;
        final cellHeight = (height / rows) * controller.zoomY;

        return Stack(
          children: [
            // ================= VISUAL GRID =================
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


// ================= TAP LAYER =================
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) {
                  final x = details.localPosition.dx;
                  final y = details.localPosition.dy;

                  final beat = (x / cellWidth).floor();
                  final row = (y / cellHeight).floor();

                  if (beat < 0 || beat >= beats) return;
                  if (row < 0 || row >= rows) return;

                  final existing = controller.getNoteAt(beat, row);

                  if (existing == null) {
                    controller.addNote(
                      beat: beat,
                      row: row,
                    );
                  } else {
                    controller.removeNote(existing);
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),

            // ================= NOTES =================
            ...controller.notes.map((note) {
              return NoteBlockWidget(
                note: note,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                controller: controller,
              );
            }).toList(),
          ],
        );
      },
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

// Vertical lines
    for (int i = 0; i <= beats; i++) {
      final x = i * cellWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

// Horizontal lines
    for (int i = 0; i <= rows; i++) {
      final y = i * cellHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}