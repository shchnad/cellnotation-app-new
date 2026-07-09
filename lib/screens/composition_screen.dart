import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
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

                    // GRID SCALING
                    IconButton(
                      icon: const Icon(Icons.grid_on, color: Colors.white),
                      onPressed: () {
                        showGridScaleDialog(context, controller);
                      },
                    ),

                    const Divider(color: Colors.white24),

                    // PASTE MODE - long tap on the note starts this mode,
                    // so the note is copied and can be paste everywhere,
                    // if do not wish to paste it any more, toggle this mode
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
                            // Turns off copy mode and reverts the icon back to white
                            controller.exitPasteMode();
                          } else {
                            // Shows your instruction alert if they tap it while empty
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


