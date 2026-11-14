import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// A single "go to measure" number picker — used by the toolbar's
/// "Go to Measure" button (right under Scroll to Start) to let the
/// person jump the grid straight to any measure by number, rather
/// than scrolling there by hand. [onConfirm] is called with the
/// 0-based measure index (grid position) once a valid measure number
/// is entered.
///
/// The number typed is the measure number as shown on the grid (see
/// CompositionController.measureNumbers): in playback mode the
/// temporary reprise copies show the numbers of the measures they copy.
/// When that number occurs more than once (1st time, 2nd time…),
/// buttons let the person pick which time through to go to.
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

  final numbers = controller.measureNumbers();
  final highest = numbers.reduce((a, b) => a > b ? a : b);
  final hasRepeats = highest != totalMeasures;

  final measureController = TextEditingController();
  int timeThrough = 0; // which occurrence of the number (0 = 1st time)

  /// Grid positions showing [number], in order.
  List<int> occurrences(int? number) => [
    for (int i = 0; i < numbers.length; i++)
      if (numbers[i] == number) i
  ];

  String ordinal(int n) {
    const names = ['1st', '2nd', '3rd'];
    return n < names.length ? names[n] : '${n + 1}th';
  }

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final found = occurrences(int.tryParse(measureController.text));
          if (timeThrough >= found.length) timeThrough = 0;
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

            // A narrow dialog: the text wraps instead of stretching it
            // across the screen.
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasRepeats
                        ? 'Measures are numbered 1–$highest '
                        '($totalMeasures with the repeats played out — '
                        'the repeated ones have red numbers).'
                        : 'Composition has in total $totalMeasures '
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
                    onChanged: (_) => setState(() => timeThrough = 0),
                  ),
                  // The number is played more than once: which time?
                  if (found.length > 1) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (int k = 0; k < found.length; k++)
                          ChoiceChip(
                            label: Text(
                              '${ordinal(k)} time',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: k == timeThrough ? Colors.white : Colors.black,
                              ),
                            ),
                            selected: k == timeThrough,
                            selectedColor: Colors.blue,
                            backgroundColor: Colors.white,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => timeThrough = k),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
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
                      if (found.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Enter a measure number between 1 and $highest',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                        return;
                      }
                      // The caller works in 0-based grid positions, same
                      // convention as measureRangeDialog.
                      onConfirm(found[timeThrough]);
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
    },
  );
}