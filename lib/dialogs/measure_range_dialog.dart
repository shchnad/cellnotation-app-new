import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// Generic "from measure / to measure" range picker — used for
/// Duplicate Range, Delete Range, and Clean Range. [title] and
/// [actionLabel] customize the dialog's wording, [actionColor] tints
/// the confirm button (e.g. red for a destructive action), and
/// [onConfirm] is called with 0-based (fromIndex, toIndex) once a
/// valid range is entered.
void measureRangeDialog({
  required BuildContext context,
  required CompositionController controller,
  required String title,
  required String actionLabel,
  required Color actionColor,
  required void Function(int fromIndex, int toIndex) onConfirm,
}) {
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

        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'composition has in total $totalMeasures '
                  'measure${totalMeasures == 1 ? '' : 's'}.',
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'From Measure',
                      labelStyle: TextStyle(
                        fontSize: 22,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: toController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 22,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'To Measure',
                      labelStyle: TextStyle(
                        fontSize: 22,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          // const Divider(thickness: 1.0),
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

                  // Shown/entered as 1-based; callers work in 0-based
                  // indices and tolerate from/to being given in
                  // either order.
                  onConfirm(from! - 1, to! - 1);
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: actionColor,
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