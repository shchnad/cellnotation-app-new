import 'package:flutter/material.dart';


void confirmDeleteCompositionDialog(
    BuildContext context, {
      required String title,
      required VoidCallback onDelete,
    }) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'Delete Composition?',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'This will permanently delete "$title". This cannot be undone.',
        style: const TextStyle(fontSize: 22),
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
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // close confirmation only
                onDelete();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}