import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../dialogs/edit_measure_beat_dialog.dart';
import '../dialogs/scale_dialog.dart';
import '../dialogs/tempo_dialog.dart';
import '../dialogs/dynamic_dialog.dart';
import '../dialogs/dynamic_change_dialog.dart';
import '../enums/dynamic_change.dart';
import '../enums/note_duration.dart';
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

/// sustain pedal — "ped" sign plus the thin connecting line drawn
/// from a pedalDown event to its matching pedalUp (see
/// _drawPedalMarks), in red.
const _pedalLabelStyle = TextStyle(
  color: Colors.green,
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

/// scale name — drawn at the TOP of the grid, below the measure
/// number (see _measureNumberLabelStyle), same size/weight as the
/// tempo label at the bottom, in blue.
const _scaleLabelStyle = TextStyle(
  color: Colors.blue,
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

/// measure number — drawn at the very TOP of the grid, above the
/// scale name, for EVERY measure (unlike the scale name, which only
/// repeats where the scale actually changes).
const _measureNumberLabelStyle = TextStyle(
  color: Colors.blue,
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

/// time signature — drawn at the very BOTTOM of the grid (below
/// tempo/dynamic, which stack above it), in blue. Used to also show
/// the measure number too (e.g. "1: 4/4") — that moved to the TOP of
/// the grid instead (see _measureNumberLabelStyle), so this is just
/// the fraction now (e.g. "4/4").
const _measureLabelStyle = TextStyle(
  color: Colors.blue,
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

const double _labelOffsetX = 5;
const double _bottomMargin = 5; // distance from bottom of grid to the time-signature label
const double _topMargin = 5; // distance from top of grid to the measure number label
const double _topLabelGap = 4; // gap between measure number and scale name, both at the top
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

TextPainter _pedalTextPainter() {
  return TextPainter(
    text: const TextSpan(
      text: 'ped',
      style: _pedalLabelStyle,
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

TextPainter _measureNumberTextPainter(String text) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: _measureNumberLabelStyle,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

TextPainter _measureLabelTextPainter(String text) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: _measureLabelStyle,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

/// The denominator to show for a beat's NoteDuration when writing a
/// time signature as e.g. "5/4" — derived from how many of
/// [beatDuration] fit into a whole note, using NoteDuration.quarter
/// as the reference point (a quarter note is a denominator of 4, by
/// definition), so this works for any NoteDuration without needing to
/// hardcode every enum member's own denominator individually.
int _beatDenominator(dynamic beatDuration) {
  final wholeNoteTicks = NoteDuration.quarter.ticks * 4;
  return (wholeNoteTicks / beatDuration.ticks).round();
}

/// e.g. "1" for the 1st measure (1-based) — shown at the TOP of the
/// grid for every measure (see the measure number label style).
String _measureNumberText(int measureNumber) => '$measureNumber';

/// e.g. "5/4" for a time signature of 5 beats of a quarter note each
/// — shown at the BOTTOM of the grid. No longer includes the measure
/// number (that moved to the top — see [_measureNumberText]).
String _measureLabelText(dynamic timeSignature) {
  final denominator = _beatDenominator(timeSignature.beatDuration);
  return '${timeSignature.beats}/$denominator';
}

/// Line-height of the measure number label at the top — content-
/// independent for single-line text at a fixed style, so any sample
/// string works as a consistent reference for stacking the scale name
/// below it.
double _measureNumberReferenceHeight() =>
    _measureNumberTextPainter('0').height;

/// Line-height of the time-signature label at the bottom — content-
/// independent for single-line text at a fixed style, so any sample
/// string works as a consistent reference for stacking the tempo/
/// dynamic labels above it (same idea as the existing
/// referenceTempoHeight/referenceDynamicHeight pattern below).
double _measureLabelReferenceHeight() =>
    _measureLabelTextPainter('0/0').height;

/// Computes tap-target rects for both tempo and dynamic labels.
/// Both stack above the measure/time-signature label at the very
/// bottom of the grid: tempo directly above it, dynamic above tempo.
/// [gridHeight] is needed to place them correctly.
List<_LabelHit> _computeLabelHits(
    CompositionController controller,
    double pixelsPerTick,
    double gridHeight,
    ) {
  final hits = <_LabelHit>[];
  final measureLabelHeight = _measureLabelReferenceHeight();

  for (final tempoEvent in controller.timeline.tempoEvents) {
    final x = tempoEvent.tick * pixelsPerTick;
    final tp = _tempoTextPainter(tempoEvent);
    final y = gridHeight - measureLabelHeight - _bottomMargin - _labelGap - tp.height;
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

    final y = gridHeight -
        measureLabelHeight -
        _bottomMargin -
        _labelGap -
        tempoLineHeight -
        _labelGap -
        dynamicTp.height;

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
  final measureNumberHeight = _measureNumberReferenceHeight();
  final scaleY = _topMargin + measureNumberHeight + _topLabelGap;

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
        Rect.fromLTWH(x + _labelOffsetX, scaleY, tp.width, tp.height),
      ),
    );
  }

  return hits;
}

/// Computes tap-target rects for the green crescendo/diminuendo start &
/// finish lines. Each line spans the full grid height, so the hit rect is
/// just a thin vertical strip centered on the line's x position.
/// Excludes pedalDown/pedalUp events — pedal marks share the same
/// DynamicChangeEvent storage but are drawn and edited entirely
/// separately (see _drawPedalMarks and CompositionController.
/// togglePedalAtTick) — so they don't get this green line/tap target
/// or the crescendo/diminuendo dialog it opens.
List<_DynamicChangeLineHit> _computeDynamicChangeLineHits(
    CompositionController controller,
    double pixelsPerTick,
    double gridHeight,
    ) {
  final hits = <_DynamicChangeLineHit>[];

  for (final event in controller.timeline.dynamicChangeEvents) {
    if (event.dynamic_change == DynamicChange.pedalDown ||
        event.dynamic_change == DynamicChange.pedalUp) {
      continue;
    }
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

                        // 0. If a glissando end-row pick is pending
                        //    (see CompositionController.
                        //    startGlissandoPick, kicked off from
                        //    NoteDialog's Glissando field), this tap
                        //    ONLY completes that — it doesn't select a
                        //    measure, open a label dialog, or create a
                        //    note. An invalid pick (wrong side of the
                        //    note, or off-grid) shows a message and
                        //    stays in picking mode so the person can
                        //    just tap again.
                        if (controller.isPickingGlissandoEndRow) {
                          final visualRow =
                          (details.localPosition.dy / cellHeight).floor();
                          final row = controller.totalRows - 1 - visualRow;
                          final errorMessage =
                          controller.finishGlissandoPick(row);
                          if (errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  errorMessage,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        // 1. If "Add Grace Note" mode is on (see
                        //    CompositionController.
                        //    startAddingGraceNotes, kicked off from
                        //    NoteDialog's Grace Notes field), this tap
                        //    ONLY adds one more grace note — it
                        //    doesn't select a measure, open a label
                        //    dialog, or create an ordinary note.
                        //    Unlike glissando's pick, this mode stays
                        //    on for MANY taps — it's only turned off
                        //    via the app-bar toggle (see
                        //    CompositionController.
                        //    stopAddingGraceNotes), not automatically
                        //    after one tap. A failed add (already at
                        //    the max, or off-grid) just shows a
                        //    message; the mode stays on either way.
                        if (controller.isAddingGraceNotes) {
                          final visualRow =
                          (details.localPosition.dy / cellHeight).floor();
                          final row = controller.totalRows - 1 - visualRow;
                          final errorMessage =
                          controller.addGraceNoteAtRow(row);
                          if (errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  errorMessage,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        // 2. Whatever else this tap does, it also tells us
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

                        // 3. Check the scale name label at the top —
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
                            scaleDialog(
                              context: context,
                              controller: controller,
                              currentScale: measure.scaleName,
                              onSelected: (newScale) {
                                controller.updateMeasureScale(
                                  hit.measureIndex,
                                  newScale,
                                );
                              },
                            );
                            return; // don't fall through to note creation
                          }
                        }

                        // 4. Check tempo/dynamic labels next — tapping a
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

                        // 5. Check crescendo/diminuendo start & finish
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

                        // 6. Otherwise, normal grid/note tap handling.
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

                        // While waiting for a glissando end-row tap
                        // (see onTapUp above), a double-tap shouldn't
                        // open the measure/beat dialog either — it's
                        // still just an ordinary single tap as far as
                        // that pending pick is concerned, and onTapUp
                        // already handles it.
                        if (controller.isPickingGlissandoEndRow) {
                          return;
                        }

                        // Same idea while "Add Grace Note" mode is on
                        // — a double-tap is still just an ordinary
                        // single tap as far as adding a grace note is
                        // concerned, and onTapUp already handles it.
                        if (controller.isAddingGraceNotes) {
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

  /// The pedal row's own y baseline — directly above the dynamic
  /// label's own top edge (matches the DYNAMIC EVENTS loop in
  /// paint()), with just enough clearance for the pedal text's own
  /// height plus a small buffer. Per request, pedal now sits on the
  /// row directly above Dynamic — CLOSER to the bottom than the
  /// hairpin/Dynamic Change row, which is the reverse of how these
  /// two used to stack. Shared by [_drawPedalMarks] (draws AT this y)
  /// and [_drawHairpins] (draws its own row further ABOVE this one,
  /// so the two never overlap) so both stay in sync from one source
  /// of truth.
  double _pedalRowY(Size size) {
    final referenceTempoHeight = controller.timeline.tempoEvents.isNotEmpty
        ? _tempoTextPainter(controller.timeline.tempoEvents.first).height
        : 0.0;
    final referenceDynamicHeight = controller.timeline.dynamicEvents.isNotEmpty
        ? _dynamicTextPainter(controller.timeline.dynamicEvents.first).height
        : 0.0;
    final measureLabelHeight = _measureLabelReferenceHeight();

    final dynamicLabelY = size.height
        - measureLabelHeight
        - _bottomMargin
        - _labelGap
        - referenceTempoHeight
        - _labelGap
        - referenceDynamicHeight;

    // Small gap above the dynamic label's own top edge.
    const pedalBuffer = 4.0;
    final pedalTextHeight = _pedalTextPainter().height;
    // Pedal text is painted CENTERED on its own y (see
    // `pedalY - tp.height / 2` in _drawPedalMarks), so half its height
    // needs to be reserved above dynamicLabelY too.
    return dynamicLabelY - pedalBuffer - pedalTextHeight / 2;
  }

  void _drawHairpins(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    DynamicChangeEvent? crescendoBegin;
    DynamicChangeEvent? diminuendoBegin;

    // How far the hairpin's own zigzag swings above (and below) its
    // own y baseline — matches _drawCrescendo/_drawDiminuendo's "h"
    // constant exactly.
    const hairpinSwing = 10.0;
    // Small safety margin between the hairpin's lower swing point and
    // the pedal row's own top edge.
    const hairpinBuffer = 2.0;

    final pedalY = _pedalRowY(size);
    final pedalTextHeight = _pedalTextPainter().height;
    // The hairpin's row now sits ABOVE the pedal row (reversed from
    // how these two used to stack — see _pedalRowY's doc) — its own
    // lower swing point (y + hairpinSwing) must clear the pedal
    // text's own top edge (pedalY - pedalTextHeight / 2).
    final y = pedalY - pedalTextHeight / 2 - hairpinBuffer - hairpinSwing;


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

      // Pedal marks share this same event list/enum but are drawn
      // entirely separately — see _drawPedalMarks below.
        case DynamicChange.pedalDown:
        case DynamicChange.pedalUp:
          break;
      }
    }
  }

  /// Draws every pedalDown → pedalUp pair (see
  /// CompositionController.togglePedalAtTick) as a red "ped" sign at
  /// the pedalDown tick plus a thin red horizontal line connecting it
  /// to the matching pedalUp tick. An unmatched trailing pedalDown
  /// (no pedalUp yet — the pedal is still "held" through the rest of
  /// the composition) draws just the sign, no line, same as
  /// _drawHairpins leaves an unmatched crescendo/diminuendo start
  /// undrawn.
  ///
  /// Stacked directly above the dynamic label — the hairpin/Dynamic
  /// Change row (see [_drawHairpins]) sits further above THIS row now
  /// (reversed from how these two used to stack — pedal is now closer
  /// to the bottom, per request), so none of these annotation rows
  /// overlap.
  void _drawPedalMarks(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 1.5;

    final pedalY = _pedalRowY(size);

    DynamicChangeEvent? pedalBegin;

    for (final event in controller.timeline.dynamicChangeEvents) {
      if (event.dynamic_change == DynamicChange.pedalDown) {
        pedalBegin = event;
        final tp = _pedalTextPainter();
        final x = event.tick * pixelsPerTick;
        tp.paint(canvas, Offset(x, pedalY - tp.height / 2));
      } else if (event.dynamic_change == DynamicChange.pedalUp) {
        if (pedalBegin != null) {
          final tp = _pedalTextPainter();
          final startX = pedalBegin.tick * pixelsPerTick + tp.width + 4;
          final endX = event.tick * pixelsPerTick;
          if (endX > startX) {
            canvas.drawLine(
              Offset(startX, pedalY),
              Offset(endX, pedalY),
              linePaint,
            );
          }
          pedalBegin = null;
        }
      }
    }
  }

  // Draws a full-height green vertical line at every crescendo/diminuendo
  // start & finish tick — these are the tap targets handled in
  // _computeDynamicChangeLineHits above. Excludes pedalDown/pedalUp —
  // see that function's doc comment.
  void _drawDynamicChangeLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2;

    for (final event in controller.timeline.dynamicChangeEvents) {
      if (event.dynamic_change == DynamicChange.pedalDown ||
          event.dynamic_change == DynamicChange.pedalUp) {
        continue;
      }
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

      // MEASURE NUMBER — drawn at the very TOP of the grid, for EVERY
      // measure (unlike the scale name below it, which only repeats
      // where the scale actually changes).
      final measureNumberPainter = _measureNumberTextPainter(
        _measureNumberText(i + 1),
      );
      measureNumberPainter.paint(
        canvas,
        Offset(measureX + _labelOffsetX, _topMargin),
      );

      // SCALE NAME — drawn just below the measure number, same way
      // the tempo label is drawn at the bottom, but blue. Only shown
      // for the first measure and wherever the scale actually changes
      // (same condition as the double measure-line above) — not
      // repeated on every single measure.
      if (i == 0 || scaleChanged) {
        final scaleTextPainter = _scaleTextPainter(measure.scaleName);
        final scaleY = _topMargin +
            _measureNumberReferenceHeight() +
            _topLabelGap;
        scaleTextPainter.paint(
          canvas,
          Offset(measureX + _labelOffsetX, scaleY),
        );
      }

      // TIME SIGNATURE — drawn at the very BOTTOM of the grid, below
      // the tempo/dynamic labels (which stack above it — see the
      // reshuffled Y math throughout this file). Shown for EVERY
      // measure, not just where something changes, since the time
      // signature can differ measure to measure. The measure number
      // itself is drawn at the TOP instead (see above).
      final measureLabelText = _measureLabelText(measure.timeSignature);
      final measureLabelPainter = _measureLabelTextPainter(measureLabelText);
      final measureLabelY = size.height - measureLabelPainter.height - _bottomMargin;
      measureLabelPainter.paint(
        canvas,
        Offset(measureX + _labelOffsetX, measureLabelY),
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

    // TRIPLE LINE — marks the very last column of the grid (end of the
    // last measure).
    if (measuresList.isNotEmpty) {
      _drawMultiVerticalLine(
        canvas, size.width, size.height, measurePaint, 3,
        alignRight: true,
      );
    }


    // TEMPO EVENTS — line full height, label stacked above the
    // measure/time-signature label at the bottom of the grid

    final tempoLinePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;

    final measureLabelHeightForTempo = _measureLabelReferenceHeight();

    for (final tempoEvent in controller.timeline.tempoEvents) {
      final x = tempoEvent.tick * pixelsPerTick;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        tempoLinePaint,
      );

      final textPainter = _tempoTextPainter(tempoEvent);
      final y = size.height -
          measureLabelHeightForTempo -
          _bottomMargin -
          _labelGap -
          textPainter.height;
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
          measureLabelHeightForTempo -
          _bottomMargin -
          _labelGap -
          referenceTempoHeight -
          _labelGap -
          textPainter.height;

      textPainter.paint(canvas, Offset(x + _labelOffsetX, y));
    }

// CRESCENDO/DIMINUENDO START & FINISH — full-height green line, clickable
    _drawDynamicChangeLines(canvas, size);

// DRAW ALL CRESCENDO/DIMINUENDO AT ONE FIXED HEIGHT
    _drawHairpins(canvas, size);

// SUSTAIN PEDAL — red "ped" sign + connecting line, stacked above the hairpins
    _drawPedalMarks(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

}