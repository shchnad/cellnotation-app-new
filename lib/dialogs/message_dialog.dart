import 'package:flutter/material.dart';

void messageDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text(
          'Message',
          style: TextStyle(fontSize: 22),
        ),
        content: Text(
            message,
            style: TextStyle(fontSize: 22),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'OK',
               style: TextStyle(fontSize: 22),
            ),
          ),

        ],
      );
    },
  );
}