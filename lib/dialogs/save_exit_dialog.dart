import 'package:flutter/material.dart';

void saveExitDialog(
    BuildContext context, {
      required Future<bool> Function() onSave,
    }) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      // title: const Text(
      //   'Save Composition',
      //   style: TextStyle(
      //     fontSize: 22,
      //     color: Colors.black,
      //   ),
      // ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Save changes?',
            style: TextStyle(fontSize: 22),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text(
            'Close',
            style: TextStyle(
              fontSize: 22,
              color: Colors.black,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.pop(context);
          },
          child: const Text(
            "No",
            style: TextStyle(
              fontSize: 22,
              color: Colors.red,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            // Only leave the composition screen if the save actually
            // went through — onSave can return false (e.g. the person
            // cancelled a confirmation prompt partway through), in
            // which case we stay put instead of silently discarding
            // that cancellation.
            final proceeded = await onSave();
            if (context.mounted && proceeded) {
              Navigator.pop(context);
            }
          },
          child: const Text(
            'Yes',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    ),
  );
}