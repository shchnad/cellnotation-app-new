import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// Red-pen marks drawn over the grid (above the notes).
///
/// Always paints the saved marks. While Pen mode is on
/// (CompositionController.penMode) it also takes the finger: one finger
/// draws a thin red line (or a dot on a tap), or — with the Eraser
/// selected — erases every mark it touches. While Pen mode is off it
/// ignores touches completely, so the grid works exactly as before.
///
/// Fills the grid's own content area (same size as GridPainter), so
/// local positions convert to grid coordinates directly:
/// tick = x / pixelsPerTick, row = y / cellHeight.
class InkLayer extends StatefulWidget {
  final CompositionController controller;
  final double pixelsPerTick;
  final double cellHeight;

  const InkLayer({
    super.key,
    required this.controller,
    required this.pixelsPerTick,
    required this.cellHeight,
  });

  @override
  State<InkLayer> createState() => _InkLayerState();
}

class _InkLayerState extends State<InkLayer> {
  /// The stroke being drawn right now, in grid points (tick, row).
  List<Offset>? _current;

  /// Only the first finger draws; extra fingers are ignored.
  int? _pointer;

  Offset _toGrid(Offset local) => Offset(
    local.dx / widget.pixelsPerTick,
    local.dy / widget.cellHeight,
  );

  void _erase(Offset local) {
    widget.controller.eraseInkAt(
      _toGrid(local),
      pixelsPerTick: widget.pixelsPerTick,
      cellHeight: widget.cellHeight,
    );
  }

  void _onDown(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    if (widget.controller.inkEraser) {
      _erase(e.localPosition);
    } else {
      setState(() => _current = [_toGrid(e.localPosition)]);
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (widget.controller.inkEraser) {
      _erase(e.localPosition);
      return;
    }
    final current = _current;
    if (current == null) return;
    // Skip points closer than 2 px to the last one — smoother line,
    // smaller saved file.
    final last = current.last;
    final lastPx = Offset(
      last.dx * widget.pixelsPerTick,
      last.dy * widget.cellHeight,
    );
    if ((e.localPosition - lastPx).distance < 2) return;
    setState(() => current.add(_toGrid(e.localPosition)));
  }

  void _onUp(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final current = _current;
    if (current != null) {
      _current = null;
      widget.controller.addInkStroke(current); // repaints via controller
    }
  }

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.infinite,
      painter: InkPainter(
        strokes: widget.controller.absoluteInkStrokes,
        current: _current,
        pixelsPerTick: widget.pixelsPerTick,
        cellHeight: widget.cellHeight,
      ),
    );

    if (!widget.controller.penMode) {
      return IgnorePointer(child: paint);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: paint,
    );
  }
}

class InkPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? current;
  final double pixelsPerTick;
  final double cellHeight;

  InkPainter({
    required this.strokes,
    required this.current,
    required this.pixelsPerTick,
    required this.cellHeight,
  });

  static const double strokeWidth = 3.0;
  static const Color inkColor = Color(0xFFE53935); // clear, bright red

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = inkColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final dot = Paint()
      ..color = inkColor
      ..style = PaintingStyle.fill;

    void drawStroke(List<Offset> gridPoints) {
      if (gridPoints.isEmpty) return;
      final pts = [
        for (final p in gridPoints)
          Offset(p.dx * pixelsPerTick, p.dy * cellHeight),
      ];
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, strokeWidth * 1.2, dot);
        return;
      }
      // Smooth curve through the midpoints of the finger samples.
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length - 1; i++) {
        final mid = Offset(
          (pts[i].dx + pts[i + 1].dx) / 2,
          (pts[i].dy + pts[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
      canvas.drawPath(path, line);
    }

    for (final s in strokes) {
      drawStroke(s);
    }
    final c = current;
    if (c != null) drawStroke(c);
  }

  @override
  bool shouldRepaint(covariant InkPainter old) => true;
}