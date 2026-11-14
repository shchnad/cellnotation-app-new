import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../enums/hand.dart';

/// Opens from the Audio icon. Left column "No Sound", right column
/// "Sound", each with Right hand, Left hand, Additional hand and All
/// hands. Buttons whose choice is in effect have coloured text — red in
/// No Sound, blue in Sound — at first the hands as they are now (by
/// default right and left hand heard). Taps only change the choice
/// shown here; Set applies it and closes the dialog.
void audioHandsDialog(
    BuildContext context,
    CompositionController controller,
    ) {
  // The silent hands as chosen in this dialog (applied by Set).
  final muted = <Hand>{
    for (final h in Hand.values)
      if (controller.isHandMuted(h)) h,
  };

  const rows = <(String, List<Hand>)>[
    ('Right hand', [Hand.right]),
    ('Left hand', [Hand.left]),
    ('Additional hand', [Hand.additional]),
    ('All hands', [Hand.right, Hand.left, Hand.additional]),
  ];

  const headStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          // Same buttons as noteValuesDialog: grey, the chosen ones with
          // blue text.
          Widget button(String label, bool selected, Color color,
              VoidCallback onTap) =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    minimumSize: const Size(220, 55),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: onTap,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      color: selected ? color : Colors.black,
                    ),
                  ),
                ),
              );

          Widget column(String title, bool silent) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: headStyle),
              const SizedBox(height: 6),
              for (final (label, hands) in rows)
                button(
                  label,
                  hands.every((h) => muted.contains(h) == silent),
                  silent ? Colors.red : Colors.blue,
                      () => setState(() {
                    for (final h in hands) {
                      silent ? muted.add(h) : muted.remove(h);
                    }
                  }),
                ),
            ],
          );


          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Audio',
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
                  column('Off', true),
                  const SizedBox(width: 16),
                  column('On', false),
                ],
              ),
            ),
            actions: [
              const Divider(thickness: 1.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      controller.setMutedHandsTo(muted);
                    },
                    child: const Text(
                      'Set',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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