import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../dialogs/beat_subdivision_dialog.dart';
import '../dialogs/edit_measure_beat_dialog.dart';
import '../dialogs/scale_dialog.dart';
import '../dialogs/tempo_dialog.dart';
import '../dialogs/dynamic_dialog.dart';
import '../dialogs/dynamic_change_dialog.dart';
import '../enums/dynamic_change.dart';
import '../enums/note_duration.dart';
import '../models/dynamic_change_event.dart';
import '../utils/app_colors.dart';
import '../utils/scale_resolver.dart';
import 'note_block_widget.dart';

/// tempo — blue in light mode, white in dark mode (see
/// AppColors.gridLabelText) for legibility against the black grid.
TextStyle _tempoLabelStyle(double fontSize, bool isDarkMode) => TextStyle(
  color: Colors.blue,
  fontSize: fontSize,
  fontWeight: FontWeight.bold,
);

/// dynamic
TextStyle _dynamicLabelStyle(double fontSize) => TextStyle(
  color: Colors.green,
  fontSize: fontSize,
  fontWeight: FontWeight.bold,
);

/// sustain pedal — "ped" sign plus the thin connecting line drawn
/// from a pedalDown event to its matching pedalUp (see
/// _drawPedalMarks), in red.
TextStyle _pedalLabelStyle(double fontSize) => TextStyle(
  color: Colors.green,
  fontSize: fontSize,
  fontWeight: FontWeight.bold,
);

/// scale name — drawn at the TOP of the grid, below the measure
/// number (see _measureNumberLabelStyle), same size/weight as the
/// tempo label at the bottom. Blue in light mode, white in dark mode.
TextStyle _scaleLabelStyle(double fontSize, bool isDarkMode) => TextStyle(
  color: AppColors.gridLabelText(isDarkMode),
  fontSize: fontSize,
  fontWeight: FontWeight.bold,
);

/// measure number — drawn at the very TOP of the grid, above the
/// scale name, for EVERY measure (unlike the scale name, which only
/// repeats where the scale actually changes). Blue in light mode,
/// white in dark mode.
TextStyle _measureNumberLabelStyle(double fontSize, bool isDarkMode) =>
    TextStyle(
      color: AppColors.gridLabelText(isDarkMode),
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );

