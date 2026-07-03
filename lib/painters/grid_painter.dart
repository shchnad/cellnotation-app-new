import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final int beats;
  final int rows;
  final double cellWidth;
  final double cellHeight;

  GridPainter({
    required this.beats,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    final thick = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1.5;

    // Vertical beat lines
    for (int beat = 0; beat <= beats; beat++) {
      final x = beat * cellWidth;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        beat % 4 == 0 ? thick : thin,
      );
    }

    // Horizontal note lines
    for (int row = 0; row <= rows; row++) {
      final y = row * cellHeight;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        thin,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.beats != beats ||
        oldDelegate.rows != rows;
  }
}