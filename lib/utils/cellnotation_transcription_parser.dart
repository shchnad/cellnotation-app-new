import '../enums/accidental.dart';
import '../enums/hand.dart';
import '../enums/note_duration.dart';
import '../enums/grace_note_type.dart';
import '../models/note_import.dart';

/// Parses the "line-position" transcription notation worked out for
/// reading directly off traditional sheet music, and converts it
/// straight into the same [ImportBatch]/[ImportMeasure]/[ImportEvent]/
/// [ImportNoteSpec] structures the rest of the app already knows how
/// to import (see CompositionController.importBatch/
/// importTranscribedMeasures) — this file only handles turning text
/// into that structure; the actual note creation is unchanged.
///
/// This is a SEPARATE notation from the older word-based dictation
/// format (dorian/remy/mickael/... — see the existing dictation
/// parser); the two are not interchangeable and this file does not
/// touch that one.
///
/// ## Syntax
///
/// Whitespace-separated tokens, read left to right. Newlines are
/// treated the same as any other whitespace — purely for the
/// person's own readability, not meaningful to the parser.
///
/// - `t{beats}/{denominator}` — a time signature, e.g. `t4/4`.
///   Informational only: it is NOT used to compute anything here
///   (beats are already expressed directly as beat NUMBERS below,
///   and tick conversion happens later using the composition's own
///   actual measure time signature).
/// - `m{n}` — starts measure n (1-based on input, matching every
///   other 1-based measure reference in this app's UI; converted to
///   0-based for [ImportMeasure.measureIndex]).
/// - `hl` / `hr` / `ha` — all following notes belong to the
///   left/right/additional hand, until the next `hl`/`hr`/`ha`.
/// - `b{n}` or `b{n}&{a}/{c}` — starts a new beat (1-based); `&a/c`
///   is the part of the beat where the note starts, e.g. `b1&1/2` is
///   halfway through beat 1, `b1&1/4` / `b1&3/4` a quarter / three
///   quarters into it, `b2&1/3` one third into beat 2 (a triplet).
///   (The older forms `b1.25`, `b1.5`, `b1.75` and `b2+1/3` are still
///   read.)
/// - A note token: `l{position}{accidental?}{duration}` — "l" (line)
///   marks a note position, e.g. `l2d8`, `l3/4d8:3`, `(l-1, l0)d4`
///   (the older form without "l" is still read).
///   - `{position}` is either a single integer (the note sits ON
///     that staff line) or `A/B` (the note sits BETWEEN lines A and
///     B — order doesn't matter, `-5/-4` and `-4/-5` are the same).
///   - `{accidental?}` is optional: `+` sharp, `++` double sharp,
///     `-` flat, `--` double flat, `x` natural.
///   - `{duration}` is `d` followed by 1/2/4/8/16/32/64 (whole
///     through sixty-fourth), optionally repeated for a dotted/tied
///     note — e.g. `d4d8` for a dotted quarter (quarter tied to an
///     eighth, per [ImportEvent.durationParts]).
/// - Tuplets (triplets…): a beat position can also be a fraction of
///   the beat, `b{n}+{a}/{c}` — e.g. `b2+1/3` and `b2+2/3` are the 2nd
///   and 3rd notes of a triplet on beat 2 — and a note of a tuplet has
///   `:{k}` after its duration — e.g. `2d8:3` is an eighth of a triplet
///   (3 eighths in the time of 2), `2d16:5` a sixteenth of a
///   quintuplet. On import the beat is split into equal columns
///   (see CompositionController.setBeatDivision).
/// - A rest: `r{duration}` — e.g. `rd4` for a quarter rest, `rd8` for
///   an eighth rest. Produces an [ImportEvent] with an empty
///   [ImportEvent.pitches] list.
/// - A chord: `({position}{accidental?}, {position}{accidental?}, ...)
///   {duration}` — one or more notes, separated by commas, inside
///   parentheses, with NO duration on the individual notes — the
///   single shared duration is written once after the closing paren
///   — matches how [ImportEvent] itself only ever carries one
///   duration per event regardless of how many simultaneous
///   [ImportNoteSpec] pitches it has.
///
/// ## Line position → row
///
/// The staff is centered so that Do (octave 4) sits ON line 0 — the
/// same anchor CompositionController's own row 28 already represents
/// (row 28 = octave 4 × 7 + degree 1, i.e. exactly Do4 — this is not
/// a coincidence, it's how the mapping below was derived and checked
/// against the app's existing row/degree/octave convention). Moving
/// up or down the staff by one line is a scale STEP (not a
/// semitone), same as the notes on any drawn staff:
///
///   - On line N               -> row = 2*N + 28
///   - Between lines A and A+1 -> row = 2*A + 29 (either order of
///     A/A+1 in the input normalizes to this, using whichever is the
///     numerically lower of the pair)
///
/// [ImportNoteSpec] itself is expressed as degree (1-7) + octave, not
/// row directly, so this file converts row -> (degree, octave) via
/// the same relationship CompositionController.getDegree already
/// uses in the other direction (`degree = row % 7 + 1`,
/// `octave = row ~/ 7`), just solved for degree/octave instead of
/// row — see [_degreeAndOctaveForRow].

