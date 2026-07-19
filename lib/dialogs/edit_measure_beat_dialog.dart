import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../utils/default_values.dart';


void editMeasureBeatDialog({
  required BuildContext context,
  required CompositionController controller,
  required int measureIndex,
  required int beatIndex,
}) {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
              leading: const Icon(Icons.lock_clock),
              title: const Text(
                "Tempo",
                style: TextStyle(
                  fontSize: 22,
                  // fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              onTap: () {
                // open tempo dialog
              },
            ),


            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text(
                "Duplicate Measure",
                style: TextStyle(
                  fontSize: 22,
                  // fontWeight: FontWeight.bold,
                  color: Colors.black,
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
              leading: const Icon(Icons.add_box),
              title: const Text(
                "Insert Measure",
                style: TextStyle(
                  fontSize: 22,
                  // fontWeight: FontWeight.bold,
                  color: Colors.black,
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
                  // fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              onTap: () {
                controller.deleteMeasure(
                  measureIndex,
                );
                Navigator.pop(context);
              },
            ),

            const Divider(thickness: 1.0),

            // Beat actions

            Text(
              "Beat ${beatIndex + 1}",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text(
                "Dynamic",
                style: TextStyle(
                  fontSize: 22,
                  // fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              onTap: () {
                // open dynamic dialog here
              },
            ),


            ListTile(
              leading: const Icon(Icons.add),
              title: const Text(
                "Insert Beat",
                style: TextStyle(
                  fontSize: 22,
                  // fontWeight: FontWeight.bold,
                  color: Colors.black,
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
              leading: const Icon(Icons.copy),
              title: const Text(
                "Duplicate Beat",
                style: TextStyle(
                  fontSize: 22,
                  // fontWeight: FontWeight.bold,
                  color: Colors.black,
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
              leading: const Icon(Icons.remove),
              title: const Text(
                "Delete Beat",
                style: TextStyle(
                  fontSize: 22,
                  // fontWeight: FontWeight.bold,
                  color: Colors.red,
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


            const Divider(thickness: 1.0),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
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
        ),

      );

    },
  );

}