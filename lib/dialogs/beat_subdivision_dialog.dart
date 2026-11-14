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
/// Opened two ways: from the "Edit Time Signature" entry in
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

  // Same buttons as noteValuesDialog: grey, black text.
  Widget button(String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade300,
        minimumSize: const Size(220, 55),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, color: Colors.black),
      ),
    ),
  );

  const headStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  showDialog(
    context: context,
    builder: (dialogContext) {
      void range(void Function(int, int) apply) {
        Navigator.pop(dialogContext);
        measureRangeDialog(
          context: context,
          controller: controller,
          title: 'Change Time Signature',
          actionLabel: 'Apply',
          actionColor: Colors.blue,
          onConfirm: apply,
        );
      }

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
        // Two columns: split each beat in two (left), unite every two
        // beats into one (right) — each for this measure or a range.
        content: SingleChildScrollView(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Split each beat\nto halves',
                      textAlign: TextAlign.center, style: headStyle),
                  const SizedBox(height: 6),
                  button('This measure', () {
                    Navigator.pop(dialogContext);
                    doubleAndReport(measureIndex, measureIndex);
                  }),
                  button('Measure range', () => range(doubleAndReport)),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unite every two\nbeats to one',
                      textAlign: TextAlign.center, style: headStyle),
                  const SizedBox(height: 6),
                  button('This measure', () {
                    Navigator.pop(dialogContext);
                    halveAndReport(measureIndex, measureIndex);
                  }),
                  button('Measure range', () => range(halveAndReport)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          const Divider(thickness: 1.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
          ),
        ],
      );
    },
  );
}