/// time signature — drawn at the very BOTTOM of the grid (below
/// tempo/dynamic, which stack above it). Used to also show the
/// measure number too (e.g. "1: 4/4") — that moved to the TOP of the
/// grid instead (see _measureNumberLabelStyle), so this is just the
/// fraction now (e.g. "4/4"). Blue in light mode, white in dark mode.
TextStyle _measureLabelStyle(double fontSize, bool isDarkMode) => TextStyle(
  color: AppColors.gridLabelText(isDarkMode),
  fontSize: fontSize,
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

// Tap target for a fermata-stretched beat's "fz" label (see
// GridPainter's beat-line-drawing loop, which computes the exact same
// position this mirrors). Tapping it re-opens the fermata dialog so
// it can be changed or deleted.
class _FermataHit {
  final int measureIndex;
  final int beatIndex;
  final Rect rect;
  _FermataHit(this.measureIndex, this.beatIndex, this.rect);
}

// Tap target for a dynamic change (crescendo/diminuendo start/finish)
// vertical line. Tapping it opens the dynamic change dialog.
class _DynamicChangeLineHit {
  final int tick;
  final Rect rect;
  _DynamicChangeLineHit(this.tick, this.rect);
}

TextPainter _tempoTextPainter(dynamic tempoEvent, double fontSize, bool isDarkMode) {
  return TextPainter(
    text: TextSpan(
      text: '${tempoEvent.tempo.label} = ${tempoEvent.tempo.value}',
      style: _tempoLabelStyle(fontSize, isDarkMode),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

TextPainter _dynamicTextPainter(dynamic dynamicEvent, double fontSize) {
  return TextPainter(
    text: TextSpan(
      text: dynamicEvent.musical_dynamic.abbreviation,
      style: _dynamicLabelStyle(fontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

TextPainter _pedalTextPainter(double fontSize) {
  return TextPainter(
    text: TextSpan(
      text: 'ped',
      style: _pedalLabelStyle(fontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

TextPainter _scaleTextPainter(String scaleName, double fontSize, bool isDarkMode) {
  return TextPainter(
    text: TextSpan(
      text: ScaleResolver.normalizeScaleName(scaleName),
      style: _scaleLabelStyle(fontSize, isDarkMode),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

TextPainter _measureNumberTextPainter(String text, double fontSize, bool isDarkMode) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: _measureNumberLabelStyle(fontSize, isDarkMode),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

TextPainter _measureLabelTextPainter(String text, double fontSize, bool isDarkMode) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: _measureLabelStyle(fontSize, isDarkMode),
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

/// e.g. "fz=1/8x3" for a fermata stretching an eighth-note beat to
/// last 3 beats long — the beat's own ORIGINAL duration (as a
/// fraction of a whole note, via [_beatDenominator]) plus the
/// fermata's multiplier, per request.
String _fermataLabelText(dynamic beatDuration, int multiplier) {
  final denominator = _beatDenominator(beatDuration);
  return 'fz=1/${denominator}x$multiplier';
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
double _measureNumberReferenceHeight(double fontSize) =>
    _measureNumberTextPainter('0', fontSize, false).height;

/// Line-height of the time-signature label at the bottom — content-
/// independent for single-line text at a fixed style, so any sample
/// string works as a consistent reference for stacking the tempo/
/// dynamic labels above it (same idea as the existing
/// referenceTempoHeight/referenceDynamicHeight pattern below).
double _measureLabelReferenceHeight(double fontSize) =>
    _measureLabelTextPainter('0/0', fontSize, false).height;

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
  final fontSize = controller.gridFontSize;
  final measureLabelHeight = _measureLabelReferenceHeight(fontSize);

  for (final tempoEvent in controller.timeline.tempoEvents) {
    final x = tempoEvent.tick * pixelsPerTick;
    final tp = _tempoTextPainter(tempoEvent, fontSize, false);
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
    final dynamicTp = _dynamicTextPainter(dynamicEvent, fontSize);

    // Position above the tempo label's height at the bottom, regardless
    // of whether a tempo event exists at this exact tick, so dynamic
    // labels always sit at a consistent height.
    final tempoLineHeight = _tempoTextPainter(
      controller.getTempoAtTick(tempoEventFallbackTick(controller, dynamicEvent.tick)) ??
          controller.timeline.tempoEvents.first,
      fontSize,
      false,
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
  final fontSize = controller.gridFontSize;
  final measureNumberHeight = _measureNumberReferenceHeight(fontSize);
  final scaleY = _topMargin + measureNumberHeight + _topLabelGap;

  for (int i = 0; i < measures.length; i++) {
    final measure = measures[i];
    final scaleChanged =
        i > 0 && measures[i - 1].scaleName != measure.scaleName;
    if (i != 0 && !scaleChanged) continue;

    final x = measure.startTick * pixelsPerTick;
    final tp = _scaleTextPainter(measure.scaleName, fontSize, false);
    hits.add(
      _ScaleLabelHit(
        i,
        Rect.fromLTWH(x + _labelOffsetX, scaleY, tp.width, tp.height),
      ),
    );
  }

  return hits;
}

// Tap target for the time-signature label drawn at the bottom of the
// grid (see GridPainter's TIME SIGNATURE section). Tapping it opens
// beatSubdivisionDialog for that measure, per request — every
// measure gets one of these labels (unlike the scale name above,
// which only repeats where it changes), matching how GridPainter
// draws it for EVERY measure.
class _TimeSignatureLabelHit {
  final int measureIndex;
  final Rect rect;
  _TimeSignatureLabelHit(this.measureIndex, this.rect);
}

/// Computes tap-target rects for the time-signature label at the
/// bottom of the grid — mirrors GridPainter's own TIME SIGNATURE
/// drawing exactly (same position, drawn for EVERY measure), so the
/// tap target always lines up with what's actually visible.
List<_TimeSignatureLabelHit> _computeTimeSignatureLabelHits(
    CompositionController controller,
    double pixelsPerTick,
    double gridHeight,
    ) {
  final hits = <_TimeSignatureLabelHit>[];
  final measures = controller.measures;
  final fontSize = controller.gridFontSize;

  for (int i = 0; i < measures.length; i++) {
    final measure = measures[i];
    final x = measure.startTick * pixelsPerTick;
    final text = _measureLabelText(measure.timeSignature);
    final tp = _measureLabelTextPainter(text, fontSize, false);
    final y = gridHeight - tp.height - _bottomMargin;
    hits.add(
      _TimeSignatureLabelHit(
        i,
        Rect.fromLTWH(x + _labelOffsetX, y, tp.width, tp.height),
      ),
    );
  }

  return hits;
}

/// (same beat-by-beat walk, same per-beat width accounting for a
/// fermata multiplier, same centered label position), so the tap
/// target always lines up with what's actually visible.
List<_FermataHit> _computeFermataHits(
    CompositionController controller,
    double pixelsPerTick,
    double gridHeight,
    ) {
  final hits = <_FermataHit>[];
  final fontSize = controller.gridFontSize;
  final measures = controller.measures;

  for (int i = 0; i < measures.length; i++) {
    final measure = measures[i];
    final beatTicks = measure.timeSignature.beatDuration.ticks;
    int cursorTick = measure.startTick;
    int beatIdx = 0;
    while (cursorTick < measure.endTick) {
      final multiplier = controller.getFermataMultiplier(i, beatIdx) ?? 1;
      final thisBeatTicks = beatTicks * multiplier;
      final beatStartX = cursorTick * pixelsPerTick;
      cursorTick += thisBeatTicks;

      if (multiplier > 1) {
        final beatWidthPx = thisBeatTicks * pixelsPerTick;
        final tp = TextPainter(
          text: TextSpan(
            text: _fermataLabelText(measure.timeSignature.beatDuration, multiplier),
            style: TextStyle(
              color: Colors.blue,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelLeft = beatStartX + beatWidthPx / 2 - tp.width / 2;
        final labelTop =
            gridHeight - _measureLabelReferenceHeight(fontSize) - _bottomMargin;
        hits.add(
          _FermataHit(
            i,
            beatIdx,
            Rect.fromLTWH(labelLeft, labelTop, tp.width, tp.height),
          ),
        );
      }

      beatIdx++;
    }
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

/// Converts a tapped/dragged Y position's visual row index (0 = the
/// very top row on screen) into the actual logical row number — row
/// 0 (lowest pitch) is always at the BOTTOM, so this always flips.
/// Does NOT change with Rotate Pitch Text (that toggle only rotates
/// the pitch digit itself, not the grid's own row layout).
int visualRowToLogicalRow(CompositionController controller, int visualRow) {
  return controller.totalRows - 1 - visualRow;
}

/// The LOGICAL beat index within [measure] that [tick] falls into —
/// walks beat-by-beat from the measure's own start, accounting for
/// any EARLIER fermata-stretched beat (see
/// CompositionController.getFermataMultiplier/applyFermataToBeat),
/// the same way getBeatTick and _computeFermataHits already do.
/// Unlike the naive `(tick - measure.startTick) ~/ ticksPerBeat`
/// formula — which silently gives the WRONG beat index once any
/// earlier beat in the measure is fermata-stretched wider than a
/// single beat's own tick span — this always lines up with the
/// beat the person actually tapped on, visually.
int beatIndexAtTick(
    CompositionController controller,
    int measureIndex,
    dynamic measure,
    int tick,
    ) {
  final int beatTicks = measure.timeSignature.beatDuration.ticks;
  int cursorTick = measure.startTick;
  int beatIdx = 0;
  while (cursorTick < measure.endTick) {
    final multiplier =
        controller.getFermataMultiplier(measureIndex, beatIdx) ?? 1;
    final int thisBeatTicks = beatTicks * multiplier;
    if (tick < cursorTick + thisBeatTicks) {
      return beatIdx;
    }
    cursorTick += thisBeatTicks;
    beatIdx++;
  }
  // Tick is at or past the measure's own end (shouldn't normally
  // happen given callers clamp to maxTicks - 1 first) — fall back to
  // the last beat index reached.
  return beatIdx > 0 ? beatIdx - 1 : 0;
}

// Shared look for the small help-mode callout labels attached to the
// tempo/scale name containers — a bright, high-contrast pill so they
// read clearly against either the light or dark grid background.
Widget _helpCallout(String text, {double? maxWidth, double fontSize = 22}) {
  final textWidget = Text(
    text,
    style: TextStyle(
      color: Colors.black,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    ),
  );
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.blue.shade100,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.black, width: 1),
    ),
    child: maxWidth != null
        ? SizedBox(width: maxWidth, child: textWidget)
        : textWidget,
  );
}

// Which side of a speech bubble its pointer/tail sticks out from —
// used by the sample-note help illustration below, where one bubble
// points DOWN at the note (pointer on its own bottom edge) and the
// other points UP at it (pointer on its own top edge).
enum BubblePointerSide { top, bottom, left, right }

/// Draws a rounded speech-bubble shape with a small triangular
/// pointer on one side, per request — a round callout that visibly
/// points at its target, rather than a plain rectangular label.
class SpeechBubblePainter extends CustomPainter {
  final BubblePointerSide pointerSide;
  final Color color;

  SpeechBubblePainter({required this.pointerSide, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const pointerHeight = 10.0;
    const pointerWidth = 16.0;
    const radius = 12.0;

    final bodyTop = pointerSide == BubblePointerSide.top ? pointerHeight : 0.0;
    final bodyBottom = pointerSide == BubblePointerSide.bottom
        ? size.height - pointerHeight
        : size.height;
    // Only the `left`/`right` cases actually inset the body's
    // corresponding edge — top/bottom cases keep the body spanning
    // the full width, same as before.
    final bodyLeft = pointerSide == BubblePointerSide.left ? pointerHeight : 0.0;
    final bodyRight = pointerSide == BubblePointerSide.right
        ? size.width - pointerHeight
        : size.width;

    final path = Path()
      ..addRRect(
        RRect.fromLTRBR(
          bodyLeft,
          bodyTop,
          bodyRight,
          bodyBottom,
          const Radius.circular(radius),
        ),
      );

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    switch (pointerSide) {
      case BubblePointerSide.top:
        path.moveTo(centerX - pointerWidth / 2, bodyTop);
        path.lineTo(centerX, 0);
        path.lineTo(centerX + pointerWidth / 2, bodyTop);
        path.close();
        break;
      case BubblePointerSide.bottom:
        path.moveTo(centerX - pointerWidth / 2, bodyBottom);
        path.lineTo(centerX, size.height);
        path.lineTo(centerX + pointerWidth / 2, bodyBottom);
        path.close();
        break;
      case BubblePointerSide.left:
        path.moveTo(bodyLeft, centerY - pointerWidth / 2);
        path.lineTo(0, centerY);
        path.lineTo(bodyLeft, centerY + pointerWidth / 2);
        path.close();
        break;
      case BubblePointerSide.right:
        path.moveTo(bodyRight, centerY - pointerWidth / 2);
        path.lineTo(size.width, centerY);
        path.lineTo(bodyRight, centerY + pointerWidth / 2);
        path.close();
        break;
    }

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant SpeechBubblePainter oldDelegate) {
    return oldDelegate.pointerSide != pointerSide || oldDelegate.color != color;
  }
}

/// A rounded speech-bubble callout with [text] inside, pointing
/// toward its target from whichever side [pointerSide] selects —
/// `bottom` puts the pointer on the bubble's own bottom edge (so it
/// sits above something and points down at it); `top` puts it on the
/// top edge (so it sits below something and points up at it); `left`
/// puts it on the left edge (so it sits to the right of something and
/// points left at it).
Widget speechBubble(
    String text, {
      required BubblePointerSide pointerSide,
      double? maxWidth,
    }) {
  final textWidget = Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: Colors.black,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    ),
  );
  return CustomPaint(
    painter: SpeechBubblePainter(
      pointerSide: pointerSide,
      color: Colors.blue.shade100,
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        pointerSide == BubblePointerSide.left ? 18 : 12,
        pointerSide == BubblePointerSide.top ? 18 : 8,
        pointerSide == BubblePointerSide.right ? 18 : 12,
        pointerSide == BubblePointerSide.bottom ? 18 : 8,
      ),
      child: maxWidth != null
          ? SizedBox(width: maxWidth, child: textWidget)
          : textWidget,
    ),
  );
}

class GridWidget extends StatelessWidget {
  final CompositionController controller;
  final double cellHeight;
  final ScrollController? verticalScrollController;
  final ScrollController? horizontalScrollController;
  // Blank SCROLLABLE space added before tick 0's content — lets the
  // grid rest with beat 1 of measure 1 sitting in the middle of the
  // viewport (rather than jammed against the pitch column) before
  // playback starts. This is purely a scroll-view-level padding
  // concept — it does NOT change any tick-to-pixel math elsewhere in
  // this file (GridPainter, note positioning), so nothing else needs
  // to know about it. CompositionScreen's own _scrollTo (which
  // drives playback's auto-scroll) adds this SAME amount to its
  // offset formula, keeping the two in sync.
  final double leadingPadding;
  // Whether playback is currently active, and what to call if the
  // grid is tapped while it is — per request, tapping anywhere on
  // the grid during playback pauses it (tapping again resumes from
  // that same spot via the normal Play button/_togglePlayback logic
  // in CompositionScreen), INSTEAD of the tap's normal note-creation/
  // editing behavior.
  final bool isPlaying;
  final VoidCallback? onTapWhilePlaying;
  // While on, overlays short instructional callouts explaining how to
  // edit tempo/scale (attached right next to their own labels) plus a
  // fixed banner (pinned to the viewport, not the scrollable content)
  // covering time signature, dynamics, and note editing — per
  // request. Purely visual; doesn't change any tap/gesture behavior
  // in this widget itself.
  final bool helpMode;

  const GridWidget({
    super.key,
    required this.controller,
    required this.cellHeight,
    this.verticalScrollController,
    this.horizontalScrollController,
    this.leadingPadding = 0,
    this.isPlaying = false,
    this.onTapWhilePlaying,
    this.helpMode = false,
  });


  @override
  Widget build(BuildContext context) {
    final pixelsPerTick = controller.pixelsPerTick;
    final gridHeight = controller.totalRows * cellHeight;
    final gridWidth = controller.maxTicks * pixelsPerTick;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scaleLabelHits = helpMode
            ? _computeScaleLabelHits(controller, pixelsPerTick)
            : const <_ScaleLabelHit>[];
        final labelHits = helpMode
            ? _computeLabelHits(controller, pixelsPerTick, gridHeight)
            : const <_LabelHit>[];

        return LayoutBuilder(
          builder: (context, constraints) {
            // Trailing padding, symmetric to [leadingPadding] at the
            // start — per request, without this the scrollable
            // content's own width was exactly gridWidth, so
            // maxScrollExtent (gridWidth - viewportWidth) was reached
            // the instant the LAST notes first became visible at the
            // viewport's right edge; they could never be dragged any
            // further left to actually reach the pitch column, unlike
            // every earlier note in the piece. Sized to the viewport's
            // own width (constraints.maxWidth, from this LayoutBuilder)
            // so the very last tick can be scrolled all the way to the
            // viewport's left edge, exactly mirroring what
            // leadingPadding already does for tick 0 at the start.
            final trailingPadding = constraints.maxWidth;

            return Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  controller: verticalScrollController,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: horizontalScrollController,
                    padding: EdgeInsets.only(
                      left: leadingPadding,
                      right: trailingPadding,
                    ),
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
                                // While playback is active, ANY tap on the
                                // grid pauses it instead of doing its normal
                                // note-creation/editing thing — tapping again
                                // later resumes from that same spot via the
                                // ordinary Play button logic, since pausing
                                // (unlike stopping) never resets the playback
                                // position.
                                if (isPlaying) {
                                  onTapWhilePlaying?.call();
                                  return;
                                }
                                // Skipped in Help Mode — otherwise this
                                // early return (triggered because Help
                                // Mode forces Scroll Lock on) would also
                                // block reaching the fermata/scale/tempo/
                                // dynamic label checks below, which SHOULD
                                // still work while Help Mode is on. Note
                                // creation itself is separately blocked
                                // further down (see the helpMode check
                                // right before it).
                                if (!helpMode && controller.editingBlocked) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 2),
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
                                  final row = visualRowToLogicalRow(controller, visualRow);
                                  final errorMessage =
                                  controller.finishGlissandoPick(row);
                                  if (errorMessage != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        duration: const Duration(seconds: 2),
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
                                  final row = visualRowToLogicalRow(controller, visualRow);
                                  final errorMessage =
                                  controller.addGraceNoteAtRow(row);
                                  if (errorMessage != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        duration: const Duration(seconds: 2),
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

                                // 3. Check any fermata "fz" labels next —
                                //    tapping one reopens the fermata
                                //    dialog (to change or delete it)
                                //    instead of creating a note.
                                final fermataHits = _computeFermataHits(
                                  controller,
                                  pixelsPerTick,
                                  gridHeight,
                                );

                                for (final hit in fermataHits) {
                                  if (hit.rect.contains(details.localPosition)) {
                                    fermataDialog(
                                      context: context,
                                      controller: controller,
                                      measureIndex: hit.measureIndex,
                                      beatIndex: hit.beatIndex,
                                    );
                                    return; // don't fall through to note creation
                                  }
                                }

                                // 4. Check the scale name label at the top —
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

                                // 4.5. Check the time-signature label at
                                //    the bottom next — tapping it opens
                                //    beatSubdivisionDialog for that
                                //    measure (per request), not creating
                                //    a note.
                                final timeSignatureLabelHits =
                                _computeTimeSignatureLabelHits(
                                  controller,
                                  pixelsPerTick,
                                  gridHeight,
                                );

                                for (final hit in timeSignatureLabelHits) {
                                  if (hit.rect.contains(details.localPosition)) {
                                    beatSubdivisionDialog(
                                      context: context,
                                      controller: controller,
                                      measureIndex: hit.measureIndex,
                                    );
                                    return; // don't fall through to note creation
                                  }
                                }

                                // 5. Check tempo/dynamic labels next — tapping a
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

                                // 6. Check crescendo/diminuendo start & finish
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

                                // 7. Otherwise, normal grid/note tap handling.
                                // While Help Mode is on, tapping the grid
                                // never creates a note — per request, this
                                // mode is purely informational, not for
                                // editing. Everything above this point
                                // (fermata/scale/tempo/dynamic labels) still
                                // works normally even in Help Mode, since
                                // those already open their own dialogs
                                // rather than creating a note.
                                if (helpMode) {
                                  return;
                                }
                                // The tapped screen position is converted to a
                                // musical row: row 0 (lowest pitch) sits at the
                                // BOTTOM of the grid, so a tap near the bottom
                                // (large visualRow) should map to a small row
                                // number.
                                final visualRow =
                                (details.localPosition.dy / cellHeight).floor();
                                final row = visualRowToLogicalRow(controller, visualRow);

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
                                // Skipped in Help Mode for the same reason
                                // as onTapUp above — double-tap only opens
                                // a dialog here, never creates a note, so
                                // there's no reason to block it, and the
                                // help illustrations promise this still
                                // works.
                                if (!helpMode && controller.editingBlocked) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 2),
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
                                final beatIndex = beatIndexAtTick(
                                  controller,
                                  measureIndex,
                                  measure,
                                  rawTick,
                                );

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
                              isPlaying: isPlaying,
                              onTapWhilePlaying: onTapWhilePlaying,
                            ),
                          ),

                          // HELP MODE — tempo callouts, positioned just
                          // below each tempo label's own rect. Points
                          // DOWN (per request) since the bubble sits
                          // ABOVE the tempo/time-signature label it's
                          // pointing at.
                          if (helpMode)
                            ...labelHits.where((h) => h.isTempo).map(
                                  (hit) => Positioned(
                                left: hit.rect.left,
                                // Positioned via `bottom` (relative to the
                                // stack's own bottom edge) rather than
                                // `top`, since the callout's own rendered
                                // height isn't known in advance here —
                                // this puts its bottom edge 2px above the
                                // tempo label's own top edge, i.e. ABOVE
                                // the tempo name, per request (previously
                                // below it).
                                bottom: gridHeight - hit.rect.top + 2,
                                child: speechBubble(
                                  'To edit tempo or\ntime signature,\ntap its label.',
                                  pointerSide: BubblePointerSide.bottom,
                                ),
                              ),
                            ),

                          // HELP MODE — scale callouts, positioned just
                          // below each scale name label's own rect.
                          // Points UP (per request) since the bubble
                          // sits BELOW the scale label it's pointing at.
                          if (helpMode)
                            ...scaleLabelHits.map(
                                  (hit) => Positioned(
                                left: hit.rect.left,
                                top: hit.rect.bottom + 2,
                                child: speechBubble(
                                  'To edit the scale,\ntap its label.',
                                  pointerSide: BubblePointerSide.top,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // HELP MODE — instructional banners about note editing,
                // pinned to the viewport itself (outside the scrollable
                // content above) so they stay visible regardless of
                // scroll position, rather than scrolling away with the
                // grid. No longer draws a sample note — per request, this
                // mode shouldn't create/show any note (even an
                // illustrative one) — so these use the plain, pointer-
                // less _helpCallout style instead of speech bubbles
                // pointing at a note that no longer exists.
                //
                // Combined into ONE banner, per request — previously
                // this was 4 separate stacked callouts in the center
                // plus a 5th one lower down explaining hand/duration
                // setup; all 5 are now one single _helpCallout so
                // there's just one box to read instead of several.
                if (helpMode)
                  Positioned.fill(
                    child: Align(
                      alignment: const Alignment(0.8, -0.2),
                      child: _helpCallout(
                        "To set the hand for new notes, tap the 'Hand Set' icon.\n\n"
                            "To set the duration for new notes, tap the 'Note Duration' icon.\n\n"
                            "To add a note, tap the grid once on the correct row (pitch) and beat (column).\n\n"
                            "To edit a note, tap it once.\n\n"
                            "To move a note, drag it.\n\n"
                            "To copy a note, press and hold it, then tap the grid to paste the copy while the 'Paste Mode' icon is highlighted.\n\n"
                            "To add grace notes to a note, tap it once, choose the grace note type, then, while the 'Grace Notes' icon is highlighted, tap the grid once on the correct rows (pitches) and beats (columns).\n\n"
                            "To edit a beat or measure, double-tap it.\n\n"
                            "To add or edit a dynamic marking or pedal, double-tap the grid on the correct column (beat).\n\n"
                            "To change the scale, tempo, or time signature, tap its label.",
                        maxWidth: 400,
                      ),
                    ),
                  ),

                // HELP MODE — points at the toolbar icons sitting just
                // outside the grid's own left edge (in CompositionScreen's
                // app-bar columns), per request. Positioned in the TOP-left
                // band (not vertically centered) so it never overlaps the
                // sample-note illustration group below, which sits at
                // Alignment.center — the two previously shared the same
                // vertical band (centerLeft vs center both sit at the
                // viewport's own vertical middle), so a wide sample-note
                // group could overlap this bubble.
                if (helpMode)
                  Positioned.fill(
                    child: Align(
                      alignment: const Alignment(-1.1, -0.60),
                      child: speechBubble(
                        'Tap an icon to\nsee what it does.',
                        pointerSide: BubblePointerSide.left,
                      ),
                    ),
                  ),
              ],
            );
          },
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
    final fontSize = controller.gridFontSize;
    final referenceTempoHeight = controller.timeline.tempoEvents.isNotEmpty
        ? _tempoTextPainter(controller.timeline.tempoEvents.first, fontSize, false).height
        : 0.0;
    final referenceDynamicHeight = controller.timeline.dynamicEvents.isNotEmpty
        ? _dynamicTextPainter(controller.timeline.dynamicEvents.first, fontSize).height
        : 0.0;
    final measureLabelHeight = _measureLabelReferenceHeight(fontSize);

    final dynamicLabelY = size.height
        - measureLabelHeight
        - _bottomMargin
        - _labelGap
        - referenceTempoHeight
        - _labelGap
        - referenceDynamicHeight;

    // Small gap above the dynamic label's own top edge.
    const pedalBuffer = 4.0;
    final pedalTextHeight = _pedalTextPainter(fontSize).height;
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
    final pedalTextHeight = _pedalTextPainter(controller.gridFontSize).height;
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
    final fontSize = controller.gridFontSize;

    DynamicChangeEvent? pedalBegin;

    for (final event in controller.timeline.dynamicChangeEvents) {
      if (event.dynamic_change == DynamicChange.pedalDown) {
        pedalBegin = event;
        final tp = _pedalTextPainter(fontSize);
        final x = event.tick * pixelsPerTick;
        // + _labelOffsetX to match every other label in this file
        // (dynamic, tempo, scale, measure number) — without it the
        // "ped" sign started exactly at the tick line instead of
        // slightly to the right, so it didn't line up vertically with
        // the dynamic label stacked directly below it.
        tp.paint(canvas, Offset(x + _labelOffsetX, pedalY - tp.height / 2));
      } else if (event.dynamic_change == DynamicChange.pedalUp) {
        if (pedalBegin != null) {
          final tp = _pedalTextPainter(fontSize);
          final startX =
              pedalBegin.tick * pixelsPerTick + _labelOffsetX + tp.width + 4;
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
    final fontSize = controller.gridFontSize;
    final isDarkMode = controller.isDarkMode;

    // BACKGROUND — the grid previously had no explicit fill of its
    // own, relying on the white Scaffold sitting behind it; drawn
    // explicitly now so it can be black in dark mode instead.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppColors.gridBackground(isDarkMode),
    );

    final thinPaint = Paint()
      ..color = AppColors.gridLineThin(isDarkMode)
      ..strokeWidth = 1;

    final beatPaint = Paint()
      ..color = AppColors.gridLineMedium(isDarkMode)
      ..strokeWidth = 1.5;

    final octavePaint = Paint()
      ..color = AppColors.gridLineMedium(isDarkMode)
      ..strokeWidth = 1.5;

    final measurePaint = Paint()
      ..color = AppColors.gridLineStrong(isDarkMode)
      ..strokeWidth = 2;

    final middleOctavePaint = Paint()
      ..color = AppColors.gridLineStrong(isDarkMode)
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
      // The very top and bottom boundary lines of the whole grid —
      // made as visible as the strongest line style available
      // (matching measure boundaries), overriding whatever they'd
      // otherwise get, so the grid's own edges always read clearly
      // rather than blending into the regular row lines.
      if (row == 0 || row == controller.totalRows) {
        linePaint = measurePaint;
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
        fontSize,
        isDarkMode,
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
        final scaleTextPainter =
        _scaleTextPainter(measure.scaleName, fontSize, isDarkMode);
        final scaleY = _topMargin +
            _measureNumberReferenceHeight(fontSize) +
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
      final measureLabelPainter =
      _measureLabelTextPainter(measureLabelText, fontSize, isDarkMode);
      final measureLabelY = size.height - measureLabelPainter.height - _bottomMargin;
      measureLabelPainter.paint(
        canvas,
        Offset(measureX + _labelOffsetX, measureLabelY),
      );

      final beatTicks = measure.timeSignature.beatDuration.ticks;
      // Walks beat-by-beat rather than assuming every beat in this
      // measure is the same width — a fermata-stretched beat (see
      // CompositionController.getFermataMultiplier/
      // applyFermataToBeat) is wider than an ordinary one, so its
      // beat line needs to be drawn further along, and it gets a
      // blue "fz" label centered in its own (wider) column.
      int cursorTick = measure.startTick;
      int beatIdx = 0;
      while (cursorTick < measure.endTick) {
        final fermataMultiplier =
            controller.getFermataMultiplier(i, beatIdx) ?? 1;
        final thisBeatTicks = beatTicks * fermataMultiplier;
        final beatStartX = cursorTick * pixelsPerTick;
        cursorTick += thisBeatTicks;

        if (cursorTick < measure.endTick) {
          final x = cursorTick * pixelsPerTick;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), beatPaint);
        }

        if (fermataMultiplier > 1) {
          final beatWidthPx = thisBeatTicks * pixelsPerTick;
          final fermataTp = TextPainter(
            text: TextSpan(
              text: _fermataLabelText(
                measure.timeSignature.beatDuration,
                fermataMultiplier,
              ),
              style: TextStyle(
                color: Colors.blue,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          fermataTp.paint(
            canvas,
            Offset(
              beatStartX + beatWidthPx / 2 - fermataTp.width / 2,
              size.height - _measureLabelReferenceHeight(fontSize) - _bottomMargin,
            ),
          );
        }

        beatIdx++;
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

    final measureLabelHeightForTempo = _measureLabelReferenceHeight(fontSize);

    for (final tempoEvent in controller.timeline.tempoEvents) {
      final x = tempoEvent.tick * pixelsPerTick;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        tempoLinePaint,
      );

      final textPainter = _tempoTextPainter(tempoEvent, fontSize, isDarkMode);
      final y = size.height -
          measureLabelHeightForTempo -
          _bottomMargin -
          _labelGap -
          textPainter.height;
      textPainter.paint(canvas, Offset(x + _labelOffsetX, y));
    }

// DYNAMIC EVENTS — labels stacked above tempo label

    final referenceTempoHeight = controller.timeline.tempoEvents.isNotEmpty
        ? _tempoTextPainter(controller.timeline.tempoEvents.first, fontSize, false).height
        : 0.0;

    for (final dynamicEvent in controller.timeline.dynamicEvents) {
      final x = dynamicEvent.tick * pixelsPerTick;
      final textPainter = _dynamicTextPainter(dynamicEvent, fontSize);

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