/// One parse-time problem — a token or line that couldn't be
/// understood. Distinct from [ImportWarning], which covers problems
/// found later while actually creating notes from an already-valid
/// [ImportBatch] (e.g. overlapping an existing note) — a
/// [TranscriptionParseError] means the TEXT itself didn't match the
/// notation's own syntax, so no [ImportBatch] could be produced at
/// all for that token.
class TranscriptionParseError {
  final int lineNumber; // 1-based, matching how a person counts lines
  final String line;
  final String message;

  const TranscriptionParseError({
    required this.lineNumber,
    required this.line,
    required this.message,
  });

  @override
  String toString() => 'Line $lineNumber: $message\n  "$line"';
}

/// The result of parsing — either a usable [batch] (when [errors] is
/// empty) or a list of everything that went wrong (when it isn't).
/// [batch] and [errors] can both be non-empty at once: a line with an
/// error is skipped, but every OTHER line still parses normally, so
/// the person can see (and fix) just the problem lines rather than
/// getting nothing back at all.
///
/// [scaleName]/[timeSignatureBeats]/[timeSignatureDenominator] are
/// read from the transcription's own leading "<root> <mode>" scale
/// line (e.g. "do major") and "t<beats>/<denominator>" time-signature
/// line — null if that line wasn't present at all. [measuresNeeded]
/// is the highest "m<n>" measure number seen anywhere in the text
/// (0 if none) — together, these three let a caller (see
/// sheet_music_transcription_dialog.dart) create exactly the empty
/// measures a transcription needs, with the right scale and time
/// signature, before actually importing notes into them, rather than
/// requiring those measures to already exist beforehand.
class TranscriptionParseResult {
  final ImportBatch batch;
  final List<TranscriptionParseError> errors;
  final String? scaleName;
  final int? timeSignatureBeats;
  final int? timeSignatureDenominator;
  final int measuresNeeded;

  const TranscriptionParseResult({
    required this.batch,
    required this.errors,
    this.scaleName,
    this.timeSignatureBeats,
    this.timeSignatureDenominator,
    this.measuresNeeded = 0,
  });

  bool get hasErrors => errors.isNotEmpty;
}

// Matches a full chord token: "(...)d..." — the parenthesized group
// (no nested parens supported) followed immediately by one or more
// "d<n>" duration parts. Captured as one token so splitting the line
// on whitespace doesn't break it apart, even though its own INSIDE
// contains commas (and possibly spaces after them) between each
// chord note.
final RegExp _chordTokenPattern =
RegExp(r'^\(([^()]*)\)((?:[dD]\d+)+)(?::(\d+))?$');

// A single note token: position, optional accidental, duration.
// Longest-accidental-first alternation (++ before +, -- before -) so
// a double sharp/flat isn't misread as a single one followed by a
// leftover sign. The duration marker (d) is matched case-
// insensitively — a stray capital D (an easy typo when dictating or
// typing quickly) shouldn't silently fail to parse.
final RegExp _noteTokenPattern =
RegExp(r'^[lL]?(-?\d+(?:/-?\d+)?)(\+\+|\+|--|-|x)?((?:[dD]\d+)+)(?::(\d+))?$');

// One note WITHOUT a duration — used for each note inside a chord's
// parentheses, since the chord's single shared duration is written
// once after the closing paren instead.
final RegExp _chordNotePattern =
RegExp(r'^[lL]?(-?\d+(?:/-?\d+)?)(\+\+|\+|--|-|x)?$');

final RegExp _restTokenPattern = RegExp(r'^[rR]((?:[dD]\d+)+)(?::(\d+))?$');
final RegExp _measureTokenPattern = RegExp(r'^m(\d+)$');
final RegExp _timeSignatureTokenPattern = RegExp(r'^t(\d+)/(\d+)$');

