import 'package:flutter/material.dart';

import '../enums/hand.dart';

/// Asks which hand's notes to clean: Right hand, Left hand,
/// Additional hand or All hands. Tapping a choice closes the dialog and
/// calls [onChosen] with the hands to clean — null for All hands (which
/// also removes the dynamics and pedal marks, as before).
///
/// Used by Clean Beat, Clean Measure and Clean Range in the
/// beat-and-measure dialog.
void cleanHandsDialog({
  required BuildContext context,
  required String title,
  required void Function(Set<Hand>? hands) onChosen,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      // Same buttons as noteValuesDialog: grey, black text.
      Widget button(String label, Set<Hand>? hands, {Color? color}) =>
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                minimumSize: const Size(260, 55),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                onChosen(hands);
              },
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, color: color ?? Colors.black),
              ),
            ),
          );

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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Which notes to clean?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, color: Colors.black),
              ),
              const SizedBox(height: 8),
              button('Right hand', {Hand.right}),
              button('Left hand', {Hand.left}),
              button('Additional hand', {Hand.additional}),
              button('All hands', null, color: Colors.red),
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