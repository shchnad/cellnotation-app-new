import 'package:flutter/material.dart';

void noteValuesDialog<T>({
  required BuildContext context,
  required T? currentValue,
  required ValueChanged<T> onSelected,
  required String title,
  required List<T> values,
  required String Function(T) labelBuilder,
  required int numberOfColumns,
  VoidCallback? onClear,
}) {
  const fontSize = 22.0;
  const spacing = 8.0;
  final screenWidth = MediaQuery.of(context).size.width;
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

  final maxWidth = [
    ...values.map((v) => textWidth(labelBuilder(v))),
    if (onClear != null) textWidth('none'),
  ].reduce((a, b) => a > b ? a : b);

  final buttonWidth = maxWidth + 40;

// Convert the integer math to a double first, then clamp
  final dialogWidth = (((buttonWidth * numberOfColumns) +
      spacing * (numberOfColumns - 1) +
      48.0)
      .toDouble() // <-- Add this right here
      .clamp(0.0, screenWidth * 0.8));

  final buttons = [
    ...values.map(
          (value) {
        final selected = value == currentValue;
        return _button(
          labelBuilder(value),
          selected,
          buttonWidth,
          () {
            onSelected(value);
            Navigator.pop(context);
          },
        );
      },
    ),
    if (onClear != null)
      _button(
        'none',
        currentValue == null,
        buttonWidth,
        () {
          onClear();
          Navigator.pop(context);
        },
      ),

  ];


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
        child: GridView.count(
          crossAxisCount: numberOfColumns,
          shrinkWrap: true,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: buttonWidth / 55,
          children: buttons,
        ),
      ),
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