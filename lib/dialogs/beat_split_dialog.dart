import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import 'measure_range_dialog.dart';

/// "Change to Triplet": splits a beat into 2–13 equal columns
/// (triplet = 3, quintuplet = 5…), for this beat only, for all beats of
/// this measure, or for all beats of a range of measures — or reverses
/// the split (one column again) for the same three choices. See
/// CompositionController.setBeatDivision.
void beatSplitDialog({
  required BuildContext context,
  required CompositionController controller,
  required int measureIndex,
  required int beatIndex,
}) {
  final current = controller.measures[measureIndex].beatDivisions[beatIndex];
  int columns = current ?? 3;

  void report(List<String> warnings) {
    if (warnings.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          warnings.join('\n'),
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }

  const titleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );
  const redStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.red,
  );
  const blueStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.blue,
  );

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Split beat into columns',
              textAlign: TextAlign.center,
              style: titleStyle,
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose number of columns:',
                      style: titleStyle,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (int n = 2; n <= 13; n++)
                          ChoiceChip(
                            label: Text(
                              '$n',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: n == columns ? Colors.white : Colors.black,
                              ),
                            ),
                            selected: n == columns,
                            selectedColor: Colors.blue,
                            backgroundColor: Colors.grey.shade200,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => columns = n),
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('Apply to:', style: titleStyle),
                    ListTile(
                      leading: const Icon(Icons.looks_one_outlined),
                      iconColor: Colors.blue,
                      title: const Text('This beat', style: blueStyle),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        final w = controller.setBeatDivision(
                            measureIndex, beatIndex, columns);
                        report([if (w != null) w]);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.view_week_outlined),
                      iconColor: Colors.blue,
                      title: const Text('All beats of this measure',
                          style: blueStyle),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        report(controller.setBeatDivisionForMeasureRange(
                            measureIndex, measureIndex, columns));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.view_column_outlined),
                      iconColor: Colors.blue,
                      title: const Text('All beats of a measure range',
                          style: blueStyle),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        final n = columns;
                        measureRangeDialog(
                          context: context,
                          controller: controller,
                          title: 'Change to Triplet ($n)',
                          actionLabel: 'Apply',
                          actionColor: Colors.blue,
                          onConfirm: (from, to) => report(controller
                              .setBeatDivisionForMeasureRange(from, to, n)),
                        );
                      },
                    ),
                    // REVERSE THE SPLIT — the beats become one column
                    // again (notes stay where they are).
                    const Divider(height: 24),
                    const Text('Reverse the split (one column):',
                        style: titleStyle),
                    ListTile(
                      leading: const Icon(Icons.looks_one_outlined),
                      iconColor: Colors.red,
                      title: const Text('This beat', style: redStyle),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        controller.setBeatDivision(measureIndex, beatIndex, 1);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.view_week_outlined),
                      iconColor: Colors.red,
                      title: const Text('All beats of this measure',
                          style: redStyle),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        controller.setBeatDivisionForMeasureRange(
                            measureIndex, measureIndex, 1);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.view_column_outlined),
                      iconColor: Colors.red,
                      title: const Text('All beats of a measure range',
                          style: redStyle),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        measureRangeDialog(
                          context: context,
                          controller: controller,
                          title: 'Reverse the split',
                          actionLabel: 'Reverse',
                          actionColor: Colors.red,
                          onConfirm: (from, to) => controller
                              .setBeatDivisionForMeasureRange(from, to, 1),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close', style: titleStyle),
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