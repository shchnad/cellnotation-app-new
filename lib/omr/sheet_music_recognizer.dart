import 'dart:math' as math;
import 'dart:typed_data';

/// On-device recognition of printed piano sheet music (one page image)
/// into the app's line-position transcription ("cellnotation"), the
/// same text sheet_music_transcription_dialog.dart imports.
///
/// Pure Dart, no Flutter imports, so it can run in a background
/// isolate (see omr_service.dart). Classic image analysis, step by
/// step:
///   1. grayscale -> black/white, rescaled so the gap between staff
///      lines is about [_targetSpacing] pixels;
///   2. staff lines found from the row projection (a 5-line comb),
///      then traced across the page (pages are often slightly tilted)
///      and erased;
///   3. pairs of staves = one piano system (upper = right hand / treble
///      clef, lower = left hand / bass clef); bar lines = thin vertical
///      lines running through both staves;
///   4. filled noteheads = blobs that survive an erosion that removes
///      lines, stems, beams and text; hollow noteheads (half, whole) =
///      small enclosed white holes with a notehead-sized ring;
///   5. stems (filled and half notes always have one), then beams and
///      flags counted at the stem's far end -> duration; a dot right of
///      the head -> dotted;
///   6. accidentals (sharp, flat, natural, double sharp, double flat)
///      from the shape of the sign just left of each head;
///   7. pitch = the head's position on the staff, written exactly as
///      the transcription does (line numbers: treble bottom line 1 ...
///      top line 5, bass top line -1 ... bottom line -5, middle C 0);
///   8. the time signature is worked out from how much music each
///      measure holds, and every note gets its beat.
///
/// Works best on clean digital PDFs; scans and photos give more
/// mistakes (the AI option in the import screen handles those better).
/// Assumes piano music: every system is a treble staff above a bass
/// staff. Rests, ties, grace notes, clefs changes and key signatures
/// are not read — the person chooses the key in the import screen.

const double _targetSpacing = 14.0;

// =====================================================================
// Public results
// =====================================================================

class OmrNote {
  /// Line position, e.g. "4", "4/5", "-5/-4" (lower number first).
  final String position;

  /// '', '+', '++', '-', '--' or 'x'.
  final String accidental;

  /// Vertical centre on the page (used for ordering low -> high).
  final double y;

  OmrNote(this.position, this.accidental, this.y);
}

class OmrEvent {
  /// Left edge of the chord on the page.
  final double x;

  /// Duration in 1/128ths of a whole note (quarter = 32);
  /// [wholeMeasure] for a whole-measure rest.
  final int duration;

  /// Empty for a rest.
  final List<OmrNote> notes;

  static const int wholeMeasure = -1;

  bool get isRest => notes.isEmpty;

  /// A wavy arpeggio line was found before this chord.
  final bool arpeggio;

  /// A note of a tuplet: 3 for a triplet (3 in the time of 2), 5, 6, 7…;
  /// 1 for an ordinary note. Its real length is [duration] ×
  /// 2/3 (triplet), 4/5, 4/6, 4/7.
  int tuplet;

  /// The tuplet number ("3") was found printed over/under it.
  bool tupletPrinted = false;

  /// Highest and lowest point of the chord (heads and stem end) on the
  /// page — to tell whether a tuplet number belongs to it.
  final double top;
  final double bottom;

  OmrEvent(this.x, this.duration, this.notes,
      {this.arpeggio = false, this.tuplet = 1, this.top = 0, this.bottom = 0});
}

class OmrMeasure {
  final double x0;
  final double x1;

  /// Staff spacing on the (rescaled) page this measure came from.
  final double spacing;

  /// 'hr' (upper staff) and 'hl' (lower staff) events, sorted by x.
  final Map<String, List<OmrEvent>> hands;

  /// Repeat barlines: 𝄆 at the start / 𝄇 at the end of the measure.
  final bool repeatStart;
  final bool repeatEnd;

  /// Key signature written at the start of this measure (the first of
  /// a system, or a key change): +n sharps, -n flats, 0 none; null when
  /// nothing is written (the key goes on).
  final int? key;

  OmrMeasure(this.x0, this.x1, this.spacing, this.hands,
      {this.repeatStart = false, this.repeatEnd = false, this.key});

  bool get isEmpty =>
      (hands['hr'] ?? const []).isEmpty && (hands['hl'] ?? const []).isEmpty;
}

class OmrPageResult {
  final int staffCount;
  final int systemCount;
  final List<OmrMeasure> measures;

  OmrPageResult(this.staffCount, this.systemCount, this.measures);
}

/// Recognizes one page. [gray] holds width*height luminance bytes
/// (0 = black, 255 = white), row by row.
OmrPageResult recognizeSheetMusicPage(Uint8List gray, int width, int height) {
  final page = _prepare(_Gray(width, height, gray));
  final bw = page.bw;

  var staves = _findStavesInStrips(page.lines);
  if (staves.length < 2) {
    return OmrPageResult(staves.length, 0, const []);
  }
  final spLt = _estimateSpacing(page.lines);
  for (final s in staves) {
    s.lt = spLt.lt;
  }
  _analyseStaves(page.lines, staves);
  final nos = _removeStaffLines(bw, staves);
  final spacings = staves.map((s) => s.sp).toList()..sort();
  final sp = _median(spacings);

  // Keep real staves only: their lines run a good part of the way.
  // (Specks in a dark page corner or a line of text can look like a
  // staff for a moment.)
  staves = staves
      .where((s) => s.x1 - s.x0 >= 8 * sp && _lineCoverage(s) >= 0.25)
      .toList();

  final hollow = _findHollowHeads(bw, sp);
  // (and those whose hole a staff line cuts in two)
  for (final h in _findHollowHeads(bw, sp, nos)) {
    if (!hollow.any((g) => (h.cx - g.cx).abs() < 0.5 * sp && (h.cy - g.cy).abs() < 0.5 * sp)) {
      hollow.add(h);
    }
  }
  // The centre of a hollow head is the middle of its ring (the hole
  // alone can be cut short by a staff line running through it).
  for (int i = 0; i < hollow.length; i++) {
    final h = hollow[i];
    final tops = <int>[], bots = <int>[];
    for (int x = h.cx.toInt() - 1; x <= h.cx.toInt() + 1; x++) {
      if (x < 0 || x >= nos.w) continue;
      int y = h.cy.round();
      while (y > 0 && !nos.at(x, y) && h.cy - y < sp) {
        y--;
      }
      while (y > 0 && nos.at(x, y - 1) && h.cy - y < 1.2 * sp) {
        y--;
      }
      tops.add(y);
      y = h.cy.round();
      while (y < nos.h - 1 && !nos.at(x, y) && y - h.cy < sp) {
        y++;
      }
      while (y < nos.h - 1 && nos.at(x, y + 1) && y - h.cy < 1.2 * sp) {
        y++;
      }
      bots.add(y);
    }
    if (tops.isEmpty) continue;
    tops.sort();
    bots.sort();
    final t = tops[tops.length ~/ 2].toDouble(), b = bots[bots.length ~/ 2].toDouble();
    if (0.6 * sp <= b - t && b - t <= 1.3 * sp && ((t + b) / 2 - h.cy).abs() <= 0.4 * sp) {
      hollow[i] = _Head(h.x0, h.x1, h.cx, (t + b) / 2, false, whole: h.whole);
    }
  }
  var heads = <_Head>[..._findFilledHeads(bw, sp, nos), ...hollow];
  final index = _CompIndex(_components(nos, eight: true), nos);

  for (final h in heads) {
    if (h.filled) h.stem = _findStem(nos, h, sp);
  }
  // A piece of a beam can look like a filled notehead (blurred photos
  // make beams thick). It sits at the far end of a real note's stem
  // and "finds" that same stem, running the other way.
  final beamPieces = <_Head>{
    for (final h in heads)
      if (h.filled && _isBeamPiece(nos, h, heads, sp)) h
  };
  heads = heads.where((h) => !beamPieces.contains(h)).toList();
  // Hollow candidates next to a stemmed filled note are holes in its
  // sharp, its flag or between chord notes — not half notes.
  final stemmed = heads.where((h) => h.filled && h.stem != null).toList();
  bool nearFilled(_Head h) {
    for (final f in stemmed) {
      if ((f.cx - h.cx).abs() < 2.2 * sp) {
        final st = f.stem!;
        final ylo = math.min(f.cy, st.end.toDouble()) - 1.2 * sp;
        final yhi = math.max(f.cy, st.end.toDouble()) + 1.2 * sp;
        if (ylo <= h.cy && h.cy <= yhi) return true;
      }
    }
    return false;
  }

  heads = heads.where((h) => h.filled || !nearFilled(h)).toList();
  for (final h in heads) {
    if (!h.filled) {
      h.stem = _findStem(nos, h, sp);
      // A half note's stem is a full one; letters like the "d" of
      // "dolce" have a short one.
      if (h.stem != null && h.stem!.len < 2.8 * sp) h.stem = null;
    }
  }
  // Stemless filled heads may be the far head of a second in a chord.
  final loose = heads.where((h) => h.filled && h.stem == null).toList();
  heads = heads.where((h) => h.stem != null || h.whole).toList();
  final headCentres = [for (final h in heads) [h.cx, h.cy]];
  final bt = _beamThickness(nos, heads, sp);
  // Every stem as (x, top row, bottom row).
  final stems = [
    for (final h in heads)
      if (h.stem != null)
        [
          h.stem!.x.toDouble(),
          math.min(h.cy, h.stem!.end.toDouble()),
          math.max(h.cy, h.stem!.end.toDouble()),
        ]
  ];
  index.stems = stems;

  // Pair staves into piano systems: the two staves of a system are
  // closer together than one system is to the next.
  final pairs = <List<_Staff>>[];
  // An even number of staves, all pairing up neatly in order (each pair
  // close and side by side): that is the page — a gap that is a little
  // wide (high bass notes, low treble notes) does not matter then.
  if (staves.length.isEven && staves.length >= 2) {
    final neat = [
      for (int k = 0; k + 1 < staves.length; k += 2) [staves[k], staves[k + 1]]
    ];
    bool ok = neat.every((p) =>
    p[1].lines[0] - p[0].lines[4] <= 12 * sp &&
        math.min(p[0].x1, p[1].x1) - math.max(p[0].x0, p[1].x0) >= 8 * sp);
    if (ok && neat.length >= 2) {
      double maxInside = 0, minBetween = double.infinity;
      for (int k = 0; k < neat.length; k++) {
        maxInside = math.max(maxInside, neat[k][1].lines[0] - neat[k][0].lines[4]);
        if (k + 1 < neat.length) {
          minBetween = math.min(minBetween, neat[k + 1][0].lines[0] - neat[k][1].lines[4]);
        }
      }
      ok = maxInside < 1.5 * minBetween;
    }
    if (ok) pairs.addAll(neat);
  }
  for (int i = pairs.isEmpty ? 0 : staves.length; i + 1 < staves.length;) {
    final a = staves[i], b = staves[i + 1];
    final gap = b.lines[0] - a.lines[4];
    final overlap = math.min(a.x1, b.x1) - math.max(a.x0, b.x0);
    final next = i + 2 < staves.length ? staves[i + 2].lines[0] - b.lines[4] : null;
    if (gap <= 12 * sp && overlap >= 8 * sp && (next == null || gap <= next + 2 * sp)) {
      pairs.add([a, b]);
      i += 2;
    } else {
      i += 1;
    }
  }

  final measures = <OmrMeasure>[];
  int systems = 0;
  // An octave sign still running at the end of a system, per hand.
  final carriedOctave = <String, int?>{'hr': null, 'hl': null};
  for (final pair in pairs) {
    systems++;
    final tr = pair[0];
    final bs = pair[1];
    final x0 = math.max(tr.x0, bs.x0);
    final x1 = math.min(tr.x1, bs.x1);
    var bars = _findBarlines(nos, tr, bs, x0, x1, sp);
    // The first bar line is the system's left edge.
    if (bars.isEmpty || bars.first - x0 > 2 * sp) {
      bars = [x0.toDouble(), ...bars];
    }
    if (x1 - bars.last > 3 * sp) bars.add(x1.toDouble());

    // Music starts after the clef / key / time signature.
    final infos = {'hr': _HeaderInfo(), 'hl': _HeaderInfo()};
    final headerEnd = {
      'hr': _staffHeaderEnd(index, tr, x0.toDouble(), sp, stems, heads, nos, infos['hr']),
      'hl': _staffHeaderEnd(index, bs, x0.toDouble(), sp, stems, heads, nos, infos['hl']),
    };
    // Key signature of the system: the signs between the clef and the
    // time signature (or the first note).
    final keyCounts = <List<int>>[];
    for (final hand in const ['hr', 'hl']) {
      final inf = infos[hand]!;
      if (inf.clefEnd == null) continue;
      final ke = inf.timeX ?? inf.end ?? inf.clefEnd!;
      keyCounts.add(_signCounts(_keySignList(
          nos, hand == 'hr' ? tr : bs, inf.clefEnd! + 0.2 * sp, ke - 0.1 * sp, sp)));
    }
    // (No sign read at all: the key goes on from before — a real
    // change back to C major / A minor shows naturals, read as 0.)
    final int? systemKey =
    keyCounts.isEmpty ? null : _keyFromCounts(keyCounts);

    // 8va / 15ma lines over the treble staff, 8vb / 15mb under the bass
    // staff. A line going on from the previous system keeps its sign.
    final octaveLines = <String, List<_OctaveLine>>{
      'hr': _findOctaveLines(index, tr, true, x0.toDouble(), x1.toDouble(), sp,
          heads, carriedOctave['hr']),
      'hl': _findOctaveLines(index, bs, false, x0.toDouble(), x1.toDouble(), sp,
          heads, carriedOctave['hl']),
    };
    for (final hand in const ['hr', 'hl']) {
      final lines = octaveLines[hand]!;
      carriedOctave[hand] =
      lines.isNotEmpty && lines.last.x1 >= x1 - 3 * sp ? lines.last.octaves : null;
    }
    // The "8" / "15" of a sign is not a note.
    final signBoxes = [
      for (final l in [...octaveLines['hr']!, ...octaveLines['hl']!])
        if (l.glyph != null) l.glyph!
    ];
    bool inSign(_Head h) => signBoxes.any((b) =>
    b[0] - 0.2 * sp <= h.cx && h.cx <= b[2] + 0.2 * sp &&
        b[1] - 0.2 * sp <= h.cy && h.cy <= b[3] + 0.2 * sp);

    for (int mi = 0; mi + 1 < bars.length; mi++) {
      final mx0 = bars[mi];
      final mx1 = bars[mi + 1];
      // A new key signature right after the bar line.
      double mstart = mx0;
      int? mkey = mi == 0 ? systemKey : null;
      if (mi > 0) {
        final change = _keyChangeAt(nos, [tr, bs], mx0, sp, heads);
        if (change != null) {
          mkey = change[0].round();
          mstart = change[1];
        }
      }
      final hands = <String, List<OmrEvent>>{};
      for (final hand in const ['hr', 'hl']) {
        final treble = hand == 'hr';
        final st = treble ? tr : bs;
        // Which staff a head belongs to is decided at its own x (on a
        // tilted or bent page the staves are not level).
        bool inStaff(_Head h) {
          final m = (_lineY(tr, 4, h.cx) + _lineY(bs, 0, h.cx)) / 2;
          // Hollow "notes" far from the staff are letters of text
          // between the staves (e.g. the "o" of "dolce").
          final reach = h.filled ? 6 * sp : 3 * sp;
          if (treble) {
            return _lineY(tr, 0, h.cx) - reach < h.cy &&
                h.cy < math.min(m, _lineY(tr, 4, h.cx) + reach);
          }
          return math.max(m, _lineY(bs, 0, h.cx) - reach) < h.cy &&
              h.cy < _lineY(bs, 4, h.cx) + reach;
        }

        // A hollow "note" whose stem is a bar line is a letter touching
        // the bar line.
        bool onBar(_Head h) =>
            !h.filled &&
                h.stem != null &&
                bars.any((b) => (h.stem!.x - b).abs() <= 0.6 * sp);

        final start = math.max(mstart, headerEnd[hand]!);
        final hs = heads
            .where((h) =>
        start + 0.3 * sp < h.cx &&
            h.cx < mx1 - 0.3 * sp &&
            inStaff(h) &&
            !onBar(h) &&
            !inSign(h))
            .toList();

        final chords = <_Chord>[];
        for (final h in hs) {
          final stem = h.stem;
          if (stem == null && (h.filled || !h.whole)) continue;
          if (stem != null) {
            _Chord? found;
            for (final c in chords) {
              if (c.stem != null &&
                  (c.stem!.x - stem.x).abs() <= 3 &&
                  c.stem!.dir == stem.dir) {
                found = c;
                break;
              }
            }
            if (found == null) {
              chords.add(_Chord(stem, [h], h.filled));
            } else {
              found.heads.add(h);
              if (stem.len > found.stem!.len) found.stem = stem;
            }
          } else {
            // Whole notes stacked on top of each other are one chord.
            _Chord? stack;
            for (final c in chords) {
              if (c.stem == null && (c.heads.first.cx - h.cx).abs() < 0.6 * sp) {
                stack = c;
                break;
              }
            }
            if (stack != null) {
              stack.heads.add(h);
            } else {
              chords.add(_Chord(null, [h], false));
            }
          }
        }
        // Attach a chord's displaced head (the other note of a second
        // sits on the far side of the stem, touching it).
        for (final h in loose) {
          if (!(mx0 < h.cx && h.cx < mx1 && inStaff(h))) continue;
          for (final c in chords) {
            final st = c.stem;
            if (st == null) continue;
            if ((h.cx - st.x).abs() > 1.0 * sp) continue;
            if (!c.heads.any((o) => (h.cy - o.cy).abs() <= 1.1 * sp)) {
              // Farther off, at the stem's open end, with the stem
              // running on to it (e.g. a second at the top of a chord).
              var edge = c.heads.first;
              for (final o in c.heads) {
                if (st.dir == 1 ? o.cy < edge.cy : o.cy > edge.cy) edge = o;
              }
              final beyond = st.dir == 1 ? h.cy < edge.cy : h.cy > edge.cy;
              if (!beyond || (h.cy - edge.cy).abs() > 2.8 * sp) continue;
              final ya = math.min(h.cy, edge.cy).toInt(), yb = math.max(h.cy, edge.cy).toInt();
              bool reached = true;
              for (int yy = ya; yy <= yb && reached; yy++) {
                bool any = false;
                for (int xx = st.x - 1; xx <= st.x + 1; xx++) {
                  if (xx >= 0 && xx < nos.w && yy >= 0 && yy < nos.h && nos.at(xx, yy)) any = true;
                }
                reached = any;
              }
              if (!reached) continue;
            }
            c.heads.addAll(_splitSecond(nos, h, st.x, sp));
            break;
          }
        }

        final events = <OmrEvent>[];
        for (final c in chords) {
          // De-duplicate heads found twice at the same place.
          final sorted = [...c.heads]..sort((a, b) => a.cy.compareTo(b.cy));
          final hs2 = <_Head>[];
          for (final h in sorted) {
            if (hs2.isNotEmpty &&
                (h.cy - hs2.last.cy).abs() < 0.35 * sp &&
                (h.cx - hs2.last.cx).abs() < 0.5 * sp) {
              continue;
            }
            hs2.add(h);
          }
          final stem = c.stem;
          if (stem != null && c.filled) {
            final more = _extendChord(nos, hs2, stem, sp);
            hs2
              ..clear()
              ..addAll(more);
          }
          int dur;
          if (stem == null) {
            dur = 128; // whole note
          } else if (!c.filled) {
            dur = 64; // half note
          } else {
            // The head closest to the stem's far end.
            double near = hs2.first.cy;
            for (final h in hs2) {
              if (stem.dir == -1 ? h.cy < near : h.cy > near) near = h.cy;
            }
            final n = _countBars(nos, stem.x, stem.dir, stem.end, near, sp, bt);
            dur = const [32, 16, 8, 4][n];
          }
          double cx1 = hs2.first.x1;
          for (final h in hs2) {
            cx1 = math.max(cx1, h.x1);
          }
          if (hs2.any((h) => _hasDot(index, cx1, h.cy, sp))) {
            dur = dur * 3 ~/ 2;
          }
          final notes = <OmrNote>[];
          for (final h in hs2) {
            final pos = _positionOf(st, treble, h.cx, h.cy,
                _octaveShiftAt(octaveLines[hand]!, h.cx, sp));
            final acc = _classifyAccidental(index, h, sp, mx0 + 2, headCentres);
            notes.add(OmrNote(pos, acc, h.cy));
          }
          double ex = hs2.first.x0;
          for (final h in hs2) {
            ex = math.min(ex, h.x0);
          }
          final arp = hs2.length >= 2 && _hasArpeggio(nos, index, hs2, sp);
          double top = hs2.first.cy, bottom = hs2.first.cy;
          for (final h in hs2) {
            top = math.min(top, h.cy);
            bottom = math.max(bottom, h.cy);
          }
          if (stem != null) {
            top = math.min(top, stem.end.toDouble());
            bottom = math.max(bottom, stem.end.toDouble());
          }
          events.add(OmrEvent(ex, dur, notes,
              arpeggio: arp, top: top, bottom: bottom));
        }
        final staffHeads = heads.where(inStaff).toList();
        for (final r in _findRests(
            index, st, mx0, mx1, sp, staffHeads, stems,
            math.max(headerEnd[hand]!, mstart))) {
          events.add(OmrEvent(r[0].toDouble(), r[1], const []));
        }
        events.sort((a, b) => a.x.compareTo(b.x));
        // Tuplet numbers ("3"…) over or under a group of notes.
        _markTuplets(
            _tupletNumerals(index, st, mx0, mx1, sp, heads), events, sp);
        hands[hand] = events;
      }
      // Repeat barlines: dots left of the closing bar line / right of
      // the opening one.
      measures.add(OmrMeasure(mx0, mx1, sp, hands,
          key: mkey,
          repeatStart: mi > 0 && _repeatDots(index, [tr, bs], mx0, sp)[1],
          repeatEnd: _repeatDots(index, [tr, bs], mx1, sp)[0]));
    }
  }
  return OmrPageResult(staves.length, systems, measures);
}

