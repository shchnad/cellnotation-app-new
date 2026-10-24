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

  OmrEvent(this.x, this.duration, this.notes);
}

class OmrMeasure {
  final double x0;
  final double x1;

  /// Staff spacing on the (rescaled) page this measure came from.
  final double spacing;

  /// 'hr' (upper staff) and 'hl' (lower staff) events, sorted by x.
  final Map<String, List<OmrEvent>> hands;

  OmrMeasure(this.x0, this.x1, this.spacing, this.hands);

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

  var heads = <_Head>[..._findFilledHeads(bw, sp), ..._findHollowHeads(bw, sp)];
  final index = _CompIndex(_components(nos, eight: true));

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

  // Pair staves into piano systems: the two staves of a system are
  // closer together than one system is to the next.
  final pairs = <List<_Staff>>[];
  for (int i = 0; i + 1 < staves.length;) {
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
    final headerEnd = {
      'hr': _staffHeaderEnd(index, tr, x0.toDouble(), sp, stems, heads, nos),
      'hl': _staffHeaderEnd(index, bs, x0.toDouble(), sp, stems, heads, nos),
    };
    for (int mi = 0; mi + 1 < bars.length; mi++) {
      final mx0 = bars[mi];
      final mx1 = bars[mi + 1];
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

        final start = math.max(mx0, headerEnd[hand]!);
        final hs = heads
            .where((h) =>
        start + 0.3 * sp < h.cx &&
            h.cx < mx1 - 0.3 * sp &&
            inStaff(h) &&
            !onBar(h))
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
            chords.add(_Chord(null, [h], false));
          }
        }
        // Attach a chord's displaced head (the other note of a second
        // sits on the far side of the stem, touching it).
        for (final h in loose) {
          if (!(mx0 < h.cx && h.cx < mx1 && inStaff(h))) continue;
          for (final c in chords) {
            if (c.stem == null) continue;
            if ((h.cx - c.stem!.x).abs() > 1.0 * sp) continue;
            if (c.heads.any((o) => (h.cy - o.cy).abs() <= 1.1 * sp)) {
              c.heads.add(h);
              break;
            }
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
            final pos = _positionOf(st, treble, h.cx, h.cy);
            final acc = _classifyAccidental(index, h, sp, mx0 + 2, headCentres);
            notes.add(OmrNote(pos, acc, h.cy));
          }
          double ex = hs2.first.x0;
          for (final h in hs2) {
            ex = math.min(ex, h.x0);
          }
          events.add(OmrEvent(ex, dur, notes));
        }
        final staffHeads = heads.where(inStaff).toList();
        for (final r in _findRests(
            index, st, mx0, mx1, sp, staffHeads, stems, headerEnd[hand]!)) {
          events.add(OmrEvent(r[0].toDouble(), r[1], const []));
        }
        events.sort((a, b) => a.x.compareTo(b.x));
        hands[hand] = events;
      }
      measures.add(OmrMeasure(mx0, mx1, sp, hands));
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
String omrMeasuresToTranscription(
    List<OmrMeasure> allMeasures, {
      String scaleName = 'do major',
      bool scaleHasAccidentals = false,
      List<int>? timeSignature,
    }) {
  final measures = allMeasures.where((m) => !m.isEmpty).toList();

  final totals = <int>[];
  for (final m in measures) {
    for (final hand in const ['hr', 'hl']) {
      final ev = m.hands[hand] ?? const <OmrEvent>[];
      // A whole-measure rest says nothing about the meter.
      if (ev.isNotEmpty && ev.every((e) => e.duration > 0)) {
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

  final has32 = measures.any((m) => const ['hr', 'hl'].any((h) =>
      (m.hands[h] ?? const <OmrEvent>[])
          .any((e) => e.duration > 0 && e.duration % 8 != 0)));
  int unit = 32; // quarter
  if (timeSignature != null) unit = math.max(2, 128 ~/ timeSignature[1]);
  if (unit > 16 && (has32 || meter % unit != 0)) unit = 16; // eighth
  final out = StringBuffer();
  out.writeln(scaleName);
  if (meter % unit == 0) {
    out.writeln('t${meter ~/ unit}/${128 ~/ unit}');
  } else {
    out.writeln('t3/4');
  }

  for (int i = 0; i < measures.length; i++) {
    final m = measures[i];
    out.writeln('m${i + 1}');
    for (final hand in const ['hr', 'hl']) {
      final ev = [
        for (final e in m.hands[hand] ?? const <OmrEvent>[])
          e.duration == OmrEvent.wholeMeasure
              ? OmrEvent(e.x, meter, e.notes)
              : e
      ];
      if (!ev.any((e) => !e.isRest)) continue;
      final total = ev.fold<int>(0, (s, e) => s + e.duration);
      final toks = <String>[hand];
      int onset = 0;
      final carried = <String, String>{};
      final xf = ev.first.x;
      final xe = m.x1 - 0.8 * m.spacing;
      int prev = -1;
      for (final e in ev) {
        int t;
        if (total == meter) {
          t = onset;
        } else {
          // Durations don't add up: place by x position, with the first
          // note on beat 1 and the bar line as the end of the measure.
          const grid = 8; // a sixteenth
          final frac = (e.x - xf) / math.max(1.0, xe - xf);
          t = (frac * meter / grid).round() * grid;
          t = math.max(0, math.min(t, meter - grid));
          if (t <= prev) t = prev + grid < meter ? prev + grid : prev;
        }
        prev = t;
        if (e.isRest) {
          // A rest only takes up time; the beats of the notes say it.
          onset += e.duration;
          continue;
        }
        final b = 1 + t / unit;
        final q = (b * 4).round() / 4;
        toks.add(q == q.roundToDouble() ? 'b${q.round()}' : 'b$q');

        final notes = <String>[];
        final sortedNotes = [...e.notes]..sort((a, b) => b.y.compareTo(a.y));
        for (final n in sortedNotes) {
          var acc = n.accidental;
          // An accidental lasts until the end of the measure.
          if (acc.isEmpty && carried.containsKey(n.position)) {
            acc = carried[n.position]!;
          } else if (acc == 'x') {
            carried.remove(n.position);
            if (!scaleHasAccidentals) acc = '';
          } else if (acc.isNotEmpty) {
            carried[n.position] = acc;
          }
          notes.add('${n.position}$acc');
        }
        final dc = _durationCode(e.duration);
        if (notes.length == 1) {
          toks.add('${notes.first}$dc');
        } else {
          toks.add('(${notes.join(', ')})$dc');
        }
        onset += e.duration;
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
  _CompIndex(this.comps);

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
double _staffHeaderEnd(_CompIndex index, _Staff st, double xStart, double sp,
    List<List<double>> stems, List<_Head> heads, _Bin nos) {
  final top = _lineY(st, 0, xStart), bot = _lineY(st, 4, xStart);
  final near = index.comps
      .where((c) =>
  c.y0 <= bot &&
      c.y1 >= top &&
      c.h <= 9 * sp &&
      xStart - 0.5 * sp <= c.x0 &&
      c.x0 <= xStart + 3.0 * sp)
      .toList();
  final clef = _clustersByX(near)
      .where((k) => k[3] - k[2] + 1 >= 2.5 * sp && k[1] - k[0] + 1 >= 1.0 * sp)
      .toList();
  if (clef.isEmpty) return xStart;
  double end = clef.map((k) => k[1]).reduce(math.max).toDouble();
  final others = index.comps
      .where((c) =>
  c.y0 >= top - 1.0 * sp &&
      c.y1 <= bot + 1.0 * sp &&
      c.x0 > end)
      .toList();
  for (final g in _clustersByX(others)) {
    final gx0 = g[0], gx1 = g[1], gy0 = g[2], gy1 = g[3];
    if (gx0 - end > 2.0 * sp) break;
    if (gx1 - gx0 + 1 > 1.8 * sp || gy1 - gy0 + 1 < 0.5 * sp) break;
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
  return end + 0.2 * sp;
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

List<_Head> _findFilledHeads(_Bin bw, double sp) {
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
          int firstFull = -1, lastFull = -1, fullRows = 0;
          for (int y = ya; y < yb; y++) {
            int ink = 0;
            for (int x = math.max(0, xa); x < math.min(bw.w, xb); x++) {
              if (bw.at(x, y)) ink++;
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
List<_Head> _findHollowHeads(_Bin bw, double sp) {
  final holes = <List<int>>[];
  for (final c in _components(bw, eight: false, value: 0)) {
    if (c.touchesBorder) continue;
    if (0.25 * sp <= c.w &&
        c.w <= 1.2 * sp &&
        0.15 * sp <= c.h &&
        c.h <= 0.8 * sp &&
        c.area >= 0.06 * sp * sp) {
      holes.add([c.x0, c.y0, c.x1, c.y1]);
    }
  }
  // Merge holes split by a staff line.
  holes.sort((a, b) => a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]));
  final merged = <List<int>>[];
  for (final r in holes) {
    bool done = false;
    for (final m in merged) {
      if (((r[0] + r[2]) / 2 - (m[0] + m[2]) / 2).abs() < 0.4 * sp &&
          (r[1] - m[3]) <= 0.4 * sp &&
          (m[1] - r[3]) <= 0.4 * sp) {
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
    if (!(0.35 * sp <= hh && hh <= 0.9 * sp)) continue;
    final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    final iy = cy.round(), ix = cx.round();
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

    final left = walk(-1), right = walk(1);
    final outerW = right - left;
    if (!(1.0 * sp <= outerW && outerW <= 2.0 * sp)) continue;
    // Ring sides must be thicker than a stem / letter stroke.
    if ((x0 - left) < 0.12 * sp || (right - x1) < 0.12 * sp) continue;
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
    final y = edge.cy + step * sp; // a third (a second would sit on the
    // other side of the stem)
    final ya = math.min(edge.cy, y).round(), yb = math.max(edge.cy, y).round();
    bool reached = true;
    for (int yy = ya; yy <= yb && reached; yy++) {
      bool any = false;
      for (int xx = stem.x - 1; xx <= stem.x + 1; xx++) {
        if (xx >= 0 && xx < nos.w && yy >= 0 && yy < nos.h && nos.at(xx, yy)) any = true;
      }
      reached = any;
    }
    if (!reached) break;
    if (_inkFraction(nos, edge.cx, y, 0.9 * sp, 0.5 * sp) >= 0.7 &&
        _inkFraction(nos, edge.cx, y + step * 0.75 * sp, 0.9 * sp, 0.2 * sp) < 0.5) {
      hs.add(_Head(edge.x0, edge.x1, edge.cx, y, true)..stem = edge.stem);
    } else {
      break;
    }
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
  final comps = index
      .inside(math.max(xLimit, head.x0 - 2.4 * sp), cy - 2.2 * sp,
      head.x0 - 1, cy + 1.8 * sp)
      .where((c) => !headCentres.any((p) =>
  c.x0 <= p[0] && p[0] <= c.x0 + c.w && c.y0 <= p[1] && p[1] <= c.y0 + c.h))
      .toList();
  if (comps.isEmpty) return '';
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
    return w <= 0.62 * sp ? 'x' : '+';
  }
  return '';
}

// =====================================================================
// Pitch
// =====================================================================

/// Staff position in transcription units: treble staff bottom line = 1
/// ... top line = 5; bass staff top line = -1 ... bottom line = -5;
/// ledger lines continue the count (middle C = 0 from either staff).
String _positionOf(_Staff st, bool treble, double x, double y) {
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
  if (hs.isEven) return '${base + hs ~/ 2}';
  final lower = base + ((hs - 1) / 2).floor();
  return '$lower/${lower + 1}';
}