import 'package:flutter/material.dart';
import 'package:music_composer/enums/note_duration.dart';
import '../controllers/composition_controller.dart';


void showGridScaleDialog(
    BuildContext context,
    CompositionController controller,
    ) {

  NoteDuration tempValue = controller.gridResolution;

  showDialog(
    context: context,
    builder: (_) {

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              "Grid Resolution",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Smallest grid cell",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                    NoteDuration.values.map(
                          (duration) {
                        final selected = duration == tempValue;
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            selected
                                ? Colors.blue
                                : Colors.grey.shade300,
                            foregroundColor: selected
                                ? Colors.white
                                : Colors.black,
                          ),
                          onPressed: () {
                            setState(() {
                              tempValue = duration;
                            });
                            controller.setGridResolution(duration,);
                          },
                          child: Text(
                            duration.label,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.setGridResolution(
                    NoteDuration.sixteenth,
                  );
                  Navigator.pop(context);
                },
                child: const Text(
                  "Reset",
                  style: TextStyle(
                    fontSize: 22,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context),
                child: const Text(
                  "Close",
                  style: TextStyle(
                    fontSize: 22,
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