// =====================================================================
// Transcription text
// =====================================================================

/// Turns recognized measures (of one or more pages, in order) into the
/// line-position transcription text. [scaleName] is written as the
/// first line (e.g. "do major"); when the scale has sharps or flats,
/// a recognized natural sign is written as "x", otherwise it is simply
/// left out (the note is already natural).
///
/// The time signature is chosen from how much music the measures hold
/// (the most consistent of the usual meters), and the beat unit is a
/// quarter — or an eighth when the music has thirty-second notes or
/// the meter isn't a whole number of quarters (so every note still
/// falls on a quarter-of-a-beat position).
/// The grid a note of [dur] (1/128ths) starts on: its own length — a
/// quarter starts on a beat, an eighth on an eighth… — at most [unit].
int _noteGrid(int dur, int unit) {
  int g = unit;
  while (g > 4 && g > dur) {
    g ~/= 2;
  }
  return g;
}

/// Time is counted in 1/(128 × [_tupletScale]) of a whole note inside
/// [_measureOnsets], so the notes of triplets, quintuplets and
/// septuplets (2/3, 4/5, 4/7 of their written length) are whole numbers.
const int _tupletScale = 105; // 3 × 5 × 7

/// The real length of [e] in 1/(128 × [_tupletScale]) — its written
/// length, shortened when it is a note of a tuplet.
int _effectiveDuration(OmrEvent e) {
  final k = e.tuplet;
  final d = e.duration * _tupletScale;
  if (k <= 1) return d;
  if (k == 2) return d * 3 ~/ 2;
  int p = 1;
  while (p * 2 < k) {
    p *= 2;
  }
  return d * p ~/ k;
}

/// Start time (1/(128 × [_tupletScale]) from the bar line) of every
/// event of each hand
/// of [m]. A hand whose durations fill the measure exactly is placed
/// note after note. The other hand's notes take the start of the note
/// right above / below them (notes under each other start together),
/// else the time between such known points by their x position, snapped
/// to the grid of their own length — so notes start where cells start.
/// [meter] and [unit] are in 1/128ths.
Map<String, List<int>> _measureOnsets(OmrMeasure m, int meter, int unit) {
  final sp = m.spacing;
  final hands = <String, List<OmrEvent>>{};
  for (final hand in const ['hr', 'hl']) {
    hands[hand] = [
      for (final e in m.hands[hand] ?? const <OmrEvent>[])
        e.duration == OmrEvent.wholeMeasure ? OmrEvent(e.x, meter, e.notes) : e
    ];
  }
  final meterS = meter * _tupletScale;
  final result = <String, List<int>>{};
  final anchors = <List<double>>[]; // [x, t]
  for (final hand in const ['hr', 'hl']) {
    final ev = hands[hand]!;
    final total = ev.fold<int>(0, (s, e) => s + _effectiveDuration(e));
    if (ev.isNotEmpty && total == meterS) {
      int t = 0;
      final starts = <int>[];
      for (final e in ev) {
        starts.add(t);
        anchors.add([e.x, t.toDouble()]);
        t += _effectiveDuration(e);
      }
      result[hand] = starts;
    }
  }
  final xs = [for (final ev in hands.values) for (final e in ev) e.x];
  if (xs.isEmpty) return {'hr': [], 'hl': []};
  final xFirst = xs.reduce(math.min);
  final xEnd = m.x1 - 0.8 * sp;
  final pts = [...anchors]..sort((a, b) => a[0].compareTo(b[0]));
  if (pts.isEmpty || pts.first[0] > xFirst + 0.5 * sp) pts.insert(0, [xFirst, 0]);
  pts.add([math.max(xEnd, pts.last[0] + 1), meterS.toDouble()]);

  for (final hand in const ['hr', 'hl']) {
    if (result.containsKey(hand)) continue;
    final ev = hands[hand]!;
    final starts = <int>[];
    int prev = -1;
    for (final e in ev) {
      // A note of a tuplet starts on the grid of its own real length.
      final g = e.tuplet > 1
          ? _effectiveDuration(e)
          : _noteGrid(e.duration, unit) * _tupletScale;
      int t;
      List<double>? near;
      for (final a in anchors) {
        if ((a[0] - e.x).abs() <= 1.0 * sp &&
            (near == null || (a[0] - e.x).abs() < (near[0] - e.x).abs())) {
          near = a;
        }
      }
      if (near != null) {
        t = near[1].round();
      } else {
        // Between the known points left and right of it.
        var left = pts.first, right = pts.last;
        for (final p in pts) {
          if (p[0] <= e.x && p[0] >= left[0]) left = p;
        }
        for (final p in pts.reversed) {
          if (p[0] > e.x && p[0] <= right[0]) right = p;
        }
        final tf = right[0] <= left[0]
            ? left[1]
            : left[1] + (e.x - left[0]) / (right[0] - left[0]) * (right[1] - left[1]);
        t = (tf / g).round() * g;
      }
      t = t.clamp(0, meterS - math.min(g, meterS)).toInt();
      if (t <= prev) t = prev + g < meterS ? prev + g : prev;
      starts.add(t);
      prev = t;
    }
    // Ran out of room (the durations read were too long, or the
    // measure is a pickup): several notes would pile up on the same
    // last position. Rather than stacking them there, place this hand's
    // notes by their x position across the measure, on the finest grid
    // (a 32nd), keeping their order.
    bool piled = false;
    for (int k = 1; k < starts.length; k++) {
      if (starts[k] <= starts[k - 1]) {
        piled = true;
        break;
      }
    }
    if (piled) {
      final fine = 4 * _tupletScale; // a 32nd
      final span = math.max(1.0, xEnd - xFirst);
      final byX = <int>[];
      int last = -fine;
      for (final e in ev) {
        var t = (((e.x - xFirst) / span * meterS) / fine).round() * fine;
        if (t <= last) t = last + fine;
        byX.add(t);
        last = t;
      }
      // Use it only when it fits in the measure.
      if (byX.isEmpty || byX.last < meterS) {
        result[hand] = byX;
        continue;
      }
    }
    result[hand] = starts;
  }
  return result;
}

/// Repairs misread beam counts in one hand of a measure so that it
/// fills the measure ([meter], 1/128ths) exactly. A slur, a fingering
/// or a "Ped." sign touching a stem can add a beam that isn't there
/// (a 16th read as a 32nd), and a faint beam can be missed (a 16th
/// read as an 8th). When the hand's notes don't add up to the meter,
/// beamed notes whose length differs from their neighbours' are given
/// their neighbours' length — one at a time, the most obvious first —
/// as long as that brings the total closer. The changes are kept only
/// if the hand then fills the measure EXACTLY; otherwise nothing is
/// changed (a pickup, a real 32nd, a misread note…).
void _fitBeamCounts(List<OmrEvent> ev, int meter) {
  if (ev.isEmpty ||
      ev.any((e) => e.duration <= 0 || e.tuplet > 1 || e.isRest)) {
    return;
  }
  int total(List<int> d) => d.fold<int>(0, (s, x) => s + x);
  final durs = [for (final e in ev) e.duration];
  if (total(durs) == meter) return;
  if (ev.length < 2) return;

  // Plain (undotted) beamed lengths only: 8th, 16th, 32nd, 64th.
  bool beamed(int d) => d == 16 || d == 8 || d == 4 || d == 2;

  final work = [...durs];
  for (int step = 0; step < ev.length; step++) {
    final t = total(work);
    if (t == meter) break;
    int bestI = -1, bestD = 0, bestScore = 0;
    for (int i = 0; i < work.length; i++) {
      final d = work[i];
      if (!beamed(d)) continue;
      final prev = i > 0 ? work[i - 1] : null;
      final next = i + 1 < work.length ? work[i + 1] : null;
      for (final nd in [d * 2, d ~/ 2]) {
        if (!beamed(nd)) continue;
        final newT = t - d + nd;
        if ((newT - meter).abs() >= (t - meter).abs()) continue;
        // How much it agrees with its neighbours after the change.
        int score = 0;
        if (prev == nd) score++;
        if (next == nd) score++;
        // A note that agreed with neither neighbour before is the
        // likelier misread.
        if (prev != d && next != d) score++;
        if (score > bestScore) {
          bestScore = score;
          bestI = i;
          bestD = nd;
        }
      }
    }
    if (bestI < 0 || bestScore < 2) break;
    work[bestI] = bestD;
  }
  if (total(work) != meter) return;
  for (int i = 0; i < ev.length; i++) {
    if (work[i] != ev[i].duration) {
      final e = ev[i];
      ev[i] = OmrEvent(e.x, work[i], e.notes,
          arpeggio: e.arpeggio, tuplet: e.tuplet, top: e.top, bottom: e.bottom)
        ..tupletPrinted = e.tupletPrinted;
    }
  }
}

/// In a beat that holds triplet notes (in either hand), the other notes
/// starting inside that beat are put on the triplet grid too — e.g. the
/// dotted eighth + sixteenth over triplets of the Moonlight Sonata: the
/// sixteenth goes with the last note of the triplet (written d4:3 +
/// d8:3), as it is played. Without this the beat needs 12 columns in
/// the app instead of 3. [onsets] (1/(128 × [_tupletScale])) and the
/// events of [m] are changed in place; [unit] is the beat in 1/128ths.
void _alignToTriplets(OmrMeasure m, Map<String, List<int>> onsets, int unit) {
  final beatS = unit * _tupletScale;
  final third = beatS ~/ 3;
  if (third * 3 != beatS) return;
  // Beats with a triplet note in them.
  final tripletBeats = <int>{};
  for (final hand in const ['hr', 'hl']) {
    final ev = m.hands[hand] ?? const <OmrEvent>[];
    final st = onsets[hand] ?? const <int>[];
    for (int i = 0; i < ev.length && i < st.length; i++) {
      if (ev[i].tuplet == 3) tripletBeats.add(st[i] ~/ beatS);
    }
  }
  if (tripletBeats.isEmpty) return;
  for (final hand in const ['hr', 'hl']) {
    final ev = m.hands[hand];
    final st = onsets[hand];
    if (ev == null || st == null) continue;
    for (int i = 0; i < ev.length && i < st.length; i++) {
      final e = ev[i];
      if (e.tuplet > 1 || e.duration <= 0) continue;
      final beat = st[i] ~/ beatS;
      if (!tripletBeats.contains(beat)) continue;
      final f = st[i] - beat * beatS; // position inside the beat
      final len = _effectiveDuration(e);
      final end = f + len;
      if (f % third == 0 && (end % third == 0 || end >= beatS)) continue;
      // Nearest triplet column (3/4 of the beat → the last one).
      final ns = ((f / third).round() * third).clamp(0, 2 * third).toInt();
      int newLen;
      if (end >= beatS) {
        newLen = len + (f - ns); // keep its end
      } else {
        int ne = ((end / third).round() * third).clamp(third, 3 * third).toInt();
        if (ne <= ns) ne = ns + third;
        newLen = ne - ns;
      }
      st[i] = beat * beatS + ns;
      // A length of 1 or 2 triplet notes is written as a triplet note
      // (2/3 of its written length); a whole beat or more stays plain.
      if (newLen % beatS != 0 && newLen % third == 0) {
        final written = newLen * 3 ~/ 2 ~/ _tupletScale;
        ev[i] = OmrEvent(e.x, written, e.notes,
            arpeggio: e.arpeggio, tuplet: 3, top: e.top, bottom: e.bottom)
          ..tupletPrinted = e.tupletPrinted;
      }
    }
  }
}

/// The beat marker for a start [t] (see [_measureOnsets]) with beats of
/// [unit] 1/128ths: "b2", "b2&1/2", "b2&1/3"…
String _beatMarker(int t, int unit) {
  final beatS = unit * _tupletScale;
  final whole = t ~/ beatS + 1;
  final rem = t % beatS;
  if (rem == 0) return 'b$whole';
  final g = rem.gcd(beatS);
  return 'b$whole&${rem ~/ g}/${beatS ~/ g}';
}

