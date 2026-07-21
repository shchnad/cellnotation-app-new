import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../enums/tempo.dart';


void tempoDialog(
    BuildContext context,
    CompositionController controller,
    int tick,
    ) {

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
          ),
        ),


        content: SizedBox(
          width: 340,

          child: GridView.count(

            crossAxisCount: 3,
            shrinkWrap: true,

            mainAxisSpacing: 8,
            crossAxisSpacing: 8,

            children: Tempo.values.map(
                    (tempo){

                  return ElevatedButton(

                    style:
                    ElevatedButton.styleFrom(
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

                      style:
                      const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),

                  );

                }
            ).toList(),

          ),

        ),
      );
    },
  );
}