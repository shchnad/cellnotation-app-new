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

        final beats = controller.maxTicks;
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

              // GRID
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


              // EMPTY CELL TAP
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,

                  onTapDown: (details) {
                    final tick =
                    (details.localPosition.dx / cellWidth).floor();
                    final row =
                    (details.localPosition.dy / cellHeight).floor();
                    if (controller.getNoteAt(tick,row) == null) {
                      if (controller.pasteMode) {
                        controller.pasteNote(
                          tick: tick,
                          row: row,
                        );
                      } else {
                        controller.addNote(
                          tick: tick,
                          row: row,
                        );
                      }
                    }
                  },

                  onLongPressStart: (details) {
                    final tick = (details.localPosition.dx / cellWidth).floor();
                    final row = (details.localPosition.dy / cellHeight).floor();
                    controller.pasteNote(
                      tick: tick,
                      row: row,
                    );
                  },

                  child: const SizedBox.expand(),
                ),
              ),


              // NOTES LAST
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