import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../dialogs/duration_dialog.dart';
import '../enums/hand.dart';
import '../widgets/grid_widget.dart';

// ================= SCALE DIALOG =================

void showScaleDialog(
    BuildContext context,
    CompositionController controller,
    ) {
  final majors = controller.availableScales
      .where((s) => s.contains('major'))
      .toList();

  final minors = controller.availableScales
      .where((s) => s.contains('minor'))
      .toList();

  Widget buildButtons(List<String> scales) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: scales.map((scale) {
        final originalIndex =
        controller.availableScales.indexOf(scale);

        final isSelected =
            controller.scaleName == scale;

        return SizedBox(
          width: 210,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor:
              isSelected ? Colors.blue : null,
            ),
            onPressed: () {
              controller.setScale(originalIndex);
              Navigator.pop(context);
            },
            child: Text(
              scale,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text(
          "Select Scale",
          style: TextStyle(fontSize: 28),
        ),
        content: SizedBox(
          width: 900,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildButtons(majors),

              const SizedBox(height: 30),

              buildButtons(minors),
            ],
          ),
        ),
      );
    },
  );
}

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
              // ================= TOOLBAR =================
              Container(
                width: 70,
                color: Colors.grey.shade900,
                child: Column(
                  children: [

                    const SizedBox(height: 20),

                    // HOME
                    IconButton(
                      icon: const Icon(Icons.home, color: Colors.white),
                      onPressed: () {
                        if (controller.notes.isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Exit?"),
                              content: const Text(
                                  "Unsaved work will be lost."),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.popUntil(
                                      context,
                                          (r) => r.isFirst,
                                    );
                                  },
                                  child: const Text("Exit"),
                                ),
                              ],
                            ),
                          );
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),

                    const SizedBox(height: 10),

                    // SCALE
                    IconButton(
                      icon: const Icon(Icons.tune,
                          color: Colors.white),
                      onPressed: () {
                        showScaleDialog(context, controller);
                      },
                    ),

                    const SizedBox(height: 10),

                    // DURATION CHOICE
                    IconButton(
                      icon: const Icon(Icons.av_timer, color: Colors.white),
                      onPressed: () {
                        showDurationDialog(context, controller);
                      },
                    ),

                    const SizedBox(height: 10),

                    // HAND
                    IconButton(
                      icon: Icon(
                        controller.currentHand == Hand.left
                            ? Icons.pan_tool
                            : Icons.back_hand,
                        color: controller.currentHand == Hand.left
                            ? Colors.blue
                            : Colors.white,
                      ),
                      onPressed: controller.toggleHand,
                    ),

                    const Divider(color: Colors.white24),

                    // ZOOM IN
                    IconButton(
                      icon: const Icon(Icons.zoom_in,
                          color: Colors.white),
                      onPressed: () {
                        controller.setZoom(
                          controller.zoomX + 0.1,
                          controller.zoomY + 0.1,
                        );
                      },
                    ),

                    // ZOOM OUT
                    IconButton(
                      icon: const Icon(Icons.zoom_out,
                          color: Colors.white),
                      onPressed: () {
                        controller.setZoom(
                          controller.zoomX - 0.1,
                          controller.zoomY - 0.1,
                        );
                      },
                    ),

                    // RESET
                    IconButton(
                      icon: const Icon(
                        Icons.center_focus_strong,
                        color: Colors.white,
                      ),
                      onPressed: controller.resetZoom,
                    ),

                    const Divider(color: Colors.white24),

                    Text(
                      "X:${controller.zoomX.toStringAsFixed(1)}\n"
                          "Y:${controller.zoomY.toStringAsFixed(1)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // ================= GRID =================
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