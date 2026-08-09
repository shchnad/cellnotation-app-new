import 'package:flutter/material.dart';

void noteValuesDialog<T>({
  required BuildContext context,
  required T? currentValue,
  required ValueChanged<T> onSelected,
  required String title,
  required List<T> values,
  required String Function(T) labelBuilder,
  required int numberOfColumns,
  required bool allowToCloseNextWindow,
  VoidCallback? onClear,
}) {
  const fontSize = 22.0;
  const spacing = 8.0;
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  double textWidth(String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  // Sized to the single WIDEST label among all values, so every button
  // in the grid is uniform width and wide enough to show its own label
  // on one line in full — nothing gets truncated or ellipsized.
  final maxWidth = values
      .map((v) => textWidth(labelBuilder(v)))
      .reduce((a, b) => a > b ? a : b);

  final buttonWidth = maxWidth + 40;

  // How much width the requested numberOfColumns of full-size buttons
  // (plus the spacing between them and the dialog's own padding)
  // actually needs.
  final desiredContentWidth =
      buttonWidth * numberOfColumns + spacing * (numberOfColumns - 1);

  // The dialog itself is capped to a comfortable fraction of the
  // screen — but, critically, the BUTTONS below are never shrunk to
  // fit inside that cap (that shrinking is what used to clip long
  // ornament names). If the full desired width doesn't fit, buttons
  // simply wrap onto more rows instead (see the Wrap widget below).
  final dialogWidth =
  (desiredContentWidth + 48.0).clamp(0.0, screenWidth * 0.9);

  final buttons = values.map(
        (value) {
      final selected = value == currentValue;
      return _button(
        labelBuilder(value),
        selected,
        buttonWidth,
            () {
          onSelected(value);
          Navigator.pop(context);
          if (allowToCloseNextWindow) Navigator.pop(context);
        },
      );
    },
  ).toList();


  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      content: SizedBox(
        width: dialogWidth,
        // Buttons are laid out with Wrap (not GridView.count) so each
        // one always renders at its full computed `buttonWidth` —
        // enough to fit its own label text on one line — rather than
        // being squeezed to `dialogWidth / numberOfColumns`. When the
        // full-width row of `numberOfColumns` buttons doesn't fit the
        // (screen-capped) dialog width, Wrap simply moves the
        // overflow buttons to the next row instead of shrinking them.
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.6),
          child: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing,
              runSpacing: spacing,
              children: buttons,
            ),
          ),
        ),
      ),
      actions: [
        const Divider(thickness: 1.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (onClear != null)
              TextButton(
                onPressed: () {
                  onClear();
                  Navigator.pop(context);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


Widget _button(
    String text,
    bool selected,
    double width,
    VoidCallback onPressed,
    ) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.grey.shade300,
      minimumSize: Size(width, 55),
      // Buttons are laid out in a Wrap now (not a size-constrained
      // GridView cell), so this minimumSize is actually respected —
      // each button renders at exactly `width` (wide enough for its
      // full label) instead of being forced smaller by its parent.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    onPressed: onPressed,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color:  selected
            ? Colors.blue
            : Colors.black,
        fontSize: 22,
        // fontWeight: FontWeight.bold,
      ),
    ),
  );


}