/// Settles the tuplets of one hand of a measure against the meter
/// (1/128ths): a printed "3" that is really a fingering (the measure is
/// already full without it) is dropped; and when no number is printed
/// (it is often left out after the first few) but the measure is too
/// long, groups of 3 equal notes are made triplets until it fits.
void _settleTuplets(List<OmrEvent> ev, int meter, {bool allowUnmarked = true}) {
  if (ev.isEmpty || ev.any((e) => e.duration <= 0)) {
    for (final e in ev) {
      e.tuplet = 1;
    }
    return;
  }
  final target = meter * _tupletScale;
  final written = ev.fold<int>(0, (s, e) => s + e.duration) * _tupletScale;
  int real() => ev.fold<int>(0, (s, e) => s + _effectiveDuration(e));
  if (ev.any((e) => e.tuplet > 1)) {
    final r = real();
    if (r == target) return;
    if (written == target || (written - target).abs() < (r - target).abs()) {
      for (final e in ev) {
        e.tuplet = 1;
      }
    }
    return;
  }
  // Triplets without a printed number only once the piece has had
  // printed ones (otherwise a too-long measure is a reading mistake,
  // not a triplet).
  if (written <= target || !allowUnmarked) return;
  final marked = <OmrEvent>[];
  for (int i = 0; i + 3 <= ev.length;) {
    final g = ev.sublist(i, i + 3);
    final d = g.first.duration;
    if (d <= 32 && g.every((e) => e.duration == d)) {
      for (final e in g) {
        e.tuplet = 3;
      }
      marked.addAll(g);
      i += 3;
      final r = real();
      if (r == target) return;
      if (r < target) break;
    } else {
      i++;
    }
  }
  for (final e in marked) {
    e.tuplet = 1;
  }
}

/// Small upright marks near staff [st] between [x0] and [x1] that can
/// be tuplet numbers ("3", "5", "6"…): about a space tall, not a
/// notehead, not crossed by a stem, outside the staff lines.
List<_Comp> _tupletNumerals(_CompIndex index, _Staff st, double x0, double x1,
    double sp, List<_Head> heads) {
  final result = <_Comp>[];
  for (final c in index.comps) {
    if (c.x1 < x0 || c.x0 > x1) continue;
    if (c.h < 0.75 * sp || c.h > 1.9 * sp) continue;
    if (c.w < 0.35 * sp || c.w > 1.4 * sp || c.w > 1.2 * c.h) continue;
    final fill = c.area / (c.w * c.h);
    if (fill < 0.15 || fill > 0.6) continue;
    final cx = (c.x0 + c.x1) / 2, cy = (c.y0 + c.y1) / 2;
    final top = _lineY(st, 0, cx), bottom = _lineY(st, 4, cx);
    if (cy > top - 0.3 * sp && cy < bottom + 0.3 * sp) continue;
    if (cy < top - 8 * sp || cy > bottom + 8 * sp) continue;
    if (heads.any((h) =>
    c.x0 - 0.2 * sp <= h.cx && h.cx <= c.x1 + 0.2 * sp &&
        c.y0 - 0.2 * sp <= h.cy && h.cy <= c.y1 + 0.2 * sp)) {
      continue;
    }
    if (index.stems.any((s) =>
    s[0] >= c.x0 && s[0] <= c.x1 && s[1] <= c.y1 && s[2] >= c.y0)) {
      continue;
    }
    result.add(c);
  }
  return result;
}

/// Marks the group of notes each tuplet number in [numerals] stands
/// over (or under): 3, 6, 5 or 7 notes of equal length centred on the
/// number — or 2 notes, one twice as long as the other (a quarter and
/// an eighth of a triplet).
void _markTuplets(List<_Comp> numerals, List<OmrEvent> events, double sp) {
  bool near(List<OmrEvent> g, double cy) {
    final notes = g.where((e) => !e.isRest).toList();
    if (notes.isEmpty) return false;
    double lo = notes.first.top, hi = notes.first.bottom;
    for (final e in notes) {
      lo = math.min(lo, e.top);
      hi = math.max(hi, e.bottom);
    }
    // Beyond the notes and beam, within a few spaces of them.
    return (cy < lo && lo - cy <= 3.5 * sp) || (cy > hi && cy - hi <= 3.5 * sp);
  }

  for (final c in numerals) {
    final cx = (c.x0 + c.x1) / 2, cy = (c.y0 + c.y1) / 2;
    var done = false;
    for (final k in const [3, 6, 5, 7]) {
      for (int i = 0; i + k <= events.length && !done; i++) {
        final g = events.sublist(i, i + k);
        final d = g.first.duration;
        if (d <= 0 || d > 64) continue;
        if (g.any((e) => e.tuplet > 1 || e.duration != d)) continue;
        final mid = (g.first.x + g.last.x) / 2 + 0.6 * sp;
        if ((mid - cx).abs() > 1.2 * sp) continue;
        if (g.last.x - g.first.x > k * 6 * sp) continue;
        if (!near(g, cy)) continue;
        for (final e in g) {
          e.tuplet = k;
          e.tupletPrinted = true;
        }
        done = true;
      }
      if (done) break;
    }
    for (int i = 0; i + 2 <= events.length && !done; i++) {
      final a = events[i], b = events[i + 1];
      if (a.tuplet > 1 || b.tuplet > 1 || a.duration <= 0 || b.duration <= 0) {
        continue;
      }
      if (a.duration != 2 * b.duration && b.duration != 2 * a.duration) continue;
      final mid = (a.x + b.x) / 2 + 0.6 * sp;
      if ((mid - cx).abs() > 1.5 * sp) continue;
      if (!near([a, b], cy)) continue;
      a.tuplet = 3;
      b.tuplet = 3;
      a.tupletPrinted = true;
      b.tupletPrinted = true;
      done = true;
    }
  }
}

const _majorSharps = ['do major', 'sol major', 're major', 'la major', 'mi major',
  'si major', 'fa sharp major', 'do sharp major'];
const _minorSharps = ['la minor', 'mi minor', 'si minor', 'fa sharp minor',
  'do sharp minor', 'sol sharp minor', 're sharp minor', 'la sharp minor'];
const _majorFlats = ['do major', 'fa major', 'si flat major', 'mi flat major',
  'la flat major', 're flat major', 'sol flat major', 'si major'];
const _minorFlats = ['la minor', 're minor', 'sol minor', 'do minor', 'fa minor',
  'si flat minor', 'mi flat minor', 'la flat minor'];
const _letters = 'cdefgab';

/// The scale for a key signature (+n sharps / -n flats), major or minor.
String scaleForKey(int key, bool minor) {
  key = key.clamp(-7, 7).toInt();
  if (key >= 0) return (minor ? _minorSharps : _majorSharps)[key];
  return (minor ? _minorFlats : _majorFlats)[-key];
}

/// Grid row of a line position ("4", "4/5", "-5/-4"): middle C = 28.
int _rowOfPosition(String pos) {
  // Only the numbers count (anything else, e.g. an accidental, is
  // ignored), so an unusual position can never stop the import.
  final nums = <int>[
    for (final m in RegExp(r'-?\d+').allMatches(pos)) int.parse(m.group(0)!)
  ];
  if (nums.isEmpty) return 28;
  if (nums.length == 1) return 2 * nums[0] + 28;
  final int low = nums[0] < nums[1] ? nums[0] : nums[1];
  return 2 * low + 29;
}

String _letterOfPosition(String pos) => _letters[_rowOfPosition(pos) % 7];

/// Major or minor, for measures with the same key signature [key]: the
/// music of a key ends on its tonic, so the lowest note of the last
/// chord decides; the first bass note and raised leading tones (the 7th
/// of the minor key, with a sharp or natural) help when it is unclear.
bool _isMinor(List<OmrMeasure> section, int key) {
  final major = key >= 0 ? 'cgdaebfc'[key] : 'cfbeadgc'[-key];
  final minor = key >= 0 ? 'aebfcgda'[key] : 'adgcfbea'[-key];
  OmrNote? bassOf(OmrEvent e) {
    OmrNote? low;
    for (final n in e.notes) {
      if (low == null || _rowOfPosition(n.position) < _rowOfPosition(low.position)) low = n;
    }
    return low;
  }

  OmrNote? lastBass, firstBass;
  for (final m in section.reversed) {
    for (final hand in const ['hl', 'hr']) {
      final ev = (m.hands[hand] ?? const <OmrEvent>[]).where((e) => !e.isRest).toList();
      if (ev.isNotEmpty) {
        lastBass = bassOf(ev.last);
        break;
      }
    }
    if (lastBass != null) break;
  }
  for (final m in section) {
    for (final hand in const ['hl', 'hr']) {
      final ev = (m.hands[hand] ?? const <OmrEvent>[]).where((e) => !e.isRest).toList();
      if (ev.isNotEmpty) {
        firstBass = bassOf(ev.first);
        break;
      }
    }
    if (firstBass != null) break;
  }
  double score = 0; // > 0: minor
  for (final (n, weight) in [(lastBass, 3.0), (firstBass, 1.0)]) {
    if (n == null) continue;
    final l = _letterOfPosition(n.position);
    if (l == minor) score += weight;
    if (l == major) score -= weight;
  }
  final leading = _letters[(_letters.indexOf(minor) + 6) % 7];
  int raised = 0;
  for (final m in section) {
    for (final hand in const ['hr', 'hl']) {
      for (final e in m.hands[hand] ?? const <OmrEvent>[]) {
        for (final n in e.notes) {
          if (_letterOfPosition(n.position) == leading &&
              (n.accidental == '+' || n.accidental == 'x')) {
            raised++;
          }
        }
      }
    }
  }
  score += 0.5 * math.min(raised, 4);
  return score > 0;
}

/// Writes the recognized measures as a transcription. [scaleName] null
/// (or 'Auto'): the scale is found from the key signatures and the
/// notes, and every key change gets its own scale line in the measure
/// where it happens; otherwise the given scale is used throughout.
String omrMeasuresToTranscription(
    List<OmrMeasure> allMeasures, {
      String? scaleName,
      bool scaleHasAccidentals = false,
      List<int>? timeSignature,
    }) {
  // A key change on an empty "measure" moves on to the next one.
  final measures = <OmrMeasure>[];
  int? pendingKey;
  for (final m in allMeasures) {
    if (m.isEmpty) {
      pendingKey = m.key ?? pendingKey;
      continue;
    }
    if (pendingKey != null && m.key == null) {
      measures.add(OmrMeasure(m.x0, m.x1, m.spacing, m.hands,
          repeatStart: m.repeatStart, repeatEnd: m.repeatEnd, key: pendingKey));
    } else {
      measures.add(m);
    }
    pendingKey = null;
  }

  // The scale of each key section.
  final auto = scaleName == null || scaleName == 'Auto';
  final scales = List<String?>.filled(measures.length, null);
  if (auto) {
    final starts = <int>[];
    int? current;
    for (int i = 0; i < measures.length; i++) {
      final k = measures[i].key;
      if (k != null && k != current) {
        current = k;
        starts.add(i);
      }
    }
    for (int s = 0; s < starts.length; s++) {
      final i0 = starts[s];
      final i1 = s + 1 < starts.length ? starts[s + 1] : measures.length;
      final key = measures[i0].key!;
      scales[i0] = scaleForKey(key, _isMinor(measures.sublist(i0, i1), key));
    }
  }
  final String firstScale =
  auto ? ((scales.isNotEmpty ? scales.first : null) ?? 'do major') : scaleName!;

  final totals = <int>[];
  for (final m in measures) {
    for (final hand in const ['hr', 'hl']) {
      final ev = m.hands[hand] ?? const <OmrEvent>[];
      // A whole-measure rest says nothing about the meter.
      if (ev.isNotEmpty &&
          ev.every((e) => e.duration > 0) &&
          !ev.any((e) => e.tuplet > 1)) {
        totals.add(ev.fold<int>(0, (s, e) => s + e.duration));
      }
    }
  }
  // Candidate meters in 1/128ths: 2/4 3/4 4/4 3/8 6/8 9/8 12/8 2/2 5/4
  // 6/4 7/8 5/8 (6/8 has the same length as 3/4, etc.)
  const candidates = [64, 96, 128, 48, 96, 144, 192, 128, 160, 192, 112, 80];
  int meter = 96;
  if (timeSignature != null) {
    meter = timeSignature[0] * 128 ~/ timeSignature[1];
  } else if (totals.isNotEmpty) {
    // Measures that add up exactly count most; nearly-full ones only
    // break ties. 2/4, 3/4 (= 6/8) and 4/4 (= 2/2) are preferred.
    double bestExact = -1, bestNear = -double.infinity;
    for (int i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      int exactCount = 0;
      double near = 0;
      for (final t in totals) {
        if (t == c) {
          exactCount++;
        } else if (c - 32 <= t && t < c) {
          near += 0.5; // a few notes missed
        } else if (t > c + 8) {
          near -= 0.5;
        }
      }
      final exact =
          exactCount * ((c == 64 || c == 96 || c == 128) ? 1.0 : 0.7);
      if (exact > bestExact || (exact == bestExact && near > bestNear)) {
        bestExact = exact;
        bestNear = near;
        meter = c;
      }
    }
  }

  int unit = 32; // quarter
  if (timeSignature != null) unit = math.max(2, 128 ~/ timeSignature[1]);
  // An eighth-note beat only when the meter needs it (3/8, 5/8, 7/8…).
  // 32nd notes alone don't: in 3/4 they simply start at b2&1/8 … —
  // before, they turned a 3/4 piece into "6/8".
  if (unit > 16 && meter % unit != 0) unit = 16; // eighth
  final out = StringBuffer();
  out.writeln(firstScale);
  var currentScale = firstScale;
  if (meter % unit == 0) {
    out.writeln('t${meter ~/ unit}/${128 ~/ unit}');
  } else {
    out.writeln('t3/4');
  }

  // Set once a printed tuplet number was confirmed (see _settleTuplets).
  var printedTupletSeen = false;
  for (int i = 0; i < measures.length; i++) {
    final m = measures[i];
    out.writeln('m${i + 1}');
    // The key changes here.
    if (i > 0 && scales[i] != null && scales[i] != currentScale) {
      currentScale = scales[i]!;
      out.writeln(currentScale);
    }
    for (final hand in const ['hr', 'hl']) {
      final hev = m.hands[hand];
      if (hev != null) _fitBeamCounts(hev, meter);
      final ev = m.hands[hand] ?? <OmrEvent>[];
      _settleTuplets(ev, meter, allowUnmarked: printedTupletSeen);
      if (ev.any((e) => e.tuplet > 1 && e.tupletPrinted)) {
        printedTupletSeen = true;
      }
    }
    final onsets = _measureOnsets(m, meter, unit);
    _alignToTriplets(m, onsets, unit);
    final keyHasAccidentals = auto
        ? currentScale != 'do major' && currentScale != 'la minor'
        : scaleHasAccidentals;
    // Repeat barlines (see notation_marks.dart for these words).
    final signs = [if (m.repeatStart) '|:', if (m.repeatEnd) ':|'];
    if (signs.isNotEmpty) out.writeln(signs.join(' '));
    for (final hand in const ['hr', 'hl']) {
      final ev = [
        for (final e in m.hands[hand] ?? const <OmrEvent>[])
          e.duration == OmrEvent.wholeMeasure
              ? OmrEvent(e.x, meter, e.notes)
              : e
      ];
      if (!ev.any((e) => !e.isRest)) continue;
      final toks = <String>[hand];
      final carried = <String, String>{};
      final starts = onsets[hand]!;
      for (int ei = 0; ei < ev.length; ei++) {
        final e = ev[ei];
        final int t = starts[ei];
        if (e.isRest) {
          // A rest only takes up time; the beats of the notes say it.
          continue;
        }
        toks.add(_beatMarker(t, unit));
        if (e.arpeggio) toks.add('arp');

        final notes = <String>[];
        final sortedNotes = [...e.notes]..sort((a, b) => b.y.compareTo(a.y));
        for (final n in sortedNotes) {
          var acc = n.accidental;
          // An accidental lasts until the end of the measure.
          if (acc.isEmpty && carried.containsKey(n.position)) {
            acc = carried[n.position]!;
          } else if (acc == 'x') {
            // A printed natural: written (and kept for the rest of the
            // measure) when the key has sharps or flats; in do major /
            // la minor it only cancels an earlier accidental.
            if (keyHasAccidentals) {
              carried[n.position] = 'x';
            } else {
              carried.remove(n.position);
              acc = '';
            }
          } else if (acc.isNotEmpty) {
            carried[n.position] = acc;
          }
          notes.add('l${n.position}$acc'); // "l" = line position
        }
        // A note of a tuplet: ":3" after its written length.
        // Never longer than what is left of the measure (a whole note
        // in 3/8 is a misread head).
        final left = meter - t ~/ _tupletScale;
        final written = e.tuplet <= 1 && e.duration > left && left > 0
            ? left
            : e.duration;
        final dc = _durationCode(written) +
            (e.tuplet > 1 ? ':${e.tuplet}' : '');
        if (notes.length == 1) {
          toks.add('${notes.first} $dc');
        } else {
          toks.add('(${notes.join(', ')}) $dc');
        }
      }
      out.writeln(toks.join(' '));
    }
  }
  return out.toString().trimRight();
}

/// 1/128ths of a whole note -> "d4d8" style (dotted / tied).
String _durationCode(int units) {
  final sb = StringBuffer();
  var rem = units;
  for (final den in const [1, 2, 4, 8, 16, 32, 64]) {
    final v = 128 ~/ den;
    while (rem >= v) {
      sb.write('d$den');
      rem -= v;
    }
  }
  final s = sb.toString();
  return s.isEmpty ? 'd16' : s;
}

// =====================================================================
// Images
// =====================================================================

class _Gray {
  final int w;
  final int h;
  final Uint8List d;
  _Gray(this.w, this.h, this.d);
}

