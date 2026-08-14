import 'package:flutter/material.dart';
import 'package:music_composer/enums/dynamic_change.dart';
import '../controllers/composition_controller.dart';
import '../enums/musical_dynamic.dart';
import '../models/dynamic_change_event.dart';
import '../models/dynamic_event.dart';


void dynamicChangeDialog(
    BuildContext context,
    CompositionController controller,
    int tick,
    ) {

  showDialog(
    context: context,
    builder: (_) {

      final screen = MediaQuery.of(context).size;

      DynamicChangeEvent? currentEvent;

      // Only ever considers a crescendo/diminuendo event at this tick
      // — a pedal event can independently exist at the exact same
      // tick (see CompositionController.updateDynamicChangeEvent's
      // doc) and must never be picked up here instead.
      for (final event in controller.timeline.dynamicChangeEvents) {
        if (event.tick == tick &&
            event.dynamic_change != DynamicChange.pedalDown &&
            event.dynamic_change != DynamicChange.pedalUp) {
          currentEvent = event;
          break;
        }
      }

      // Pedal marks (pedalDown/pedalUp) share this same enum/event
      // storage but are set exclusively via the single toggle button
      // in editMeasureBeatDialog (see
      // CompositionController.togglePedalAtTick) — they're excluded
      // here so there's exactly one way to set pedal, with no risk of
      // this dialog and that toggle disagreeing about the current
      // state.
      final pickableValues = DynamicChange.values
          .where((d) =>
      d != DynamicChange.pedalDown && d != DynamicChange.pedalUp)
          .toList();

      return AlertDialog(

        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        title: const Text(
          "Select Dynamic Change",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        content: SizedBox(
          width: 320,

          child: GridView.count(
            crossAxisCount: 2, // number of columns
            shrinkWrap: true,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2,
            children: pickableValues.map(
                    (dChange) {

                  final selected =
                      currentEvent?.dynamic_change == dChange;

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      minimumSize: const Size(0, 36),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      controller.updateDynamicChangeEvent(
                        tick,
                        dChange,
                      );
                      Navigator.pop(context);
                    },
                    child: SizedBox.expand(
                      child: Center(
                        child: Text(
                          dChange.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            color: selected
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                }
            ).toList(),
          ),
        ),

        actions: [

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              TextButton(
                onPressed: currentEvent == null
                    ? null
                    : () {
                  controller.deleteDynamicChangeEvent(
                    tick,
                    isPedal: false,
                  );
                  Navigator.pop(context);
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Close",
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}