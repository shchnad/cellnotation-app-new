import 'package:flutter/material.dart';

/// Picks a composition's level of complexity — how hard it is to
/// play: 1 (easy), 2 (medium) or 3 (hard). Three buttons in a row;
/// the chosen one is filled with [color].
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _button(int level) {
    final selected = level == value;
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            children: [
              Text(
                '$level',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.black,
                ),
              ),
              Text(
                _names[level]!,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? Colors.white : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}