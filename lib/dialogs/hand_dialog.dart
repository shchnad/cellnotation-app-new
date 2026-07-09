// import 'package:flutter/material.dart';
//
// import '../controllers/composition_controller.dart';
// import '../models/note.dart';
// import '../enums/hand.dart';
//
//
// void showHandDialog(
//     BuildContext context,
//     Note note,
//     CompositionController controller,
//     ) {
//
//   showDialog(
//     context: context,
//     builder: (_) {
//       return AlertDialog(
//
//         title: const Text(
//           'Choose Hand',
//           style: TextStyle(fontSize: 22),
//         ),
//
//
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _button(
//               context,
//               'Right',
//               Hand.right,
//               note,
//               controller,
//             ),
//
//
//             _button(
//               context,
//               'Left',
//               Hand.left,
//               note,
//               controller,
//             ),
//
//           ],
//
//         ),
//
//       );
//
//     },
//
//   );
//
// }
//
//
//
//
// Widget _button(
//     BuildContext context,
//     String text,
//     Hand hand,
//     Note note,
//     CompositionController controller,
//     ) {
//
//
//   return SizedBox(
//
//     width: double.infinity,
//
//     child: ElevatedButton(
//
//       onPressed: () {
//
//
//         final updated =
//         note.copyWith(
//           hand: hand,
//         );
//
//
//         controller.replaceNote(
//           note,
//           updated,
//         );
//
//
//         Navigator.pop(context);
//
//
//       },
//
//
//       child: Text(
//         text,
//       ),
//
//     ),
//
//   );
//
// }