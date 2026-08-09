import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../dialogs/edit_measure_beat_dialog.dart';
import '../dialogs/note_dialog.dart';
import '../enums/accidental.dart';
import '../enums/articulation.dart';
import '../enums/hand.dart';
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

// NOTE: ornaments are no longer drawn as a sign/symbol above the note.
// When a note carries an ornament, CompositionController.displayNotes
// always expands it into its short "ghost" sequence of shifted-pitch
// notes (see that getter) — that sequence IS the ornament's entire
// presentation now. Accordingly, the ornament sign/symbol strip
// (previously reserved via an "ornament space" above the finger
// number) and the custom painter that drew mordent/turn/tremolo
// symbols have been removed from this widget.


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
  /// CompositionController.displayNotes when expanding an ornament —
  /// never actually in controller.notes. A ghost's `note.row` is
  /// always the underlying real note's own UNCHANGED row (no walking
  /// baked in); this widget always walks `note.row` plus
  /// `ornamentShift` to the genuinely different row the ghost
  /// actually displays on (see the pitch/row computation in build()),
  /// regardless of the compensated-notation toggle. Ghosts never show
  /// an ornament sign of their own (ornaments no longer draw a sign
  /// at all — the ghost sequence's shifted pitches ARE the ornament's
  /// presentation).
  final bool isCompensatedGhost;

  /// Whether this block responds to taps/drags/long-press/double-tap
  /// at all. False for every ghost in an ornament's sequence except
  /// the one covering the longest slice of the original note's
  /// duration — see CompositionController.displayNotes. Always true
  /// for ordinary (non-ghost) notes.
  final bool isClickable;

  /// The real note that a tap/drag on this block should actually
  /// edit. Defaults to [note] itself. For the one clickable ghost in
  /// an ornament's sequence, this is the real underlying note (which
  /// still carries the ornament) rather than that ghost's own
  /// synthetic copy — edits to the synthetic copy would silently go
  /// nowhere, since it isn't in controller.notes.
  final Note? interactionNote;

  /// For a ghost only: the RAW semitone shift from its ornament's
  /// shiftMap entry (0 for the ornament's own unaltered/base-pitch
  /// ghosts, and for every non-ghost note). [note]'s own row is
  /// always the underlying note's UNCHANGED row; this shift is what
  /// build() walks (via [CompositionController.resolveOrnamentWalk])
  /// to find the genuinely different row the ghost actually displays
  /// on — e.g. pitch "3" shifted by a semitone below shows as "2+" on
  /// the row below, not "3-" on the same row. This walking is always
  /// applied for ghosts, regardless of
  /// [CompositionController.showCompensatedNotation] (that toggle
  /// only affects ORDINARY notes' display).
  final int ornamentShift;

  const NoteBlockWidget({
    super.key,
    required this.note,
    required this.pixelsPerTick,
    required this.cellHeight,
    required this.controller,
    this.isCompensatedGhost = false,
    this.isClickable = true,
    this.interactionNote,
    this.ornamentShift = 0,
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
      case Articulation.staccato:
      case Articulation.tenuto:
      case Articulation.marcato:
      case Articulation.accent:
      case null:
        return null;
    }
  }

  /// Legato used to be one of the mutually exclusive Articulation
  /// values, drawn as a red bottom border — it's now a separate,
  /// independent flag ([Note.legato]), so a note can be legato AND
  /// carry an articulation (e.g. sforzando) at the same time. This
  /// merges the two: [_articulationBorder]'s border (if any) is kept
  /// on every side except the bottom, which legato — when on —
  /// always claims for its own red border, overriding whatever that
  /// side would otherwise have been.
  Border? _combinedBorder() {
    final articulationBorder = _articulationBorder();
    if (!widget.note.legato) return articulationBorder;

    const legatoBottom = BorderSide(color: Colors.red, width: 3);
    if (articulationBorder == null) {
      return const Border(bottom: legatoBottom);
    }
    return Border(
      top: articulationBorder.top,
      left: articulationBorder.left,
      right: articulationBorder.right,
      bottom: legatoBottom,
    );
  }

  @override
  Widget build(BuildContext context) {

    final note = widget.note;

    final controller = widget.controller;

    final isGhost = widget.isCompensatedGhost;

    // The note that taps/drags on this block should actually mutate.
    // For ordinary notes this is just `note` itself; for the one
    // clickable ghost in an ornament's sequence, the caller passes the
    // real underlying note explicitly (see the class doc above).
    final interactionNote = widget.interactionNote ?? note;

    final String pitch;
    final String accidental;
    // Only ever actually read for a ghost (see the `isGhost ?`
    // ternary building `displayRow` below) — declared as a plain
    // initialized local so it's always unambiguously assigned
    // regardless of which branch runs.
    int ghostWalkedRow = note.row;
    if (isGhost) {
      // An ornament ghost ALWAYS shows its shift by moving to a
      // genuinely different row (walking, via resolveOrnamentWalk)
      // rather than staying on the base note's row with an
      // accidental — this is how mordents/turns/etc. are actually
      // notated: the auxiliary note gets its own staff position, not
      // an accidental glued onto the same line. E.g. a note at
      // pitch "3" with a semitone-below shift shows as "2+" on the
      // row below, not "3-" on the same row. This is independent of
      // the compensated-notation toggle, which only affects ORDINARY
      // notes' display (see the else branch below) — a ghost's
      // actual SOUND (see CompositionController.getOrnamentFrequencyHz)
      // is unaffected either way, since it's computed directly from
      // the base row and raw shift regardless of how it's drawn.
      final measure = controller.getMeasureAtTick(note.startTick);
      final walked =
      controller.resolveOrnamentWalk(note.row, widget.ornamentShift);
      final baseDigit = controller.getPitchNameForRow(walked.row, measure);
      final strippedDigit =
      baseDigit.endsWith('+') || baseDigit.endsWith('-')
          ? baseDigit.substring(0, baseDigit.length - 1)
          : baseDigit;
      final leftoverSign = controller.signStringForShift(walked.remainingShift);
      pitch = '$strippedDigit$leftoverSign';
      accidental = '';
      ghostWalkedRow = walked.row;
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

    // Row 0 is the lowest pitch (octave 0, degree 1) and should render
    // at the BOTTOM of the grid; the highest row should render at the
    // TOP. Since `top` grows downward on screen, we flip the row here
    // so the highest row gets the smallest `top` (top of screen) and
    // row 0 gets the largest `top` (bottom of screen).
    //
    // When compensated notation is on, a note whose accidental doubles
    // up with the scale's own sign displays on the *next* row over
    // (see getCompensatedDisplay) — note.row itself is untouched, this
    // only affects where the block is drawn. Ghost notes always walk
    // to their own genuinely-different row (see the pitch/accidental
    // computation above, and ghostWalkedRow), regardless of the
    // compensated-notation toggle.
    final displayRow = isGhost
        ? ghostWalkedRow
        : (controller.showCompensatedNotation
        ? controller.getCompensatedDisplay(note).row
        : note.row);
    final top = (controller.totalRows - 1 - displayRow) * widget.cellHeight;

    final drawMark = _hasDrawnMark(note.articulation);
    final hasFinger = note.finger != null;
    final hasTechnique = note.playingTechnique != null;

    // Reserve extra room above the note box: finger number at the
    // top, articulation mark just above the note itself. Reserve
    // extra room below for the playing technique abbreviation. The
    // note's own position/size (and drag math below) stays untouched
    // — it's simply offset within this taller Positioned/Stack.
    // (Ornaments no longer reserve any space here — see the file-level
    // note above.)
    final fingerSpace = hasFinger ? _fingerHeight : 0.0;
    final markSpace = drawMark ? _articulationMarkHeight : 0.0;
    final topExtra = fingerSpace + markSpace;

    final techniqueSpace = hasTechnique ? _techniqueHeight : 0.0;

    final noteContainer = Container(
      decoration: BoxDecoration(
        color: _handColor(note.hand),
        borderRadius: BorderRadius.circular(4),
        border: _combinedBorder(),
      ),

      child:
      showPitch // PITCH
          ? Padding(
        padding: const EdgeInsets.only(left: 3, right: 2),
        child: RotatedBox(
          quarterTurns: controller.rotatePitchText ? 3 : 0,
          child: FittedBox(
            // Alignment is applied BEFORE the RotatedBox above
            // rotates everything — "right" becomes "top" after a
            // 90° counter-clockwise turn, so this has to flip to
            // centerRight while rotated to keep the digit pinned
            // to the top of the cell (matching centerLeft's
            // normal, unrotated placement at the left edge).
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
    );

    return Positioned(
      left: left,
      top: top - topExtra,
      width: noteWidth,
      height: widget.cellHeight + topExtra + techniqueSpace,
      child: Stack(
        clipBehavior: Clip.none,
        children: [

          if (hasFinger)
            Positioned(
              left: 0,
              top: 0,
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
              top: fingerSpace,
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
            // Only the clickable block (ordinary notes, or the
            // single longest ghost in an ornament's sequence — see
            // CompositionController.displayNotes) gets a
            // GestureDetector at all. Every other ghost renders the
            // same visual container but is otherwise inert, so
            // tapping/dragging it does nothing.
            child: widget.isClickable
                ? GestureDetector(
              // behavior: HitTestBehavior.opaque,
              behavior: HitTestBehavior.deferToChild,

              onPanStart: (details) {
                if (_blockedFromEditing(context)) return;
                dragStartTick = interactionNote.startTick;
                dragStartRow = interactionNote.row;
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
                if (newTick != interactionNote.startTick ||
                    newRow != interactionNote.row) {
                  controller.updateNote(interactionNote, newTick, newRow);
                }
              },

              onTap: () {
                if (_blockedFromEditing(context)) return;
                if (controller.pasteMode) {
                  return;
                }
                // Legato Mode is its own tap interaction, the same
                // way paste mode overrides a normal tap above — while
                // it's on, tapping a note toggles Note.legato instead
                // of opening the edit dialog. Drag/long-press/
                // double-tap are unaffected by this mode.
                if (controller.legatoMode) {
                  controller.toggleNoteLegato(interactionNote);
                  return;
                }
                showDialog(
                  context: context,
                  builder: (_) => NoteDialog(
                    note: interactionNote,
                    controller: controller,
                  ),
                );
              },

              onLongPress: () {
                if (_blockedFromEditing(context)) return;
                controller.copyNote(interactionNote);
                controller.enterPasteMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Note ${controller.noteNumber(interactionNote)} is copied',
                        style: const TextStyle(fontSize: 22)
                    ),
                  ),
                );
              },

              onDoubleTap: () {
                if (_blockedFromEditing(context)) return;
                final rawTick = interactionNote.startTick;
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

              child: noteContainer,
            )
                : noteContainer,
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