import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final int totalTicks;
  final int ppqn;
  final int rows;
  final double pixelsPerBeat;
  final double cellHeight;
  final Set<int> barLines;
  final List<dynamic> measures; //actual measures list to read dynamic signatures
  final List<String> currentScale; // active scale to calculate horizontal styling

  GridPainter({
    required this.totalTicks,
    required this.ppqn,
    required this.rows,
    required this.pixelsPerBeat,
    required this.cellHeight,
    required this.barLines,
    required this.measures,
    required this.currentScale,
  });

  bool _isOctaveBoundary(int row) => row % 7 == 0;
  bool _isMiddleLine(int row) => row == (rows ~/ 2);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Force White Canvas Background
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final double pixelsPerTick = pixelsPerBeat / ppqn;

    // ================= PAINTS =================
    final subdivisionLine = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;

    final beatLine = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 0.9;

    final barLine = Paint()
      ..color = Colors.grey.shade800 // Bold line separating distinct measures
      ..strokeWidth = 2.0;

    final octaveLine = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.2;

    final middleLine = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5;

    // ================= DYNAMIC VERTICAL MEASURE LINES =================
    int currentStartTick = 0;

    for (int i = 0; i < measures.length; i++) {
      final measure = measures[i];
      final timeSig = measure.timeSignature;

      // Calculate exactly how many ticks this specific measure contains
      final int beatsInMeasure = timeSig.beats;
      final int ticksPerBeat = timeSig.ticksPerBeat;
      final int totalMeasureTicks = beatsInMeasure * ticksPerBeat;
      final int stepTicks = ticksPerBeat ~/ 4; // 16th note subdivisions

      // A. Draw the Left Boundary of this Measure
      final double startX = currentStartTick * pixelsPerTick;
      if (startX <= size.width) {
        canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), barLine);
      }

      // B. Subdivide the interior of THIS measure based on ITS specific time signature
      for (int mTick = 0; mTick < totalMeasureTicks; mTick += stepTicks) {
        // Skip 0 because the main major barline is already drawn at startX
        if (mTick == 0) continue;

        final int absoluteTick = currentStartTick + mTick;
        final double x = absoluteTick * pixelsPerTick;
        if (x > size.width) break;

        // Determine if this internal tick lands squarely on a beat or a sub-step
        if (mTick % ticksPerBeat == 0) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), beatLine);
        } else {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), subdivisionLine);
        }
      }

      // Move the pointer forward by the exact tick calculation of this specific signature
      currentStartTick += totalMeasureTicks;
    }

    // Draw the final closing timeline boundary edge line
    final double finalX = currentStartTick * pixelsPerTick;
    if (finalX <= size.width) {
      canvas.drawLine(Offset(finalX, 0), Offset(finalX, size.height), barLine);
    }

    // ================= HORIZONTAL LINES (SCALE MAPPING) =================
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

      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.pixelsPerBeat != pixelsPerBeat ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.totalTicks != totalTicks ||
        oldDelegate.ppqn != ppqn ||
        oldDelegate.rows != rows ||
        oldDelegate.barLines != barLines ||
        oldDelegate.measures != measures ||
        oldDelegate.currentScale != currentScale;
  }
}