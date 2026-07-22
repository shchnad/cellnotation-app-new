import 'package:flutter/material.dart';

void saveExitDialog(
    BuildContext context, {
      required Future<void> Function() onSave,
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
            'Cancel',
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
            await onSave();
            if (context.mounted) {
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