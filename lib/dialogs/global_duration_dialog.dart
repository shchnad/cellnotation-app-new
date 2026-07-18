import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../enums/note_duration.dart';


void globalDurationDialog(
    BuildContext context,
    CompositionController controller,
    ) {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
           'Select Duration',
           textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: SizedBox(
          width: 340,
          child: GridView.count(
            crossAxisCount: 3, // number of columns
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: NoteDuration.values.map((d) {
              final selected = controller.currentDuration == d;

              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  minimumSize: const Size(130, 48),
                  // shape: RoundedRectangleBorder(
                  //   borderRadius:
                  //   BorderRadius.circular(8),
                  // ),
                ),
                onPressed: () {
                  controller.setDuration(d);
                  Navigator.pop(context);
                },
                child: Text(
                  d.label,
                  style: TextStyle(
                    fontSize: 22,
                    // fontWeight: FontWeight.bold,
                    color: selected
                        ? Colors.blue
                        : Colors.black,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}