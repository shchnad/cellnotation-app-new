import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../dialogs/edit_measure_beat_dialog.dart';
import '../dialogs/note_values_dialog.dart';
import '../dialogs/tempo_dialog.dart';
import '../dialogs/dynamic_dialog.dart';
import '../dialogs/dynamic_change_dialog.dart';
import '../enums/dynamic_change.dart';
import '../models/dynamic_change_event.dart';
import '../utils/scale_resolver.dart';
import 'note_block_widget.dart';

/// tempo
const _tempoLabelStyle = TextStyle(
  color: Colors.blue,
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

/// dynamic
const _dynamicLabelStyle = TextStyle(
  color: Colors.green,
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

/// scale name — drawn at the TOP of the grid, same size/weight as the
/// tempo label at the bottom, in red.
const _scaleLabelStyle = TextStyle(
  color: Colors.red,
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

const double _labelOffsetX = 5;
const double _bottomMargin = 5; // distance from bottom of grid to tempo label
const double _topMargin = 5; // distance from top of grid to scale label
const double _labelGap = 4; // gap between tempo label and dynamic label above it

// How many pixels wide (on each side of the line) count as a hit when
// tapping a dynamic change line.
const double _dynamicChangeLineHitTolerance = 6;

class _LabelHit {
  final int tick;
  final Rect rect;
  final bool isTempo; // true = tempo, false = dynamic
  _LabelHit(this.tick, this.rect, this.isTempo);
}

// Tap target for the scale name drawn at the top of the grid (see
// GridPainter's SCALE NAME section). measureIndex is whichever
// measure the label actually belongs to — the first measure, or
// wherever the scale changes from the previous measure — matching
// exactly which measures GridPainter draws a label for in the first
// place (a label isn't repeated for every measure, only where it
// changes).
class _ScaleLabelHit {
  final int measureIndex;
  final Rect rect;
  _ScaleLabelHit(this.measureIndex, this.rect);
}

// Tap target for a dynamic change (crescendo/diminuendo start/finish)
// vertical line. Tapping it opens the dynamic change dialog.
class _DynamicChangeLineHit {
  final int tick;
  final Rect rect;
  _DynamicChangeLineHit(this.tick, this.rect);
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

TextPainter _scaleTextPainter(String scaleName) {
  return TextPainter(
    text: TextSpan(
      text: ScaleResolver.normalizeScaleName(scaleName),
      style: _scaleLabelStyle,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

/// Computes tap-target rects for both tempo and dynamic labels.
/// Both sit at the bottom of the grid: tempo on the very bottom row,
/// dynamic stacked directly above it. [gridHeight] is needed to place
/// them correctly.
List<_LabelHit> _computeLabelHits(
    CompositionController controller,
    double pixelsPerTick,
    double gridHeight,
    ) {
  final hits = <_LabelHit>[];

  for (final tempoEvent in controller.timeline.tempoEvents) {
    final x = tempoEvent.tick * pixelsPerTick;
    final tp = _tempoTextPainter(tempoEvent);
    final y = gridHeight - tp.height - _bottomMargin;
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
    final dynamicTp = _dynamicTextPainter(dynamicEvent);

    // Position above the tempo label's height at the bottom, regardless
    // of whether a tempo event exists at this exact tick, so dynamic
    // labels always sit at a consistent height.
    final tempoLineHeight = _tempoTextPainter(
      controller.getTempoAtTick(tempoEventFallbackTick(controller, dynamicEvent.tick)) ??
          controller.timeline.tempoEvents.first,
    ).height;

    final y = gridHeight - tempoLineHeight - _bottomMargin - _labelGap - dynamicTp.height;

    hits.add(
      _LabelHit(
        dynamicEvent.tick,
        Rect.fromLTWH(x + _labelOffsetX, y, dynamicTp.width, dynamicTp.height),
        false,
      ),
    );
  }

  return hits;
}

/// Computes tap-target rects for the scale name drawn at the top of
/// the grid — mirrors GridPainter's own SCALE NAME drawing exactly
/// (same "first measure, or wherever the scale changes" condition,
/// same position), so the tap target always lines up with what's
/// actually visible.
List<_ScaleLabelHit> _computeScaleLabelHits(
    CompositionController controller,
    double pixelsPerTick,
    ) {
  final hits = <_ScaleLabelHit>[];
  final measures = controller.measures;

  for (int i = 0; i < measures.length; i++) {
    final measure = measures[i];
    final scaleChanged =
        i > 0 && measures[i - 1].scaleName != measure.scaleName;
    if (i != 0 && !scaleChanged) continue;

    final x = measure.startTick * pixelsPerTick;
    final tp = _scaleTextPainter(measure.scaleName);
    hits.add(
      _ScaleLabelHit(
        i,
        Rect.fromLTWH(x + _labelOffsetX, _topMargin, tp.width, tp.height),
      ),
    );
  }

  return hits;
}

/// Computes tap-target rects for the green crescendo/diminuendo start &
/// finish lines. Each line spans the full grid height, so the hit rect is
/// just a thin vertical strip centered on the line's x position.
List<_DynamicChangeLineHit> _computeDynamicChangeLineHits(
    CompositionController controller,
    double pixelsPerTick,
    double gridHeight,
    ) {
  final hits = <_DynamicChangeLineHit>[];

  for (final event in controller.timeline.dynamicChangeEvents) {
    final x = event.tick * pixelsPerTick;
    hits.add(
      _DynamicChangeLineHit(
        event.tick,
        Rect.fromLTWH(
          x - _dynamicChangeLineHitTolerance,
          0,
          _dynamicChangeLineHitTolerance * 2,
          gridHeight,
        ),
      ),
    );
  }

  return hits;
}

/// Helper used only for consistent row height — returns the tick to look
/// up for sizing purposes (falls back to any existing tempo event if none
/// exists at this exact tick, since we just need a representative height).
int tempoEventFallbackTick(CompositionController controller, int tick) {
  final exists = controller.getTempoAtTick(tick);
  return exists != null ? tick : controller.timeline.tempoEvents.first.tick;
}

class GridWidget extends StatelessWidget {
  final CompositionController controller;
  final double cellHeight;
  final ScrollController? verticalScrollController;
  final ScrollController? horizontalScrollController;

  const GridWidget({
    super.key,
    required this.controller,
    required this.cellHeight,
    this.verticalScrollController,
    this.horizontalScrollController,
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
          controller: verticalScrollController,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: horizontalScrollController,
            child: SizedBox(
              width: gridWidth,
              height: gridHeight,
              child: Stack(
                children: [
                  // GRID BACKGROUND
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Deliberately onTapUp (fires only once a tap is
                      // confirmed to NOT be the first half of a double
                      // tap), not onTapDown (which fires immediately on
                      // every touch regardless of what follows).
                      // Providing both this and onDoubleTapDown below
                      // makes Flutter insert the standard double-tap
                      // disambiguation delay before this fires — the
                      // tradeoff that buys double-tapping empty grid
                      // space (onDoubleTapDown) without a note getting
                      // created first. A double-tap directly ON an
                      // existing note is unaffected by any of this — the
                      // note's own GestureDetector (see NoteBlockWidget)
                      // sits on top in the Stack and captures the touch
                      // before it ever reaches this background detector.
                      onTapUp: (details) {
                        if (controller.editingBlocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.editingBlockedMessage,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                          return;
                        }

                        // 0. Whatever else this tap does, it also tells us
                        //    which measure the person is pointing at — so
                        //    the pitch column can switch to that measure's
                        //    scale.
                        final tappedTick =
                        (details.localPosition.dx / pixelsPerTick)
                            .floor()
                            .clamp(0, controller.maxTicks - 1);
                        if (controller.maxTicks > 0) {
                          controller.selectMeasureAtTick(tappedTick);
                        }

                        // 1. Check the scale name label at the top —
                        //    tapping it opens a scale picker for that
                        //    measure, not creating a note.
                        final scaleLabelHits = _computeScaleLabelHits(
                          controller,
                          pixelsPerTick,
                        );

                        for (final hit in scaleLabelHits) {
                          if (hit.rect.contains(details.localPosition)) {
                            final measure =
                            controller.measures[hit.measureIndex];
                            noteValuesDialog<String>(
                              context: context,
                              currentValue: measure.scaleName,
                              onSelected: (newScale) {
                                controller.updateMeasureScale(
                                  hit.measureIndex,
                                  newScale,
                                );
                              },
                              title: 'Select Scale',
                              values: controller.availableScales,
                              labelBuilder: (s) =>
                                  ScaleResolver.normalizeScaleName(s),
                              numberOfColumns: 2,
                              allowToCloseNextWindow: false,
                            );
                            return; // don't fall through to note creation
                          }
                        }

                        // 2. Check tempo/dynamic labels next — tapping a
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

                        // 3. Check crescendo/diminuendo start & finish
                        //    lines next — tapping one opens the dynamic
                        //    change dialog instead of creating a note.
                        final dynamicChangeLineHits =
                        _computeDynamicChangeLineHits(
                          controller,
                          pixelsPerTick,
                          gridHeight,
                        );

                        for (final hit in dynamicChangeLineHits) {
                          if (hit.rect.contains(details.localPosition)) {
                            dynamicChangeDialog(context, controller, hit.tick);
                            return; // don't fall through to note creation
                          }
                        }

                        // 4. Otherwise, normal grid/note tap handling.
                        // The tapped screen position is converted to a
                        // musical row: row 0 (lowest pitch) sits at the
                        // BOTTOM of the grid, so a tap near the bottom
                        // (large visualRow) should map to a small row
                        // number.
                        final visualRow =
                        (details.localPosition.dy / cellHeight).floor();
                        final row = controller.totalRows - 1 - visualRow;

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
                      // Double-tapping empty grid space (no note there —
                      // a tap on an actual note is captured by that
                      // note's own detector first, see the comment
                      // above) opens the edit-measure-beat dialog
                      // directly, computed straight from the tapped
                      // position — no note is created as a side effect
                      // first.
                      onDoubleTapDown: (details) {
                        if (controller.editingBlocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.editingBlockedMessage,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                          return;
                        }

                        final rawTick =
                        (details.localPosition.dx / pixelsPerTick)
                            .floor()
                            .clamp(0, controller.maxTicks - 1);

                        if (controller.maxTicks > 0) {
                          controller.selectMeasureAtTick(rawTick);
                        }

                        final measure = controller.getMeasureAtTick(rawTick);
                        final measureIndex =
                        controller.measures.indexOf(measure);
                        final beatIndex = (rawTick - measure.startTick) ~/
                            measure.timeSignature.ticksPerBeat;

                        editMeasureBeatDialog(
                          context: context,
                          controller: controller,
                          measureIndex: measureIndex,
                          beatIndex: beatIndex,
                        );
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

                  // NOTES — displayNotes expands any note carrying an
                  // ornament into its ghost sequence (see Ornament.shiftMap /
                  // CompositionController.displayNotes). Only the ghost(s)
                  // at the ornament's own unaltered/base pitch (raw
                  // shift == 0) are clickable and carry an
                  // interactionNote pointing back at the real note —
                  // every other ghost in the sequence is display-only.
                  // Each ghost's raw shift is passed through as
                  // ornamentShift so NoteBlockWidget can interpret it
                  // according to the compensated-notation toggle.
                  ...controller.displayNotes.map(
                        (entry) => NoteBlockWidget(
                      key: ValueKey(entry.note.id),
                      note: entry.note,
                      pixelsPerTick: pixelsPerTick,
                      cellHeight: cellHeight,
                      controller: controller,
                      isCompensatedGhost: entry.isGhost,
                      isClickable: entry.isClickable,
                      interactionNote: entry.interactionNote,
                      ornamentShift: entry.shift,
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

  // Draws [count] parallel vertical lines, [spacing] pixels apart.
  // By default they're centered on [x] (used at measure boundaries);
  // pass alignRight: true to have the rightmost line sit exactly at
  // [x] instead (used for the grid's final edge, so nothing gets
  // clipped off-canvas).
  void _drawMultiVerticalLine(
      Canvas canvas,
      double x,
      double height,
      Paint paint,
      int count, {
        bool alignRight = false,
        double spacing = 3.0,
      }) {
    if (count <= 1) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), paint);
      return;
    }
    final totalWidth = spacing * (count - 1);
    final startX = alignRight ? x - totalWidth : x - totalWidth / 2;
    for (int i = 0; i < count; i++) {
      final lineX = startX + spacing * i;
      canvas.drawLine(Offset(lineX, 0), Offset(lineX, height), paint);
    }
  }

  void _drawCrescendo(
      Canvas canvas,
      Paint paint,
      double x1,
      double x2,
      double y,
      ) {
    const h = 10.0;

    canvas.drawLine(
      Offset(x1, y),
      Offset(x2, y - h),
      paint,
    );

    canvas.drawLine(
      Offset(x1, y),
      Offset(x2, y + h),
      paint,
    );
  }


  void _drawDiminuendo(
      Canvas canvas,
      Paint paint,
      double x1,
      double x2,
      double y,
      ) {
    const h = 10.0;

    canvas.drawLine(
      Offset(x1, y - h),
      Offset(x2, y),
      paint,
    );

    canvas.drawLine(
      Offset(x1, y + h),
      Offset(x2, y),
      paint,
    );
  }

  void _drawHairpins(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    DynamicChangeEvent? crescendoBegin;
    DynamicChangeEvent? diminuendoBegin;

    final referenceTempoHeight =
    controller.timeline.tempoEvents.isNotEmpty
        ? _tempoTextPainter(
      controller.timeline.tempoEvents.first,
    ).height
        : 0.0;

    final referenceDynamicHeight = controller.timeline.dynamicEvents.isNotEmpty
        ? _dynamicTextPainter(
      controller.timeline.dynamicEvents.first,
    ).height
        : 0.0;

    const hairpinOffset = 18.0;

    final y = size.height
        - referenceTempoHeight
        - _bottomMargin
        - _labelGap
        - referenceDynamicHeight
        - hairpinOffset;


    for (final event in controller.timeline.dynamicChangeEvents) {
      switch (event.dynamic_change) {

        case DynamicChange.crescendoStart:
          crescendoBegin = event;
          break;

        case DynamicChange.crescendoFinish:
          if (crescendoBegin != null) {
            _drawCrescendo(
              canvas,
              paint,
              crescendoBegin.tick * pixelsPerTick,
              event.tick * pixelsPerTick,
              y,
            );
            crescendoBegin = null;
          }
          break;

        case DynamicChange.diminuendoStart:
          diminuendoBegin = event;
          break;

        case DynamicChange.diminuendoFinish:
          if (diminuendoBegin != null) {
            _drawDiminuendo(
              canvas,
              paint,
              diminuendoBegin.tick * pixelsPerTick,
              event.tick * pixelsPerTick,
              y,
            );
            diminuendoBegin = null;
          }
          break;
      }
    }
  }

  // Draws a full-height green vertical line at every crescendo/diminuendo
  // start & finish tick — these are the tap targets handled in
  // _computeDynamicChangeLineHits above.
  void _drawDynamicChangeLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2;

    for (final event in controller.timeline.dynamicChangeEvents) {
      final x = event.tick * pixelsPerTick;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        linePaint,
      );
    }
  }

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
    final measuresList = controller.measures;
    for (int i = 0; i < measuresList.length; i++) {
      final measure = measuresList[i];
      final measureX = measure.startTick * pixelsPerTick;

      // A measure boundary gets a double line when this measure's scale
      // differs from the previous measure's — the very first measure has
      // no "previous" to compare against, so it always gets a single line.
      final scaleChanged = i > 0 &&
          measuresList[i - 1].scaleName != measure.scaleName;

      if (scaleChanged) {
        _drawMultiVerticalLine(canvas, measureX, size.height, measurePaint, 2);
      } else {
        canvas.drawLine(
          Offset(measureX, 0),
          Offset(measureX, size.height),
          measurePaint,
        );
      }

      // SCALE NAME — drawn at the top of the grid, same way the tempo
      // label is drawn at the bottom, but red. Only shown for the
      // first measure and wherever the scale actually changes (same
      // condition as the double measure-line above) — not repeated on
      // every single measure.
      if (i == 0 || scaleChanged) {
        final scaleTextPainter = _scaleTextPainter(measure.scaleName);
        scaleTextPainter.paint(
          canvas,
          Offset(measureX + _labelOffsetX, _topMargin),
        );
      }

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

    // TRIPLE LINE — marks the very last column of the grid (end of the
    // last measure).
    if (measuresList.isNotEmpty) {
      _drawMultiVerticalLine(
        canvas, size.width, size.height, measurePaint, 3,
        alignRight: true,
      );
    }


    // TEMPO EVENTS — line full height, label at bottom of grid

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
      final y = size.height - textPainter.height - _bottomMargin;
      textPainter.paint(canvas, Offset(x + _labelOffsetX, y));
    }

// DYNAMIC EVENTS — labels stacked above tempo label

    final referenceTempoHeight = controller.timeline.tempoEvents.isNotEmpty
        ? _tempoTextPainter(controller.timeline.tempoEvents.first).height
        : 0.0;

    for (final dynamicEvent in controller.timeline.dynamicEvents) {
      final x = dynamicEvent.tick * pixelsPerTick;
      final textPainter = _dynamicTextPainter(dynamicEvent);

      final y = size.height -
          referenceTempoHeight -
          _bottomMargin -
          _labelGap -
          textPainter.height;

      textPainter.paint(canvas, Offset(x + _labelOffsetX, y));
    }

// CRESCENDO/DIMINUENDO START & FINISH — full-height green line, clickable
    _drawDynamicChangeLines(canvas, size);

// DRAW ALL CRESCENDO/DIMINUENDO AT ONE FIXED HEIGHT
    _drawHairpins(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

}