// A scale declaration is a WHOLE LINE (not tokenized like everything
// else), since a scale name can itself be more than one word — e.g.
// "re flat major", not just "do major" — matching
// CompositionController.availableScales / ScaleResolver's own
// "<root> <mode>" naming. Recognized by ending in "major" or "minor"
// case-insensitively; not validated against the exact set of scales
// ScaleResolver actually defines — an unrecognized name just falls
// back to ScaleResolver.getScale's own default scale rather than
// failing to parse here.
final RegExp _scaleLinePattern =
RegExp(r'^(.+?)\s+(major|minor)$', caseSensitive: false);

// Beat marker: a whole beat number, optionally followed by a quarter-
// beat decimal fraction — .25, .5, or .75 (no other fraction is a
// valid subdivision here). Anchored so "b1.3" (not one of the three
// allowed fractions) is correctly rejected as unrecognized rather
// than silently truncated to "b1".
final RegExp _beatTokenPattern =
RegExp(r'^b(\d+)(?:(\.(25|5|75))|[&+](\d+)/(\d+))?$');

const Map<String, Accidental?> _accidentalBySign = {
  '+': Accidental.sharp,
  '++': Accidental.doubleSharp,
  '-': Accidental.flat,
  '--': Accidental.doubleFlat,
  'x': Accidental.natural,
};

/// Splits one duration-code run like "d4" or "d4d8" into its
/// [NoteDuration] parts. Returns null (rather than throwing) if any
/// "d<n>" piece doesn't match a real duration's own ticks-per-whole-
/// note denominator (1/2/4/8/16/32/64) — the caller turns that into a
/// proper [TranscriptionParseError] with the original line/token for
/// context, rather than this low-level helper needing to know
/// anything about line numbers.
/// The [NoteDuration] whose denominator (whole-note-ticks / its own
/// ticks) matches [denominator] — e.g. 4 -> [NoteDuration.quarter] —
/// used to convert a parsed time signature's denominator (from
/// [TranscriptionParseResult.timeSignatureDenominator]) into the
/// [NoteDuration] a real `TimeSignature`'s own `beatDuration` field
/// expects. Returns null for a denominator with no matching standard
/// duration (not 1/2/4/8/16/32/64).
NoteDuration? noteDurationForDenominator(int denominator) {
  for (final d in NoteDuration.values) {
    if (NoteDuration.whole.ticks ~/ d.ticks == denominator) return d;
  }
  return null;
}

List<NoteDuration>? _parseDurationParts(String raw) {
  final parts = <NoteDuration>[];
  for (final m in RegExp(r'[dD](\d+)').allMatches(raw)) {
    final denom = int.parse(m.group(1)!);
    NoteDuration? match;
    for (final d in NoteDuration.values) {
      // NoteDuration doesn't store its own denominator directly, but
      // ticks are already defined as inversely proportional to it
      // (whole=64 ... sixty-fourth=1), so "does this duration's
      // label match d<denom>" is just "whole-note-ticks / d.ticks ==
      // denom", using NoteDuration.whole.ticks as the whole-note
      // reference point.
      if (NoteDuration.whole.ticks ~/ d.ticks == denom) {
        match = d;
        break;
      }
    }
    if (match == null) return null;
    parts.add(match);
  }
  return parts.isEmpty ? null : parts;
}

/// Converts a line-position string ("6", "-5/-4", "-4/-5", ...) into
/// the app's own row number — see this file's own top-level doc
/// comment for the derivation. Returns null for a malformed position
/// (e.g. two line numbers not exactly 1 apart), so the caller can
/// report a precise error rather than silently misplacing the note.
int? _rowForPosition(String position) {
  final slash = position.indexOf('/');
  if (slash == -1) {
    final line = int.tryParse(position);
    if (line == null) return null;
    return 2 * line + 28;
  }
  final aStr = position.substring(0, slash);
  final bStr = position.substring(slash + 1);
  final a = int.tryParse(aStr);
  final b = int.tryParse(bStr);
  if (a == null || b == null) return null;
  final lower = a < b ? a : b;
  final upper = a < b ? b : a;
  if (upper - lower != 1) return null;
  return 2 * lower + 29;
}

/// A degree (1-7) + octave pair — see [_degreeAndOctaveForRow]. A
/// plain class rather than a Dart 3 record (the `(...)` tuple
/// syntax), kept compatible with older Dart SDKs that don't support
/// records.
class _DegreeOctave {
  final int degree;
  final int octave;
  const _DegreeOctave({required this.degree, required this.octave});
}

