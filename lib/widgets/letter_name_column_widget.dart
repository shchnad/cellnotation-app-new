import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// A persistent column, meant to sit next to
/// [TranscriptionColumnWidget] and [PitchColumnWidget], listing the
/// plain Western letter name + octave for every row (top to bottom)
/// — e.g. "C4", "A5" — with "#"/"b" appended when the CURRENT
/// MEASURE's scale gives that degree its own inherent sharp/flat
/// (matching how [TranscriptionColumnWidget] appends "+"/"-" for the
/// same reason, just in letter-name spelling instead of this app's
/// own solfège-degree signs).
///
/// Scrolls vertically in lockstep with the grid via
/// [scrollController], but never scrolls on its own — dragging
/// happens on the grid, the same way [PitchColumnWidget] and
/// [TranscriptionColumnWidget] behave.
///
/// Wrapped in an AnimatedBuilder listening to [controller] for the
/// same reason as those two: selecting a different measure changes
/// controller.currentMeasure's scale, which this column's own
/// accidental signs depend on.
class LetterNameColumnWidget extends StatelessWidget {
  final CompositionController controller;
  final double cellHeight;
  final ScrollController scrollController;

  static const double widthOfLetterNameColumn = 40;

  const LetterNameColumnWidget({
    super.key,
    required this.controller,
    required this.cellHeight,
    required this.scrollController,
  });

  // Degree (1-7) -> plain Western letter — matches
  // CompositionController.getDegreeLabel's own switch exactly (1=C
  // ... 7=B), just keyed by a bare degree int here since that method
  // itself takes a whole Note rather than a row/degree directly.
  static const Map<int, String> _letterForDegree = {
    1: 'C',
    2: 'D',
    3: 'E',
    4: 'F',
    5: 'G',
    6: 'A',
    7: 'B',
  };

  /// The scale's own inherent alteration for [row]'s degree, in the
  /// CURRENT measure, as a letter-name accidental symbol — "#" for a
  /// scale sign of "+", "b" for "-", or "" for a natural degree.
  /// Reads the scale token directly (see
  /// CompositionController.getPitchNameForRow, which already returns
  /// tokens like "1+"/"2-") rather than duplicating ScaleResolver's
  /// own logic — the exact same technique
  /// TranscriptionColumnWidget's own accidental lookup uses, just
  /// mapped to "#"/"b" instead of "+"/"-".
  String _letterAccidentalSignForRow(int row) {
    final token = controller.getPitchNameForRow(row);
    if (token.endsWith('+')) return '#';
    if (token.endsWith('-')) return 'b';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final totalRows = controller.totalRows;

        return Container(
          width: widthOfLetterNameColumn,
          // Matches PitchColumnWidget/TranscriptionColumnWidget's own
          // fixed white background — this column sits right next to
          // them and should read as part of the same fixed strip,
          // independent of the grid's own dark-mode theme.
          color: Colors.white,
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: List.generate(totalRows, (index) {
                // Same "index 0 = highest row" convention as the
                // other two columns, so all three always line up
                // with each other and with the grid.
                final row = totalRows - 1 - index;
                final degree = row % 7 + 1;
                final octave = row ~/ 7;
                final letter = _letterForDegree[degree] ?? '?';
                final accidentalSign = _letterAccidentalSignForRow(row);
                final letterName = '$letter$octave$accidentalSign';
                return Container(
                  height: cellHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade400,
                        width: 0.5,
                      ),
                    ),
                  ),
                  // Rotated the same way (and by the same toggle) as
                  // the other two columns' own text, so all three
                  // turn together. Wrapped in a FittedBox for the
                  // same reason as TranscriptionColumnWidget's own —
                  // a letter name with an accidental ("A5#") is
                  // longer than one without ("C4"), so a single fixed
                  // font-size multiplier would either overflow the
                  // longer ones or under-size the shorter ones.
                  child: RotatedBox(
                    quarterTurns: controller.rotatePitchText ? 3 : 0,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        letterName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}