import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';

/// Opens from the Play icon (see CompositionScreen): lets the person
/// choose how fast to scroll before playback starts. One button per
/// speed: the left column slows down (125 % … 200 % slower, in steps of
/// 25 %), the right column speeds up (125 % … 200 % faster), and the
/// button in the middle is the tempo (100 %). The chosen speed is
/// highlighted. Tapping a speed closes the dialog and starts playback
/// via [onPlay] (after its 3-second pause); Close leaves without
/// playing. The chosen speed is kept, so the dialog opens at the same
/// value next time.
void scrollSpeedDialog(
    BuildContext context,
    CompositionController controller, {
      required VoidCallback onPlay,
    }) {
  final level = controller.playbackSpeedLevel;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Widget speedButton(int l) {
            final selected = l == level;
            final percent = 100 + 25 * l.abs();
            // Same buttons as noteValuesDialog: grey, the chosen one
            // with blue text.
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  minimumSize: const Size(130, 55),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                // Tapping a speed closes the dialog and starts
                // playback (after the usual 3-second pause).
                onPressed: () {
                  Navigator.pop(dialogContext);
                  controller.setPlaybackSpeedLevel(l);
                  onPlay();
                },
                child: Text(
                  '$percent %',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    color: selected ? Colors.blue : Colors.black,
                  ),
                ),
              ),
            );
          }

          const labelStyle = TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          );

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              "Set Scroll Speed",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // SLOWER
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Slower', style: labelStyle),
                      const SizedBox(height: 6),
                      for (int l = -1; l >= -4; l--) speedButton(l),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // TEMPO (reset)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Tempo', style: labelStyle),
                      const SizedBox(height: 6),
                      speedButton(0),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // FASTER
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Faster', style: labelStyle),
                      const SizedBox(height: 6),
                      for (int l = 1; l <= 4; l++) speedButton(l),
                    ],
                  ),
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
                      "Close",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}