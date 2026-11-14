import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../utils/scale_resolver.dart';
import 'measure_range_dialog.dart';
import 'scale_dialog.dart';

/// "Set Scale": for this measure, or for a range of measures (From/To,
/// then the scale) — like "Change Subdivision".
void setScaleDialog({
  required BuildContext context,
  required CompositionController controller,
  required int measureIndex,
}) {
  void chooseScale(int from, int to) {
    scaleDialog(
      context: context,
      controller: controller,
      currentScale: ScaleResolver.normalizeScaleName(
        controller.measures[from].scaleName,
      ),
      onSelected: (scale) =>
          controller.updateMeasureScaleRange(from, to, scale),
    );
  }

  const blue = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.blue,
  );

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Set Scale',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              ListTile(
                leading: const Icon(Icons.looks_one_outlined),
                title: const Text('This measure', style: blue),
                onTap: () {
                  Navigator.pop(dialogContext);
                  chooseScale(measureIndex, measureIndex);
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_column_outlined),
                title: const Text('Measure range', style: blue),
                onTap: () {
                  Navigator.pop(dialogContext);
                  measureRangeDialog(
                    context: context,
                    controller: controller,
                    title: 'Set Scale',
                    actionLabel: 'Next',
                    actionColor: Colors.blue,
                    // The range picker closes itself right AFTER this
                    // call — so the scale list opens once it has
                    // closed (otherwise it would be closed with it).
                    onConfirm: (from, to) => Future.delayed(
                      Duration.zero,
                          () {
                        if (context.mounted) chooseScale(from, to);
                      },
                    ),
                  );
                },
              ),
              const Divider(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Close',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      );
    },
  );
}