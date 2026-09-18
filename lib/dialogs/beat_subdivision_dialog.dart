import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import 'measure_range_dialog.dart';

/// Lets the person change a measure's (or a range of measures')
/// "beat subdivision" in either direction — either doubling the beat
/// count while halving each beat's own duration (e.g. 3 beats of a
/// quarter note each becomes 6 beats of an eighth note each), or the
/// exact inverse: halving the beat count while doubling each beat's
/// own duration (e.g. 6 beats of an eighth note each becomes 3 beats
/// of a quarter note each) — only possible when the halved beat count
/// is a whole number, per request. Either direction is offered either
/// for just the CURRENT measure (the one this dialog was opened for)
/// or for an explicit measure range (reusing measureRangeDialog's own
/// from/to picker, the same pattern as Duplicate Range/Delete Range/
/// Clean Range).
///
/// Opened two ways: from a new "Change Subdivision" entry in
/// editMeasureBeatDialog's Measure column, or by tapping the time-
/// signature label at the bottom of the grid (see grid_widget.dart).
///
/// See CompositionController.doubleSubdivisionForMeasureRange /
/// halveSubdivisionForMeasureRange for what actually changes, why
/// nothing needs to shift in time to do either, and exactly when each
/// direction is possible.
void beatSubdivisionDialog({
  required BuildContext context,
  required CompositionController controller,
  required int measureIndex,
}) {
  void showWarnings(List<String> warnings) {
    if (warnings.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          warnings.join('\n'),
          style: const TextStyle(fontSize: 20),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void doubleAndReport(int from, int to) {
    showWarnings(controller.doubleSubdivisionForMeasureRange(from, to));
  }

  void halveAndReport(int from, int to) {
    showWarnings(controller.halveSubdivisionForMeasureRange(from, to));
  }

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Change Time Signature',
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

              const Text(
                'Split each beat to halves',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              // const Text(
              //   'Doubles the number of beats halving its duration',
              //   style: TextStyle(fontSize: 16),
              // ),
              ListTile(
                leading: const Icon(Icons.looks_one_outlined),
                title: const Text(
                  'This measure',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  doubleAndReport(measureIndex, measureIndex);
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_column_outlined),
                title: const Text(
                  'Measure range',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  measureRangeDialog(
                    context: context,
                    controller: controller,
                    title: 'Change Time Subdivision',
                    actionLabel: 'Apply',
                    actionColor: Colors.blue,
                    onConfirm: doubleAndReport,
                  );
                },
              ),

              const Divider(),

              const Text(
                'Unite every two beats to one',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              // const Text(
              //   'Halves the number of beats doubling its duration',
              //   style: TextStyle(fontSize: 16),
              // ),
              ListTile(
                leading: const Icon(Icons.looks_one_outlined),
                title: const Text(
                  'This measure',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  halveAndReport(measureIndex, measureIndex);
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_column_outlined),
                title: const Text(
                  'Measure range',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  measureRangeDialog(
                    context: context,
                    controller: controller,
                    title: 'Change Time Subdivision',
                    actionLabel: 'Apply',
                    actionColor: Colors.blue,
                    onConfirm: halveAndReport,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
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
        ],
      );
    },
  );
}