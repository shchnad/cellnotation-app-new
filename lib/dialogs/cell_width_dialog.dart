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

            title: Center(
              child: const Text(
                "Set Cell Width",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Text(
                  "${controller.pixelsPerTick.toStringAsFixed(0)} px",
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.blue,
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
                        color: Colors.blue,
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
                        color: Colors.blue,
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
              const Divider(thickness: 1.0),

              Row(
                children: [
                  TextButton(
                    onPressed: (){
                      controller.setMinimumCellWidth();
                    },
                    child: const Text(
                      "Min",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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
                        color: Colors.blue,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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
                        color: Colors.black,
                        fontSize: 22,
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

    },
  );

}