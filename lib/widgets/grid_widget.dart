import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../dialogs/tempo_dialog.dart';
import '../dialogs/dynamic_dialog.dart';
import 'note_block_widget.dart';

/// Shared text styles so hit-testing and painting always agree on size.
const _tempoLabelStyle = TextStyle(
  color: Colors.blue,
  fontSize: 18,
  fontWeight: FontWeight.bold,
);

const _dynamicLabelStyle = TextStyle(
  color: Colors.deepOrange,
  fontSize: 18,
  fontWeight: FontWeight.bold,
);

const double _labelOffsetX = 5;
const double _dynamicLabelOffsetY = 5; // top of grid
const double _tempoLabelBottomMargin = 5; // distance from bottom of grid

class _LabelHit {
  final int tick;
  final Rect rect;
  final bool isTempo; // true = tempo, false = dynamic
  _LabelHit(this.tick, this.rect, this.isTempo);
}

TextPainter _tempoTextPainter(dynamic tempoEvent) {
  return TextPainter(
    text: TextSpan(
      text: '${tempoEvent.tempo.label} = ${tempoEvent.tempo.value}',
      style: _tempoLabelStyle,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

TextPainter _dynamicTextPainter(dynamic dynamicEvent) {
  return TextPainter(
    text: TextSpan(
      text: dynamicEvent.musical_dynamic.abbreviation,
      style: _dynamicLabelStyle,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

/// Computes tap-target rects for both tempo and dynamic labels.
/// Tempo labels sit at the bottom of the grid, dynamic labels at the top —
/// [gridHeight] is needed to place the tempo rects correctly.
List<_LabelHit> _computeLabelHits(
    CompositionController controller,
    double pixelsPerTick,
    double gridHeight,
    ) {
  final hits = <_LabelHit>[];

  for (final tempoEvent in controller.timeline.tempoEvents) {
    final x = tempoEvent.tick * pixelsPerTick;
    final tp = _tempoTextPainter(tempoEvent);
    final y = gridHeight - tp.height - _tempoLabelBottomMargin;
    hits.add(
      _LabelHit(
        tempoEvent.tick,
        Rect.fromLTWH(x + _labelOffsetX, y, tp.width, tp.height),
        true,
      ),
    );
  }

  for (final dynamicEvent in controller.timeline.dynamicEvents) {
    final x = dynamicEvent.tick * pixelsPerTick;
    final tp = _dynamicTextPainter(dynamicEvent);
    hits.add(
      _LabelHit(
        dynamicEvent.tick,
        Rect.fromLTWH(x + _labelOffsetX, _dynamicLabelOffsetY, tp.width, tp.height),
        false,
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
                        // 1. Check tempo/dynamic labels first — tapping a
                        //    label should open its edit dialog, not create
                        //    a note.
                        final labelHits = _computeLabelHits(
                          controller,
                          pixelsPerTick,
                          gridHeight,
                        );

                        for (final hit in labelHits) {
                          if (hit.rect.contains(details.localPosition)) {
                            if (hit.isTempo) {
                              tempoDialog(context, controller, hit.tick);
                            } else {
                              dynamicDialog(context, controller, hit.tick);
                            }
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
    // TEMPO EVENTS — line full height, label at bottom of grid
    // =====================================================
    final tempoLinePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;

    for (final tempoEvent in controller.timeline.tempoEvents) {
      final x = tempoEvent.tick * pixelsPerTick;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        tempoLinePaint,
      );

      final textPainter = _tempoTextPainter(tempoEvent);
      final y = size.height - textPainter.height - _tempoLabelBottomMargin;
      textPainter.paint(canvas, Offset(x + _labelOffsetX, y));
    }

    // =====================================================
    // DYNAMIC EVENTS — no line, label only, top of grid
    // =====================================================
    for (final dynamicEvent in controller.timeline.dynamicEvents) {
      final x = dynamicEvent.tick * pixelsPerTick;

      final textPainter = _dynamicTextPainter(dynamicEvent);
      textPainter.paint(canvas, Offset(x + _labelOffsetX, _dynamicLabelOffsetY));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}