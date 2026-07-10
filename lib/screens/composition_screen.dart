import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../dialogs/create_composition_dialog.dart';
import '../dialogs/duration_dialog.dart';
import '../dialogs/grid_cell_dialog.dart';
import '../dialogs/message_dialog.dart';
import '../enums/hand.dart';
import '../widgets/grid_widget.dart';
import '../dialogs/scale_dialog.dart';

class CompositionScreen extends StatelessWidget {
  final CompositionController controller;

  const CompositionScreen({
    super.key,
    required this.controller,
  });


  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => CreateCompositionDialog(
        controller: controller,
        onCompositionCreated: (newComposition) {
          controller.updateComposition(newComposition);
        },
      ),
    );
  }

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
                              content: const Text("Unsaved work will be lost."),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
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

                    // FIXED: Replaced the broken nested AppBar with a uniform dark-theme sidebar utility icon button
                    IconButton(
                      icon: const Icon(Icons.note_add, color: Colors.white),
                      tooltip: 'New Composition',
                      onPressed: () => _showCreateDialog(context),
                    ),

                    const SizedBox(height: 10),

                    // SCALE
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
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

                    // GRID SCALING
                    IconButton(
                      icon: const Icon(Icons.grid_on, color: Colors.white),
                      onPressed: () {
                        showGridScaleDialog(context, controller);
                      },
                    ),

                    const Divider(color: Colors.white24),

                    // PASTE MODE
                    if (controller.canPaste)
                      IconButton(
                        icon: Icon(
                          controller.pasteMode
                              ? Icons.copy
                              : Icons.content_paste,
                          color: controller.pasteMode ? Colors.blue : Colors.white,
                        ),
                        onPressed: () {
                          if (controller.pasteMode) {
                            controller.exitPasteMode();
                          } else {
                            showCopyPasteHelpDialog(
                              context,
                              'Long tap the note you want to copy, '
                                  'then paste it to where you wish. To stop copying tap this button.',
                            );
                          }
                        },
                      ),

                    const Divider(color: Colors.white24),

                    // ZOOM IN
                    IconButton(
                      icon: const Icon(Icons.zoom_in, color: Colors.white),
                      onPressed: () {
                        controller.setZoom(
                          controller.zoomX + 10.0, // Fixed math logic scaling step context variables
                          controller.zoomY + 0.1,
                        );
                      },
                    ),

                    // ZOOM OUT
                    IconButton(
                      icon: const Icon(Icons.zoom_out, color: Colors.white),
                      onPressed: () {
                        controller.setZoom(
                          controller.zoomX - 10.0,
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
                      "X:${controller.zoomX.toStringAsFixed(0)}\nY:${controller.zoomY.toStringAsFixed(1)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // ================= GRID CANVAS =================
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