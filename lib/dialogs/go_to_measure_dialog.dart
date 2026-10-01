import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// A single "go to measure" number picker — used by the toolbar's
/// "Go to Measure" button (right under Scroll to Start) to let the
/// person jump the grid straight to any measure by number, rather
/// than scrolling there by hand. [onConfirm] is called with the
/// 0-based measure index once a valid measure number is entered.
/// Styled to match measure_range_dialog.dart's own look (same plain
/// Text label above a bare TextField, rather than a Material
/// labelText — see that file's own doc for why).
void goToMeasureDialog({
  required BuildContext context,
  required CompositionController controller,
  required void Function(int measureIndex) onConfirm,
}) {
  final totalMeasures = controller.measures.length;
  if (totalMeasures == 0) return;

  final measureController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        title: const Text(
          'Go to Measure',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Composition has in total $totalMeasures '
                  'measure${totalMeasures == 1 ? '' : 's'}.',
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Measure Number',
              style: TextStyle(
                fontSize: 22,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: measureController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),

        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
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
                onPressed: () {
                  final measureNumber = int.tryParse(measureController.text);
                  final valid = measureNumber != null &&
                      measureNumber >= 1 &&
                      measureNumber <= totalMeasures;

                  if (!valid) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Enter a measure number between 1 and $totalMeasures',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                    return;
                  }

                  // Shown/entered as 1-based; the caller works in
                  // 0-based indices, same convention as
                  // measureRangeDialog.
                  onConfirm(measureNumber! - 1);
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Go',
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