import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

import '../dialogs/create_composition_dialog.dart';
import '../dialogs/duration_dialog.dart';
import '../dialogs/grid_cell_dialog.dart';
import '../dialogs/append_measures_dialog.dart';

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
      builder: (context) => AppendMeasuresDialog(
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

                      controller.composition.title,


                      overflow: TextOverflow.ellipsis,


                      style: const TextStyle(

                        color: Colors.white,

                        fontSize: 22,

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

                color: Colors.grey.shade900,


                child: SingleChildScrollView(

                  child: Column(

                    children: [


                      const SizedBox(height: 10),



                      // HOME

                      IconButton(

                        icon: const Icon(
                          Icons.home,
                          color: Colors.white,
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
                          color: Colors.white,
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
                          color: Colors.white,
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
                          color: Colors.white,
                        ),

                        tooltip: 'Raise scales',

                        onPressed:
                        controller.raiseAllScales,

                      ),




                      // LOWER SCALE

                      IconButton(

                        icon: const Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                        ),

                        tooltip: 'Lower scales',

                        onPressed:
                        controller.lowerAllScales,

                      ),





                      // DURATION

                      IconButton(

                        icon: const Icon(
                          Icons.av_timer,
                          color: Colors.white,
                        ),

                        tooltip: 'Note Duration',

                        onPressed: () {

                          showDurationDialog(
                            context,
                            controller,
                          );

                        },

                      ),





                      // HAND

                      IconButton(

                        icon: Icon(

                          controller.currentHand == Hand.left

                              ? Icons.pan_tool

                              : Icons.back_hand,


                          color: Colors.white,

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
                          color: Colors.white,
                        ),

                        tooltip: 'Grid Size',

                        onPressed: () {

                          showGridScaleDialog(
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

                                : Colors.white,

                          ),


                          tooltip: 'Paste',


                          onPressed: () {

                            controller.pasteMode

                                ? controller.exitPasteMode()

                                : controller.enterPasteMode();

                          },

                        ),






                      const Divider(
                        color: Colors.white24,
                      ),






                      // ZOOM IN

                      IconButton(

                        icon: const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
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
                          color: Colors.white,
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
                          color: Colors.white,
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

                    icon: const Icon(Icons.add),


                    label: const Text(
                      'Add First Measures',
                    ),


                    onPressed: () {

                      _openAppendMeasuresForm(context);

                    },

                  ),

                )


                    : SafeArea(

                  child: GridWidget(

                    controller: controller,


                    cellHeight:

                    controller.getCellHeight(context),

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