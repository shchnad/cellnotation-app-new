import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final int totalTicks;
  final int ppqn; // Ticks per beat (Pulses Per Quarter Note)
  final int rows;
  final double pixelsPerBeat;
  final double cellHeight;
  final Set<int> barLines; // 💡 The actual set of starting ticks for each measure

  GridPainter({
    required this.totalTicks,
    required this.ppqn,
    required this.rows,
    required this.pixelsPerBeat,
    required this.cellHeight,
    required this.barLines,
  });

  bool _isOctaveBoundary(int row) => row % 7 == 0;
  bool _isMiddleLine(int row) => row == (rows ~/ 2);

  @override
  void paint(Canvas canvas, Size size) {
    // ================= 💡 FIX 1: FORCE WHITE BACKGROUND =================
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final double pixelsPerTick = pixelsPerBeat / ppqn;

    // ================= PAINTS =================
    final subdivisionLine = Paint()
      ..color = Colors.grey.shade300 // Slightly darkened so it stands out beautifully on white
      ..strokeWidth = 0.5;

    final beatLine = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 0.8;

    final barLine = Paint()
      ..color = Colors.grey.shade700 // Crisp dark line for measure boundaries
      ..strokeWidth = 1.8;

    final octaveLine = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1.2;

    final middleLine = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5;

    // ================= VERTICAL LINES (DYNAMIC MEASURE TIMING GRID) =================
    final int stepTicks = ppqn ~/ 4; // 16th note steps

    for (int tick = 0; tick <= totalTicks; tick += stepTicks) {
      final double x = tick * pixelsPerTick;
      if (x > size.width) break;

      Paint paint;

      // 💡 FIX 2: Check if this tick is an authentic measure boundary from your added measures
      if (barLines.contains(tick) || tick == 0 || tick == totalTicks) {
        paint = barLine; // Draws the real measure line dynamically!
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