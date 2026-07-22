import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../dialogs/tempo_dialog.dart';
import 'note_block_widget.dart';

/// Shared text style so the widget's hit-testing and the painter's
/// drawing always agree on the label's size.
const _tempoLabelStyle = TextStyle(
  color: Colors.blue,
  fontSize: 18,
  fontWeight: FontWeight.bold,
);

class _TempoLabelHit {
  final dynamic tempoEvent;
  final Rect rect;
  _TempoLabelHit(this.tempoEvent, this.rect);
}

List<_TempoLabelHit> _computeTempoLabelRects(
    CompositionController controller,
    double pixelsPerTick,
    ) {
  final hits = <_TempoLabelHit>[];
  for (final tempoEvent in controller.timeline.tempoEvents) {
    final x = tempoEvent.tick * pixelsPerTick;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${tempoEvent.tempo.label} = ${tempoEvent.tempo.value}',
        style: _tempoLabelStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    hits.add(
      _TempoLabelHit(
        tempoEvent,
        Rect.fromLTWH(x + 5, 5, textPainter.width, textPainter.height),
      ),
    );
  }
  return hits;
}

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
                        // 1. Check tempo labels first — tapping a label
                        //    should edit tempo, not create a note.
                        final tempoHits = _computeTempoLabelRects(
                          controller,
                          pixelsPerTick,
                        );

                        for (final hit in tempoHits) {
                          if (hit.rect.contains(details.localPosition)) {
                            tempoDialog(
                              context,
                              controller,
                              hit.tempoEvent.tick,
                            );
                            return; // don't fall through to note creation
                          }
                        }

                        // 2. Otherwise, normal grid/note tap handling.
                        final row =
                        (details.localPosition.dy / cellHeight).floor();
                        final rawTick =
                        (details.localPosition.dx / pixelsPerTick).floor();

                        if (row >= 0 && row < controller.totalRows) {
                          final existing = controller.getNoteAtPosition(
                            rawTick,
                            row,
                          );

                          if (existing == null) {
                            if (controller.pasteMode) {
                              controller.pasteNoteAt(rawTick, row);
                            } else {
                              controller.handleGridTap(rawTick, row);
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
                        (note) => NoteBlockWidget(
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
      },
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
  void paint(Canvas canvas, Size size) {
    final thinPaint = Paint()
      ..color = Colors.grey.withOpacity(0.25)
      ..strokeWidth = 1;

    final beatPaint = Paint()
      ..color = Colors.grey.withOpacity(0.55)
      ..strokeWidth = 1.5;

    final octavePaint = Paint()
      ..color = Colors.grey.withOpacity(0.55)
      ..strokeWidth = 1.5;

    final measurePaint = Paint()
      ..color = Colors.black.withOpacity(0.75)
      ..strokeWidth = 2;

    final middleOctavePaint = Paint()
      ..color = Colors.black.withOpacity(0.75)
      ..strokeWidth = 2;

    // HORIZONTAL LINES
    for (int row = 0; row <= controller.totalRows; row++) {
      final y = row * cellHeight;
      Paint linePaint = thinPaint;

      if (row > 0 && row % 7 == 0) {
        linePaint = octavePaint;
      }
      if (row == 28) {
        linePaint = middleOctavePaint;
      }

      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // VERTICAL MEASURE / BEAT LINES
    for (final measure in controller.measures) {
      final measureX = measure.startTick * pixelsPerTick;
      canvas.drawLine(
        Offset(measureX, 0),
        Offset(measureX, size.height),
        measurePaint,
      );

      final beatTicks = measure.timeSignature.beatDuration.ticks;
      for (
      int tick = measure.startTick + beatTicks;
      tick < measure.endTick;
      tick += beatTicks
      ) {
        final x = tick * pixelsPerTick;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), beatPaint);
      }
    }

    // =====================================================
    // TEMPO EVENTS — drawn once, not per measure
    // =====================================================
    final tempoLinePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;

    for (final tempoEvent in controller.timeline.tempoEvents) {
      final x = tempoEvent.tick * pixelsPerTick;

      // Vertical line
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        tempoLinePaint,
      );

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${tempoEvent.tempo.label} = ${tempoEvent.tempo.value}',
          style: _tempoLabelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x + 5, 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}