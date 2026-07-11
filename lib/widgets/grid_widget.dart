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

        final int rows = controller.maxRows.toInt();
        final int totalTicks = controller.maxTicks.toInt();

        // 1. Calculate continuous pixel mapping scaling instead of fixed cell widths
        final double pixelsPerBeat = controller.zoomX * controller.gridScale;
        final double cellHeight = (height / rows) * controller.zoomY;

        // 2. Fetch PPQN directly from the timeline to know how many ticks fit in a beat
        final int ppqn = controller.timeline.measures.isNotEmpty
            ? controller.timeline.measures.first.timeSignature.ticksPerBeat
            : 96;

        final double pixelsPerTick = pixelsPerBeat / ppqn;

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

              // LAYER 1: THE BACKGROUND GRID CANVAS
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(
                    totalTicks: totalTicks,
                    ppqn: ppqn,
                    rows: rows,
                    pixelsPerBeat: pixelsPerBeat,
                    cellHeight: cellHeight,
                    barLines: controller.barLines,
                    // 💡 FIXED: Now passing real timeline data so barlines calculate dynamic widths
                    measures: controller.timeline.measures,
                    currentScale: controller.currentScale,
                  ),
                ),
              ),

              // LAYER 2: INTERACTION OVERLAY FOR CREATING NOTES
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,

                  onTapDown: (details) {
                    final int rawTick = (details.localPosition.dx / pixelsPerTick).floor();
                    final int row = (details.localPosition.dy / cellHeight).floor();

                    final int snappedTick = controller.snapTick(rawTick);

                    if (controller.getNoteAt(snappedTick, row) == null) {
                      if (controller.pasteMode) {
                        controller.pasteNote(
                          tick: snappedTick,
                          row: row,
                        );
                      } else {
                        controller.addNote(
                          tick: snappedTick,
                          row: row,
                        );
                      }
                    }
                  },

                  onLongPressStart: (details) {
                    final int rawTick = (details.localPosition.dx / pixelsPerTick).floor();
                    final int row = (details.localPosition.dy / cellHeight).floor();
                    final int snappedTick = controller.snapTick(rawTick);

                    controller.pasteNote(
                      tick: snappedTick,
                      row: row,
                    );
                  },

                  child: const SizedBox.expand(),
                ),
              ),

              // LAYER 3: DYNAMICALLY POSITIONED NOTE BLOCK WIDGETS
              ...controller.notes.map(
                    (note) => NoteBlockWidget(
                  note: note,
                  pixelsPerTick: pixelsPerTick,
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