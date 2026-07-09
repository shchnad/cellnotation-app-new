import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final int totalTicks;
  final int ppqn; // Ticks per beat (Pulses Per Quarter Note)
  final int rows;
  final double pixelsPerBeat;
  final double cellHeight;
  final Set<int> barLines; // Set of bar indexes (Measure numbers)

  GridPainter({
    required this.totalTicks,
    required this.ppqn,
    required this.rows,
    required this.pixelsPerBeat,
    required this.cellHeight,
    required this.barLines,
  });

  // ================= HORIZONTAL HELPERS =================

  bool _isOctaveBoundary(int row) => row % 7 == 0;

  bool _isMiddleLine(int row) => row == (rows ~/ 2);

  @override
  void paint(Canvas canvas, Size size) {
    final double pixelsPerTick = pixelsPerBeat / ppqn;

    // ================= PAINTS =================

    final subdivisionLine = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;

    final beatLine = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 0.8;

    final barLine = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5;

    final octaveLine = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1.2;

    final middleLine = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5;

    // ================= VERTICAL LINES (DAW TIMING GRID) =================

    // FL Studio Default Subdivision: 16th notes (4 steps per beat)
    final int stepTicks = ppqn ~/ 4;
    final int ticksPerBar = ppqn * 4; // Assuming 4/4 time signature placeholder for grid drawing

    for (int tick = 0; tick <= totalTicks; tick += stepTicks) {
      final double x = tick * pixelsPerTick;
      if (x > size.width) break;

      Paint paint;

      if (tick % ticksPerBar == 0) {
        paint = barLine; // Major Measure boundary
      } else if (tick % ppqn == 0) {
        paint = beatLine; // Individual Quarter Note Beat
      } else {
        paint = subdivisionLine; // 16th Note Step
      }

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // ================= HORIZONTAL LINES (NOTES / OCTAVES) =================

    for (int row = 0; row <= rows; row++) {
      final double y = row * cellHeight;
      if (y > size.height) break;

      Paint paint;

      if (_isMiddleLine(row)) {
        paint = middleLine;
      } else if (_isOctaveBoundary(row)) {
        paint = octaveLine;
      } else {
        paint = subdivisionLine;
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
    return oldDelegate.pixelsPerBeat != pixelsPerBeat ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.totalTicks != totalTicks ||
        oldDelegate.ppqn != ppqn ||
        oldDelegate.rows != rows ||
        oldDelegate.barLines != barLines;
  }
}