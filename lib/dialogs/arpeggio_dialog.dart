import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../enums/hand.dart';

/// The choices of the "Set Arpeggio" dialog.
enum ArpeggioChoice {
  left('Left Hand', {Hand.left}),
  right('Right Hand', {Hand.right}),
  both('Both Hands', {Hand.left, Hand.right});

  final String label;
  final Set<Hand> hands;
  const ArpeggioChoice(this.label, this.hands);
}

/// "Set Arpeggio" for the chord at [tick]: grey buttons (left hand,
/// right hand, both hands; the current one in blue text), with Delete
/// and Close in the bottom row — the same look as the pedal dialog. In edit mode a wavy line
/// is drawn at the start of the beat; in playback mode the chord's
/// notes are played one after another (lowest first) with equal
/// durations.
void arpeggioDialog({
  required BuildContext context,
  required CompositionController controller,
  required int tick,
}) {
  final hands = controller.arpeggioAt(tick)?.hands ?? const <Hand>{};
  final ArpeggioChoice? current =
  hands.contains(Hand.left) && hands.contains(Hand.right)
      ? ArpeggioChoice.both
      : hands.contains(Hand.left)
      ? ArpeggioChoice.left
      : hands.contains(Hand.right)
      ? ArpeggioChoice.right
      : null;

  void apply(BuildContext dialogContext, Set<Hand> newHands) {
    final error = controller.setArpeggio(tick, newHands);
    Navigator.pop(dialogContext);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error, style: const TextStyle(fontSize: 22))),
      );
    }
  }

  // One grey choice button (the current choice in blue text), the same
  // look as the pedal dialog's buttons.
  Widget button(BuildContext dialogContext, ArpeggioChoice choice) {
    return SizedBox(
      width: double.infinity,
      height: 76,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          minimumSize: const Size(0, 36),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => apply(dialogContext, choice.hands),
        child: Center(
          child: Text(
            choice.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              color: choice == current ? Colors.blue : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'Set Arpeggio',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left hand and right hand side by side…
            Row(
              children: [
                Expanded(child: button(dialogContext, ArpeggioChoice.left)),
                const SizedBox(width: 6),
                Expanded(child: button(dialogContext, ArpeggioChoice.right)),
              ],
            ),
            const SizedBox(height: 6),
            // …and both hands on its own row underneath.
            button(dialogContext, ArpeggioChoice.both),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Greyed out when this chord has no arpeggio.
            TextButton(
              onPressed: current == null
                  ? null
                  : () => apply(dialogContext, const <Hand>{}),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}