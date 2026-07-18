import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../dialogs/edit_measure_beat_dialog.dart';
import '../dialogs/note_dialog.dart';
import '../enums/articulation.dart';
import '../enums/hand.dart';
import '../models/note.dart';

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

  //Articulation borders
  Border? _articulationBorder() {
    switch (widget.note.articulation) {
      case Articulation.accent:
      case Articulation.marcato:
      case Articulation.sforzando:
        return Border.all(color: Colors.red, width: 3);
      case Articulation.legato:
        return const Border(bottom: BorderSide(color: Colors.red, width: 3));
      case Articulation.staccato:
        return const Border(left: BorderSide(color: Colors.red, width: 3));
      case Articulation.tenuto:
        return const Border(top: BorderSide(color: Colors.red, width: 3));
      case Articulation.fermata:
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

    return Positioned(
      left: left,
      top: top,
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
          final newTick = controller.snapTick(dragStartTick + tickChange);
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
            builder: (_) => NoteDialog(note: note, controller: controller),
          );
        },

        onLongPress: () {
          controller.copyNote(note);
          controller.enterPasteMode();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Note copied")));
        },

        onDoubleTapDown: (details) {
          final rawTick = note.startTick;
          final measure = controller.getMeasureAtTick(rawTick,);
          final measureIndex = controller.measures.indexOf(measure,);
          final beatIndex =
          ((rawTick - measure.startTick) ~/
              measure.timeSignature
                  .ticksPerBeat);
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

          child: showPitch // PITCH
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
                        color: Colors.yellow,
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
    );
  }

  Color _handColor(Hand hand) {
    return hand == Hand.right ? Colors.black : Colors.blue;
  }
}
