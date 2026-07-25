import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// Shown right before saving if any measure's scale has been
/// raised/lowered away from its original. Since raiseAllScales/
/// lowerAllScales always move every measure by the same amount in the
/// same direction, all drifted measures share the same delta — so this
/// just reports one summary figure instead of listing each measure.
/// Returns:
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
  // All drifted measures should carry the same delta (see class doc
  // above) — the first one is representative.
  final delta = driftMeasureIndices.isEmpty
      ? 0
      : controller.semitoneDeltaForMeasure(driftMeasureIndices.first);
  final direction = delta > 0 ? 'up' : 'down';
  final amount = delta.abs();
  final unit = amount == 1 ? 'semitone' : 'semitones';

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
          child: Text(
            'The initial scale was changed by $amount $unit $direction. '
                'Keep the change, or revert back to the original scale '
                'before saving?',
            style: const TextStyle(fontSize: 22, color: Colors.black),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Revert and Save',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Keep and Save',
                  style: TextStyle(
                    fontSize: 22,
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