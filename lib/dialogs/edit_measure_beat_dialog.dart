import 'package:flutter/material.dart';
import 'package:music_composer/dialogs/tempo_dialog.dart';

import '../controllers/composition_controller.dart';
import '../utils/scale_resolver.dart';
import 'dynamic_change_dialog.dart';
import 'dynamic_dialog.dart';
import 'measure_range_dialog.dart';
import 'pedal_dialog.dart';
import 'scale_dialog.dart';


void editMeasureBeatDialog({
  required BuildContext context,
  required CompositionController controller,
  required int measureIndex,
  required int beatIndex,
}) {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        // No fixed height and no SingleChildScrollView around either
        // column below (unlike before) — every action must be
        // visible without scrolling, so both columns are just left to
        // size naturally to their own content (via
        // mainAxisSize: MainAxisSize.min) instead of being squeezed
        // into a fixed fraction of the screen height. The ListTile
        // Theme override below keeps each row compact so everything
        // still comfortably fits on a normal screen even with the
        // extra Delete Range / Clean Range actions.
        content: Theme(
          data: Theme.of(context).copyWith(
            listTileTheme: const ListTileThemeData(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.75,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // LEFT COLUMN
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      Text(
                        "Measure ${measureIndex + 1}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      ListTile(
                        leading: const Icon(Icons.playlist_add),
                        title: const Text(
                          "Insert Measure",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          final measure = controller.measures[measureIndex];
                          controller.insertMeasureAt(
                            measureIndex,
                            measure.timeSignature,
                            measure.scaleName,
                          );
                          Navigator.pop(context);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.copy),
                        title: const Text(
                          "Duplicate Measure",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          controller.copyMeasure(measureIndex);
                          Navigator.pop(context);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.library_books_outlined),
                        title: const Text(
                          "Duplicate Range",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          measureRangeDialog(
                            context: context,
                            controller: controller,
                            title: 'Duplicate Measures',
                            actionLabel: 'Duplicate',
                            actionColor: Colors.blue,
                            onConfirm: (from, to) {
                              controller.duplicateMeasureRange(from, to);
                            },
                          );
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.cleaning_services_outlined),
                        title: const Text(
                          "Clean Measure",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          controller.clearMeasureNotes(measureIndex);
                          Navigator.pop(context);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.cleaning_services),
                        title: const Text(
                          "Clean Range",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          measureRangeDialog(
                            context: context,
                            controller: controller,
                            title: 'Clean Measures',
                            actionLabel: 'Clean',
                            actionColor: Colors.black,
                            onConfirm: (from, to) {
                              controller.clearMeasureRangeNotes(from, to);
                            },
                          );
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        iconColor: Colors.red,
                        title: const Text(
                          "Delete Measure",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          controller.deleteMeasure(measureIndex);
                          Navigator.pop(context);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.delete_sweep_outlined),
                        iconColor: Colors.red,
                        title: const Text(
                          "Delete Range",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          measureRangeDialog(
                            context: context,
                            controller: controller,
                            title: 'Delete Measures',
                            actionLabel: 'Delete',
                            actionColor: Colors.red,
                            onConfirm: (from, to) {
                              controller.deleteMeasureRange(from, to);
                            },
                          );
                        },
                      ),

                      const Divider(),

                      ListTile(
                        leading: const Icon(Icons.lock_clock),
                        iconColor: Colors.blue,
                        title: const Text(
                          "Set Tempo",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          tempoDialog(
                            context,
                            controller,
                            controller.getBeatTick(
                              measureIndex,
                              beatIndex,
                            ),
                          );
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.music_note),
                        iconColor: Colors.blue,
                        title: const Text(
                          "Set Scale",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          scaleDialog(
                            context: context,
                            controller: controller,
                            currentScale: ScaleResolver.normalizeScaleName(
                              controller.measures[measureIndex].scaleName,
                            ),
                            onSelected: (scale) {
                              controller.updateMeasureScale(
                                measureIndex,
                                scale,
                              );
                            },
                          );
                        },
                      ),

                    ],
                  ),
                ),

                const VerticalDivider(thickness: 1),

                // RIGHT COLUMN
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      Text(
                        "Beat ${beatIndex + 1}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      ListTile(
                        leading: const Icon(Icons.playlist_add),
                        title: const Text(
                          "Insert Beat",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          controller.addBeatToMeasure(measureIndex);
                          Navigator.pop(context);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.copy),
                        title: const Text(
                          "Duplicate Beat",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          controller.copyBeat(measureIndex, beatIndex);
                          Navigator.pop(context);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.cleaning_services_outlined),
                        title: const Text(
                          "Clean Beat",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          controller.clearBeatNotes(measureIndex, beatIndex);
                          Navigator.pop(context);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        iconColor: Colors.red,
                        title: const Text(
                          "Delete Beat",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          controller.removeBeatFromMeasure(
                            measureIndex,
                            beatIndex,
                          );
                          Navigator.pop(context);
                        },
                      ),


                      const Divider(),

                      ListTile(
                        leading: const Icon(Icons.campaign_outlined),
                        iconColor: Colors.green,
                        title: const Text(
                          "Set Dynamic",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          dynamicDialog(
                            context,
                            controller,
                            controller.getBeatTick(
                              measureIndex,
                              beatIndex,
                            ),
                          );
                        },
                      ),


                      ListTile(
                        leading: const Icon(Icons.bar_chart_outlined),
                        iconColor: Colors.green,
                        title: const Text(
                          "Set Dynamic Change",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          dynamicChangeDialog(
                            context,
                            controller,
                            controller.getBeatTick(
                              measureIndex,
                              beatIndex,
                            ),
                          );
                        },
                      ),

                      // PEDAL — same pattern as "Set Dynamic Change"
                      // above: opens a dedicated grid-of-options
                      // dialog (pedalDialog) with Delete/Close
                      // actions, rather than toggling in place.
                      ListTile(
                        leading: const Icon(Icons.arrow_circle_down),
                        iconColor: Colors.green,
                        title: const Text(
                          "Set Pedal",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          pedalDialog(
                            context,
                            controller,
                            controller.getBeatTick(
                              measureIndex,
                              beatIndex,
                            ),
                          );
                        },
                      ),


                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        actions: [
          const Divider(thickness: 1.0),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      );

    },
  );

}