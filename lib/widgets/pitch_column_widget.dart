import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../utils/default_values.dart';

/// A persistent column, meant to sit right next to the grid, listing the
/// pitch name of every row (top to bottom) for the current scale. It
/// scrolls vertically in lockstep with the grid via [scrollController],
/// but never scrolls on its own — dragging happens on the grid.
class PitchColumnWidget extends StatelessWidget {
  final CompositionController controller;
  final double cellHeight;
  final ScrollController scrollController;

  static const double widthOfPitchColumn = 15;

  const PitchColumnWidget({
    super.key,
    required this.controller,
    required this.cellHeight,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final totalRows = controller.totalRows;

    return Container(
      width: widthOfPitchColumn,
      // color: Colors.grey.shade200,
      // color: Colors.white,
      color: Colors.green.shade100,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children:
          List.generate(totalRows, (index) {
            final row = totalRows - 1 - index;
            final pitch = controller.getPitchNameForRow(row);
            return Container(
              height: cellHeight,
              // alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade400,
                    width: 0.5,
                  ),
                ),
              ),
              child: Text(
                pitch,
                style: TextStyle(
                  fontSize: cellHeight * 0.80,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}