class ScaleResolver {
  // Chromatic lookup wheel structured exactly like your switch case suffixes
  static const List<String> _chromaticNotes = [
    'C', 'C sharp', 'D', 'E flat', 'E', 'F', 'F sharp', 'G', 'A flat', 'A', 'B flat', 'B'
  ];

  /// Shifts the base scale root note up or down by absolute semitones, matching your exact naming style.
  static String transposeScale(String baseScale, int semitoneOffset) {
    if (semitoneOffset == 0) return baseScale;

    final parts = baseScale.split(' ');
    if (parts.length < 2) return baseScale;

    final String mode = parts[0]; // 'major' or 'minor'
    final String baseRoot = parts.sublist(1).join(' '); // Reconstructs e.g. "C sharp"

    // Find current position on the chromatic circle wheel
    int currentIdx = _chromaticNotes.indexWhere(
            (note) => note.toLowerCase() == baseRoot.toLowerCase()
    );

    if (currentIdx == -1) return baseScale; // Fallback safety

    // Shift mathematically, cleanly accommodating negative wrapping
    int newIdx = (currentIdx + semitoneOffset) % _chromaticNotes.length;
    if (newIdx < 0) {
      newIdx += _chromaticNotes.length;
    }

    final String newRoot = _chromaticNotes[newIdx];

    // Returns structural strings like "major C sharp" or "minor E flat"
    return '$mode $newRoot';
  }

  static List<String> getScale(String name) {
    switch (name) {
    // MAJOR

      case 'major C':
        return ['1', '2', '3', '4', '5', '6', '7'];

      case 'major C sharp':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7+'];

      case 'major D flat':
        return ['1', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'major D':
        return ['1+', '2', '3', '4+', '5', '6', '7'];

      case 'major E flat':
        return ['1', '2', '3-', '4', '5', '6-', '7-'];

      case 'major E':
        return ['1+', '2+', '3', '4+', '5+', '6', '7'];

      case 'major F':
        return ['1', '2', '3', '4', '5', '6', '7-'];

      case 'major F sharp':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7'];

      case 'major G flat':
        return ['1-', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'major G':
        return ['1', '2', '3', '4+', '5', '6', '7'];

      case 'major A flat':
        return ['1', '2-', '3-', '4', '5', '6-', '7-'];

      case 'major A':
        return ['1+', '2', '3', '4+', '5+', '6', '7'];

      case 'major B flat':
        return ['1', '2', '3-', '4', '5', '6', '7-'];

    //  MINOR

      case 'minor C':
        return ['1', '2', '3-', '4', '5', '6-', '7-'];

      case 'minor C sharp':
        return ['1+', '2+', '3', '4+', '5+', '6', '7'];

      case 'minor D':
        return ['1', '2', '3', '4', '5', '6', '7-'];

      case 'minor D sharp':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7'];

      case 'minor E flat':
        return ['1-', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'minor E':
        return ['1', '2', '3', '4+', '5', '6', '7'];

      case 'minor F':
        return ['1', '2-', '3-', '4', '5', '6-', '7-'];

      case 'minor F sharp':
        return ['1+', '2', '3', '4+', '5+', '6', '7'];

      case 'minor G':
        return ['1', '2', '3-', '4', '5', '6', '7-'];

      case 'minor G sharp':
        return ['1+', '2+', '3', '4+', '5+', '6+', '7'];

      case 'minor A flat':
        return ['1-', '2-', '3-', '4-', '5-', '6-', '7-'];

      case 'minor A':
        return ['1', '2', '3', '4', '5', '6', '7'];

      case 'minor A sharp':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7+'];

      case 'minor B flat':
        return ['1', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'minor B':
        return ['1+', '2', '3', '4+', '5', '6', '7'];

      default:
        return ['1','2','3','4','5','6','7'];
    }
  }
}