/// Black/white image: 1 = black.
class _Bin {
  final int w;
  final int h;
  final Uint8List d;
  _Bin(this.w, this.h, this.d);
  _Bin.empty(this.w, this.h) : d = Uint8List(w * h);

  bool at(int x, int y) => d[y * w + x] != 0;
  _Bin copy() => _Bin(w, h, Uint8List.fromList(d));
}

int _otsu(Uint8List gray) {
  final hist = List<double>.filled(256, 0);
  for (final v in gray) {
    hist[v] += 1;
  }
  final total = gray.length.toDouble();
  double sumAll = 0;
  for (int t = 0; t < 256; t++) {
    sumAll += t * hist[t];
  }
  double wb = 0, sb = 0, best = 0;
  int thr = 128;
  for (int t = 0; t < 256; t++) {
    wb += hist[t];
    if (wb == 0) continue;
    final wf = total - wb;
    if (wf == 0) break;
    sb += t * hist[t];
    final mb = sb / wb;
    final mf = (sumAll - sb) / wf;
    final between = wb * wf * (mb - mf) * (mb - mf);
    if (between > best) {
      best = between;
      thr = t;
    }
  }
  return thr;
}

class _Prepared {
  /// Strict black/white image, for reading the symbols.
  final _Bin bw;

  /// Lenient one, for finding and following the staff lines (keeps
  /// faint lines of a photo).
  final _Bin lines;
  _Prepared(this.bw, this.lines);
}

/// Black where a pixel is clearly darker than the average of the
/// win x win square around it (Bradley's method), for each k in [ks].
/// Works on grey paper, with shadows and uneven lighting, where one
/// cut-off for the whole page fails.
List<_Bin> _adaptive(_Gray g, int win, List<double> ks) {
  final w = g.w, h = g.h, w1 = w + 1;
  // Integral image in 32 bits. On a very large page the running sums
  // wrap around, but the sum of one window is small, so taking the
  // difference modulo 2^32 (the & below) still gives it exactly.
  final ii = Uint32List(w1 * (h + 1));
  for (int y = 0; y < h; y++) {
    int rowSum = 0;
    final row = y * w;
    for (int x = 0; x < w; x++) {
      rowSum += g.d[row + x];
      ii[(y + 1) * w1 + x + 1] = ii[y * w1 + x + 1] + rowSum;
    }
  }
  final outs = [for (final _ in ks) _Bin.empty(w, h)];
  final r = win ~/ 2;
  for (int y = 0; y < h; y++) {
    final y0 = math.max(0, y - r), y1 = math.min(h, y + r + 1);
    for (int x = 0; x < w; x++) {
      final x0 = math.max(0, x - r), x1 = math.min(w, x + r + 1);
      final sum = (ii[y1 * w1 + x1] - ii[y0 * w1 + x1] - ii[y1 * w1 + x0] + ii[y0 * w1 + x0]) &
      0xFFFFFFFF;
      final mean = sum / ((y1 - y0) * (x1 - x0));
      final v = g.d[y * w + x];
      for (int i = 0; i < ks.length; i++) {
        if (v < mean * (1 - ks[i])) outs[i].d[y * w + x] = 1;
      }
    }
  }
  return outs;
}

/// Black/white page, rescaled so the staff spacing is about
/// [_targetSpacing]. Local (adaptive) thresholding handles photos;
/// what a single page-wide cut-off calls ink is added for dense,
/// heavily printed scans.
_Prepared _prepare(_Gray gray) {
  final first = _adaptive(gray, math.max(15, gray.w ~/ 40), const [0.15])[0];
  final sp = _estimateSpacing(first).sp;
  var f = _targetSpacing / sp;
  // Keep the working image at most ~6 million pixels (memory).
  const maxPixels = 6000000;
  final scaledPixels = gray.w * gray.h * f * f;
  if (scaledPixels > maxPixels) f *= math.sqrt(maxPixels / scaledPixels);
  var g = gray;
  if ((f - 1).abs() > 0.15) {
    g = _resizeCubic(gray, f);
  }
  final thr = _otsu(g.d).toDouble();
  final lenient = thr + 0.25 * (255 - thr);
  int band = 0;
  for (final v in g.d) {
    if (v > thr && v <= lenient) band++;
  }
  final globalThr = band / g.d.length < 0.02 ? lenient : thr;
  final darkThr = 0.75 * thr;
  final win = (8 * _targetSpacing).toInt() | 1;
  final both = _adaptive(g, win, const [0.15, 0.06]);
  final strict = both[0], lenientBw = both[1];
  for (int i = 0; i < g.d.length; i++) {
    final v = g.d[i];
    if (v <= globalThr || v < darkThr) {
      strict.d[i] = 1;
      lenientBw.d[i] = 1;
    }
  }
  return _Prepared(strict, lenientBw);
}

double _cubicWeight(double t) {
  const a = -0.75; // as OpenCV's bicubic
  final x = t.abs();
  if (x <= 1) return (a + 2) * x * x * x - (a + 3) * x * x + 1;
  if (x < 2) return a * x * x * x - 5 * a * x * x + 8 * a * x - 4 * a;
  return 0;
}

/// Separable bicubic resize by factor [f].
_Gray _resizeCubic(_Gray src, double f) {
  final nw = (src.w * f).round();
  final nh = (src.h * f).round();
  // Horizontal pass.
  final tmp = Float32List(nw * src.h);
  final scaleX = src.w / nw;
  final xIdx = List<List<int>>.generate(nw, (_) => List<int>.filled(4, 0));
  final xW = List<List<double>>.generate(nw, (_) => List<double>.filled(4, 0));
  for (int i = 0; i < nw; i++) {
    final x = (i + 0.5) * scaleX - 0.5;
    final x0 = x.floor();
    final t = x - x0;
    for (int k = -1; k <= 2; k++) {
      xIdx[i][k + 1] = math.min(math.max(x0 + k, 0), src.w - 1);
      xW[i][k + 1] = _cubicWeight(t - k);
    }
  }
  for (int y = 0; y < src.h; y++) {
    final row = y * src.w;
    final orow = y * nw;
    for (int i = 0; i < nw; i++) {
      final idx = xIdx[i];
      final w = xW[i];
      tmp[orow + i] = w[0] * src.d[row + idx[0]] +
          w[1] * src.d[row + idx[1]] +
          w[2] * src.d[row + idx[2]] +
          w[3] * src.d[row + idx[3]];
    }
  }
  // Vertical pass.
  final out = Uint8List(nw * nh);
  final scaleY = src.h / nh;
  for (int j = 0; j < nh; j++) {
    final y = (j + 0.5) * scaleY - 0.5;
    final y0 = y.floor();
    final t = y - y0;
    final rows = List<int>.generate(
        4, (k) => math.min(math.max(y0 + k - 1, 0), src.h - 1) * nw);
    final ws = List<double>.generate(4, (k) => _cubicWeight(t - (k - 1)));
    final orow = j * nw;
    for (int i = 0; i < nw; i++) {
      final v = ws[0] * tmp[rows[0] + i] +
          ws[1] * tmp[rows[1] + i] +
          ws[2] * tmp[rows[2] + i] +
          ws[3] * tmp[rows[3] + i];
      out[orow + i] = v.round().clamp(0, 255).toInt();
    }
  }
  return _Gray(nw, nh, out);
}

/// Box erosion: a pixel stays black only if the whole kw x kh box
/// around it (anchor at the centre, the outside of the image ignored)
/// is black.
_Bin _erodeBox(_Bin src, int kw, int kh) {
  final w = src.w, h = src.h;
  final ax = kw ~/ 2, ay = kh ~/ 2;
  final tmp = Uint8List(w * h);
  // Horizontal: count of white pixels in the window via prefix sums.
  final pre = Int32List(w + 1);
  for (int y = 0; y < h; y++) {
    final row = y * w;
    pre[0] = 0;
    for (int x = 0; x < w; x++) {
      pre[x + 1] = pre[x] + (src.d[row + x] == 0 ? 1 : 0);
    }
    for (int x = 0; x < w; x++) {
      final a = math.max(0, x - ax);
      final b = math.min(w - 1, x - ax + kw - 1);
      if (pre[b + 1] - pre[a] == 0) tmp[row + x] = 1;
    }
  }
  final out = _Bin.empty(w, h);
  final preY = Int32List(h + 1);
  for (int x = 0; x < w; x++) {
    preY[0] = 0;
    for (int y = 0; y < h; y++) {
      preY[y + 1] = preY[y] + (tmp[y * w + x] == 0 ? 1 : 0);
    }
    for (int y = 0; y < h; y++) {
      final a = math.max(0, y - ay);
      final b = math.min(h - 1, y - ay + kh - 1);
      if (preY[b + 1] - preY[a] == 0) out.d[y * w + x] = 1;
    }
  }
  return out;
}

class _Comp {
  int x0, y0, x1, y1, area = 0;
  bool touchesBorder = false;
  _Comp(this.x0, this.y0, this.x1, this.y1);
  int get x => x0;
  int get y => y0;
  int get w => x1 - x0 + 1;
  int get h => y1 - y0 + 1;
}

/// Connected components of the pixels equal to [value] (1 = black,
/// 0 = white), with bounding boxes, area and whether they touch the
/// image border. 8-connected when [eight], else 4-connected.
List<_Comp> _components(_Bin img, {bool eight = true, int value = 1}) {
  // Scanline flood fill: fills whole horizontal runs at once and only
  // remembers one seed per run, so memory stays small even for the
  // huge white "paper" region (a pixel-by-pixel fill needed tens of
  // megabytes there, enough to get the app killed on a tablet).
  final w = img.w, h = img.h;
  final d = img.d;
  final visited = Uint8List(w * h);
  final comps = <_Comp>[];
  final stack = <int>[];
  for (int start = 0; start < w * h; start++) {
    if (d[start] != value || visited[start] != 0) continue;
    final c = _Comp(start % w, start ~/ w, start % w, start ~/ w);
    comps.add(c);
    stack
      ..add(start % w)
      ..add(start ~/ w);
    while (stack.isNotEmpty) {
      final y = stack.removeLast();
      final x = stack.removeLast();
      final row = y * w;
      if (visited[row + x] != 0 || d[row + x] != value) continue;
      int xl = x;
      while (xl - 1 >= 0 && d[row + xl - 1] == value && visited[row + xl - 1] == 0) {
        xl--;
      }
      int xr = x;
      while (xr + 1 < w && d[row + xr + 1] == value && visited[row + xr + 1] == 0) {
        xr++;
      }
      for (int i = row + xl; i <= row + xr; i++) {
        visited[i] = 1;
      }
      c.area += xr - xl + 1;
      if (xl < c.x0) c.x0 = xl;
      if (xr > c.x1) c.x1 = xr;
      if (y < c.y0) c.y0 = y;
      if (y > c.y1) c.y1 = y;
      if (xl == 0 || xr == w - 1 || y == 0 || y == h - 1) c.touchesBorder = true;
      final a = eight ? math.max(0, xl - 1) : xl;
      final b = eight ? math.min(w - 1, xr + 1) : xr;
      for (final ny in [y - 1, y + 1]) {
        if (ny < 0 || ny >= h) continue;
        final nrow = ny * w;
        int xx = a;
        while (xx <= b) {
          if (d[nrow + xx] == value && visited[nrow + xx] == 0) {
            stack
              ..add(xx)
              ..add(ny);
            while (xx <= b && d[nrow + xx] == value && visited[nrow + xx] == 0) {
              xx++;
            }
          } else {
            xx++;
          }
        }
      }
    }
  }
  return comps;
}

class _CompIndex {
  final List<_Comp> comps;

  /// The line-free image the components come from.
  final _Bin? nos;

  /// Every stem as (x, top row, bottom row) — set once they are found.
  List<List<double>> stems = const [];
  _CompIndex(this.comps, [this.nos]);

  List<_Comp> inside(double x0, double y0, double x1, double y1) => [
    for (final c in comps)
      if (c.x0 >= x0 && c.y0 >= y0 && c.x1 <= x1 && c.y1 <= y1) c
  ];
}

