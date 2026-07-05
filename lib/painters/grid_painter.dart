import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final int beats;
  final int rows;
  final double cellWidth;
  final double cellHeight;

  final Set<int> barLines;

  GridPainter({
    required this.beats,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.barLines,
  });

  // ================= VERTICAL HELPERS =================

  bool _isBarLine(int beat) => barLines.contains(beat);

  // ================= HORIZONTAL HELPERS =================

  bool _isOctaveBoundary(int row) => row % 7 == 0;

  bool _isMiddleLine(int row) => row == (rows ~/ 2);

  @override
  void paint(Canvas canvas, Size size) {

    // ================= PAINTS =================

    final thin = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    final beatLine = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 0.8;

    final barLine = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5;

    final octaveLine = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.2;

    final middleLine = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5;

    // ================= VERTICAL LINES (BEATS) =================

    for (int beat = 0; beat <= beats; beat++) {
      final x = beat * cellWidth;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        _isBarLine(beat) ? barLine : beatLine,
      );
    }

    // ================= HORIZONTAL LINES (NOTES / OCTAVES) =================

    for (int row = 0; row <= rows; row++) {
      final y = row * cellHeight;

      Paint paint;

      if (_isMiddleLine(row)) {
        paint = middleLine;
      } else if (_isOctaveBoundary(row)) {
        paint = octaveLine;
      } else {
        paint = thin;
      }

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
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