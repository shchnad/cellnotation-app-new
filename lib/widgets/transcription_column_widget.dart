import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../utils/cellnotation_transcription_parser.dart';

/// A persistent column, meant to sit right next to
/// [PitchColumnWidget] (between the toolbar and it), listing the
/// line-position TRANSCRIPTION code of every row (top to bottom) —
/// e.g. "0", "0/1", "-1/0" — the exact same notation
/// cellnotation_transcription_parser.dart reads and writes. It
/// scrolls vertically in lockstep with the grid via
/// [scrollController], but never scrolls on its own — dragging
/// happens on the grid, the same way [PitchColumnWidget] behaves.
///
/// When the CURRENT MEASURE's scale gives a row's degree its own
/// inherent alteration (the scale token ending in "+" or "-" — see
/// CompositionController.getPitchNameForRow), that sign is appended
/// directly to the position code — e.g. "0/1+" — matching how a
/// sharp/flat note is written in the transcription notation itself.
///
/// Wrapped in an AnimatedBuilder listening to [controller] for the
/// same reason as [PitchColumnWidget]: selecting a different measure
/// on the grid changes controller.currentMeasure's scale, which this
/// column's own accidental signs depend on.
class TranscriptionColumnWidget extends StatelessWidget {
  final CompositionController controller;
  final double cellHeight;
  final ScrollController scrollController;

  static const double widthOfTranscriptionColumn = 40;

  const TranscriptionColumnWidget({
    super.key,
    required this.controller,
    required this.cellHeight,
    required this.scrollController,
  });

  /// The scale's own inherent alteration sign for [row]'s degree, in
  /// the CURRENT measure — "+"/"-" if the scale token for that degree
  /// ends in one (see CompositionController.getPitchNameForRow,
  /// which already returns tokens like "1+"/"2-"), or "" for a
  /// natural degree. Reads the scale token directly rather than
  /// duplicating ScaleResolver's own logic.
  String _scaleAccidentalSignForRow(int row) {
    final token = controller.getPitchNameForRow(row);
    if (token.endsWith('+')) return '+';
    if (token.endsWith('-')) return '-';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final totalRows = controller.totalRows;

        return Container(
          width: widthOfTranscriptionColumn,
          // Matches PitchColumnWidget's own fixed white background —
          // this column sits right next to it and should read as
          // part of the same fixed strip, independent of the grid's
          // own dark-mode theme.
          color: Colors.white,
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: List.generate(totalRows, (index) {
                // Same "index 0 = highest row" convention as
                // PitchColumnWidget, so this column's rows always
                // line up with its own and with the grid's.
                final row = totalRows - 1 - index;
                final position = positionForRow(row);
                final accidentalSign = _scaleAccidentalSignForRow(row);
                final transcription = '$position$accidentalSign';
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
                  // PitchColumnWidget's own pitch text, so both
                  // columns turn together. Wrapped in a FittedBox
                  // (rather than a fixed cellHeight-based font size,
                  // like PitchColumnWidget uses) since a transcription
                  // code varies much more in length than a plain
                  // pitch label does — "0" versus "-1/0+" — so a
                  // single fixed multiplier would either overflow the
                  // longer codes or leave the shorter ones too small.
                  child: RotatedBox(
                    quarterTurns: controller.rotatePitchText ? 3 : 0,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        transcription,
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