/// Converts [row] into the (degree, octave) pair [ImportNoteSpec]
/// itself is expressed in — the exact inverse of
/// CompositionController.getDegree's `row % 7 + 1` (degree) and its
/// implicit `row ~/ 7` (octave), just solved the other way around.
/// Dart's `%`/`~/` on a negative [row] (a very low note, below the
/// bottom of this app's own octave 0) would otherwise misbehave —
/// Dart's remainder can come out negative — so this always floors
/// toward negative infinity first, matching how the rest of the app
/// already treats row 0 as the single fixed origin point rather than
/// wrapping negative rows back around into range.
_DegreeOctave _degreeAndOctaveForRow(int row) {
  final octave = row >= 0 ? row ~/ 7 : -(((-row) + 6) ~/ 7);
  final degree = row - octave * 7 + 1;
  return _DegreeOctave(degree: degree, octave: octave);
}

/// Parses one note token's position+accidental (shared by both the
/// plain note-token pattern and the inside-a-chord pattern, which
/// only differ in whether a duration suffix is present) into an
/// [ImportNoteSpec], given the [hand] currently in effect. Returns
/// null for an unrecognized line position (see [_rowForPosition]).
ImportNoteSpec? _noteSpecFromMatch(RegExpMatch match, Hand hand) {
  final position = match.group(1)!;
  final accidentalSign = match.group(2);
  final row = _rowForPosition(position);
  if (row == null) return null;
  final degreeOctave = _degreeAndOctaveForRow(row);
  return ImportNoteSpec(
    degree: degreeOctave.degree,
    octave: degreeOctave.octave,
    accidental:
    accidentalSign == null ? null : _accidentalBySign[accidentalSign],
    hand: hand,
  );
}

/// Tokenizes one line, keeping a parenthesized chord (which contains
/// its own internal commas/spaces) together as a single token rather
/// than letting a naive whitespace split break it into pieces.
List<String> _tokenizeLine(String line) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (final ch in line.split('')) {
    if (ch == '(') depth++;
    if (ch == ')') depth--;
    if (ch.trim().isEmpty && depth == 0) {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
    } else {
      buffer.write(ch);
    }
  }
  if (buffer.isNotEmpty) tokens.add(buffer.toString());
  // An ornament may be written attached with "~" ("d4~trill"): split
  // into its own word.
  final split = <String>[];
  for (final t in tokens) {
    final i = t.indexOf('~');
    if (i > 0) {
      split.add(t.substring(0, i));
      split.add(t.substring(i + 1));
    } else {
      split.add(i == 0 ? t.substring(1) : t);
    }
  }
  // The duration may be written apart from the note ("l2 d8",
  // "(l-1, l0) d4"): joined back to the note before it.
  final joined = <String>[];
  for (final t in split) {
    if (joined.isNotEmpty &&
        _durationOnlyPattern.hasMatch(t) &&
        (_positionOnlyPattern.hasMatch(joined.last) ||
            (joined.last.startsWith('(') && joined.last.endsWith(')')))) {
      joined[joined.length - 1] = joined.last + t;
    } else {
      joined.add(t);
    }
  }
  return joined;
}

/// Grace notes before the next note: g + type letter + positions,
/// e.g. "gs(l5)", "gm(l5, l6+)".
final RegExp _graceTokenPattern = RegExp(r'^g([alms])\(([^()]*)\)$');

final RegExp _durationOnlyPattern = RegExp(r'^(?:[dD]\d+)+(?::\d+)?$');
final RegExp _positionOnlyPattern =
RegExp(r'^[lL]?-?\d+(?:/-?\d+)?(?:\+\+|\+|--|-|x)?$');

/// Converts a beat token's regex match into its numeric beat value —
/// whole + a quarter-beat fraction (.25/.5/.75), or just whole when
/// no fraction suffix is present.
double _beatValueFromMatch(RegExpMatch match) {
  final whole = int.parse(match.group(1)!);
  // A part of the beat: "&a/c" (or the older "+a/c").
  if (match.group(4) != null) {
    final a = int.parse(match.group(4)!);
    final c = int.parse(match.group(5)!);
    if (c > 0 && a < c) return whole + a / c;
  }
  final fractionDigits = match.group(3); // "25", "5", "75", or null
  double fraction;
  switch (fractionDigits) {
    case '25':
      fraction = 0.25;
      break;
    case '75':
      fraction = 0.75;
      break;
    case '5':
      fraction = 0.5;
      break;
    default:
      fraction = 0.0;
  }
  return whole + fraction;
}

