import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../enums/musical_dynamic.dart';
import '../models/dynamic_event.dart';


void dynamicDialog(
    BuildContext context,
    CompositionController controller,
    int tick,
    ) {

  showDialog(
    context: context,
    builder: (_) {

      final screen = MediaQuery.of(context).size;

      DynamicEvent? currentEvent;

      for (final event in controller.timeline.dynamicEvents) {
        if (event.tick == tick) {
          currentEvent = event;
          break;
        }
      }

      return AlertDialog(

        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        title: const Text(
          "Select Dynamic",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        content: SizedBox(
          width: screen.width * 0.75,

          child: GridView.count(
            // crossAxisCount: 3,
            // shrinkWrap: true,
            // mainAxisSpacing: 6,
            // crossAxisSpacing: 6,
            // childAspectRatio: 3.2,
            crossAxisCount: 3, // number of columns
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: MusicalDynamic.values.map(
                    (dynamic) {

                  final selected =
                      currentEvent?.musical_dynamic == dynamic;

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      minimumSize: const Size(0, 36),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      controller.updateDynamicEvent(
                        tick,
                        dynamic,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(
                      dynamic.abbreviation,
                      style: TextStyle(
                        fontSize: 22,
                        color: selected
                            ? Colors.blue
                            : Colors.black,
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
              // DELETE BUTTON
              TextButton(
                onPressed: currentEvent == null
                    ? null
                    : () {
                  controller.deleteDynamicEvent(
                    tick,
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

              // CANCEL BUTTON
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