import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../widgets/grid_widget.dart';

class CompositionScreen extends StatefulWidget {
  final CompositionController controller;

  const CompositionScreen({
    super.key,
    required this.controller,
  });

  @override
  State<CompositionScreen> createState() => _CompositionScreenState();
}

class _CompositionScreenState extends State<CompositionScreen> {
  @override
  void initState() {
    super.initState();

    // Listen to controller updates
    widget.controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.composition.title),

        actions: [
          // Zoom out
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              controller.setZoom(
                controller.zoomX - 0.1,
                controller.zoomY - 0.1,
              );
            },
          ),

          // Zoom in
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              controller.setZoom(
                controller.zoomX + 0.1,
                controller.zoomY + 0.1,
              );
            },
          ),

          // Reset zoom
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () {
              controller.setZoom(1.0, 1.0);
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // Zoom indicator (useful for debugging)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Text(
              "Zoom X: ${controller.zoomX.toStringAsFixed(1)}   "
                  "Zoom Y: ${controller.zoomY.toStringAsFixed(1)}",
            ),
          ),

          // GRID
          Expanded(
            child: GridWidget(controller: controller),
          ),
        ],
      ),
    );
  }
}