/// Parses [text] (the whole pasted/typed transcription) into an
/// [ImportBatch] labeled [label], collecting every problem
/// encountered along the way rather than stopping at the first one —
/// see [TranscriptionParseResult].
TranscriptionParseResult parseCellnotationTranscription(
    String text, {
      required String label,
    }) {
  final errors = <TranscriptionParseError>[];
  final measuresByIndex = <int, List<ImportEvent>>{};
  // Preserves the ORDER measures first appear in, regardless of
  // whether the text revisits an earlier measure number later on
  // (not expected, but not actively prevented either) — matters
  // because ImportBatch.measures is a plain ordered list, not keyed
  // by index.
  final measureOrder = <int>[];

  int? currentMeasureIndex; // 0-based
  Hand? currentHand;
  double? currentBeat;
  // Grace notes waiting for the main note after them.
  GraceNoteType? pendingGraceType;
  var pendingGraces = <ImportNoteSpec>[];
  // True right after a note/chord (and its ornament word): grace notes
  // written now come AFTER that note ("l4 d4 gs(l5)").
  var afterNote = false;
  // Two plain nullable ints rather than a record — see
  // _DegreeOctave's own doc for why records are avoided throughout
  // this file. Reserved for a future mismatch-warning check; not
  // used for any tick math (see this file's own top-level doc
  // comment).
  int? declaredTimeSignatureBeats;
  int? declaredTimeSignatureDenominator;
  String? scaleName;
  int measuresNeeded = 0;

  final lines = text.split('\n');
  for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
    final rawLine = lines[lineIdx];
    final lineNumber = lineIdx + 1;
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) continue;

    // Checked as a WHOLE LINE, before tokenizing — a scale name can
    // itself be more than one word (e.g. "re flat major"), which
    // tokenizing by whitespace would otherwise break into pieces and
    // report as unrecognized tokens. Only the FIRST such line found
    // is kept as the scale — a repeated scale line later in the text
    // is treated as an ordinary (harmless) restatement, not an error.
    final scaleLineMatch = _scaleLinePattern.firstMatch(trimmed);
    if (scaleLineMatch != null) {
      scaleName ??= trimmed.toLowerCase();
      continue;
    }

    for (final token in _tokenizeLine(trimmed)) {
      final wasAfterNote = afterNote;
      afterNote = false;
      // --- Structural tokens -------------------------------------
      final measureMatch = _measureTokenPattern.firstMatch(token);
      if (measureMatch != null) {
        final oneBased = int.parse(measureMatch.group(1)!);
        currentMeasureIndex = oneBased - 1;
        currentHand = null;
        currentBeat = null;
        if (oneBased > measuresNeeded) measuresNeeded = oneBased;
        if (!measuresByIndex.containsKey(currentMeasureIndex)) {
          measuresByIndex[currentMeasureIndex!] = [];
          measureOrder.add(currentMeasureIndex);
        }
        continue;
      }

      final timeSigMatch = _timeSignatureTokenPattern.firstMatch(token);
      if (timeSigMatch != null) {
        declaredTimeSignatureBeats = int.parse(timeSigMatch.group(1)!);
        declaredTimeSignatureDenominator = int.parse(timeSigMatch.group(2)!);
        continue;
      }

      if (token == 'hl') {
        currentHand = Hand.left;
        currentBeat = null;
        continue;
      }
      if (token == 'hr') {
        currentHand = Hand.right;
        currentBeat = null;
        continue;
      }
      if (token == 'ha') {
        currentHand = Hand.additional;
        currentBeat = null;
        continue;
      }

      final beatMatch = _beatTokenPattern.firstMatch(token);
      if (beatMatch != null) {
        currentBeat = _beatValueFromMatch(beatMatch);
        continue;
      }

      // --- Note-bearing tokens need measure/hand/beat established -
      if (currentMeasureIndex == null ||
          currentHand == null ||
          currentBeat == null) {
        errors.add(TranscriptionParseError(
          lineNumber: lineNumber,
          line: rawLine,
          message: currentMeasureIndex == null
              ? 'Note appears before any "m<n>" measure marker.'
              : currentHand == null
              ? 'Note appears before any "hl"/"hr"/"ha" hand marker.'
              : 'Note appears before any "b<n>" beat marker.',
        ));
        continue;
      }

      // --- Ornament word after a note: "l4 d4 trill" ---------------
      final ornament = ornamentForTranscriptionWord(token);
      if (ornament != null) {
        final events = measuresByIndex[currentMeasureIndex]!;
        if (events.isEmpty || events.last.pitches.isEmpty) {
          errors.add(TranscriptionParseError(
            lineNumber: lineNumber,
            line: rawLine,
            message: '"$token" must follow a note or a chord.',
          ));
        } else {
          events[events.length - 1] = events.last.withOrnament(ornament);
          afterNote = wasAfterNote; // grace notes may still follow
        }
        continue;
      }

      // --- Grace notes before the next note: "gs(l5) l4 d4" ---------
      final graceMatch = _graceTokenPattern.firstMatch(token);
      if (graceMatch != null) {
        final specs = <ImportNoteSpec>[];
        for (final piece in graceMatch.group(2)!.trim().split(RegExp(r'[\s,]+'))) {
          if (piece.isEmpty) continue;
          final m = _chordNotePattern.firstMatch(piece);
          final spec = m == null ? null : _noteSpecFromMatch(m, currentHand);
          if (spec == null) {
            errors.add(TranscriptionParseError(
              lineNumber: lineNumber,
              line: rawLine,
              message: 'Unrecognized grace note "$piece" in "$token".',
            ));
            continue;
          }
          specs.add(spec);
        }
        final type = transcriptionGraceTypes[graceMatch.group(1)!];
        final events = measuresByIndex[currentMeasureIndex]!;
        if (wasAfterNote && events.isNotEmpty && events.last.pitches.isNotEmpty) {
          // Right after a note: grace notes AFTER it.
          events[events.length - 1] =
              events.last.withGraces(type, specs, true);
        } else {
          // Before the next note.
          pendingGraceType = type;
          pendingGraces = specs;
        }
        continue;
      }

      // --- Rest ------------------------------------------------------
      final restMatch = _restTokenPattern.firstMatch(token);
      if (restMatch != null) {
        final durationParts = _parseDurationParts(restMatch.group(1)!);
        if (durationParts == null) {
          errors.add(TranscriptionParseError(
            lineNumber: lineNumber,
            line: rawLine,
            message: 'Unrecognized rest duration in "$token".',
          ));
          continue;
        }
        measuresByIndex[currentMeasureIndex]!.add(ImportEvent(
          beat: currentBeat,
          durationParts: durationParts,
          pitches: const [],
          tuplet: int.tryParse(restMatch.group(2) ?? '') ?? 1,
        ));
        continue;
      }

      // --- Chord -------------------------------------------------------
      final chordMatch = _chordTokenPattern.firstMatch(token);
      if (chordMatch != null) {
        final inner = chordMatch.group(1)!.trim();
        final durationParts = _parseDurationParts(chordMatch.group(2)!);
        if (durationParts == null) {
          errors.add(TranscriptionParseError(
            lineNumber: lineNumber,
            line: rawLine,
            message: 'Unrecognized chord duration in "$token".',
          ));
          continue;
        }
        final pitches = <ImportNoteSpec>[];
        var chordOk = true;
        // Notes inside a chord are comma-separated (optionally with
        // surrounding whitespace, e.g. "-5/-4, -1, 0" or
        // "-5/-4,-1,0") — per request.
        // Notes in a chord are separated by spaces and/or commas:
        // "(l-5/-4 l-1 l0)" or "(l-5/-4, l-1, l0)".
        for (final notePiece in inner.split(RegExp(r'[\s,]+'))) {
          if (notePiece.isEmpty) continue;
          final noteMatch = _chordNotePattern.firstMatch(notePiece);
          if (noteMatch == null) {
            errors.add(TranscriptionParseError(
              lineNumber: lineNumber,
              line: rawLine,
              message:
              'Unrecognized note "$notePiece" inside chord "$token".',
            ));
            chordOk = false;
            continue;
          }
          final spec = _noteSpecFromMatch(noteMatch, currentHand);
          if (spec == null) {
            errors.add(TranscriptionParseError(
              lineNumber: lineNumber,
              line: rawLine,
              message:
              'Unrecognized line position in "$notePiece" inside chord "$token".',
            ));
            chordOk = false;
            continue;
          }
          pitches.add(spec);
        }
        if (!chordOk || pitches.isEmpty) continue;
        measuresByIndex[currentMeasureIndex]!.add(ImportEvent(
          beat: currentBeat,
          durationParts: durationParts,
          pitches: pitches,
          tuplet: int.tryParse(chordMatch.group(3) ?? '') ?? 1,
          graceType: pendingGraces.isEmpty ? null : pendingGraceType,
          graces: pendingGraces,
        ));
        pendingGraces = <ImportNoteSpec>[];
        pendingGraceType = null;
        afterNote = true;
        continue;
      }

      // --- Plain single note -------------------------------------------
      final noteMatch = _noteTokenPattern.firstMatch(token);
      if (noteMatch != null) {
        final durationParts = _parseDurationParts(noteMatch.group(3)!);
        if (durationParts == null) {
          errors.add(TranscriptionParseError(
            lineNumber: lineNumber,
            line: rawLine,
            message: 'Unrecognized duration in "$token".',
          ));
          continue;
        }
        final spec = _noteSpecFromMatch(noteMatch, currentHand);
        if (spec == null) {
          errors.add(TranscriptionParseError(
            lineNumber: lineNumber,
            line: rawLine,
            message: 'Unrecognized line position in "$token".',
          ));
          continue;
        }
        measuresByIndex[currentMeasureIndex]!.add(ImportEvent(
          beat: currentBeat,
          durationParts: durationParts,
          pitches: [spec],
          tuplet: int.tryParse(noteMatch.group(4) ?? '') ?? 1,
          graceType: pendingGraces.isEmpty ? null : pendingGraceType,
          graces: pendingGraces,
        ));
        pendingGraces = <ImportNoteSpec>[];
        pendingGraceType = null;
        afterNote = true;
        continue;
      }

      // --- Nothing matched ----------------------------------------------
      errors.add(TranscriptionParseError(
        lineNumber: lineNumber,
        line: rawLine,
        message: 'Unrecognized token "$token".',
      ));
    }
  }

  final measures = [
    for (final idx in measureOrder)
      ImportMeasure(measureIndex: idx, events: measuresByIndex[idx]!),
  ];

  return TranscriptionParseResult(
    batch: ImportBatch(label: label, measures: measures),
    errors: errors,
    scaleName: scaleName,
    timeSignatureBeats: declaredTimeSignatureBeats,
    timeSignatureDenominator: declaredTimeSignatureDenominator,
    measuresNeeded: measuresNeeded,
  );
}

