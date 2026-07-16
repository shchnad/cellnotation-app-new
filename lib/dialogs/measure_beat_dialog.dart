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
        title: Text(
          "Measure ${measureIndex + 1}   Beat ${beatIndex + 1}",
          style: const TextStyle(fontSize: 22),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text("Insert Beat"),
              onTap: () {
                controller.addBeatToMeasure(measureIndex);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove),
              title: const Text("Delete Beat"),
              onTap: () {
                controller.removeBeatFromMeasure(measureIndex, beatIndex);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text("Duplicate Beat"),
              onTap: () {
                controller.copyBeat(measureIndex, beatIndex);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text("Add / Edit Dynamic"),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text("Insert Measure"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text("Delete Measure"),
              onTap: () {
                controller.deleteMeasure(measureIndex);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text("Duplicate Measure"),
              onTap: () {
                controller.copyMeasure(measureIndex);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_video),
              title: const Text("Add / Edit Tempo"),
              onTap: () {},
            ),
          ],
        ),
      );
    },
  );
}