double _median(List<double> sorted) {
  if (sorted.isEmpty) return _targetSpacing;
  final n = sorted.length;
  return n.isOdd
      ? sorted[n ~/ 2]
      : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

// =====================================================================
// Staves
// =====================================================================

class _SpLt {
  final double sp;
  final int lt;
  _SpLt(this.sp, this.lt);
}

/// Most common vertical black run (line thickness) and white run (gap
/// between lines) -> staff spacing and line thickness.
_SpLt _estimateSpacing(_Bin bw) {
  final black = <int, int>{};
  final white = <int, int>{};
  for (int x = 0; x < bw.w; x += 2) {
    int y = 0;
    while (y < bw.h) {
      final v = bw.at(x, y);
      int j = y;
      while (j < bw.h && bw.at(x, j) == v) {
        j++;
      }
      final len = j - y;
      if (v) {
        black[len] = (black[len] ?? 0) + 1;
      } else if (y > 0 && j < bw.h) {
        white[len] = (white[len] ?? 0) + 1;
      }
      y = j;
    }
  }
  int mostCommon(Map<int, int> m, {int? except}) {
    int best = -1, bestN = -1;
    m.forEach((k, n) {
      if (k == except) return;
      if (n > bestN) {
        bestN = n;
        best = k;
      }
    });
    return best;
  }

  if (black.isEmpty || white.isEmpty) return _SpLt(_targetSpacing, 2);
  final lt = mostCommon(black);
  final a = mostCommon(white);
  final na = white[a]!;
  final b = mostCommon(white, except: a);
  double gap = a.toDouble();
  if (b != -1 && (a - b).abs() <= 1) {
    final nb = white[b]!;
    gap = (a * na + b * nb) / (na + nb);
  }
  return _SpLt(gap + lt, lt);
}

class _Staff {
  final int y0;
  final List<double> lines;
  final double sp;
  int lt = 2;
  int x0 = 0, x1 = 0;

  /// Per line: the top/bottom row of the thin line run at each column
  /// (-1 where none), and the traced centre y (NaN where unknown).
  final List<Int32List> thinTop = [];
  final List<Int32List> thinBot = [];
  final List<Float64List> centre = [];

  /// Where tracing starts (the strip where the staff was found best).
  int? xStart;

  _Staff(this.y0, this.lines, this.sp, {this.xStart});
}

/// Staves on a tilted or bent page: a 5-line comb is matched in each
/// of [nStrips] vertical strips separately (inside one strip the lines
/// are nearly straight), then the pieces are linked from strip to strip.
List<_Staff> _findStavesInStrips(_Bin bw, {int nStrips = 6}) {
  final w = bw.w, h = bw.h;
  final sp0 = _estimateSpacing(bw).sp;
  final sw = w ~/ nStrips;
  // Per strip: [score, y0, sp, centre x] and the strip's projection.
  final found = <List<List<double>>>[];
  final projs = <Float64List>[];
  for (int si = 0; si < nStrips; si++) {
    final xa = si * sw, xb = si < nStrips - 1 ? (si + 1) * sw : w;
    final proj = Float64List(h);
    for (int y = 0; y < h; y++) {
      int n = 0;
      final row = y * w;
      for (int x = xa; x < xb; x++) {
        n += bw.d[row + x];
      }
      proj[y] = n.toDouble();
    }
    projs.add(proj);
    final pm = Float64List.fromList(proj);
    for (int y = 1; y < h - 1; y++) {
      pm[y] = math.max(math.max(proj[y - 1], proj[y]), proj[y + 1]);
    }
    final need = 0.4 * (xb - xa);
    final best = <List<double>>[];
    for (int y0 = 0; y0 < h; y0++) {
      List<double>? bestv;
      for (int k = 0; k <= 10; k++) {
        final sp = sp0 * (0.85 + 0.03 * k);
        if (y0 + 4 * sp >= h - 1) continue;
        final vals = [for (int i = 0; i < 5; i++) pm[(y0 + i * sp).round()]];
        final mn = vals.reduce(math.min);
        final mx = vals.reduce(math.max);
        // Five long lines of similar length.
        if (mn < need || mn < 0.55 * mx) continue;
        double mids = 0;
        for (int i = 0; i < 4; i++) {
          mids += pm[(y0 + (i + 0.5) * sp).round()];
        }
        final score = vals.reduce((a, b) => a + b) - 0.5 * mids;
        if (bestv == null || score > bestv[0]) {
          bestv = [score, y0.toDouble(), sp, ((xa + xb) ~/ 2).toDouble()];
        }
      }
      if (bestv != null) best.add(bestv);
    }
    best.sort((a, b) {
      if (a[0] != b[0]) return b[0].compareTo(a[0]);
      if (a[1] != b[1]) return b[1].compareTo(a[1]);
      return b[2].compareTo(a[2]);
    });
    final chosen = <List<double>>[];
    for (final b in best) {
      if (chosen.any((c) => (b[1] - c[1]).abs() < 5 * b[2])) continue;
      chosen.add(b);
    }
    found.add(chosen);
  }
  // Link pieces across neighbouring strips into staves; a chain holds
  // [strip index, piece] entries.
  final chains = <List<List<Object>>>[];
  for (int si = 0; si < nStrips; si++) {
    for (final piece in found[si]) {
      final y0 = piece[1], sp = piece[2];
      List<List<Object>>? best;
      double bestD = double.infinity;
      for (final ch in chains) {
        final lastSi = ch.last[0] as int;
        final last = ch.last[1] as List<double>;
        if (lastSi == si || si - lastSi > 2) continue;
        final d = (last[1] - y0).abs();
        if (d <= 1.5 * sp && d < bestD) {
          best = ch;
          bestD = d;
        }
      }
      if (best != null) {
        best.add([si, piece]);
      } else {
        chains.add([
          [si, piece]
        ]);
      }
    }
  }
  final staves = <_Staff>[];
  for (final ch in chains) {
    var anchor = ch.first;
    for (final e in ch) {
      if ((e[1] as List<double>)[0] > (anchor[1] as List<double>)[0]) anchor = e;
    }
    final si = anchor[0] as int;
    final piece = anchor[1] as List<double>;
    final y0 = piece[1].toInt();
    final sp = piece[2];
    final proj = projs[si];
    final lines = <double>[];
    for (int k = 0; k < 5; k++) {
      final y = (y0 + k * sp).round();
      double num = 0, den = 0;
      for (int yy = y - 1; yy <= y + 1; yy++) {
        if (yy < 0 || yy >= h) continue;
        num += yy * proj[yy];
        den += proj[yy];
      }
      lines.add(num / math.max(den, 1));
    }
    staves.add(_Staff(y0, lines, (lines[4] - lines[0]) / 4, xStart: piece[3].round()));
  }
  // Two chains for the same staff (a strip skipped): keep the first.
  staves.sort((a, b) => a.y0.compareTo(b.y0));
  final out = <_Staff>[];
  for (final st in staves) {
    if (out.isNotEmpty && (st.y0 - out.last.y0).abs() < 3 * st.sp) continue;
    out.add(st);
  }
  return out;
}

/// Share of the staff's columns where at least 4 of its 5 lines were
/// seen while tracing.
double _lineCoverage(_Staff s) {
  int good = 0;
  for (int x = s.x0; x <= s.x1; x++) {
    int n = 0;
    for (int k = 0; k < 5; k++) {
      if (s.thinTop[k][x] >= 0) n++;
    }
    if (n >= 4) good++;
  }
  return good / math.max(1, s.x1 - s.x0 + 1);
}

/// Follows one staff line left and right from [xMid], allowing for a
/// tilted page. Records, per column, the line's thin black run (where
/// it is not covered by a symbol) and the estimated centre y.
List<int> _traceLine(_Bin bw, _Staff st, int k, int xMid) {
  final w = bw.w, h = bw.h;
  // (blurred photo lines are thicker than the most common run)
  final maxrun = math.max(st.lt + 2, (0.3 * st.sp).round());
  final r = math.max(2, (0.3 * st.sp).round());
  final top = st.thinTop[k], bot = st.thinBot[k], centre = st.centre[k];
  int first = -1, last = -1;
  for (final direction in const [1, -1]) {
    double y = st.lines[k];
    int x = direction == 1 ? xMid : xMid - 1;
    int miss = 0;
    while (x >= 0 && x < w && miss < 3 * st.sp) {
      int? bTop, bBot;
      double? bC;
      final yi = y.round();
      for (int yy = math.max(0, yi - r); yy < math.min(h, yi + r + 1); yy++) {
        if (bw.at(x, yy)) {
          int t = yy;
          while (t - 1 >= 0 && bw.at(x, t - 1)) {
            t--;
          }
          int b = yy;
          while (b + 1 < h && bw.at(x, b + 1)) {
            b++;
          }
          final c = (t + b) / 2;
          if (bC == null || (c - y).abs() < (bC - y).abs()) {
            bTop = t;
            bBot = b;
            bC = c;
          }
        }
      }
      centre[x] = y;
      if (bC != null) {
        if (bBot! - bTop! + 1 <= maxrun) {
          top[x] = bTop;
          bot[x] = bBot;
          if (first == -1 || x < first) first = x;
          if (last == -1 || x > last) last = x;
          y = 0.8 * y + 0.2 * bC; // follow the tilt slowly
        }
        miss = 0;
      } else {
        miss++;
      }
      x += direction;
    }
  }
  return first == -1 ? [xMid, xMid] : [first, last];
}

void _analyseStaves(_Bin bw, List<_Staff> staves) {
  final w = bw.w;
  for (final st in staves) {
    // Start tracing at a column where all five lines are present, as
    // close to the page centre as possible.
    final ys = st.lines.map((y) => y.round()).toList();
    bool ok(int x) {
      for (final y in ys) {
        bool any = false;
        for (int yy = y - 1; yy <= y + 1; yy++) {
          if (yy >= 0 && yy < bw.h && bw.at(x, yy)) any = true;
        }
        if (!any) return false;
      }
      return true;
    }

    int xMid = st.xStart ?? w ~/ 2;
    for (int dx = 0; dx < w ~/ 2; dx++) {
      if (xMid - dx >= 0 && ok(xMid - dx)) {
        xMid = xMid - dx;
        break;
      }
      if (xMid + dx < w && ok(xMid + dx)) {
        xMid = xMid + dx;
        break;
      }
    }
    final ext0 = <int>[], ext1 = <int>[];
    for (int k = 0; k < 5; k++) {
      st.thinTop.add(Int32List(w)..fillRange(0, w, -1));
      st.thinBot.add(Int32List(w)..fillRange(0, w, -1));
      st.centre.add(Float64List(w)..fillRange(0, w, double.nan));
      final e = _traceLine(bw, st, k, xMid);
      ext0.add(e[0]);
      ext1.add(e[1]);
    }
    ext0.sort();
    ext1.sort();
    st.x0 = ext0[2];
    st.x1 = ext1[2];
  }
}

double _lineY(_Staff st, int k, double x) {
  final xi = x.round();
  if (xi >= 0 && xi < st.centre[k].length) {
    final v = st.centre[k][xi];
    if (!v.isNaN) return v;
  }
  return st.lines[k];
}

_Bin _removeStaffLines(_Bin bw, List<_Staff> staves) {
  final out = bw.copy();
  for (final st in staves) {
    for (int k = 0; k < 5; k++) {
      final top = st.thinTop[k], bot = st.thinBot[k];
      for (int x = math.max(0, st.x0 - 2); x <= math.min(bw.w - 1, st.x1 + 2); x++) {
        if (top[x] < 0) continue;
        for (int y = top[x]; y <= bot[x]; y++) {
          out.d[y * bw.w + x] = 0;
        }
      }
    }
  }
  return out;
}

// =====================================================================
// Bar lines
// =====================================================================

/// Follows a (possibly slanted or slightly curved) vertical line down
/// from (x, top) to row [bottom], stepping at most 1 px sideways per row
/// and drifting at most a few px in total. Returns the fraction of rows
/// where the line is present AND thin there (a bar line is thin all the
/// way; a column of stems and chord noteheads is not).
double _followVertical(_Bin nos, int x, int top, int bottom, double sp) {
  int good = 0;
  final xStart = x;
  final maxDrift = math.max(3, (0.03 * (bottom - top)).toInt());
  final thin = 0.7 * sp;
  for (int y = top; y <= bottom; y++) {
    if (y < 0 || y >= nos.h) continue;
    if (!nos.at(x, y)) {
      bool moved = false;
      for (final dx in const [-1, 1]) {
        final xx = x + dx;
        if (xx >= 0 && xx < nos.w && nos.at(xx, y) && (xx - xStart).abs() <= maxDrift) {
          x = xx;
          moved = true;
          break;
        }
      }
      if (!moved) continue;
    }
    int l = x, r = x;
    while (l - 1 >= 0 && nos.at(l - 1, y) && x - l < sp) {
      l--;
    }
    while (r + 1 < nos.w && nos.at(r + 1, y) && r - x < sp) {
      r++;
    }
    if (r - l + 1 <= thin) good++;
  }
  return good / (bottom - top + 1);
}

/// Bar lines of a grand staff: thin vertical lines running from the
/// upper staff's top line down to the lower staff's bottom line,
/// followed row by row so a slanted line or a bent (photographed) page
/// is still found.
List<double> _findBarlines(_Bin nos, _Staff tr, _Staff bs, int x0, int x1, double sp) {
  final xs = <int>[];
  for (int x = x0; x <= x1; x++) {
    final top = _lineY(tr, 0, x.toDouble()).round();
    final bottom = _lineY(bs, 4, x.toDouble()).round();
    if (bottom <= top || top < 0 || bottom >= nos.h) continue;
    bool startBlack = false;
    for (int y = top; y < top + 3 && y < nos.h; y++) {
      if (nos.at(x, y)) startBlack = true;
    }
    if (startBlack && _followVertical(nos, x, top, bottom, sp) >= 0.85) {
      xs.add(x);
    }
  }
  final groups = <List<int>>[];
  for (final x in xs) {
    if (groups.isNotEmpty && x - groups.last.last <= 2) {
      groups.last.add(x);
    } else {
      groups.add([x]);
    }
  }
  final bars = <double>[];
  for (final g in groups) {
    if (g.length <= 0.6 * sp) bars.add((g.first + g.last) / 2); // thin
  }
  // Merge double bar lines (and repeat signs).
  final merged = <double>[];
  for (final b in bars) {
    if (merged.isNotEmpty && b - merged.last < 2.5 * sp) {
      merged[merged.length - 1] = b;
    } else {
      merged.add(b);
    }
  }
  return merged;
}

/// Groups components whose x ranges touch (pieces of one sign cut apart
/// by the staff-line removal): [x0, x1, y0, y1, area] per group.
List<List<int>> _clustersByX(List<_Comp> comps) {
  final sorted = [...comps]..sort((a, b) => a.x0.compareTo(b.x0));
  final out = <List<int>>[];
  for (final c in sorted) {
    if (out.isNotEmpty && c.x0 <= out.last[1] + 1) {
      final k = out.last;
      k[1] = math.max(k[1], c.x1);
      k[2] = math.min(k[2], c.y0);
      k[3] = math.max(k[3], c.y1);
      k[4] += c.area;
    } else {
      out.add([c.x0, c.x1, c.y0, c.y1, c.area]);
    }
  }
  return out;
}

bool _stemThrough(List<List<double>> stems, double x0, double x1, double y0, double y1) {
  for (final s in stems) {
    if (x0 <= s[0] && s[0] <= x1 && s[1] <= y1 && y0 <= s[2]) return true;
  }
  return false;
}

/// Right edge of the clef (+ key signature + time signature) at the
/// start of a staff: the clef is the tall shape right at the start;
/// the signs right after it (each about an accidental or a digit in
/// size, close together, without stems) belong to the header too.
/// Where the parts of a staff's header are (see [_staffHeaderEnd]).
class _HeaderInfo {
  double? clefEnd;
  double? timeX;
  double? end;
}

double _staffHeaderEnd(_CompIndex index, _Staff st, double xStart, double sp,
    List<List<double>> stems, List<_Head> heads, _Bin nos, [_HeaderInfo? info]) {
  final top = _lineY(st, 0, xStart), bot = _lineY(st, 4, xStart);
  final near = index.comps
      .where((c) =>
  c.y0 <= bot &&
      c.y1 >= top &&
      c.h <= 9 * sp &&
      c.w <= 4 * sp && // (not a long line, e.g. a volta bracket)
      xStart - 0.5 * sp <= c.x0 &&
      c.x0 <= xStart + 3.0 * sp)
      .toList();
  final clef = _clustersByX(near)
      .where((k) => k[3] - k[2] + 1 >= 2.5 * sp && k[1] - k[0] + 1 >= 1.0 * sp)
      .toList();
  if (clef.isEmpty) return xStart;
  double end = clef.map((k) => k[1]).reduce(math.max).toDouble();
  info?.clefEnd = end;
  // (a key signature's sharps reach well above the staff)
  final others = index.comps
      .where((c) =>
  c.y0 >= top - 2.0 * sp &&
      c.y1 <= bot + 1.5 * sp &&
      c.x0 > end)
      .toList();
  for (final g in _clustersByX(others)) {
    final gx0 = g[0], gx1 = g[1], gy0 = g[2], gy1 = g[3];
    if (gx0 - end > 2.0 * sp) break;
    if (gy1 - gy0 + 1 < 0.5 * sp) break;
    if (gx1 - gx0 + 1 > 1.8 * sp) {
      // Too wide for one sign — unless it is a KEY SIGNATURE whose
      // sharps / flats touch each other (tightly engraved, or merged
      // by a low-resolution scan), which then form one wide group:
      // e.g. the three sharps of A major. Accepted when the group is
      // a run of signs (no notehead or stem in it) about as wide as
      // its signs.
      final signs = _keySignList(
          nos, st, gx0 - 0.1 * sp, gx1 + 0.1 * sp, sp);
      final width = gx1 - gx0 + 1;
      final isSignRun = signs.length >= 2 &&
          width <= 7.5 * sp &&
          signs.length * 1.4 * sp >= 0.7 * width &&
          !_stemThrough(stems, gx0.toDouble(), gx1.toDouble(),
              gy0.toDouble(), gy1.toDouble()) &&
          !heads.any((hd) =>
          hd.stem != null &&
              gx0 <= hd.cx && hd.cx <= gx1 &&
              gy0 <= hd.cy && hd.cy <= gy1);
      if (!isSignRun) break;
      end = math.max(end, gx1.toDouble());
      continue;
    }
    // A time signature fills the staff from its top to its bottom line.
    var isTime = (gy0 - top).abs() <= 0.4 * sp && (gy1 - bot).abs() <= 0.4 * sp;
    if (isTime) {
      // Digits are wide on most rows; a note (head + thin stem) is wide
      // only where its head is.
      int wide = 0;
      for (int y = gy0; y <= gy1; y++) {
        int n = 0;
        for (int x = gx0; x <= gx1; x++) {
          if (nos.at(x, y)) n++;
        }
        if (n >= 0.45 * sp) wide++;
      }
      isTime = wide / (gy1 - gy0 + 1) >= 0.6;
    }
    if (isTime && info != null && info.timeX == null) info.timeX = gx0.toDouble();
    if (!isTime) {
      // A note (with its stem) ends the header.
      if (_stemThrough(stems, gx0 - 1.0, gx1 + 1.0, gy0.toDouble(), gy1.toDouble())) break;
      // An accidental right before a note belongs to the note.
      // (only real noteheads count: a "whole note" found inside a
      // time-signature digit must not stop the header)
      if (heads.any((hd) =>
      hd.stem != null &&
          hd.x0 - gx1 >= 0 &&
          hd.x0 - gx1 <= 1.2 * sp &&
          gy0 - 0.5 * sp <= hd.cy &&
          hd.cy <= gy1 + 0.5 * sp)) {
        break;
      }
    }
    end = math.max(end, gx1.toDouble());
  }
  info?.end = end + 0.2 * sp;
  return end + 0.2 * sp;
}

// =====================================================================
// Key signatures
// =====================================================================

/// Long thin vertical strokes (the strokes of sharps, flats and
/// naturals) between columns [xa]..[xb], rows [y0]..[y1]:
/// [x, top, bottom] each. An accidental's stroke is at most about 3
/// spaces long; a longer one is a bar line or a stem.
List<List<double>> _verticalStrokes(
    _Bin nos, double xa, double xb, double y0, double y1, double sp) {
  final x0 = math.max(0, xa.floor()), x1 = math.min(nos.w - 1, xb.floor());
  final ya = math.max(0, y0.floor()), yb = math.min(nos.h - 1, y1.floor());
  final strokes = <List<int>>[]; // [first x, last x, top, bottom]
  for (int x = x0; x <= x1; x++) {
    for (final r in _columnRunsAt(nos, x, ya, yb)) {
      if (r[1] < 1.3 * sp) continue;
      final t = r[0], b = r[0] + r[1] - 1;
      List<int>? joined;
      for (final s in strokes) {
        if (x - s[1] <= 1 && t <= s[3] && b >= s[2]) {
          joined = s;
          break;
        }
      }
      if (joined != null) {
        joined[1] = x;
        joined[2] = math.min(joined[2], t);
        joined[3] = math.max(joined[3], b);
      } else {
        strokes.add([x, x, t, b]);
      }
    }
  }
  final out = [
    for (final s in strokes)
      if (s[1] - s[0] + 1 <= 0.3 * sp && s[3] - s[2] <= 3.2 * sp)
        [(s[0] + s[1]) / 2, s[2].toDouble(), s[3].toDouble()]
  ];
  out.sort((a, b) => a[0].compareTo(b[0]));
  return out;
}

/// Fraction of black pixels in a rectangle (0 when it is empty).
double _inkMean(_Bin img, int x0, int y0, int x1, int y1) {
  x0 = math.max(0, x0);
  y0 = math.max(0, y0);
  x1 = math.min(img.w - 1, x1);
  y1 = math.min(img.h - 1, y1);
  if (x1 < x0 || y1 < y0) return 0;
  int n = 0;
  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      if (img.at(x, y)) n++;
    }
  }
  return n / ((x1 - x0 + 1) * (y1 - y0 + 1));
}

/// One sign of a key signature.
class _KeySign {
  final double x;
  final String kind; // '+' sharp, '-' flat, 'x' natural
  final double top, bottom;
  _KeySign(this.x, this.kind, this.top, this.bottom);
}

