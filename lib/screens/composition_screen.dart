import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../enums/hand.dart';
import '../widgets/grid_widget.dart';

class CompositionScreen extends StatelessWidget {
  final CompositionController controller;

  const CompositionScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            children: [
              // =====================================================
              // LEFT TOOLBAR (APP BAR REPLACEMENT)
              // =====================================================
              Container(
                width: 70,
                color: Colors.grey.shade900,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // HAND TOGGLE
                    IconButton(
                      icon: Icon(
                        controller.currentHand == Hand.left
                            ? Icons.pan_tool
                            : Icons.back_hand,
                        color:  controller.currentHand == Hand.left
                        ? Colors.white
                        : Colors.blue,
                      ),
                      onPressed: controller.toggleHand,
                    ),

                    const Divider(color: Colors.white24),

                    // ZOOM IN
                    IconButton(
                      icon: const Icon(Icons.zoom_in, color: Colors.white),
                      onPressed: () {
                        controller.setZoom(
                          controller.zoomX + 0.1,
                          controller.zoomY + 0.1,
                        );
                      },
                    ),

                    // ZOOM OUT
                    IconButton(
                      icon: const Icon(Icons.zoom_out, color: Colors.white),
                      onPressed: () {
                        controller.setZoom(
                          controller.zoomX - 0.1,
                          controller.zoomY - 0.1,
                        );
                      },
                    ),

                    // RESET ZOOM
                    IconButton(
                      icon: const Icon(Icons.center_focus_strong,
                          color: Colors.white),
                      onPressed: controller.resetZoom,
                    ),

                    const Divider(color: Colors.white24),

                    // ZOOM INFO
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        "X:${controller.zoomX.toStringAsFixed(1)}\n"
                            "Y:${controller.zoomY.toStringAsFixed(1)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // =====================================================
              // MAIN GRID AREA
              // =====================================================
              Expanded(
                child: Container(
                  color: Colors.grey.shade100,
                  child: GridWidget(controller: controller),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}