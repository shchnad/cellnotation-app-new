import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../dialogs/note_dialog.dart';
import '../enums/hand.dart';
import '../models/note.dart';

class NoteBlockWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Calculate precise bounding box dimensions using timeline ticks and track rows
    final double noteLeft = note.startTick * pixelsPerTick;
    final double noteWidth = note.durationTicks * pixelsPerTick;
    final double noteTop = note.row * cellHeight;

    // Fetch the pitch text from your controller using the note's row
    final pitchLabel = controller.getDegree(note.row);

    return Positioned(
      left: noteLeft,
      top: noteTop,
      width: noteWidth,
      height: cellHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        // FIXED: Tap now opens the custom note configuration dialog instantly
        onDoubleTap: () {
          showDialog(
            context: context,
            builder: (context) => NoteDialog(
              note: note,
              controller: controller,
            ),
          );
        },

        // FIXED: Double tap handles note deletion now
        onTap: () {
          if (!controller.pasteMode) {
            controller.removeNote(note);
          }
        },

        // FIXED: Long press copies note, updates pasteMode state, and fires the notification toast banner
        onLongPress: () {
          controller.copyNote(note);
          controller.enterPasteMode();
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Note C${note.startTick + 1} / R${note.row + 1} copied to clipboard!'),
              backgroundColor: Colors.blue.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        },

        // Dragging notes horizontally across timeline grid divisions
        onHorizontalDragUpdate: (details) {
          final int deltaTicks = (details.delta.dx / pixelsPerTick).round();
          if (deltaTicks != 0) {
            // Compute new boundary position and clamp it so it doesn't go below tick 0
            final int newStartRaw = note.startTick + deltaTicks;
            final int newStart = newStartRaw.clamp(0, controller.maxTicks);

            // Snap the dragged note to your grid settings during movement
            final int snappedStart = controller.snapTick(newStart);

            if (snappedStart != note.startTick) {
              controller.updateNote(note, snappedStart, note.row);
            }
          }
        },

        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 0.5),
          decoration: BoxDecoration(
            color: _getHandColor(note.hand),
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 1. Left-aligned context label showing assigned fingers/notations
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    note.finger != null ? note.finger!.name : '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 2. Pitch label with 0.8 * cellHeight vertical scaling and clean left padding
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double blockWidth = constraints.maxWidth;

                      // Base font size calculated directly from your row height logic
                      double dynamicFontSize = cellHeight * 0.8;

                      // Scale down text if the note block width gets too tight horizontally
                      if (blockWidth < 45.0) {
                        dynamicFontSize = (blockWidth / 3.2).clamp(9.0, cellHeight * 0.8);
                      }

                      // Completely hide text if it physically cannot fit inside the block width
                      if (blockWidth < 22.0) {
                        return const SizedBox.shrink();
                      }

                      return Text(
                          pitchLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: dynamicFontSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                            height: 1.0, // Flattens font bounding box lines perfectly top/bottom
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Changes visual theme accents depending on whether Left or Right hand plays the note
  Color _getHandColor(Hand hand) {
    if (hand == Hand.right) {
      return Colors.black;
    } else {
      return Colors.blue;
    }
  }
}