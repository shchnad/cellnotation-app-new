import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../enums/hand.dart';

/// Opens from the Audio icon: for every hand that has notes in the
/// composition (right, left, additional), a pair of radio buttons
/// chooses whether that hand is heard during playback ("Audio") or
/// silent ("Cut off"). Changes apply immediately.
void audioHandsDialog(
    BuildContext context,
    CompositionController controller,
    ) {

  String handLabel(Hand hand) {
    switch (hand) {
      case Hand.right:
        return 'Right hand';
      case Hand.left:
        return 'Left hand';
      case Hand.additional:
        return 'Additional hand';
    }
  }

  showDialog(
    context: context,
    builder: (dialogContext) {

      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {

          final hands = controller.handsInComposition;

          Widget choice(Hand hand, bool muted, String label, Color color) {
            final selected = controller.isHandMuted(hand) == muted;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => controller.setHandMuted(hand, muted),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<bool>(
                    value: muted,
                    groupValue: controller.isHandMuted(hand),
                    activeColor: color,
                    onChanged: (_) => controller.setHandMuted(hand, muted),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      color: selected ? color : Colors.black,
                      fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,

            title: const Center(
              child: Text(
                "Audio",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            content: hands.isEmpty
                ? const Text(
              "There are no notes yet.",
              style: TextStyle(fontSize: 20),
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final hand in hands) ...[
                  Text(
                    handLabel(hand),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Wrap(
                    children: [
                      choice(hand, false, 'Audio', Colors.green),
                      choice(hand, true, 'Cut off', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),

            actions: [
              const Divider(thickness: 1.0),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
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
                    onPressed: hands.isEmpty
                        ? null
                        : () => controller.setAllHandsMuted(true),
                    child: const Text(
                      "All off",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: hands.isEmpty
                        ? null
                        : () => controller.setAllHandsMuted(false),
                    child: const Text(
                      "All on",
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