// =====================================================================
// EXPORT — the inverse of everything above: converting ImportMeasures
// (see CompositionController.exportMeasureRange) back into this same
// notation text, so a range can be exported, edited by hand, and
// pasted straight back into sheetMusicTranscriptionDialog for a clean
// round trip.
// =====================================================================

/// The exact inverse of [_rowForPosition] — converts a row back into
/// its line-position string ("6", "-5/-4", ...). See this file's own
/// top-level doc comment for the row <-> line-position relationship
/// this mirrors. Public (not `_positionForRow`) so
/// transcription_column_widget.dart can reuse the exact same
/// conversion, rather than duplicating it.
String positionForRow(int row) {
  final offset = row - 28;
  if (offset % 2 == 0) {
    return (offset ~/ 2).toString();
  }
  // Dart's `%` can return a negative remainder for a negative
  // dividend (e.g. -1 % 2 == -1, not 1) — floor-dividing instead of
  // truncating keeps the "between lines" case correct for rows below
  // line 0 too.
  final lower = ((offset - 1) / 2).floor();
  return '$lower/${lower + 1}';
}

/// The exact inverse of [_parseDurationParts] — converts a list of
/// [NoteDuration] parts back into its "d<n>" code(s), concatenated
/// for a dotted/tied note (e.g. [half, quarter] -> "d2d4").
String _durationCodeFor(List<NoteDuration> parts) {
  return parts.map((d) {
    final denominator = NoteDuration.whole.ticks ~/ d.ticks;
    return 'd$denominator';
  }).join();
}