/// The sharps, flats and naturals written between [xa] and [xb] in
/// staff [st], left to right — told apart by their strokes: a sharp
/// has two level strokes, a natural two strokes of which the left goes
/// up higher and the right down lower, a flat one stroke with a bowl at
/// the bottom right.
List<_KeySign> _keySignList(_Bin nos, _Staff st, double xa, double xb, double sp) {
  if (xb - xa < 0.4 * sp) return const [];
  final xm = (xa + xb) / 2;
  final top = _lineY(st, 0, xm), bot = _lineY(st, 4, xm);
  final strokes = _verticalStrokes(nos, xa, xb, top - 1.6 * sp, bot + 1.0 * sp, sp);
  final signs = <_KeySign>[];
  final used = <int>{};
  for (int i = 0; i < strokes.length; i++) {
    if (used.contains(i)) continue;
    final x = strokes[i][0], t = strokes[i][1], b = strokes[i][2];
    int? pair;
    for (int j = i + 1; j < strokes.length; j++) {
      final x2 = strokes[j][0], t2 = strokes[j][1], b2 = strokes[j][2];
      if (x2 - x > 0.75 * sp) break;
      if (x2 - x < 0.2 * sp) continue;
      final overlap = math.min(b, b2) - math.max(t, t2);
      if (overlap >= 0.4 * math.min(b - t, b2 - t2)) {
        pair = j;
        break;
      }
    }
    if (pair != null) {
      final x2 = strokes[pair][0], t2 = strokes[pair][1], b2 = strokes[pair][2];
      used.add(pair);
      final natural = t < t2 - 0.45 * sp && b2 > b + 0.45 * sp;
      signs.add(_KeySign((x + x2) / 2, natural ? 'x' : '+', math.min(t, t2), math.max(b, b2)));
      continue;
    }
    final xr0 = (x + 0.15 * sp).floor(), xr1 = (x + 0.8 * sp).floor();
    final bowl = _inkMean(nos, xr0, (b - 0.9 * sp).floor(), xr1, b.floor());
    final above = _inkMean(nos, xr0, t.floor(), xr1, (t + 0.6 * sp).floor() - 1);
    if (bowl >= 0.12 && above < 0.12) {
      signs.add(_KeySign(x + 0.3 * sp, '-', t, b));
    }
  }
  return signs;
}

/// [sharps, flats, naturals] of a list of signs.
List<int> _signCounts(List<_KeySign> signs) => [
  signs.where((s) => s.kind == '+').length,
  signs.where((s) => s.kind == '-').length,
  signs.where((s) => s.kind == 'x').length,
];

/// The key from the sign counts of the staves: +n sharps, -n flats, 0
/// when only naturals cancel the old key; null when there is no sign.
int? _keyFromCounts(List<List<int>> counts) {
  if (counts.isEmpty) return null;
  var best = counts.first;
  for (final c in counts) {
    if (math.max(c[0], c[1]) > math.max(best[0], best[1])) best = c;
  }
  if (best[0] == 0 && best[1] == 0) {
    return counts.any((c) => c[2] > 0) ? 0 : null;
  }
  return best[0] >= best[1] ? best[0] : -best[1];
}

/// A new key signature at the start of a measure (right after its bar
/// line, before the first note): [key, x where the music starts], or
/// null. The run of signs must be in every staff and must not be just
/// the accidental of the first note.
List<double>? _keyChangeAt(
    _Bin nos, List<_Staff> staves, double mx0, double sp, List<_Head> heads) {
  final counts = <List<int>>[];
  double end = mx0;
  for (final st in staves) {
    final signs = _keySignList(nos, st, mx0 + 0.3 * sp, mx0 + 8 * sp, sp);
    final run = <_KeySign>[];
    for (final sg in signs) {
      final prev = run.isEmpty ? mx0 : run.last.x;
      if (sg.x - prev > (run.isEmpty ? 2.0 : 1.6) * sp) break;
      run.add(sg);
    }
    if (run.isEmpty) return null;
    final last = run.last;
    if (run.length == 1 &&
        heads.any((h) =>
        h.x0 - last.x >= 0 &&
            h.x0 - last.x <= 1.4 * sp &&
            last.top - 0.5 * sp <= h.cy &&
            h.cy <= last.bottom + 0.5 * sp)) {
      return null;
    }
    counts.add(_signCounts(run));
    end = math.max(end, last.x + 0.7 * sp);
  }
  final key = _keyFromCounts(counts);
  if (key == null) return null;
  return [key.toDouble(), end];
}

/// Quarter, eighth, half and whole rests inside one staff of one
/// measure: [x, duration] pairs (duration [OmrEvent.wholeMeasure] for a
/// whole rest).
List<List<int>> _findRests(_CompIndex index, _Staff st, double mx0, double mx1,
    double sp, List<_Head> heads, List<List<double>> stems, double headerEnd) {
  final top = math.min(_lineY(st, 0, mx0), _lineY(st, 0, mx1)) - 0.5 * sp;
  final bot = math.max(_lineY(st, 4, mx0), _lineY(st, 4, mx1)) + 0.5 * sp;
  final from = math.max(mx0, headerEnd) + 0.3 * sp;
  final comps = index.comps
      .where((c) =>
  c.y0 >= top && c.y1 <= bot && from < c.x0 && c.x0 + c.w < mx1 - 0.3 * sp)
      .toList();
  // Pieces of one sign (cut apart by the staff-line removal) overlap in x.
  final sorted = [...comps]..sort((a, b) => a.x0.compareTo(b.x0));
  final clusters = <_RestCluster>[];
  for (final c in sorted) {
    if (clusters.isNotEmpty && c.x0 <= clusters.last.x1 + 1) {
      final k = clusters.last;
      k.x1 = math.max(k.x1, c.x1);
      k.y0 = math.min(k.y0, c.y0);
      k.y1 = math.max(k.y1, c.y1);
      k.area += c.area;
      k.parts.add(c);
    } else {
      clusters.add(_RestCluster(c.x0, c.x1, c.y0, c.y1, c.area, [c]));
    }
  }

  List<int>? classify(_RestCluster k) {
    final kx0 = k.x0, kx1 = k.x1, ky0 = k.y0, ky1 = k.y1;
    final w = kx1 - kx0 + 1, h = ky1 - ky0 + 1;
    final cy = (ky0 + ky1) / 2;
    // Not part of a note: no notehead inside, no stem through it, and
    // not the accidental of a note just to its right.
    if (heads.any((hd) =>
    kx0 - 2 <= hd.cx && hd.cx <= kx1 + 2 && ky0 - 2 <= hd.cy && hd.cy <= ky1 + 2)) {
      return null;
    }
    if (_stemThrough(stems, kx0 - 1.0, kx1 + 1.0, ky0.toDouble(), ky1.toDouble())) {
      return null;
    }
    // (only when nothing else - e.g. the note's own accidental - lies
    // between this sign and the note)
    bool isAccidentalOf(_Head hd) {
      if (!(hd.x0 - kx1 >= 0 &&
          hd.x0 - kx1 <= 1.2 * sp &&
          hd.cy - 1.5 * sp <= cy &&
          cy <= hd.cy + 1.5 * sp)) {
        return false;
      }
      return !clusters.any((o) => !identical(o, k) && kx1 < o.x0 && o.x0 < hd.x0);
    }

    if (heads.any(isAccidentalOf)) return null;
    // A flag that came apart from its up-stem (blurred photo).
    if (stems.any((s) =>
    -0.2 * sp <= kx0 - s[0] &&
        kx0 - s[0] <= 1.0 * sp &&
        s[1] - 0.3 * sp <= ky0 &&
        ky1 <= s[2] + 0.5 * sp)) {
      return null;
    }
    final fill = k.area / (w * h);
    // The staff lines where this sign is (pages are not always level).
    final kx = (kx0 + kx1) / 2;
    final midline = _lineY(st, 2, kx);
    final line1 = _lineY(st, 1, kx);
    if (!(_lineY(st, 0, kx) - 0.5 * sp <= ky0 && ky1 <= _lineY(st, 4, kx) + 0.5 * sp)) {
      return null;
    }
    if (0.3 * sp <= h && h <= 0.75 * sp && 0.8 * sp <= w && w <= 1.7 * sp && fill >= 0.7) {
      // A whole rest hangs from the 4th line (second from the top), a
      // half rest sits on the middle line.
      if ((ky0 - line1).abs() <= (ky1 - midline).abs()) {
        return [kx0, OmrEvent.wholeMeasure];
      }
      return [kx0, 64];
    }
    if (2.6 * sp <= h && h <= 4.0 * sp && 0.6 * sp <= w && w <= 1.3 * sp &&
        (cy - midline).abs() <= 0.8 * sp) {
      return [kx0, 32]; // quarter rest
    }
    if (1.2 * sp <= h && h < 2.6 * sp && 0.6 * sp <= w && w <= 1.4 * sp &&
        (cy - midline).abs() <= 1.0 * sp) {
      return [kx0, 16]; // eighth rest
    }
    return null;
  }

  final rests = <List<int>>[];
  for (final k in clusters) {
    var r = classify(k);
    if (r == null && k.parts.length > 1) {
      // A rest touching another sign: try its pieces alone.
      for (final c in k.parts) {
        r = classify(_RestCluster(c.x0, c.x1, c.y0, c.y1, c.area, [c]));
        if (r != null) break;
      }
    }
    if (r != null) rests.add(r);
  }
  return rests;
}

class _RestCluster {
  int x0, x1, y0, y1, area;
  final List<_Comp> parts;
  _RestCluster(this.x0, this.x1, this.y0, this.y1, this.area, this.parts);
}

// =====================================================================
// Noteheads
// =====================================================================

class _Stem {
  final int x;
  final int dir; // -1 up, 1 down
  final int end;
  final int len;
  _Stem(this.x, this.dir, this.end, this.len);
}

class _Head {
  final double x0, x1, cx, cy;
  final bool filled;
  final bool whole;
  _Stem? stem;
  _Head(this.x0, this.x1, this.cx, this.cy, this.filled, {this.whole = false});
}

class _Chord {
  _Stem? stem;
  final List<_Head> heads;
  final bool filled;
  _Chord(this.stem, this.heads, this.filled);
}

List<_Head> _findFilledHeads(_Bin bw, double sp, [_Bin? nos]) {
  final kw = (0.5 * sp).round();
  final kh = (0.65 * sp).round();
  final e = _erodeBox(bw, kw, kh);
  final heads = <_Head>[];
  for (final c in _components(e, eight: true)) {
    final x0 = c.x - kw ~/ 2;
    final x1 = c.x + c.w - 1 + kw ~/ 2;
    final wo = x1 - x0 + 1;
    final ho = c.h + 2 * (kh ~/ 2);
    if (!(0.85 * sp <= wo && wo <= 3.4 * sp)) continue;
    if (ho < 0.6 * sp || ho > 6.5 * sp) continue;
    // A chord with a second has heads on both sides of the stem: split
    // such a block into a left and a right column of heads.
    final parts = wo > 2.0 * sp
        ? [
      [x0, x0 + wo ~/ 2 - 1],
      [x0 + wo ~/ 2, x1]
    ]
        : [
      [x0, x1]
    ];
    for (final p in parts) {
      final px0 = p[0], px1 = p[1];
      final cx0 = math.max(0, px0 + kw ~/ 2);
      final cx1 = math.min(e.w - 1, px1 - kw ~/ 2);
      int firstRow = -1, lastRow = -1;
      for (int y = c.y0; y <= c.y1; y++) {
        bool any = false;
        for (int x = cx0; x <= cx1; x++) {
          if (e.at(x, y)) {
            any = true;
            break;
          }
        }
        if (any) {
          if (firstRow == -1) firstRow = y;
          lastRow = y;
        }
      }
      if (firstRow == -1) continue;
      final py0 = firstRow - kh ~/ 2;
      final py1 = lastRow + kh ~/ 2;
      final pho = py1 - py0 + 1;
      if (pho < 0.6 * sp) continue;
      final n = math.max(1, (pho / sp).round());
      for (int k = 0; k < n; k++) {
        var cy = py0 + (k + 0.5) * pho / n;
        if (n == 1) {
          // Centre of the ink of this head (more exact than the shrunken
          // blob, which a stem or beam can pull aside): the middle of
          // the rows that are mostly ink.
          final xa = (px0 + 0.25 * (px1 - px0)).toInt();
          final xb = (px1 - 0.25 * (px1 - px0)).toInt() + 1;
          final ya = math.max(0, (cy - 0.75 * sp).toInt());
          final yb = math.min(bw.h, (cy + 0.75 * sp).toInt() + 1);
          // (in the image without staff lines: a full-width staff line
          // row next to the head would pull the centre towards it)
          final img = nos ?? bw;
          int firstFull = -1, lastFull = -1, fullRows = 0;
          for (int y = ya; y < yb; y++) {
            int ink = 0;
            for (int x = math.max(0, xa); x < math.min(bw.w, xb); x++) {
              if (img.at(x, y)) ink++;
            }
            if (ink >= 0.7 * (xb - xa)) {
              if (firstFull == -1) firstFull = y;
              lastFull = y;
              fullRows++;
            }
          }
          if (fullRows >= 0.4 * sp) {
            cy = (firstFull + lastFull) / 2;
          }
        }
        heads.add(_Head(px0.toDouble(), px1.toDouble(), (px0 + px1) / 2, cy, true));
      }
    }
  }
  return heads;
}

/// Half/whole noteheads: small enclosed white holes inside a ring of
/// notehead size.
/// Half/whole noteheads: small enclosed white holes. [holesFrom]: the
/// image to look for the holes in (default [bw]) — in the image without
/// staff lines a hole crossed by a staff line is one hole.
List<_Head> _findHollowHeads(_Bin bw, double sp, [_Bin? holesFrom]) {
  final holes = <List<int>>[];
  for (final c in _components(holesFrom ?? bw, eight: false, value: 0)) {
    if (c.touchesBorder) continue;
    if (0.25 * sp <= c.w &&
        c.w <= 1.2 * sp &&
        0.15 * sp <= c.h &&
        c.h <= 0.95 * sp &&
        c.area >= 0.06 * sp * sp) {
      if (c.h > 0.8 * sp) {
        // A hole the height of a whole space: only a head in a space,
        // next to a staff line (black far to both sides).
        final xa = (c.x0 - sp).floor(), xb = (c.x1 + sp).floor();
        final above = c.y0 >= 1 ? _inkMean(bw, xa, c.y0 - 1, xb, c.y0 - 1) : 0.0;
        final below = c.y1 + 1 < bw.h ? _inkMean(bw, xa, c.y1 + 1, xb, c.y1 + 1) : 0.0;
        if (above <= 0.9 && below <= 0.9) continue;
      }
      holes.add([c.x0, c.y0, c.x1, c.y1]);
    }
  }
  // Merge holes split by a staff line.
  holes.sort((a, b) => a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]));
  final merged = <List<int>>[];
  for (final r in holes) {
    bool done = false;
    for (final m in merged) {
      // (only into one head-sized hole: the holes of a chord's stacked
      // heads stay apart)
      if (((r[0] + r[2]) / 2 - (m[0] + m[2]) / 2).abs() < 0.4 * sp &&
          (r[1] - m[3]) <= 0.4 * sp &&
          (m[1] - r[3]) <= 0.4 * sp &&
          math.max(m[3], r[3]) - math.min(m[1], r[1]) + 1 <= 0.9 * sp) {
        m[0] = math.min(m[0], r[0]);
        m[1] = math.min(m[1], r[1]);
        m[2] = math.max(m[2], r[2]);
        m[3] = math.max(m[3], r[3]);
        done = true;
        break;
      }
    }
    if (!done) merged.add([...r]);
  }
  final heads = <_Head>[];
  for (final m in merged) {
    final x0 = m[0], y0 = m[1], x1 = m[2], y1 = m[3];
    final hh = y1 - y0 + 1;
    if (!(0.35 * sp <= hh && hh <= 0.95 * sp)) continue;
    final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    final ix = cx.round();
    var iy = cy.round();
    // A head ON a staff line: its middle row is the line itself, so
    // measure across a row of the hole just above or below it.
    for (final d in const [0, 1, -1, 2, -2, 3, -3]) {
      final yy = iy + d;
      if (yy >= 0 && yy < bw.h && yy >= y0 && yy <= y1 && ix >= 0 && ix < bw.w &&
          !bw.at(ix, yy)) {
        iy = yy;
        break;
      }
    }
    int walk(int dx) {
      int x = ix;
      while (x >= 0 && x < bw.w && !bw.at(x, iy)) {
        x += dx;
      }
      int n = 0;
      while (x >= 0 && x < bw.w && bw.at(x, iy) && n < sp) {
        x += dx;
        n++;
      }
      return x;
    }

    var left = walk(-1), right = walk(1);
    var outerW = right - left;
    // (a stem touching the ring makes it wider)
    if (!(1.0 * sp <= outerW && outerW <= 2.4 * sp)) continue;
    // Ring sides must be thicker than a stem / letter stroke.
    if ((x0 - left) < 0.12 * sp || (right - x1) < 0.12 * sp) continue;

    // The hole of a sharp or a natural: the strokes on BOTH sides of it
    // go on well above and below it (a notehead's ring is short; a stem
    // is only on one side).
    bool sideLong(int from, int to) {
      for (int x = from; x <= to; x++) {
        if (x < 0 || x >= bw.w) continue;
        int up = 0, dn = 0;
        int y = y0 - 1;
        while (y >= 0 && bw.at(x, y) && up < 2 * sp) {
          y--;
          up++;
        }
        y = y1 + 1;
        while (y < bw.h && bw.at(x, y) && dn < 2 * sp) {
          y++;
          dn++;
        }
        if (up > 0.45 * sp && dn > 0.45 * sp) return true;
      }
      return false;
    }

    if (sideLong(x0 - 3, x0 - 1) && sideLong(x1 + 1, x1 + 3)) continue;
    // A "hole" closed by a bar line (between it and a sign next to it).
    bool barSide(int from, int to) {
      for (int x = from; x <= to; x++) {
        if (x < 0 || x >= bw.w) continue;
        final y = cy.toInt();
        int u = 0, d = 0;
        while (y - u - 1 >= 0 && bw.at(x, y - u - 1) && u < 7 * sp) {
          u++;
        }
        while (y + d + 1 < bw.h && bw.at(x, y + d + 1) && d < 7 * sp) {
          d++;
        }
        if (u + d > 6 * sp) return true;
      }
      return false;
    }

    if (barSide(x0 - 3, x0 - 1) || barSide(x1 + 1, x1 + 3)) continue;
    // A stem touching the ring: the head ends where the ring does (the
    // thinner side tells how thick the ring is).
    final tl = x0 - left, tr = right - x1;
    if (outerW > 1.9 * sp) {
      if (tl > tr + 0.2 * sp) {
        left = x0 - tr - 1;
      } else if (tr > tl + 0.2 * sp) {
        right = x1 + tl + 1;
      }
      outerW = right - left;
    }
    heads.add(_Head(left.toDouble(), right.toDouble(), cx, cy, false,
        whole: outerW >= 1.45 * sp));
  }
  return heads;
}

