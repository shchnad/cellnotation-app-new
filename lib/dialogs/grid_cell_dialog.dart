import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';

void showGridScaleDialog(
    BuildContext context,
    CompositionController controller,
    ) {
  double tempValue = controller.gridScale;

  showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Grid Size"),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    valueIndicatorTextStyle: const TextStyle(
                      fontSize: 22, // BIGGER NUMBER HERE
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Slider(
                    value: tempValue,
                    min: 0.125,
                    max: 10.0,
                    divisions: 7,
                    label: tempValue.toStringAsFixed(2),
                    onChanged: (value) {
                      setState(() {
                        tempValue = value;
                      });

                      controller.setGridScale(value);
                      controller.setZoom(
                        controller.zoomX,
                        controller.zoomY,
                      );
                    },
                  ),
                )
              ],
            ),

            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    tempValue = 1.0;
                  });
                  controller.setGridScale(1.0);
                  controller.setZoom(
                    controller.zoomX,
                    controller.zoomY,
                  );
                },
                child: const Text("Reset", style: TextStyle(fontSize: 22),),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close", style: TextStyle(fontSize: 22),),
              ),

            ],
          );
        },
      );
    },
  );
}