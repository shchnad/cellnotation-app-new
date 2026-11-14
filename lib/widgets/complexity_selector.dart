import 'package:flutter/material.dart';

/// Picks a composition's level of complexity — how hard it is to
/// play: 1 (easy), 2 (medium) or 3 (hard). Three grey buttons in a
/// row; the chosen one has [color] text.
class ComplexitySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color color;

  const ComplexitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.color = Colors.green,
  });

  static const _names = {1: 'Easy', 2: 'Medium', 3: 'Hard'};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Level of complexity',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final level in const [1, 2, 3]) ...[
              if (level > 1) const SizedBox(width: 8),
              Expanded(
                child: _button(level),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// The same buttons as noteValuesDialog: grey, the chosen one with
  /// [color] text.
  Widget _button(int level) {
    final selected = level == value;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade300,
        minimumSize: const Size(0, 55),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () => onChanged(level),
      child: Text(
        '$level  ${_names[level]!}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 22,
          color: selected ? color : Colors.black,
        ),
      ),
    );
  }
}