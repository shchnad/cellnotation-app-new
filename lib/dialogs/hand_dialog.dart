import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../enums/hand.dart';
import '../models/note.dart';

/// Lets the person choose which hand to use — Left, Right, or
/// Additional (green) — styled to match noteValuesDialog's grid-of-
/// buttons picker (see note_values_dialog.dart) exactly: grey
/// ElevatedButtons sized to their own label text, laid out with Wrap,
/// same dialog chrome/actions row, per request — rather than the
/// earlier bespoke icon+label Row/Column layout.
///
/// Serves two callers:
/// - The toolbar's "Hand" button (composition_screen.dart), with
///   [note] left null — picks set
///   [CompositionController.currentHand] via
///   [CompositionController.setCurrentHand], the hand newly created
///   notes will use.
/// - NoteDialog's own "Hand" field, with [note] set to the note being
///   edited — picks set THAT note's hand via
///   [CompositionController.setNoteHand] instead, and this dialog
///   also closes NoteDialog itself on selection, matching every
///   other field's picker there (Accidental/Duration/Finger/etc, via
///   noteValuesDialog's own allowToCloseNextWindow).
///
/// Exactly 2 columns' worth of button width is reserved regardless of
/// how many hands exist — with exactly 3 choices, this naturally
/// wraps Left+Right onto the first row and Additional alone onto a
/// second row below, per request, the same way noteValuesDialog's own
/// Wrap overflows extra buttons onto further rows.
void handDialog({
  required BuildContext context,
  required CompositionController controller,
  Note? note,
}) {
  const fontSize = 22.0;
  const spacing = 8.0;
  const numberOfColumns = 2;
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isLandscape = screenWidth >= screenHeight;
  final buttonHeight = isLandscape ? 40.0 : 55.0;

  double textWidth(String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  final maxWidth = Hand.values
      .map((h) => textWidth(h.name))
      .reduce((a, b) => a > b ? a : b);
  final buttonWidth = maxWidth + 40;

  final desiredContentWidth =
      buttonWidth * numberOfColumns + spacing * (numberOfColumns - 1);
  final dialogWidth =
  (desiredContentWidth + 48.0).clamp(0.0, screenWidth * 0.9);

  final currentHand = note?.hand ?? controller.currentHand;

  final buttons = Hand.values.map((hand) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade300,
        minimumSize: Size(buttonWidth, buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () {
        if (note != null) {
          controller.setNoteHand(note, hand);
        } else {
          controller.setCurrentHand(hand);
        }
        Navigator.pop(context);
        // Also closes NoteDialog itself when editing a specific
        // note's hand, matching every other field's picker in that
        // dialog (see the doc comment above) — with no note (the
        // toolbar caller), there's no parent dialog to close.
        if (note != null) Navigator.pop(context);
      },
      child: Text(
        hand.name,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: hand == currentHand ? Colors.blue : Colors.black,
          fontSize: fontSize,
        ),
      ),
    );
  }).toList();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'Hand',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.6),
          child: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing,
              runSpacing: spacing,
              children: buttons,
            ),
          ),
        ),
      ),
      actions: [
        const Divider(thickness: 1.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}