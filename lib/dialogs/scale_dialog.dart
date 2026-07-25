import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

Future<void> scaleDialog({
  required BuildContext context,
  required CompositionController controller,
  required String currentScale,
  required ValueChanged<String> onSelected,
}) async {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        title: const Text(
          "Select Scale",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ===========================
                // MAJOR
                // ===========================

                const Text(
                  "Major",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.availableScales
                      .where((scale) => scale.endsWith("major"))
                      .map(
                        (scale) => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: scale == currentScale
                            ? Colors.blue
                            : Colors.black,
                        elevation: 0,
                      ),
                      onPressed: () {
                        onSelected(scale);
                        Navigator.pop(context);
                      },
                      child: Text(
                        scale.replaceFirst(RegExp(r' major$'), ''),
                        style: const TextStyle(
                          fontSize: 20,
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),

                const SizedBox(height: 24),

                const Divider(),

                const SizedBox(height: 16),

                // ===========================
                // MINOR
                // ===========================

                const Text(
                  "Minor",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.availableScales
                      .where((scale) => scale.endsWith("minor"))
                      .map(
                        (scale) => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: scale == currentScale
                            ? Colors.blue
                            : Colors.black,
                        elevation: 0,
                      ),
                      onPressed: () {
                        onSelected(scale);
                        Navigator.pop(context);
                      },
                      child: Text(
                        scale.replaceFirst(RegExp(r' minor$'), ''),
                        style: const TextStyle(
                          fontSize: 20,
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}