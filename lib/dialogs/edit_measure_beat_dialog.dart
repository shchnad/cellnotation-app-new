import 'package:flutter/material.dart';
import 'package:music_composer/dialogs/tempo_dialog.dart';

import '../controllers/composition_controller.dart';
import 'dynamic_change_dialog.dart';
import 'dynamic_dialog.dart';


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

        content: SizedBox(
          // width: MediaQuery.of(context).size.width * 0.75,
          // height: MediaQuery.of(context).size.height * 0.55,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // LEFT COLUMN
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
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
                        leading: const Icon(Icons.delete_outline),
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

                      const Divider(),

                      ListTile(
                        leading: const Icon(Icons.lock_clock),
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

                    ],
                  ),
                ),
              ),

              const VerticalDivider(thickness: 1),

              // RIGHT COLUMN
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
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
                        leading: const Icon(Icons.trending_up),
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


                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // actionsPadding: const EdgeInsets.fromLTRB(
        // DefaultValues.dialogPaddingRightLeft,
        // DefaultValues.dialogPaddingBottomTop,
        // DefaultValues.dialogPaddingRightLeft,
        // DefaultValues.dialogPaddingBottomTop,
        // ),
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