// =====================================================================
// Stems, beams, flags, dots
// =====================================================================

int _vrun(_Bin img, int x, int y, int d, int maxgap) {
  int end = y, gap = 0, yy = y;
  while (yy >= 0 && yy < img.h) {
    if (img.at(x, yy)) {
      end = yy;
      gap = 0;
    } else {
      gap++;
      if (gap > maxgap) break;
    }
    yy += d;
  }
  return end;
}

_Stem? _stemSearch(_Bin nos, _Head head, double sp, List<List<int>> combos) {
  _Stem? best;
  final cy = head.cy.round();
  for (final combo in combos) {
    final d = combo[0];
    for (int x = combo[1]; x <= combo[2]; x++) {
      if (x < 0 || x >= nos.w || cy < 0 || cy >= nos.h) continue;
      final end = _vrun(nos, x, cy, d, 3);
      final length = (end - cy).abs();
      if (length < 2.0 * sp) continue;
      final ym = (cy + end) ~/ 2;
      int l = x, r = x;
      while (l - 1 >= 0 && nos.at(l - 1, ym)) {
        l--;
      }
      while (r + 1 < nos.w && nos.at(r + 1, ym)) {
        r++;
      }
      if (r - l + 1 > 0.4 * sp) continue;
      if (best == null || length > best.len) {
        best = _Stem(x, d, end, length);
      }
    }
  }
  return best;
}

_Stem? _findStem(_Bin nos, _Head head, double sp) {
  final right = [(head.x1 - 0.3 * sp).toInt(), (head.x1 + 0.2 * sp).toInt()];
  final left = [(head.x0 - 0.2 * sp).toInt(), (head.x0 + 0.3 * sp).toInt()];
  // Normal: up-stem on the right, down-stem on the left.
  return _stemSearch(nos, head, sp, [
    [-1, right[0], right[1]],
    [1, left[0], left[1]],
  ]) ??
      // A head pushed to the other side of the stem (a second in a chord).
      _stemSearch(nos, head, sp, [
        [-1, left[0], left[1]],
        [1, right[0], right[1]],
      ]);
}

/// Height of the ink at the head's centre (a notehead is about one
/// staff space tall; a beam is thinner).
int _verticalThickness(_Bin nos, _Head h) {
  final x = h.cx.round(), y = h.cy.round();
  if (y < 0 || y >= nos.h) return 0;
  int best = 0;
  for (int xx = math.max(0, x - 2); xx < math.min(nos.w, x + 3); xx++) {
    if (!nos.at(xx, y)) continue;
    int t = y, b = y;
    while (t > 0 && nos.at(xx, t - 1)) {
      t--;
    }
    while (b < nos.h - 1 && nos.at(xx, b + 1)) {
      b++;
    }
    best = math.max(best, b - t + 1);
  }
  return best;
}

/// Length of the ink along the head's row, through its stem: a beam
/// runs on to the next stem, a notehead stops.
int _horizontalRun(_Bin nos, _Head h) {
  final y = h.cy.round();
  final x = h.stem!.x;
  if (y < 0 || y >= nos.h) return 0;
  int l = x, gap = 0;
  while (l - 1 >= 0 && (nos.at(l - 1, y) || (gap < 1 && l - 2 >= 0 && nos.at(l - 2, y)))) {
    gap = nos.at(l - 1, y) ? 0 : gap + 1;
    l--;
  }
  int r = x;
  gap = 0;
  while (r + 1 < nos.w && (nos.at(r + 1, y) || (gap < 1 && r + 2 < nos.w && nos.at(r + 2, y)))) {
    gap = nos.at(r + 1, y) ? 0 : gap + 1;
    r++;
  }
  return r - l + 1;
}

/// Whether filled "head" [h] is really a piece of a beam: the same stem
/// joins it to a real notehead g (h sits at the far end of g's stem
/// and finds that stem running the other way), and of the two, h is
/// the thin one or the one that runs on sideways.
bool _isBeamPiece(_Bin nos, _Head h, List<_Head> heads, double sp) {
  final st = h.stem;
  if (st == null) return false;
  for (final g in heads) {
    final gs = g.stem;
    if (identical(g, h) || gs == null || gs.dir == st.dir) continue;
    if ((gs.x - st.x).abs() <= 3 &&
        (gs.end - h.cy).abs() <= 0.8 * sp &&
        (g.cy - h.cy).abs() > 1.5 * sp) {
      if (_verticalThickness(nos, h) < 0.95 * sp) return true;
      if (_horizontalRun(nos, h) > _horizontalRun(nos, g) + 0.3 * sp) return true;
    }
  }
  return false;
}

/// Lengths of the black runs in column [x] between rows [y0] and [y1]
/// (inclusive).
List<int> _columnRuns(_Bin img, int x, int y0, int y1) {
  final out = <int>[];
  int run = 0;
  for (int y = math.max(0, y0); y <= math.min(img.h - 1, y1); y++) {
    if (img.at(x, y)) {
      run++;
    } else if (run > 0) {
      out.add(run);
      run = 0;
    }
  }
  if (run > 0) out.add(run);
  return out;
}

/// Black runs of column [x] between rows [y0] and [y1], as [start, length].
List<List<int>> _columnRunsAt(_Bin img, int x, int y0, int y1) {
  final out = <List<int>>[];
  int run = 0;
  final ya = math.max(0, y0), yb = math.min(img.h - 1, y1);
  for (int y = ya; y <= yb; y++) {
    if (img.at(x, y)) {
      run++;
    } else if (run > 0) {
      out.add([y - run, run]);
      run = 0;
    }
  }
  if (run > 0) out.add([yb + 1 - run, run]);
  return out;
}

