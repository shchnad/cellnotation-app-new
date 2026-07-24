import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../dialogs/edit_measure_beat_dialog.dart';
import '../dialogs/note_dialog.dart';
import '../enums/articulation.dart';
import '../enums/hand.dart';
import '../models/note.dart';

// Height of the strip reserved above each note for drawing staccato /
// tenuto / marcato / accent marks.
const double _articulationMarkHeight = 12.0;

// Height of the strip reserved above each note for the finger number.
const double _fingerHeight = 14.0;

// Height of the strip reserved below each note for the playing
// technique abbreviation.
const double _techniqueHeight = 14.0;

const _fingerTextStyle = TextStyle(
  color: Colors.red,
  fontSize: 11,
  fontWeight: FontWeight.bold,
);

const _techniqueTextStyle = TextStyle(
  color: Colors.red,
  fontSize: 11,
  fontWeight: FontWeight.bold,
  // fontStyle: FontStyle.italic,
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

  const NoteBlockWidget({
    super.key,
    required this.note,
    required this.pixelsPerTick,
    required this.cellHeight,
    required this.controller,
  });

  @override
  State<NoteBlockWidget> createState() => _NoteBlockWidgetState();
}

class _NoteBlockWidgetState extends State<NoteBlockWidget> {
  late int dragStartTick;
  late int dragStartRow;

  late Offset dragStartPosition;

  //Articulation borders — only for articulations that don't have their
  //own drawn mark above the note.
  Border? _articulationBorder() {
    switch (widget.note.articulation) {
      case Articulation.sforzando:
        return Border.all(color: Colors.green, width: 3);
      case Articulation.legato:
        return const Border(bottom: BorderSide(color: Colors.red, width: 3));
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

    final accidental = note.accidental?.sign ?? '';

    final pitch = controller.getNotePitchName(note);

    final left = note.startTick * widget.pixelsPerTick;

    final noteWidth = max(note.durationTicks * widget.pixelsPerTick, 8.0);

    final showPitch = noteWidth >= 24;

    final showAccidental = noteWidth >= 36;

    final top = note.row * widget.cellHeight;

    final drawMark = _hasDrawnMark(note.articulation);
    final hasFinger = note.finger != null;
    final hasTechnique = note.playingTechnique != null;

    // Reserve extra room above the note box: finger number on top,
    // articulation mark just above the note. Reserve extra room below
    // for the playing technique abbreviation. The note's own
    // position/size (and drag math below) stays untouched — it's simply
    // offset within this taller Positioned/Stack.
    final fingerSpace = hasFinger ? _fingerHeight : 0.0;
    final markSpace = drawMark ? _articulationMarkHeight : 0.0;
    final topExtra = fingerSpace + markSpace;

    final techniqueSpace = hasTechnique ? _techniqueHeight : 0.0;

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
            child: GestureDetector(
              // behavior: HitTestBehavior.opaque,
              behavior: HitTestBehavior.deferToChild,

              onPanStart: (details) {
                dragStartTick = note.startTick;
                dragStartRow = note.row;
                dragStartPosition = details.globalPosition;
              },

              onPanUpdate: (details) {
                final dx = details.globalPosition.dx - dragStartPosition.dx;
                final dy = details.globalPosition.dy - dragStartPosition.dy;
                final tickChange = (dx / widget.pixelsPerTick).round();
                final rowChange = (dy / widget.cellHeight).round();
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
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
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