/// The exact inverse of [_accidentalBySign] — [Accidental.sign]
/// already matches this notation's own signs exactly, so this is
/// just a direct passthrough kept here for symmetry with the parsing
/// side.
String _accidentalCodeFor(Accidental? accidental) => accidental?.sign ?? '';

/// One pitch's position+accidental (no duration — see
/// [ImportEvent]/[ImportNoteSpec]'s own doc for why a chord's shared
/// duration is written once, separately, rather than per note).
String _pitchCodeFor(ImportNoteSpec pitch) =>
    '${positionForRow(pitch.row)}${_accidentalCodeFor(pitch.accidental)}';

/// One event's full token — a rest ("rd4"), a single note
/// ("6+d4"), or a chord ("(-5/-4, -1, 0)d4") — exactly matching
/// whichever of the three forms [parseCellnotationTranscription]
/// itself would read back into the same [ImportEvent].
String _eventTokenFor(ImportEvent event) {
  final core = _noteTokenFor(event);
  final graceType = event.graceType;
  final graces = graceType == null || event.graces.isEmpty
      ? ''
      : 'g${transcriptionLetterForGrace(graceType)}'
      '(${event.graces.map((p) => 'l${_pitchCodeFor(p)}').join(', ')}) ';
  final word = transcriptionWordForOrnament(event.ornament);
  final withWord = '$core${word == null ? '' : ' $word'}';
  if (graces.isEmpty) return withWord;
  // Before the note: "gs(l5) l4 d4"; after it: "l4 d4 gs(l5)".
  return event.graceAfter
      ? '$withWord ${graces.trimRight()}'
      : '$graces$withWord';
}

