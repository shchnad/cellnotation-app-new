import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// Asks for a "from measure" / "to measure" range (1-based, as shown
/// to the person) and duplicates that whole inclusive range as one
/// new contiguous block appended at the end of the composition — see
/// CompositionController.duplicateMeasureRange.
void duplicateMeasuresDialog(
    BuildContext context,
    CompositionController controller,
    ) {
  final totalMeasures = controller.measures.length;
  if (totalMeasures == 0) return;

  final fromController = TextEditingController(text: '1');
  final toController = TextEditingController(text: '$totalMeasures');

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        title: const Text(
          "Duplicate Measures",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This composition has $totalMeasures '
                  'measure${totalMeasures == 1 ? '' : 's'}.',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22),
                    decoration: const InputDecoration(
                      labelText: 'From Measure',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: toController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22),
                    decoration: const InputDecoration(
                      labelText: 'To Measure',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          const Divider(thickness: 1.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final from = int.tryParse(fromController.text);
                  final to = int.tryParse(toController.text);
                  final valid = from != null &&
                      to != null &&
                      from >= 1 &&
                      from <= totalMeasures &&
                      to >= 1 &&
                      to <= totalMeasures;

                  if (!valid) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Enter measure numbers between 1 and $totalMeasures',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                    return;
                  }

                  // Shown/entered as 1-based; the controller works in
                  // 0-based indices and tolerates from/to being given
                  // in either order.
                  controller.duplicateMeasureRange(from! - 1, to! - 1);
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  "Duplicate",
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