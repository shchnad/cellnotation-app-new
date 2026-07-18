import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

import '../dialogs/cell_width_dialog.dart';
import '../dialogs/create_composition_dialog.dart';
import '../dialogs/global_duration_dialog.dart';
import '../dialogs/add_measures_dialog.dart';

import '../dialogs/message_dialog.dart';
import '../enums/hand.dart';

import '../widgets/grid_widget.dart';


class CompositionScreen extends StatelessWidget {

  final CompositionController controller;


  const CompositionScreen({
    super.key,
    required this.controller,
  });



  void _openAppendMeasuresForm(BuildContext context) {

    showDialog(
      context: context,
      builder: (context) => AddMeasuresDialog(
        targetComposition: controller.composition,
        controller: controller,
        onMeasuresAppended: () {},
      ),
    );

  }



  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateCompositionDialog(
        onCompositionCreated: (newComp) {
          controller.updateComposition(newComp);
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
          final hasMeasures =
              controller.composition.timeline.measures.isNotEmpty;
          return Row(
            children: [

              // =====================================================
              // TITLE COLUMN
              // =====================================================

              Container(
                width: 45,
                color: Colors.black,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      '${controller.composition.composer} - ${controller.composition.title}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),



              // =====================================================
              // LEFT TOOLBAR
              // =====================================================

              Container(
                width: 70,
                color: Colors.grey.shade300,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // HOME
                      IconButton(
                        icon: const Icon(
                          Icons.home,
                          color: Colors.black,
                        ),
                        tooltip: 'Home',
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),

                      // NEW COMPOSITION
                      IconButton(
                        icon: const Icon(
                          Icons.note_add,
                          color: Colors.black,
                        ),
                        tooltip: 'New Composition',
                        onPressed: () {
                          _showCreateDialog(context);
                        },
                      ),

                      // ADD MEASURES
                      IconButton(
                        icon: const Icon(
                          Icons.playlist_add,
                          color: Colors.black,
                        ),
                        tooltip: 'Add Measures',
                        onPressed: () {
                          _openAppendMeasuresForm(context);
                        },
                      ),

                      const Divider(
                        color: Colors.white24,
                      ),


                      // RAISE SCALE
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_upward,
                          color: Colors.black,
                        ),
                        tooltip: 'Raise scales',
                        onPressed:
                        controller.raiseAllScales,
                      ),


                      // LOWER SCALE
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_downward,
                          color: Colors.black,
                        ),
                        tooltip: 'Lower scales',
                        onPressed:
                        controller.lowerAllScales,
                      ),


                      // DURATION
                      IconButton(
                        icon: const Icon(
                          Icons.av_timer,
                          color: Colors.black,
                        ),
                        tooltip: 'Note Duration',
                        onPressed: () {
                          globalDurationDialog(
                            context,
                            controller,
                          );
                        },
                      ),


                      // HAND
                      IconButton(
                        icon: Icon(
                          Icons.pan_tool,
                          color:  controller.currentHand == Hand.right
                              ? Colors.black
                              : Colors.blue,
                        ),
                        tooltip: 'Hand',
                        onPressed:
                        controller.toggleHand,
                      ),


                      const Divider(
                        color: Colors.white24,
                      ),


                      // GRID SIZE
                      IconButton(
                        icon: const Icon(
                          Icons.grid_on,
                          color: Colors.black,
                        ),
                        tooltip: 'Cell Width',
                        onPressed: () {
                          cellWidthDialog(
                            context,
                            controller,
                          );
                        },
                      ),


                      // PASTE
                      if (controller.canPaste)
                        IconButton(
                          icon: Icon(
                            controller.pasteMode
                                ? Icons.copy
                                : Icons.content_paste,
                            color:
                            controller.pasteMode
                                ? Colors.blue
                                : Colors.black,
                          ),
                          tooltip: 'Paste',
                          onPressed: () {
                            if (controller.pasteMode) {
                              controller.exitPasteMode();
                              messageDialog(context, 'Paste mode is disable');
                            } else {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text(
                                    "Copying mode",
                                  ),
                                  content: const Text(
                                    "To copy: long-tap the note and clone it where ever you wish as many times as you wish.\n\n"
                                        "To leave copying mode, toggle this button.",
                                  ),

                                  actions: [

                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        "OK",
                                      ),
                                    ),

                                  ],

                                ),
                              );

                            }

                          },
                        ),


                      const Divider(
                        color: Colors.white24,
                      ),

                      // ZOOM IN
                      IconButton(
                        icon: const Icon(
                          Icons.zoom_in,
                          color: Colors.black,
                        ),
                        tooltip: 'Zoom In',
                        onPressed: () {
                          controller.setZoom(
                            controller.zoomX + 1,
                            controller.zoomY + 0.1,
                          );
                        },
                      ),


                      // ZOOM OUT
                      IconButton(
                        icon: const Icon(
                          Icons.zoom_out,
                          color: Colors.black,
                        ),
                        tooltip: 'Zoom Out',
                        onPressed: () {
                          controller.setZoom(
                            controller.zoomX - 1,
                            controller.zoomY - 0.1,
                          );
                        },
                      ),

                      // RESET
                      IconButton(
                        icon: const Icon(
                          Icons.center_focus_strong,
                          color: Colors.black,
                        ),
                        tooltip: 'Reset Zoom',
                        onPressed:
                        controller.resetZoom,
                      ),

                    ],

                  ),

                ),

              ),


              // =====================================================
              // GRID AREA
              // =====================================================

              Expanded(
                child: !hasMeasures
                    ? Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(
                      Icons.playlist_add,
                      size: 22,
                      // color: Colors.black,
                    ),
                    label: const Text(
                      'Add Measures',
                      style: TextStyle(
                        fontSize: 22,
                        // color: Colors.black,
                        // fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _openAppendMeasuresForm(context);
                    },
                  ),
                )
                    : SafeArea(
                  child: GridWidget(
                    controller: controller,
                    cellHeight: controller.getCellHeight(context),
                  ),
                ),
              ),

            ],

          );


        },

      ),

    );

  }

}