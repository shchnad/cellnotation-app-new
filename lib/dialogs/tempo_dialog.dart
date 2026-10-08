import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../enums/tempo.dart';
import '../models/tempo_event.dart';


void tempoDialog(
    BuildContext context,
    CompositionController controller,
    int tick,
    ) {

  showDialog(
    context: context,
    builder: (_) {

      final screen = MediaQuery.of(context).size;

      // A tempo change placed exactly at this tick (only this one can
      // be deleted).
      TempoEvent? currentEvent;

      for(final event in controller.timeline.tempoEvents){
        if(event.tick == tick){
          currentEvent = event;
          break;
        }
      }

      // The tempo actually playing at this tick — the change placed
      // here, or else the latest one before it. Its button is shown
      // with blue, bold text.
      final Tempo? currentTempo =
          currentEvent?.tempo ?? controller.getActiveTempoAtTick(tick)?.tempo;


      return AlertDialog(

        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        title: const Text(
          "Select Tempo",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),


        content: SizedBox(
          width: screen.width * 0.75,
          // height: screen.height * 0.65,

          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 3.2,
            children: Tempo.values.map(
                    (tempo) {

                  final selected = currentTempo == tempo;


                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      minimumSize: const Size(0, 36),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      controller.updateTempoEvent(
                        tick,
                        tempo,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(
                      tempo.label,
                      style: TextStyle(
                        fontSize: 22,
                        color: selected
                            ? Colors.blue
                            : Colors.black,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),

                  );
                }
            ).toList(),

          ),
        ),


        actions: [
          const Divider(thickness: 1.0),
          // DELETE BUTTON
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: currentEvent == null
                    ? null
                    : () {
                  controller.deleteTempoEvent(
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