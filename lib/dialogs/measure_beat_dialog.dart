import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';


void showMeasureBeatDialog({
  required BuildContext context,
  required CompositionController controller,
  required int measureIndex,
  required int beatIndex,
}) {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
          // title: Center(
          //   child: Text(
          //     "Measure ${measureIndex + 1}   Beat ${beatIndex + 1}",
          //     style: const TextStyle(
          //       fontSize: 22,
          //       color: Colors.blue,
          //   ),
          //  ),
          // ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Measure actions

            Text(
              "Measure ${measureIndex + 1}",
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black,
                fontWeight: FontWeight.bold
              ),
            ),

            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text(
                "Insert Measure",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              onTap: () {
                // open measure input dialog
              },
            ),

            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text(
                "Delete Measure",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              onTap: () {
                controller.deleteMeasure(
                  measureIndex,
                );
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text(
                "Duplicate Measure",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              onTap: () {
                controller.copyMeasure(
                  measureIndex,
                );
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.music_video),
              title: const Text(
                "Tempo",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              onTap: () {
                // open tempo dialog
              },
            ),

            const Divider(),

            Text(
              "Beat ${beatIndex + 1}",
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Beat actions
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text(
                "Insert Beat",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              onTap: () {
                controller.addBeatToMeasure(
                  measureIndex,
                );
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.remove),
              title: const Text(
                "Delete Beat",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              onTap: () {
                controller.removeBeatFromMeasure(
                  measureIndex,
                  beatIndex,
                );
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text(
                "Duplicate Beat",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              onTap: () {
                controller.copyBeat(
                  measureIndex,
                  beatIndex,
                );
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text(
                "Dynamic",
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
              onTap: () {
                // open dynamic dialog here
              },
            ),

            const Divider(),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Close',
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

    },
  );

}