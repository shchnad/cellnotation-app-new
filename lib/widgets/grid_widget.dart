import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../painters/grid_painter.dart';
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

        // grid cell size (zoom-safe)
        final cellHeight = (height / rows) * controller.zoomY;
        final cellWidth = (width / beats) *
            controller.zoomX *
            controller.gridScale;


        return GestureDetector(
          behavior: HitTestBehavior.opaque,

          // ================= PINCH ZOOM =================
          onScaleUpdate: (details) {
            controller.setZoom(
              (controller.zoomX * details.scale),
              (controller.zoomY * details.scale),
            );
          },

          child: Stack(
            children: [
              // ================= GRID =================
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(
                    beats: beats,
                    rows: rows,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    barLines: controller.barLines,
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

                    final note = controller.getNoteAt(beat, row);

                    if (note == null) {
                      controller.addNote(tick: beat, row: row);
                    } else {
                      controller.removeNote(note);
                    }
                  },

                  child: const SizedBox.expand(),
                ),
              ),



              // ================= NOTES =================
              ...controller.notes.map(
                    (note) => NoteBlockWidget(
                  note: note,
                  cellWidth: cellWidth,
                  cellHeight: cellHeight,
                  controller: controller,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}