import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';


void cellWidthDialog(
    BuildContext context,
    CompositionController controller,
    ){

  showDialog(
    context: context,
    builder: (_) {

      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,

            title: const Text(
              "Cell Width",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Text(
                  "${controller.pixelsPerTick.toStringAsFixed(0)} px",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [

                    IconButton(
                      icon: const Icon(
                        Icons.remove,
                        size: 35,
                      ),
                      onPressed: (){
                        controller.changeCellWidth(-2);
                      },
                    ),

                    const SizedBox(width: 30),

                    IconButton(
                      icon: const Icon(
                        Icons.add,
                        size: 35,
                      ),
                      onPressed: (){
                        controller.changeCellWidth(2);
                      },
                    ),

                  ],
                ),

              ],
            ),

            actions: [

              TextButton(
                onPressed: (){
                  controller.setMinimumCellWidth();
                },
                child: const Text(
                  "Min",
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),


              TextButton(
                onPressed: (){
                  controller.resetCellWidth();
                },
                child: const Text(
                  "Reset",
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),


              TextButton(
                onPressed: (){
                  Navigator.pop(context);
                },
                child: const Text(
                  "Close",
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),

            ],

          );

        },
      );

    },
  );

}