// import 'package:flutter/material.dart';
//
// import '../controllers/composition_controller.dart';
//
// class NoteCellWidget extends StatelessWidget {
//   final CompositionController controller;
//   final int tick;
//   final int row;
//
//   const NoteCellWidget({
//     super.key,
//     required this.controller,
//     required this.tick,
//     required this.row,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final note = controller.getNoteAt(tick, row);
//
//     return GestureDetector(
//       behavior: HitTestBehavior.opaque,
//
//       onTap: () {
//         final existing = controller.getNoteAt(tick, row);
//
//         if (existing == null) {
//           controller.addNote(
//             tick: tick,
//             row: row,
//           );
//         } else {
//           controller.removeNote(existing);
//         }
//       },
//
//       child: const SizedBox.expand(),
//     );
//   }
// }