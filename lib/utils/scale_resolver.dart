class ScaleResolver {

  // Chromatic circle for transposing MAJOR scales — one canonical
  // spelling per semitone, wraps around (si -> do, do -> si).
  static const List<String> _majorChromaticNotes = [
    'do', 're flat', 're', 'mi flat', 'mi', 'fa', 'fa sharp', 'sol',
    'la flat', 'la', 'si flat', 'si'
  ];

  // Chromatic circle for transposing MINOR scales — different
  // canonical spellings than major at several positions.
  static const List<String> _minorChromaticNotes = [
    'do', 'do sharp', 're', 're sharp', 'mi', 'fa', 'fa sharp', 'sol',
    'sol sharp', 'la', 'si flat', 'si'
  ];

  // Every "<root> <mode>" combination that actually has a defined scale
  // below — used to skip enharmonic spellings that don't (e.g. there's
  // no "re sharp major", only "mi flat major" at that semitone).
  static const Set<String> _definedScaleNames = {
    'do major', 'do sharp major', 're flat major', 're major',
    'mi flat major', 'mi major', 'fa major', 'fa sharp major',
    'sol flat major', 'sol major', 'la flat major', 'la major',
    'si flat major', 'si major',

    'do minor', 'do sharp minor', 're minor', 're sharp minor',
    'mi flat minor', 'mi minor', 'fa minor', 'fa sharp minor',
    'sol minor', 'sol sharp minor', 'la flat minor', 'la minor',
    'la sharp minor', 'si flat minor', 'si minor',
  };

  // Maps the old letter-named roots to their solfège equivalents.
  static const Map<String, String> _legacyLetterToSolfege = {
    'C': 'do',
    'C sharp': 'do sharp',
    'D flat': 're flat',
    'D': 're',
    'D sharp': 're sharp',
    'E flat': 'mi flat',
    'E': 'mi',
    'F': 'fa',
    'F sharp': 'fa sharp',
    'G flat': 'sol flat',
    'G': 'sol',
    'G sharp': 'sol sharp',
    'A flat': 'la flat',
    'A': 'la',
    'A sharp': 'la sharp',
    'B flat': 'si flat',
    'B': 'si',
  };

  /// Normalizes any reasonable scale-name spelling into the canonical
  /// "<solfège root> <mode>" format, regardless of:
  ///  - word order — mode first ("major C") or mode last ("C major")
  ///  - root spelling — letter ("C") or solfège ("do")
  static String normalizeScaleName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return name;

    final String mode;
    final List<String> rootParts;

    if (parts.first == 'major' || parts.first == 'minor') {
      mode = parts.first;
      rootParts = parts.sublist(1);
    } else if (parts.last == 'major' || parts.last == 'minor') {
      mode = parts.last;
      rootParts = parts.sublist(0, parts.length - 1);
    } else {
      // No recognizable mode word at all — nothing we can safely do.
      return name;
    }

    final rawRoot = rootParts.join(' ');
    final solfegeRoot = _legacyLetterToSolfege[rawRoot] ?? rawRoot;

    return '$solfegeRoot $mode';
  }


  /// Shifts the base scale root up or down by [semitoneOffset]
  /// semitones, one semitone at a time, using the chromatic circle for
  /// whichever mode (major/minor) [baseScale] is in. Each single
  /// semitone step moves exactly one slot in the requested direction
  /// (+1 index per semitone up, -1 per semitone down), wrapping around
  /// (si↔do at the ends) — except when that slot's spelling has no
  /// defined scale for the current mode, in which case it's skipped
  /// and the walk continues in the same direction.
  static String transposeScale(String baseScale, int semitoneOffset) {
    final normalized = normalizeScaleName(baseScale);
    if (semitoneOffset == 0) return normalized;

    final parts = normalized.split(' ');
    if (parts.length < 2) return normalized;
    final String mode = parts.last; // 'major' or 'minor'
    final String baseRoot = parts.sublist(0, parts.length - 1).join(' ');

    final List<String> chromaticNotes =
    mode == 'minor' ? _minorChromaticNotes : _majorChromaticNotes;

    int currentIdx = chromaticNotes.indexWhere(
            (note) => note.toLowerCase() == baseRoot.toLowerCase()
    );
    if (currentIdx == -1) return normalized; // Fallback safety

    final int direction = semitoneOffset > 0 ? 1 : -1;
    final int steps = semitoneOffset.abs();
    final int total = chromaticNotes.length;

    int idx = currentIdx;
    String root = baseRoot;

    for (int step = 0; step < steps; step++) {
      int nextIdx = idx;
      String? nextRoot;

      // Walk one slot at a time in [direction], skipping any spelling
      // that isn't a defined scale for this mode, until one is found
      // (or we've gone all the way around, which shouldn't normally
      // happen since the starting root is itself always valid).
      for (int attempt = 0; attempt < total; attempt++) {
        nextIdx = (nextIdx + direction) % total;
        if (nextIdx < 0) nextIdx += total;
        final candidateRoot = chromaticNotes[nextIdx];
        if (_definedScaleNames.contains('$candidateRoot $mode')) {
          nextRoot = candidateRoot;
          break;
        }
      }

      if (nextRoot == null) {
        // No valid spelling found anywhere on the wheel for this mode
        // — bail out with whatever we've reached so far.
        break;
      }

      idx = nextIdx;
      root = nextRoot;
    }

    return '$root $mode';
  }



  static List<String> getScale(String name) {
    final normalized = normalizeScaleName(name);
    switch (normalized) {

      case 'do major':
        return ['1', '2', '3', '4', '5', '6', '7'];

      case 'do sharp major':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7+'];

      case 're flat major':
        return ['1', '2-', '3-', '4', '5-', '6-', '7-'];

      case 're major':
        return ['1+', '2', '3', '4+', '5', '6', '7'];

      case 'mi flat major':
        return ['1', '2', '3-', '4', '5', '6-', '7-'];

      case 'mi major':
        return ['1+', '2+', '3', '4+', '5+', '6', '7'];

      case 'fa major':
        return ['1', '2', '3', '4', '5', '6', '7-'];

      case 'fa sharp major':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7'];

      case 'sol flat major':
        return ['1-', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'sol major':
        return ['1', '2', '3', '4+', '5', '6', '7'];

      case 'la flat major':
        return ['1', '2-', '3-', '4', '5', '6-', '7-'];

      case 'la major':
        return ['1+', '2', '3', '4+', '5+', '6', '7'];

      case 'si flat major':
        return ['1', '2', '3-', '4', '5', '6', '7-'];

      case 'si major':
        return ['1+', '2+', '3', '4+', '5+', '6+', '7'];


      case 'do minor':
        return ['1', '2', '3-', '4', '5', '6-', '7-'];

      case 'do sharp minor':
        return ['1+', '2+', '3', '4+', '5+', '6', '7'];

      case 're minor':
        return ['1', '2', '3', '4', '5', '6', '7-'];

      case 're sharp minor':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7'];

      case 'mi flat minor':
        return ['1-', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'mi minor':
        return ['1', '2', '3', '4+', '5', '6', '7'];

      case 'fa minor':
        return ['1', '2-', '3-', '4', '5', '6-', '7-'];

      case 'fa sharp minor':
        return ['1+', '2', '3', '4+', '5+', '6', '7'];

      case 'sol minor':
        return ['1', '2', '3-', '4', '5', '6', '7-'];

      case 'sol sharp minor':
        return ['1+', '2+', '3', '4+', '5+', '6+', '7'];

      case 'la flat minor':
        return ['1-', '2-', '3-', '4-', '5-', '6-', '7-'];

      case 'la minor':
        return ['1', '2', '3', '4', '5', '6', '7'];

      case 'la sharp minor':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7+'];

      case 'si flat minor':
        return ['1', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'si minor':
        return ['1+', '2', '3', '4+', '5', '6', '7'];

      default:
        return ['1','2','3','4','5','6','7'];
    }
  }
}