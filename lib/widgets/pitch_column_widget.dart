import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// A persistent column, meant to sit right next to the grid, listing the
/// pitch name of every row (top to bottom) for the current scale. It
/// scrolls vertically in lockstep with the grid via [scrollController],
/// but never scrolls on its own — dragging happens on the grid.
class PitchColumnWidget extends StatelessWidget {
  final CompositionController controller;
  final double cellHeight;
  final ScrollController scrollController;

  static const double width = 50;

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
      width: width,
      color: Colors.grey.shade200,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: List.generate(totalRows, (row) {
            final pitch = controller.getPitchNameForRow(row);
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