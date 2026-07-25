import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// Shown right before saving if any measure's scale has been
/// raised/lowered away from its original. Returns:
///  - `true`  → user chose to KEEP the changes (they become the new
///              baseline before saving)
///  - `false` → user chose to REVERT every drifted measure back to its
///              original scale before saving
///  - `null`  → user cancelled the save entirely
Future<bool?> scaleChangeWarningDialog({
  required BuildContext context,
  required CompositionController controller,
  required List<int> driftMeasureIndices,
}) {
  return showDialog<bool?>(
    context: context,
    builder: (_) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Scale Changed',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The scale was changed for the following measures. '
                      'Keep the change, or revert back to the original scale '
                      'before saving?',
                  style: TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 12),
                ...driftMeasureIndices.map((index) {
                  final delta = controller.semitoneDeltaForMeasure(index);
                  final direction = delta > 0 ? 'up' : 'down';
                  final amount = delta.abs();
                  final unit = amount == 1 ? 'semitone' : 'semitones';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Measure ${index + 1}: $amount $unit $direction',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          const Divider(thickness: 1.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Revert & Save',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Keep & Save',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}