String _noteTokenFor(ImportEvent event) {
  final durationCode = _durationCodeFor(event.durationParts) +
      (event.tuplet > 1 ? ':${event.tuplet}' : '');
  if (event.pitches.isEmpty) {
    return 'r$durationCode';
  }
  if (event.pitches.length == 1) {
    return 'l${_pitchCodeFor(event.pitches.first)} $durationCode';
  }
  // "l" (line) before every note position: l2 d8, (l-1, l0) d4.
  final inner = event.pitches.map((p) => 'l${_pitchCodeFor(p)}').join(', ');
  return '($inner) $durationCode';
}

/// The beat marker for [beat] — "b3", "b1.25", "b1.5", "b1.75" — the
/// exact inverse of [_beatValueFromMatch]. A [beat] that doesn't land
/// on a whole quarter-beat at all (shouldn't normally happen, since
/// nothing on the import side can produce one) rounds to the nearest
/// quarter-beat rather than emitting a fraction this notation can't
/// actually represent.
String _beatMarkerFor(double beat) {
  return beatMarker(beat);
}

/// The beat marker for [beat] (1-based, with its fraction): "b3",
/// "b1&1/2", "b1&3/4", "b2&1/3"…
String beatMarker(double beat) {
  var whole = beat.floor();
  final fraction = beat - whole;
  if (fraction < 1e-6) return 'b$whole';
  if (fraction > 1 - 1e-6) return 'b${whole + 1}';
  for (int c = 2; c <= 128; c++) {
    final a = (fraction * c).round();
    if ((fraction * c - a).abs() < 1e-6) {
      final g = a.gcd(c);
      return 'b$whole&${a ~/ g}/${c ~/ g}';
    }
  }
  // (not a simple fraction: the nearest 64th of the beat)
  final a = (fraction * 64).round();
  final g = a.gcd(64);
  return 'b$whole&${a ~/ g}/${64 ~/ g}';
}

/// Converts [measures] (see CompositionController.exportMeasureRange)
/// back into the line-position notation text
/// [parseCellnotationTranscription] reads — a clean round trip: export
/// a range, edit it by hand if needed, and paste it straight back into
/// sheetMusicTranscriptionDialog.
///
/// [scaleName]/[timeSignatureBeats]/[timeSignatureDenominator], when
/// all three are provided, are written as the leading "<scale>" and
/// "t<beats>/<denominator>" lines — omitted entirely if any is null,
/// since a range spanning measures with different scales/time
/// signatures has no single correct header line to write (the person
/// exporting can add per-measure headers by hand if that's ever
/// needed — this notation doesn't have a way to declare a MID-range
/// scale/time-signature change).
///
/// Within each measure, events are grouped by hand (right, then
/// left, then additional — skipping any hand with no events in this
/// measure at all) and sorted by beat within each group, matching
/// the order every hand-section appears in throughout this file's
/// own examples.
///
/// A rest ([ImportEvent.pitches] empty) carries no hand of its own to
/// group it by, so it's silently skipped here — this is never
/// actually a problem in practice, since
/// CompositionController.exportMeasureRange (the normal source of
/// [measures]) only ever builds an event from a real Note, and a
/// rest is simply the ABSENCE of one — it's never represented as its
/// own [ImportEvent] on the way out, only ever on the way IN (typed
/// by hand, to mark a silence while transcribing).
String formatMeasuresAsCellnotationText(
    List<ImportMeasure> measures, {
      String? scaleName,
      int? timeSignatureBeats,
      int? timeSignatureDenominator,
    }) {
  final buffer = StringBuffer();

  if (scaleName != null &&
      timeSignatureBeats != null &&
      timeSignatureDenominator != null) {
    buffer.writeln(scaleName);
    buffer.writeln('t$timeSignatureBeats/$timeSignatureDenominator');
  }

  for (final measure in measures) {
    buffer.writeln('m${measure.measureIndex + 1}');

    for (final hand in [Hand.right, Hand.left, Hand.additional]) {
      final handEvents = measure.events
          .where((e) => e.pitches.isNotEmpty && e.pitches.first.hand == hand)
          .toList()
        ..sort((a, b) => a.beat.compareTo(b.beat));
      if (handEvents.isEmpty) continue;

      final handMarker = switch (hand) {
        Hand.right => 'hr',
        Hand.left => 'hl',
        Hand.additional => 'ha',
      };

      final tokens = handEvents
          .map((e) => '${_beatMarkerFor(e.beat)} ${_eventTokenFor(e)}')
          .join(' ');
      buffer.writeln('$handMarker $tokens');
    }
  }

  return buffer.toString().trimRight();
}