// import 'package:flutter/material.dart';
// import '../controllers/composition_controller.dart';
// import '../models/measure.dart';
// import '../enums/note_duration.dart';
//
// class GridPainter extends CustomPainter {
//   final int rowCount;
//   final double cellHeight;
//   final double pixelsPerTick;
//   final List<Measure> measures;
//
//   GridPainter({
//     required this.rowCount,
//     required this.cellHeight,
//     required this.pixelsPerTick,
//     required this.measures,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final Paint linePaint = Paint()..color = Colors.grey.withOpacity(0.3)..strokeWidth = 1.0;
//     final Paint barLinePaint = Paint()..color = Colors.black..strokeWidth = 2.0;
//
//     // 1. Draw Rows
//     for (int i = 0; i <= rowCount; i++) {
//       canvas.drawLine(Offset(0, i * cellHeight), Offset(size.width, i * cellHeight), linePaint);
//     }
//
//     // 2. Draw Bar Lines dynamically based on measures
//     for (var measure in measures) {
//       final double x = measure.startTick * pixelsPerTick;
//       canvas.drawLine(Offset(x, 0), Offset(x, size.height), barLinePaint);
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant GridPainter oldDelegate) => true;
// }