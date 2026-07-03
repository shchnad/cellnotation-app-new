// import 'package:flutter/material.dart';
//
// import '../controllers/composition_controller.dart';
// import 'note_cell_widget.dart';
//
// class BeatWidget extends StatelessWidget {
//   final CompositionController controller;
//   final int beatIndex;
//   final double cellWidth;
//   final double cellHeight;
//
//   const BeatWidget({
//     super.key,
//     required this.controller,
//     required this.beatIndex,
//     required this.cellWidth,
//     required this.cellHeight,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final composition = controller.composition;
//     final rows = composition.numberOfOctaves * 7;
//
//     return Column(
//       children: List.generate(rows, (row) {
//         return NoteCellWidget(
//           controller: controller,
//           beatIndex: beatIndex,
//           row: row,
//           width: cellWidth,
//           height: cellHeight,
//         );
//       }),
//     );
//   }
// }