import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../enums/tempo.dart';


void tempoDialog(
    BuildContext context,
    CompositionController controller,
    int tick,
    ) {

  final screenSize = MediaQuery.of(context).size;

  final dialogWidth = screenSize.width * 0.75;
  final dialogHeight = screenSize.height * 0.75;

  final canDelete = tick != 0;


  showDialog(
    context: context,
    builder: (_) {

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
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: Tempo.values.map(
                        (tempo) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(130, 48),
                          backgroundColor:
                          Colors.grey.shade300,
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

                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                          ),

                        ),

                      );

                    },
                  ).toList(),

                ),

              ),


              const SizedBox(height: 12),


              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: canDelete
                      ? () {
                    controller.deleteTempoEvent(
                      tick,
                    );
                    Navigator.pop(context);
                  }
                      : null,
                  child: Text(
                    "Delete Tempo",
                    style: TextStyle(
                      fontSize: 18,
                      color: canDelete
                          ? Colors.red
                          : Colors.grey,
                    ),
                  ),
                ),
              ),

            ],

          ),

        ),

      );

    },

  );
}