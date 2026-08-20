import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../utils/scale_resolver.dart';

/// A reference popup, opened from scale_dialog.dart's own "Help"
/// button, showing every available scale with its actual degree
/// spelling (from ScaleResolver.getScale, the SAME source
/// scale_dialog.dart's own picker buttons use) and its key signature,
/// computed directly from that degree data rather than hardcoded
/// (sharp count if any degree carries a '+', flat count if any
/// carries a '-' — the two never mix within one scale in this app's
/// own data, matching real key-signature theory).
///
/// Responsive to the device's own orientation, but the ORDER of
/// scales is always the same — every major scale, then every minor
/// scale, in whatever order controller.availableScales already gives
/// them:
/// - Portrait (height > width): single column — all majors, a gap,
///   then all minors — sized to the viewport height so it fits
///   without scrolling wherever reasonably possible.
/// - Landscape (width >= height): two columns instead — majors in the
///   left column, minors in the right column, side by side rather
///   than stacked.
///
/// Tapping a scale here calls the SAME [onSelected] callback passed
/// into the underlying scale_dialog.dart, then closes BOTH this
/// dialog and that one — [context] must be scale_dialog's own
/// BuildContext (not this dialog's builder context) so that second
/// pop actually reaches it.
void scaleHelpDialog({
  required BuildContext context,
  required CompositionController controller,
  required String currentScale,
  required ValueChanged<String> onSelected,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      final majors =
      controller.availableScales.where((s) => s.endsWith('major')).toList();
      final minors =
      controller.availableScales.where((s) => s.endsWith('minor')).toList();

      Widget buildRow(String scale, double fontSize) {
        final degrees = ScaleResolver.getScale(scale);
        final sharpCount = degrees.where((d) => d.endsWith('+')).length;
        final flatCount = degrees.where((d) => d.endsWith('-')).length;
        final keySignature = sharpCount > 0
            ? '($sharpCount#)'
            : (flatCount > 0 ? '(${flatCount}b)' : '()');
        final isCurrent = scale == currentScale;

        return InkWell(
          onTap: () {
            onSelected(scale);
            // Closes THIS dialog, then scale_dialog.dart's own dialog
            // too — per request, choosing a scale here finishes the
            // whole picking flow rather than dropping back to the
            // plain scale list.
            Navigator.pop(dialogContext);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '$scale $keySignature = ${degrees.join(', ')}',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? Colors.blue : Colors.black,
              ),
            ),
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, _) {
          final screenSize = MediaQuery.of(context).size;
          final isLandscape = screenSize.width >= screenSize.height;
          final maxDialogHeight = screenSize.height * 0.8;
          final maxDialogWidth = screenSize.width * 0.9;
          // Smaller in portrait, where the whole list needs to fit in
          // one narrower column — landscape has more room (two
          // columns) so keeps the larger, easier-to-read size.
          final rowFontSize = isLandscape ? 22.0 : 16.0;

          final Widget listContent;

          if (isLandscape) {
            // Two columns, side by side — majors on the left, minors
            // on the right — same order within each as portrait,
            // just arranged horizontally instead of stacked.
            listContent = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in majors) buildRow(s, rowFontSize),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in minors) buildRow(s, rowFontSize),
                    ],
                  ),
                ),
              ],
            );
          } else {
            listContent = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in majors) buildRow(s, rowFontSize),
                const SizedBox(height: 24),
                for (final s in minors) buildRow(s, rowFontSize),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Scale Reference',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: maxDialogWidth,
              height: maxDialogHeight,
              child: SingleChildScrollView(child: listContent),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}