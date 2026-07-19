import 'package:flutter/material.dart';
import 'package:music_composer/utils/default_values.dart';

void messageDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(thickness: 1.0),
            SizedBox(height: DefaultValues.heightBetweenWidgets),
            Text(
                message,
              style: const TextStyle(
                fontSize: 22,
                // fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'Close',
              style: TextStyle(
                fontSize: 22,
                // fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),

        ],
      );
    },
  );
}