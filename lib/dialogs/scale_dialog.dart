import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

void showScaleDialog(
    BuildContext context,
    CompositionController controller,
    ) {

  final majors = controller.availableScales
      .where((s) => s.contains('major'))
      .toList();

  final minors = controller.availableScales
      .where((s) => s.contains('minor'))
      .toList();

  Widget buildButtons(List<String> scales) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: scales.map((scale) {
        final originalIndex =
        controller.availableScales.indexOf(scale);

        final isSelected =
            controller.scaleName == scale;

        return SizedBox(
          width: 210,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor:
              isSelected ? Colors.blue : null,
              minimumSize: const Size(130, 48),
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              controller.setScale(originalIndex);
              Navigator.pop(context);
            },
            child: Text(
              scale,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text(
          'Select Scale',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
          ),
        ),
        content: SizedBox(
          width: 900,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              buildButtons(majors),

              const SizedBox(
                height: 30,
              ),

              buildButtons(minors),

            ],
          ),
        ),
      );
    },
  );
}