/// Some row of the run [r0]..[r0]+[l]-1 in column [xs] is black all the
/// way to the stem at [x] (one-pixel gaps allowed).
bool _joinedToStem(_Bin nos, int x, int xs, int r0, int l) {
  final lo = math.min(x, xs), hi = math.max(x, xs);
  if (lo < 0 || hi >= nos.w) return false;
  for (int r = r0; r < r0 + l; r++) {
    if (r < 0 || r >= nos.h) continue;
    int gaps = 0;
    bool ok = true;
    for (int xx = lo; xx <= hi; xx++) {
      if (nos.at(xx, r)) {
        gaps = 0;
      } else if (++gaps > 1) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

/// A blob as wide as two noteheads with the stem through its middle is
/// the two notes of a second (one on each side of the stem, one step
/// apart): returns them as two heads; otherwise just [h].
List<_Head> _splitSecond(_Bin nos, _Head h, int stx, double sp) {
  if (h.x1 - h.x0 < 1.5 * sp) return [h];
  final ya = math.max(0, (h.cy - 1.0 * sp).toInt());
  final yb = math.min(nos.h - 1, (h.cy + 1.0 * sp).toInt());
  final out = <_Head>[];
  for (final r in [
    [h.x0.toInt(), stx - 2],
    [stx + 3, h.x1.toInt()]
  ]) {
    final xa = math.max(0, r[0]), xb = math.min(nos.w - 1, r[1]);
    if (xb - xa < 0.4 * sp) return [h];
    int first = -1, last = -1, count = 0;
    for (int y = ya; y <= yb; y++) {
      int ink = 0;
      for (int x = xa; x <= xb; x++) {
        if (nos.at(x, y)) ink++;
      }
      if (ink >= 0.6 * (xb - xa + 1)) {
        if (first < 0) first = y;
        last = y;
        count++;
      }
    }
    if (count < 0.4 * sp) return [h];
    out.add(_Head(xa.toDouble(), xb.toDouble(), (xa + xb) / 2, (first + last) / 2, true)
      ..stem = h.stem);
  }
  if ((out[0].cy - out[1].cy).abs() < 0.25 * sp) return [h];
  return out;
}

/// Fraction of black pixels in a w x h box centred on (cx, cy).
double _inkFraction(_Bin img, double cx, double cy, double w, double h) {
  final x0 = (cx - w / 2).round(), x1 = (cx + w / 2).round();
  final y0 = (cy - h / 2).round(), y1 = (cy + h / 2).round();
  if (x0 < 0 || y0 < 0 || x1 >= img.w || y1 >= img.h) return 0;
  int n = 0, all = 0;
  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      all++;
      if (img.at(x, y)) n++;
    }
  }
  return all == 0 ? 0 : n / all;
}

/// A notehead at the stem's start end of a chord can be missed (pale,
/// or squashed by a staff line in a photo). Looks a third beyond the
/// last head for a solid head-sized blob that the stem reaches.
List<_Head> _extendChord(_Bin nos, List<_Head> heads, _Stem stem, double sp) {
  final hs = [...heads];
  for (int i = 0; i < 2; i++) {
    _Head edge = hs.first;
    for (final h in hs) {
      if (stem.dir == 1 ? h.cy < edge.cy : h.cy > edge.cy) edge = h;
    }
    final step = stem.dir == 1 ? -1 : 1;
    bool added = false;
    // A third or a fourth beyond (a second would sit on the other side
    // of the stem).
    for (final k in const [2, 3]) {
      final y = edge.cy + step * k * sp / 2;
      final ya = math.min(edge.cy, y).round(), yb = math.max(edge.cy, y).round();
      bool reached = true;
      for (int yy = ya; yy <= yb && reached; yy++) {
        bool any = false;
        for (int xx = stem.x - 1; xx <= stem.x + 1; xx++) {
          if (xx >= 0 && xx < nos.w && yy >= 0 && yy < nos.h && nos.at(xx, yy)) any = true;
        }
        reached = any;
      }
      if (!reached) continue; // the stem must reach the new head
      if (_inkFraction(nos, edge.cx, y, 0.9 * sp, 0.5 * sp) >= 0.7 &&
          _inkFraction(nos, edge.cx, y + step * 0.75 * sp, 0.9 * sp, 0.2 * sp) < 0.5) {
        hs.add(_Head(edge.x0, edge.x1, edge.cx, y, true)..stem = edge.stem);
        added = true;
        break;
      }
    }
    if (!added) break;
  }
  hs.sort((a, b) => a.cy.compareTo(b.cy));
  return hs;
}

/// Most common vertical run length next to stem ends (= one beam).
double _beamThickness(_Bin nos, List<_Head> heads, double sp) {
  final c = <int, int>{};
  for (final h in heads) {
    final s = h.stem;
    if (s == null) continue;
    final y0 = s.dir == -1 ? s.end - 1 : (s.end - 2.5 * sp).toInt();
    final y1 = s.dir == -1 ? (s.end + 2.5 * sp).toInt() : s.end + 1;
    for (final side in const [-1, 1]) {
      final xs = (s.x + side * 0.5 * sp).toInt();
      if (xs < 0 || xs >= nos.w) continue;
      for (final l in _columnRuns(nos, xs, y0, y1 - 1)) {
        if (0.3 * sp <= l && l <= 1.0 * sp) c[l] = (c[l] ?? 0) + 1;
      }
    }
  }
  if (c.isEmpty) return 0.5 * sp;
  int best = -1;
  double bestScore = -1;
  c.forEach((l, n) {
    final score = n + 0.5 * ((c[l - 1] ?? 0) + (c[l + 1] ?? 0));
    if (score > bestScore) {
      bestScore = score;
      best = l;
    }
  });
  return best.toDouble();
}

/// Which sides of the bar line at [barX] have repeat dots: [left,
/// right]. Repeat dots are a pair of small round blobs, one in each of
/// the two middle spaces of a staff, right next to the bar line (left
/// of it for an end repeat, right of it for a start). Piano music puts
/// them in both staves; requiring both keeps specks (photo noise at a
/// page edge) from passing for repeat dots.
List<bool> _repeatDots(_CompIndex index, List<_Staff> staves, double barX, double sp) {
  int left = 0, right = 0;
  for (final st in staves) {
    final y1 = _lineY(st, 1, barX) + sp / 2; // space below the 2nd line
    final y2 = _lineY(st, 2, barX) + sp / 2; // space below the middle line
    for (final side in const [-1, 1]) {
      final lo = side == -1 ? barX - 2.4 * sp : barX + 0.15 * sp;
      final hi = side == -1 ? barX - 0.15 * sp : barX + 2.4 * sp;
      final dots = [
        for (final c in index.comps)
          if (lo <= c.x0 + c.w / 2 &&
              c.x0 + c.w / 2 <= hi &&
              0.2 * sp <= c.w &&
              c.w <= 0.8 * sp &&
              0.2 * sp <= c.h &&
              c.h <= 0.8 * sp &&
              c.area >= 0.5 * c.w * c.h)
            c
      ];
      final up = dots.where((c) => (c.y0 + c.h / 2 - y1).abs() <= 0.35 * sp);
      final down = dots.where((c) => (c.y0 + c.h / 2 - y2).abs() <= 0.35 * sp);
      final pair = up.any((u) => down.any(
              (d) => ((u.x0 + u.w / 2) - (d.x0 + d.w / 2)).abs() <= 0.4 * sp));
      if (pair) {
        if (side == -1) {
          left++;
        } else {
          right++;
        }
      }
    }
  }
  return [left >= staves.length, right >= staves.length];
}

/// A wavy vertical line just left of a chord (an arpeggio): narrow,
/// reaching over the whole chord, one stroke per row, swinging left and
/// right (a stem or an accidental does not swing).
bool _hasArpeggio(_Bin nos, _CompIndex index, List<_Head> heads, double sp) {
  double x0 = heads.first.x0, ytop = heads.first.cy, ybot = heads.first.cy;
  for (final h in heads) {
    x0 = math.min(x0, h.x0);
    ytop = math.min(ytop, h.cy);
    ybot = math.max(ybot, h.cy);
  }
  final lo = x0 - 1.9 * sp, hi = x0 - 0.1 * sp;
  final comps = [
    for (final c in index.comps)
      if (c.x0 >= lo && c.x1 <= hi && c.y0 <= ybot + 0.5 * sp && c.y1 >= ytop - 0.5 * sp) c
  ];
  for (final k in _clustersByX(comps)) {
    final cx0 = k[0], cx1 = k[1], cy0 = k[2], cy1 = k[3];
    final h = cy1 - cy0 + 1, w = cx1 - cx0 + 1;
    if (cy0 > ytop - 0.1 * sp || cy1 < ybot + 0.1 * sp) continue;
    if (h < 1.5 * sp || w > 1.0 * sp || w < 0.2 * sp) continue;
    final centres = <double>[];
    final widths = <int>[];
    int singles = 0;
    for (int y = cy0; y <= cy1; y++) {
      int first = -1, last = -1, runs = 0;
      bool prev = false;
      for (int x = cx0; x <= cx1; x++) {
        final v = nos.at(x, y);
        if (v) {
          if (first < 0) first = x;
          last = x;
          if (!prev) runs++;
        }
        prev = v;
      }
      if (first < 0) continue;
      if (runs == 1) singles++;
      widths.add(last - first + 1);
      centres.add((first + last) / 2);
    }
    if (centres.length < 0.8 * h || singles < 0.75 * centres.length) continue;
    final sortedW = [...widths]..sort();
    if (sortedW[sortedW.length ~/ 2] > 0.5 * sp) continue;
    final sortedC = [...centres]..sort();
    final mid = sortedC[sortedC.length ~/ 2];
    final thr = 0.1 * sp;
    int swings = 0, state = 0;
    for (final c in centres) {
      final d = c - mid;
      if (d > thr && state <= 0) {
        swings++;
        state = 1;
      } else if (d < -thr && state >= 0) {
        swings++;
        state = -1;
      }
    }
    if (swings >= math.max(3, h / (1.4 * sp))) return true;
  }
  return false;
}

/// Beams/flags at the stem's far end. Beams printed close together may
/// merge into one thick run, so a long run counts as several.
int _countBars(_Bin nos, int x, int d, int end, double nearHeadY, double sp, double bt) {
  final span = math.min(3.0 * sp, (end - nearHeadY).abs() - 1.0 * sp);
  if (span < 0.5 * sp) return 0;
  final y0 = d == -1 ? end - 1 : (end - span).toInt();
  final y1 = d == -1 ? (end + span).toInt() : end + 1;
  final counts = <int, int>{};
  for (final off in const [0.3, 0.4, 0.5, 0.6, 0.7]) {
    for (final side in const [-1, 1]) {
      final xs = (x + side * off * sp).round();
      if (xs < 0 || xs >= nos.w) continue;
      int n = 0;
      for (final r in _columnRunsAt(nos, xs, y0, y1)) {
        final l = r[1];
        if (l < 0.5 * bt || l > 3.6 * bt) continue;
        // A beam or flag is joined to the stem; a "Ped." mark or a slur
        // just passing by is not.
        if (!_joinedToStem(nos, x, xs, r[0], l)) continue;
        n += math.max(1, (l / bt + 0.3).floor());
      }
      if (n > 0) {
        final k = math.min(n, 3);
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
  }
  if (counts.isEmpty) return 0;
  // The most frequent count wins (ties: the larger one).
  int best = 0, bestN = -1;
  counts.forEach((k, n) {
    if (n > bestN || (n == bestN && k > best)) {
      bestN = n;
      best = k;
    }
  });
  return best;
}

/// Augmentation dot: a small, separate, round blob right of the head
/// (in the same space, or the space just above when on a line).
bool _hasDot(_CompIndex index, double chordX1, double cy, double sp) {
  for (final c in index.inside(chordX1 + 0.05 * sp, cy - 0.9 * sp,
      chordX1 + 1.4 * sp, cy + 0.5 * sp)) {
    if (0.25 * sp <= c.w &&
        c.w <= 0.65 * sp &&
        0.25 * sp <= c.h &&
        c.h <= 0.95 * sp &&
        c.area >= 0.5 * c.w * c.h) {
      return true;
    }
  }
  return false;
}

// =====================================================================
// Accidentals
// =====================================================================

/// Looks just left of the head; returns '+', '-', 'x', '++', '--' or ''.
/// Uses whole connected components (of the line-free image) lying
/// completely inside the area left of the head, so pieces of stems,
/// beams or slurs passing through are never mistaken for a sign.
String _classifyAccidental(_CompIndex index, _Head head, double sp,
    double xLimit, List<List<double>> headCentres) {
  final cy = head.cy;
  final wx0 = math.max(xLimit, head.x0 - 2.4 * sp);
  final comps = index
      .inside(wx0, cy - 2.2 * sp, head.x0 - 1, cy + 1.8 * sp)
      .where((c) => !headCentres.any((p) =>
  c.x0 <= p[0] && p[0] <= c.x0 + c.w && c.y0 <= p[1] && p[1] <= c.y0 + c.h))
      .toList();
  var kind = _accidentalFromComps(index, comps, head, sp);
  final img = index.nos;
  if (kind.isEmpty && img != null) {
    // The sign may touch a bar line, a stem or the note itself: look
    // again with those cut away. Only sharps and naturals count here —
    // two strokes are hard to mistake; a flat-like shape is too often a
    // piece of a beam or a flag.
    final local = _localSignComps(img, index.stems, head, sp, wx0,
        cy - 2.6 * sp, cy + 2.0 * sp, headCentres);
    kind = _accidentalFromComps(index, local, head, sp);
    if (kind != '+' && kind != 'x' && kind != '++') {
      kind = '';
    } else if (kind != '++') {
      var right = local.first;
      for (final c in local) {
        if (c.x1 > right.x1) right = c;
      }
      final st = _verticalStrokes(img, right.x0 - 1.0, right.x1 + 1.0,
          right.y0 - 1.0, right.y1 + 1.0, sp);
      if (st.length < 2) kind = '';
    }
  }
  return kind;
}

/// Pieces of ink left of [head], after cutting away long vertical
/// strokes (bar lines, stems), other noteheads and everything right of
/// the head's left edge — so a sign touching them comes out on its own.
List<_Comp> _localSignComps(_Bin nos, List<List<double>> stems, _Head head,
    double sp, double wx0, double wy0, double wy1, List<List<double>> headCentres) {
  final xa = math.max(0, wx0.toInt()), xb = math.min(nos.w - 1, (head.x0 - 1).toInt());
  final ya = math.max(0, wy0.toInt()), yb = math.min(nos.h - 1, wy1.toInt());
  if (xb - xa < 3 || yb - ya < 3) return const [];
  final rw = xb - xa + 1, rh = yb - ya + 1;
  final region = _Bin.empty(rw, rh);
  for (int y = 0; y < rh; y++) {
    for (int x = 0; x < rw; x++) {
      if (nos.at(xa + x, ya + y)) region.d[y * rw + x] = 1;
    }
  }
  void clear(int x0, int y0, int x1, int y1) {
    for (int y = math.max(0, y0); y <= math.min(rh - 1, y1); y++) {
      for (int x = math.max(0, x0); x <= math.min(rw - 1, x1); x++) {
        region.d[y * rw + x] = 0;
      }
    }
  }

  // Long vertical runs, measured over a taller strip.
  final ta = math.max(0, (ya - 3 * sp).toInt()), tb = math.min(nos.h - 1, (yb + 3 * sp).toInt());
  for (int x = xa; x <= xb; x++) {
    for (final r in _columnRunsAt(nos, x, ta, tb)) {
      if (r[1] > 3.4 * sp) clear(x - xa, r[0] - ya, x - xa, r[0] + r[1] - 1 - ya);
    }
  }
  // Stems of notes (even short ones).
  for (final st in stems) {
    final sx = st[0].toInt();
    if (xa - 2 <= sx && sx <= xb + 2 && st[2] >= ya && st[1] <= yb) {
      clear(sx - 2 - xa, st[1].toInt() - ya, sx + 2 - xa, st[2].toInt() - ya);
    }
  }
  // Other noteheads (e.g. the far head of a chord with a second).
  for (final p in headCentres) {
    if (xa - sp <= p[0] && p[0] <= xb + sp && ya - sp <= p[1] && p[1] <= yb + sp) {
      clear((p[0] - 0.75 * sp).toInt() - xa, (p[1] - 0.5 * sp).toInt() - ya,
          (p[0] + 0.75 * sp).toInt() - xa, (p[1] + 0.5 * sp).toInt() - ya);
    }
  }
  final out = <_Comp>[];
  for (final c in _components(region, eight: true)) {
    // Small specks (e.g. what is left of a ledger line) are not signs.
    if (c.area < 0.5 * sp * sp) continue;
    // A sign is taller than wide and not solid (a piece of a beam is).
    if (c.h < 1.2 * c.w || c.h < 0.9 * sp || c.area > 0.75 * c.w * c.h) continue;
    // It must not run out of the area at the top, bottom or left.
    if (c.y0 == 0 || c.y1 >= rh - 1 || (c.x0 == 0 && xa > wx0.toInt())) continue;
    out.add(_Comp(xa + c.x0, ya + c.y0, xa + c.x1, ya + c.y1)..area = c.area);
  }
  return out;
}

/// The accidental made by [comps] (pieces of ink left of [head]).
String _accidentalFromComps(_CompIndex index, List<_Comp> signComps, _Head head, double sp) {
  final cy = head.cy;
  if (signComps.isEmpty) return '';
  final comps = [...signComps];
  // Pieces of one sign (cut by staff-line removal) overlap in x.
  comps.sort((a, b) => (b.x0 + b.w).compareTo(a.x0 + a.w));
  final right = comps.first;
  final cl = [right];
  int cx0 = right.x0, cx1 = right.x1;
  for (final c in comps.skip(1)) {
    if (c.x0 <= cx1 + 1 && c.x1 >= cx0 - 0.3 * sp) {
      cl.add(c);
      cx0 = math.min(cx0, c.x0);
      cx1 = math.max(cx1, c.x1);
    }
  }
  final top = cl.map((c) => c.y0).reduce(math.min);
  final bot = cl.map((c) => c.y1).reduce(math.max);
  final w = cx1 - cx0 + 1, h = bot - top + 1;
  if (head.x0 - cx1 > 1.0 * sp) return ''; // too far from the head
  if (!(top - 0.2 * sp <= cy && cy <= bot + 0.2 * sp)) return '';
  if (w < 0.25 * sp || h < 0.6 * sp || h > 3.6 * sp || w > 2.0 * sp) return '';
  final above = (cy - top) / sp, below = (bot - cy) / sp;
  if (h <= 1.35 * sp && 0.5 * sp <= w && w <= 1.35 * sp && (above - below).abs() <= 0.5) {
    return '++';
  }
  if (h < 1.4 * sp) return '';
  // Flats reach high above the note and only a little below it.
  if (above > 1.4 * below + 0.2 && h <= 3.0 * sp) {
    return w > 1.15 * sp ? '--' : '-';
  }
  if (h >= 1.7 * sp) {
    var kind = w <= 0.62 * sp ? 'x' : '+';
    // Sharp or natural: a natural's left stroke goes up higher and its
    // right one down lower; a sharp's strokes are about level.
    final img = index.nos;
    if (img != null) {
      final strokes = _verticalStrokes(img, cx0 - 1.0, cx1 + 1.0, top - 2.0, bot + 2.0, sp);
      if (strokes.length >= 2) {
        final l = strokes.first, r = strokes.last;
        if (r[0] - l[0] >= 0.2 * sp) {
          kind = (l[1] < r[1] - 0.45 * sp && r[2] > l[2] + 0.45 * sp) ? 'x' : '+';
        }
      }
    }
    return kind;
  }
  return '';
}

// =====================================================================
// Octave signs (8va, 15ma, 8vb, 15mb)
// =====================================================================

/// An octave sign over (or under) a stretch of a staff: the notes from
/// [x0] to [x1] sound [octaves] octaves higher (+) or lower (-).
class _OctaveLine {
  final double x0, x1;
  final int octaves;

  /// Box of the "8" / "15" (x0, y0, x1, y1), when there is one.
  final List<double>? glyph;
  _OctaveLine(this.x0, this.x1, this.octaves, this.glyph);
}

/// The octave shift at [x] (0 when no sign covers it).
int _octaveShiftAt(List<_OctaveLine> lines, double x, double sp) {
  for (final l in lines) {
    if (l.x0 - 0.3 * sp <= x && x <= l.x1 + 0.5 * sp) return l.octaves;
  }
  return 0;
}

/// Finds the octave signs of one staff: a dashed line (at least three
/// short thin dashes in a row at one height) above the staff ([above],
/// for the treble: 8va / 15ma) or below it (bass: 8vb / 15mb), usually
/// starting with an "8" or "15". Ledger lines are not dashes: a ledger
/// line always has a notehead right over it on the far side from the
/// staff. A line with no number at the start of a system goes on from
/// the previous system ([carried]).
List<_OctaveLine> _findOctaveLines(_CompIndex index, _Staff st, bool above,
    double xFrom, double xTo, double sp, List<_Head> heads, int? carried) {
  final xm = (xFrom + xTo) / 2;
  final top = _lineY(st, 0, xm), bottom = _lineY(st, 4, xm);
  final yA = above ? top - 8 * sp : bottom + 0.6 * sp;
  final yB = above ? top - 0.6 * sp : bottom + 8 * sp;

  // Dashes.
  final dashes = <_Comp>[];
  for (final c in index.comps) {
    if (c.x1 < xFrom || c.x0 > xTo || c.y1 < yA || c.y0 > yB) continue;
    if (c.h > 0.45 * sp || c.w < 0.25 * sp || c.w > 1.2 * sp) continue;
    final cx = (c.x0 + c.x1) / 2, cy = (c.y0 + c.y1) / 2;
    // A ledger line: a head right over it, farther from the staff.
    final ledger = heads.any((h) =>
    (h.cx - cx).abs() <= 0.8 * sp &&
        (above ? h.cy < cy + 0.2 * sp : h.cy > cy - 0.2 * sp) &&
        (h.cy - cy).abs() <= 3.0 * sp);
    if (!ledger) dashes.add(c);
  }
  dashes.sort((a, b) => a.x0.compareTo(b.x0));

  // Chains of dashes at one height.
  final used = List<bool>.filled(dashes.length, false);
  final lines = <_OctaveLine>[];
  for (int i = 0; i < dashes.length; i++) {
    if (used[i]) continue;
    final chain = [dashes[i]];
    used[i] = true;
    for (int j = i + 1; j < dashes.length; j++) {
      if (used[j]) continue;
      final last = chain.last, d = dashes[j];
      final gap = d.x0 - last.x1;
      if (gap > 1.6 * sp) break;
      if (gap < 0.1 * sp) continue;
      if (((d.y0 + d.y1) / 2 - (last.y0 + last.y1) / 2).abs() > 0.3 * sp) continue;
      chain.add(d);
      used[j] = true;
    }
    if (chain.length < 3) continue;
    final lineY = chain.map((c) => (c.y0 + c.y1) / 2).reduce((a, b) => a + b) / chain.length;
    double start = chain.first.x0.toDouble();
    double end = chain.last.x1.toDouble();
    // The closing hook: a short vertical stroke at the end.
    for (final c in index.comps) {
      if (c.x0 >= end - 0.3 * sp && c.x0 <= end + 0.8 * sp &&
          c.w <= 0.4 * sp && c.h >= 0.4 * sp && c.h <= 2 * sp &&
          (above ? (c.y0 - lineY).abs() <= 0.4 * sp : (c.y1 - lineY).abs() <= 0.4 * sp)) {
        end = math.max(end, c.x1.toDouble());
      }
    }
    // The number ("8", "15", "8va"…) just left of the first dash: the
    // tallest marks there; "15" has a thin "1" before the "5".
    final marks = [
      for (final c in index.comps)
      // (the first dash is often joined to the number)
        if (c.x1 <= start + 1.0 * sp &&
            c.x1 >= start - 4.0 * sp &&
            c.h >= 0.8 * sp &&
            c.h <= 2.6 * sp &&
            c.w <= 2.5 * sp &&
            c.y1 >= lineY - 2.2 * sp &&
            c.y0 <= lineY + 1.2 * sp &&
            // (not a note: no stemmed notehead inside it)
            !heads.any((h) =>
            h.stem != null &&
                c.x0 <= h.cx && h.cx <= c.x1 && c.y0 <= h.cy && h.cy <= c.y1))
          c
    ]..sort((a, b) => a.x0.compareTo(b.x0));
    int? octaves;
    List<double>? glyph;
    if (marks.isNotEmpty) {
      // The numeral: the tallest mark (letters "va" / "vb" are smaller).
      var numeral = marks.first;
      for (final c in marks) {
        if (c.h > numeral.h) numeral = c;
      }
      // A numeral is upright: taller than wide, at least a space tall.
      // …with its middle at the height of the dashes.
      final numeralY = (numeral.y0 + numeral.y1) / 2;
      if (numeral.h < 1.0 * sp ||
          numeral.w > 1.3 * numeral.h ||
          numeral.w < 0.3 * numeral.h ||
          (numeralY - lineY).abs() > 0.9 * sp) {
        if (carried == null || start - xFrom > 8 * sp) continue;
        lines.add(_OctaveLine(xFrom, end, above ? carried.abs() : -carried.abs(), null));
        continue;
      }
      final i0 = marks.indexOf(numeral);
      // A thin "1" right before it makes "15".
      bool fifteen = false;
      double gx0 = numeral.x0.toDouble();
      for (int k = 0; k < i0; k++) {
        final c = marks[k];
        if (c.w <= 0.4 * c.h && numeral.x0 - c.x1 <= 0.6 * sp && c.h >= 0.7 * numeral.h) {
          fifteen = true;
          gx0 = math.min(gx0, c.x0.toDouble());
        }
      }
      octaves = fifteen ? 2 : 1;
      double gy0 = numeral.y0.toDouble(), gy1 = numeral.y1.toDouble();
      double gx1 = numeral.x1.toDouble();
      for (final c in marks) {
        gy0 = math.min(gy0, c.y0.toDouble());
        gy1 = math.max(gy1, c.y1.toDouble());
        gx1 = math.max(gx1, c.x1.toDouble());
      }
      glyph = [gx0, gy0, gx1, gy1];
      start = math.min(start, gx0);
    } else if (carried != null && start - xFrom <= 8 * sp) {
      // No number: the line goes on from the previous system.
      octaves = carried.abs();
      start = xFrom;
    } else {
      continue; // a dashed line with no number: not an octave sign
    }
    lines.add(_OctaveLine(start, end, above ? octaves : -octaves, glyph));
  }
  return lines;
}

// =====================================================================
// Pitch
// =====================================================================

/// Staff position in transcription units: treble staff bottom line = 1
/// ... top line = 5; bass staff top line = -1 ... bottom line = -5;
/// ledger lines continue the count (middle C = 0 from either staff).
///
/// [octaves]: an 8va / 15ma sign over the note (+1 / +2) or 8vb / 15mb
/// under it (-1 / -2): the note sounds that many octaves (7 steps each)
/// higher or lower than written.
String _positionOf(_Staff st, bool treble, double x, double y, [int octaves = 0]) {
  final top = _lineY(st, 0, x), bottom = _lineY(st, 4, x);
  final sp = (bottom - top) / 4;
  int hs;
  int base;
  if (treble) {
    hs = (2 * (bottom - y) / sp).round(); // half-spaces above the bottom line
    base = 1;
  } else {
    hs = (2 * (top - y) / sp).round(); // half-spaces above the top line
    base = -1;
  }
  hs += 7 * octaves;
  if (hs.isEven) return '${base + hs ~/ 2}';
  final lower = base + ((hs - 1) / 2).floor();
  return '$lower/${lower + 1}';
}