import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// A persistent column, meant to sit right next to the grid, listing the
/// pitch name of every row (top to bottom) for the CURRENT MEASURE's
/// scale (controller.currentMeasure, via getPitchNameForRow). It scrolls
/// vertically in lockstep with the grid via [scrollController], but never
/// scrolls on its own — dragging happens on the grid.
///
/// Wrapped in an AnimatedBuilder listening to [controller] so that
/// tapping a different measure on the grid (which calls
/// controller.selectMeasureAtTick, changing controller.currentMeasure)
/// actually rebuilds this column to show that measure's scale, instead of
/// only ever showing whatever scale was current when this widget was
/// first built.
class PitchColumnWidget extends StatelessWidget {
  final CompositionController controller;
  final double cellHeight;
  final ScrollController scrollController;

  /// Rows whose note is currently sounding during playback — those
  /// rows highlight green.shade300 while active, reverting the
  /// instant the note's endTick is reached (see CompositionScreen's
  /// _onPlaybackTick, which owns and updates this every frame). A
  /// ValueNotifier rather than a plain Set so this column can rebuild
  /// on its own via ValueListenableBuilder below WITHOUT the rest of
  /// the screen needing a full setState() at animation-frame
  /// frequency during playback.
  final ValueNotifier<Set<int>> activeNoteRows;

  static const double widthOfPitchColumn = 25;

  const PitchColumnWidget({
    super.key,
    required this.controller,
    required this.cellHeight,
    required this.scrollController,
    required this.activeNoteRows,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final totalRows = controller.totalRows;

        return Container(
          width: widthOfPitchColumn,
          // Deliberately fixed, matching the toolbar's own fixed
          // Colors.grey.shade300 exactly — the toolbar itself never
          // changes with CompositionController.isDarkMode (dark mode
          // is scoped to just the grid/notes, per request), so this
          // column — which sits right against the toolbar — stays
          // fixed too, regardless of the grid's own theme.
          // color: Colors.grey.shade300,
          color: Colors.white,
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const NeverScrollableScrollPhysics(),
            child: ValueListenableBuilder<Set<int>>(
              valueListenable: activeNoteRows,
              builder: (context, activeRows, _) {
                return Column(
                  children:
                  List.generate(totalRows, (index) {
                    // Index 0 (top of the visible list) always shows
                    // the HIGHEST row, matching the grid's own "row 0
                    // = bottom" convention. Does NOT change with
                    // Rotate Pitch Text (that toggle only rotates the
                    // pitch digit itself — see the RotatedBox below —
                    // not the column's own row layout).
                    final row = totalRows - 1 - index;
                    // No measure argument passed — defaults to
                    // controller.currentMeasure, i.e. the scale of
                    // whichever measure was most recently tapped/
                    // selected on the grid (see CompositionController.
                    // selectMeasureAtTick).
                    final pitch = controller.getPitchNameForRow(row);
                    final isActive = activeRows.contains(row);
                    return Container(
                      height: cellHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.red : null,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade400,
                            width: 0.5,
                          ),
                        ),
                      ),
                      // Rotated the same way (and by the same toggle)
                      // as the pitch text inside note cells — flipped
                      // back to quarterTurns: 3, matching that file's
                      // own second attempt at this direction.
                      child: RotatedBox(
                        quarterTurns: controller.rotatePitchText ? 3 : 0,
                        child: Text(
                          pitch,
                          style: TextStyle(
                            fontSize: cellHeight * 0.80,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        );
      },
    );
  }
}