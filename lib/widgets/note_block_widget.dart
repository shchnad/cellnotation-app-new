import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../dialogs/edit_measure_beat_dialog.dart';
import '../dialogs/note_dialog.dart';
import '../enums/accidental.dart';
import '../enums/articulation.dart';
import '../enums/hand.dart';
import '../enums/ornament.dart';
import '../models/note.dart';

// Height of the strip reserved above each note for drawing staccato /
// tenuto / marcato / accent marks.
const double _articulationMarkHeight = 12.0;

// Height of the strip reserved below each note for the playing
// technique abbreviation.
const double _techniqueHeight = 26.0;

const _techniqueTextStyle = TextStyle(
  color: Colors.red,
  fontSize: 22,
  fontWeight: FontWeight.bold,
  // fontStyle: FontStyle.italic,
);

// Height of the strip reserved above each note for the finger number.
const double _fingerHeight = 26.0;

const _fingerTextStyle = TextStyle(
  color: Colors.red,
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

// Height of the strip reserved above each note (above even the finger
// number) for the ornament sign — e.g. "uM" for upper mordent.
const double _ornamentHeight = 24.0;

const _ornamentTextStyle = TextStyle(
  color: Colors.blue,
  fontSize: 18,
  fontWeight: FontWeight.bold,
);


// Articulations that get a drawn symbol above the note (as opposed to
// the border-based treatment used for legato / sforzando).
bool _hasDrawnMark(Articulation? articulation) {
  switch (articulation) {
    case Articulation.staccato:
    case Articulation.tenuto:
    case Articulation.marcato:
    case Articulation.accent:
      return true;
    default:
      return false;
  }
}

class NoteBlockWidget extends StatefulWidget {
  final Note note;
  final double pixelsPerTick;
  final double cellHeight;
  final CompositionController controller;

  /// True for a display-only "ghost" note produced by
  /// CompositionController.displayNotes when expanding an ornament
  /// under compensated notation — never actually in
  /// controller.notes. Ghosts render their own precomputed row/
  /// accidental literally (no measure/propagation lookups, since
  /// those only work for real notes in the list) and never show an
  /// ornament sign of their own.
  final bool isCompensatedGhost;

  const NoteBlockWidget({
    super.key,
    required this.note,
    required this.pixelsPerTick,
    required this.cellHeight,
    required this.controller,
    this.isCompensatedGhost = false,
  });

  @override
  State<NoteBlockWidget> createState() => _NoteBlockWidgetState();
}

class _NoteBlockWidgetState extends State<NoteBlockWidget> {
  late int dragStartTick;
  late int dragStartRow;

  late Offset dragStartPosition;

  /// If compensated notation, input lock, or draw mode is on, shows a
  /// message naming which one and returns true so the caller can bail
  /// out — none of them allow editing notes through this widget.
  bool _blockedFromEditing(BuildContext context) {
    if (!widget.controller.editingBlocked) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.editingBlockedMessage,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
    return true;
  }

  //Articulation borders — only for articulations that don't have their
  //own drawn mark above the note.
  Border? _articulationBorder() {
    switch (widget.note.articulation) {
      case Articulation.sforzando:
        return Border.all(
          color: Colors.green,
          width: 3,
        );
      case Articulation.legato:
        return const Border(
            bottom: BorderSide(
              color: Colors.red,
              width: 3,
            ));
      case Articulation.staccato:
      case Articulation.tenuto:
      case Articulation.marcato:
      case Articulation.accent:
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {

    final note = widget.note;

    final controller = widget.controller;

    final isGhost = widget.isCompensatedGhost;

    // Ghost notes (from CompositionController.displayNotes expanding
    // an ornament) carry their own already-computed row/accidental
    // directly — they're never in controller.notes, so the normal
    // getDisplayPitchLabel/getEffectiveAccidental lookups (which scan
    // that list for measure/propagation context) wouldn't find them
    // and would derive the wrong thing from whatever real note
    // happens to be nearby instead. So ghosts read note.row/
    // note.accidental literally and build the same "merged word" style
    // compensated notes already use, without going through that
    // machinery.
    final String pitch;
    final String accidental;
    if (isGhost) {
      final measure = controller.getMeasureAtTick(note.startTick);
      final baseDigit = controller.getPitchNameForRow(note.row, measure);
      final sign = note.accidental?.sign ?? '';
      pitch = sign.isEmpty
          ? baseDigit
          : '${baseDigit.endsWith('+') || baseDigit.endsWith('-') ? baseDigit.substring(0, baseDigit.length - 1) : baseDigit}$sign';
      accidental = '';
    } else {
      // Under normal notation, show the note's own effective
      // accidental as a separate glyph next to the pitch — "x"
      // included, so a natural note reads literally as e.g. "4+" next
      // to "x". Under compensated notation the sign (if any) is
      // already merged into the single computed word from
      // getDisplayPitchLabel — and a natural collapses everything to
      // a plain digit there — so no separate glyph is drawn in that
      // mode.
      final effectiveAccidental = controller.getEffectiveAccidental(note);
      accidental = controller.showCompensatedNotation
          ? ''
          : (effectiveAccidental?.sign ?? '');
      pitch = controller.getDisplayPitchLabel(note);
    }

    final left = note.startTick * widget.pixelsPerTick;

    final noteWidth = max(note.durationTicks * widget.pixelsPerTick, 8.0);

    final showPitch = noteWidth >= 24;

    final showAccidental = noteWidth >= 36;

    // Row 0 is the lowest pitch (octave 0, degree 1) and should render
    // at the BOTTOM of the grid; the highest row should render at the
    // TOP. Since `top` grows downward on screen, we flip the row here
    // so the highest row gets the smallest `top` (top of screen) and
    // row 0 gets the largest `top` (bottom of screen).
    //
    // When compensated notation is on, a note whose accidental doubles
    // up with the scale's own sign displays on the *next* row over
    // (see getCompensatedDisplay) — note.row itself is untouched, this
    // only affects where the block is drawn. Ghost notes already carry
    // their final row directly (computed when they were expanded), so
    // they skip this lookup too.
    final displayRow = isGhost
        ? note.row
        : (controller.showCompensatedNotation
        ? controller.getCompensatedDisplay(note).row
        : note.row);
    final top = (controller.totalRows - 1 - displayRow) * widget.cellHeight;

    final drawMark = _hasDrawnMark(note.articulation);
    final hasFinger = note.finger != null;
    final hasTechnique = note.playingTechnique != null;
    // Ghosts never carry their own ornament (it's cleared when they're
    // expanded), so this is naturally false for them without needing
    // an extra check.
    final hasOrnament = note.ornament != null;

    // Reserve extra room above the note box: ornament sign at the very
    // top, finger number below that, articulation mark just above the
    // note itself. Reserve extra room below for the playing technique
    // abbreviation. The note's own position/size (and drag math below)
    // stays untouched — it's simply offset within this taller
    // Positioned/Stack.
    final ornamentSpace = hasOrnament ? _ornamentHeight : 0.0;
    final fingerSpace = hasFinger ? _fingerHeight : 0.0;
    final markSpace = drawMark ? _articulationMarkHeight : 0.0;
    final topExtra = ornamentSpace + fingerSpace + markSpace;

    final techniqueSpace = hasTechnique ? _techniqueHeight : 0.0;

    return Positioned(
      left: left,
      top: top - topExtra,
      width: noteWidth,
      height: widget.cellHeight + topExtra + techniqueSpace,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (hasOrnament)
            Positioned(
              left: 0,
              top: 0,
              width: noteWidth,
              height: _ornamentHeight,
              child: Center(
                child: Text(
                  note.ornament!.sign,
                  style: _ornamentTextStyle,
                ),
              ),
            ),

          if (hasFinger)
            Positioned(
              left: 0,
              top: ornamentSpace,
              width: noteWidth,
              height: _fingerHeight,
              child: Center(
                child: Text(
                  note.finger!.value.toString(),
                  style: _fingerTextStyle,
                ),
              ),
            ),

          if (drawMark)
            Positioned(
              left: 0,
              top: ornamentSpace + fingerSpace,
              width: noteWidth,
              height: _articulationMarkHeight,
              child: CustomPaint(
                painter: _ArticulationMarkPainter(note.articulation!),
              ),
            ),

          Positioned(
            left: 0,
            top: topExtra,
            width: noteWidth,
            height: widget.cellHeight,
            child: GestureDetector(
              // behavior: HitTestBehavior.opaque,
              behavior: HitTestBehavior.deferToChild,

              onPanStart: (details) {
                if (_blockedFromEditing(context)) return;
                dragStartTick = note.startTick;
                dragStartRow = note.row;
                dragStartPosition = details.globalPosition;
              },

              onPanUpdate: (details) {
                // No message here — onPanStart already warned once for
                // this gesture; repeating it every frame would spam.
                if (widget.controller.editingBlocked) return;
                final dx = details.globalPosition.dx - dragStartPosition.dx;
                final dy = details.globalPosition.dy - dragStartPosition.dy;
                final tickChange = (dx / widget.pixelsPerTick).round();
                // Screen Y grows downward, but row now grows upward
                // (row 0 = bottom, highest row = top) to match the
                // flipped `top` above — so dragging the finger down
                // (positive dy) must DECREASE the row, not increase it.
                final rowChange = -(dy / widget.cellHeight).round();
                final newTick =
                controller.snapTick(dragStartTick + tickChange);
                final newRow = (dragStartRow + rowChange)
                    .clamp(0, controller.totalRows - 1)
                    .toInt();
                if (newTick != note.startTick || newRow != note.row) {
                  controller.updateNote(note, newTick, newRow);
                }
              },

              onTap: () {
                if (_blockedFromEditing(context)) return;
                if (controller.pasteMode) {
                  return;
                }
                showDialog(
                  context: context,
                  builder: (_) =>
                      NoteDialog(note: note, controller: controller),
                );
              },

              onLongPress: () {
                if (_blockedFromEditing(context)) return;
                controller.copyNote(note);
                controller.enterPasteMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Note ${controller.noteNumber(note)} is copied',
                        style: TextStyle(fontSize: 22)
                    ),
                  ),
                );
              },

              onDoubleTap: () {
                if (_blockedFromEditing(context)) return;
                final rawTick = note.startTick;
                final measure = controller.getMeasureAtTick(rawTick);
                final measureIndex = controller.measures.indexOf(measure);
                final beatIndex =
                ((rawTick - measure.startTick) ~/
                    measure.timeSignature.ticksPerBeat);
                editMeasureBeatDialog(
                  context: context,
                  controller: controller,
                  measureIndex: measureIndex,
                  beatIndex: beatIndex,
                );
              },

              child: Container(
                decoration: BoxDecoration(
                  color: _handColor(note.hand),
                  borderRadius: BorderRadius.circular(4),
                  border: _articulationBorder(),
                ),

                child:
                showPitch // PITCH
                    ? Padding(
                  padding: const EdgeInsets.only(left: 3, right: 2),
                  child: RotatedBox(
                    quarterTurns: controller.rotatePitchText ? 3 : 0,
                    child: FittedBox(
                      // Alignment is applied BEFORE the RotatedBox
                      // above rotates everything — "right" becomes
                      // "top" after a 90° counter-clockwise turn, so
                      // this has to flip to centerRight while rotated
                      // to keep the digit pinned to the top of the
                      // cell (matching centerLeft's normal, unrotated
                      // placement at the left edge).
                      alignment: controller.rotatePitchText
                          ? Alignment.topCenter
                          : Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pitch,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.cellHeight * .80,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (accidental.isNotEmpty)
                            Text(
                              accidental, // ACCIDENTAL
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: widget.cellHeight * .80,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
                    : const SizedBox(),
              ),
            ),
          ),

          if (hasTechnique)
            Positioned(
              left: 0,
              top: topExtra + widget.cellHeight,
              width: noteWidth,
              height: _techniqueHeight,
              child: Center(
                child: Text(
                  note.playingTechnique!.abbreviation,
                  style: _techniqueTextStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _handColor(Hand hand) {
    return hand == Hand.right ? Colors.black : Colors.blue;
  }
}

/// Draws the small articulation symbol in the strip directly above a
/// note: staccato = short vertical line, tenuto = short horizontal
/// line, marcato = an upward wedge/accent mark, accent = a ">" sign.
class _ArticulationMarkPainter extends CustomPainter {
  final Articulation articulation;

  const _ArticulationMarkPainter(this.articulation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3 // width of articulation signs
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final top = size.height * 0.15;
    final bottom = size.height * 0.85;
    final halfWidth = min(size.width * 0.25, 5.0);

    switch (articulation) {
      case Articulation.staccato:
      // Short vertical line, centered under the note's tick.
        canvas.drawLine(Offset(cx, top), Offset(cx, bottom), paint);
        break;

      case Articulation.tenuto:
      // Short horizontal line.
        final y = size.height / 2;
        canvas.drawLine(
          Offset(cx - halfWidth, y),
          Offset(cx + halfWidth, y),
          paint,
        );
        break;

      case Articulation.marcato:
      // Upward-pointing wedge/accent (^).
        final path = Path()
          ..moveTo(cx - halfWidth, bottom)
          ..lineTo(cx, top)
          ..lineTo(cx + halfWidth, bottom);
        canvas.drawPath(path, paint..style = PaintingStyle.stroke);
        break;

      case Articulation.accent:
      // ">" sign.
        final path = Path()
          ..moveTo(cx - halfWidth, top)
          ..lineTo(cx + halfWidth, size.height / 2)
          ..lineTo(cx - halfWidth, bottom);
        canvas.drawPath(path, paint);
        break;

      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ArticulationMarkPainter oldDelegate) {
    return oldDelegate.articulation != articulation;
  }
}