import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../enums/note_duration.dart';

void showDurationDialog(
    BuildContext context,
    CompositionController controller,
    ) {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text("Select Duration"),
        content: SizedBox(
          width: 340,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: NoteDuration.values.map((d) {
              final selected = controller.currentDuration == d;

              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected ? Colors.blue : null,
                ),
                onPressed: () {
                  controller.setDuration(d);
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