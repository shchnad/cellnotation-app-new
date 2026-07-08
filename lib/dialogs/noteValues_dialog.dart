import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../enums/note_duration.dart';

void noteValuesDialog(
    BuildContext context,
    controllerCurrentValue, // controller.currentDuration
    controllerFunction,
    String titleOfDialog,
    valuesList // NoteDuration.values
    ) {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: Text(
          titleOfDialog,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 22),
        ),
        content: SizedBox(
          width: 340,
          child: GridView.count(
            crossAxisCount: 3, // number of columns
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: valuesList.map((d) {
              final selected = controllerCurrentValue == d;

              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected ? Colors.blue : null,
                  minimumSize: const Size(130, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  controllerFunction(d);
                  Navigator.pop(context);
                },
                child: Text(
                  d.label,
                  style: const TextStyle(fontSize: 22),
                ),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}