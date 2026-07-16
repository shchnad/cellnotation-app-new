import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import 'note_block_widget.dart';


class GridWidget extends StatelessWidget {

  final CompositionController controller;
  final double cellHeight;


  const GridWidget({
    super.key,
    required this.controller,
    required this.cellHeight,
  });


  @override
  Widget build(BuildContext context) {
    final pixelsPerTick = controller.pixelsPerTick;

    final gridHeight = controller.totalRows * cellHeight;

    final gridWidth = controller.maxTicks * pixelsPerTick;

    return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,

        child: SizedBox(
          width: gridWidth,
          height: gridHeight,

          child: Stack(
            children: [

              // GRID BACKGROUND
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final row = (details.localPosition.dy /
                        cellHeight)
                        .floor();

                    final rawTick =
                    (details.localPosition.dx /
                        pixelsPerTick)
                        .floor();

                    if (row >= 0 && row < controller.totalRows) {
                      // Do not create a note
                      // if there is already one here

                      final existing = controller.getNoteAtPosition(
                        rawTick,
                        row,
                      );

                      if (existing == null) {
                        if (controller.pasteMode) {
                          controller.pasteNoteAt(
                            rawTick,
                            row,
                          );
                        }
                        else {
                          controller.handleGridTap(
                            rawTick,
                            row,
                          );
                        }
                      }
                    }
                  },

                  child: CustomPaint(
                    painter: GridPainter(
                      controller: controller,
                      cellHeight: cellHeight,
                      pixelsPerTick: pixelsPerTick,

                    ),

                  ),

                ),

              ),


              // NOTES
              ...controller.notes.map(

                    (note) =>
                    NoteBlockWidget(

                      key: ValueKey(note.id),
                      note: note,
                      pixelsPerTick: pixelsPerTick,
                      cellHeight: cellHeight,
                      controller: controller,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  );

  }
}



class GridPainter extends CustomPainter {
  final CompositionController controller;
  final double cellHeight;
  final double pixelsPerTick;

  GridPainter({
    required this.controller,
    required this.cellHeight,
    required this.pixelsPerTick,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {

    final thinPaint =
    Paint()
      ..color = Colors.grey.withOpacity(0.25)
      ..strokeWidth = 1;

    final beatPaint = Paint()
      ..color =
      Colors.grey.withOpacity(0.55)
      ..strokeWidth = 1.5;


    final octavePaint = Paint()
      ..color =
      Colors.grey.withOpacity(0.55)
      ..strokeWidth = 1.5;

    final measurePaint = Paint()
      ..color =
      Colors.black.withOpacity(0.75)
      ..strokeWidth = 2;


    final middleOctavePaint = Paint()
      ..color =
      Colors.black.withOpacity(0.75)
      ..strokeWidth = 2;



    // HORIZONTAL LINES

    for(int row = 0;
    row <= controller.totalRows;
    row++) {


      final y = row * cellHeight;


      Paint linePaint = thinPaint;


      if(row > 0 && row % 7 == 0) {
        linePaint = octavePaint;
      }


      if(row == 28) {
        linePaint = middleOctavePaint;
      }


      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );

    }


    // VERTICAL MEASURE / BEAT LINES

    for(final measure
    in controller.measures) {
      final measureX = measure.startTick * pixelsPerTick;
      canvas.drawLine(
        Offset(measureX, 0),
        Offset(
            measureX,
            size.height
        ),
        measurePaint,
      );


      final beatTicks = measure.timeSignature
              .beatDuration
              .ticks;
      for(
      int tick = measure.startTick + beatTicks;
      tick < measure.endTick;
      tick += beatTicks
      ) {
        final x = tick * pixelsPerTick;
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          beatPaint,
        );
      }
    }
  }


  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return true;
  }

}