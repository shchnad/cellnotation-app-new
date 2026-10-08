import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';

/// Opens from the Play icon (see CompositionScreen): lets the person
/// choose how fast to scroll before playback starts — built the same
/// way as cellWidthDialog. The − / + buttons change the speed by
/// [CompositionController.playbackSpeedStep] (10%), Reset sets it back
/// to the speed the tempo requires (100%), and Play closes the dialog
/// and starts playback via [onPlay]. The chosen speed is kept, so the
/// dialog opens at the same value next time.
void scrollSpeedDialog(
    BuildContext context,
    CompositionController controller, {
      required VoidCallback onPlay,
    }) {

  showDialog(
    context: context,
    builder: (dialogContext) {

      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {

          final percent = (controller.playbackSpeed * 100).round();
          final description = percent == 100
              ? 'tempo'
              : (percent > 100 ? 'faster' : 'slower');

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,

            title: Center(
              child: const Text(
                "Set Scroll Speed",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Text(
                  "$percent % ($description)",
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [

                    IconButton(
                      icon: const Icon(
                        Icons.remove,
                        color: Colors.blue,
                        size: 35,
                      ),
                      onPressed: controller.playbackSpeed <=
                          CompositionController.minPlaybackSpeed
                          ? null
                          : (){
                        controller.changePlaybackSpeed(
                          -CompositionController.playbackSpeedStep,
                        );
                      },
                    ),

                    const SizedBox(width: 30),

                    IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: Colors.blue,
                        size: 35,
                      ),
                      onPressed: controller.playbackSpeed >=
                          CompositionController.maxPlaybackSpeed
                          ? null
                          : (){
                        controller.changePlaybackSpeed(
                          CompositionController.playbackSpeedStep,
                        );
                      },
                    ),

                  ],
                ),

              ],
            ),

            actions: [
              const Divider(thickness: 1.0),

              Row(
                children: [

                  TextButton(
                    onPressed: (){
                      Navigator.pop(dialogContext);
                    },
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: (){
                      controller.resetPlaybackSpeed();
                    },
                    child: const Text(
                      "Reset",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: (){
                      Navigator.pop(dialogContext);
                      onPlay();
                    },
                    child: const Text(
                      "Play",
                      style: TextStyle(
                        color: Colors.green,
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