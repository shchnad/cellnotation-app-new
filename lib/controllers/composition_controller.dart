import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:music_composer/enums/articulation.dart';
import 'package:music_composer/utils/default_values.dart';

import '../enums/accidental.dart';
import '../enums/dynamic_change.dart';
import '../enums/finger.dart';
import '../enums/glissando_direction.dart';
import '../enums/grace_note_type.dart';
import '../enums/musical_dynamic.dart';
import '../enums/ornament.dart';
import '../enums/playing_technique.dart';
import '../enums/tempo.dart';
import '../enums/hand.dart';
import '../enums/instrument.dart';
import '../enums/note_duration.dart';

import '../models/composition.dart';
import '../models/dynamic_event.dart';
import '../models/note.dart';
import '../models/measure.dart'; // also defines InkStroke
import '../models/note_import.dart';
import '../models/tempo_event.dart';
import '../models/time_signature.dart';
import '../models/timeline.dart';
import '../models/dynamic_change_event.dart';
import '../services/note_sound_service.dart';


import '../utils/scale_resolver.dart';


class CompositionController extends ChangeNotifier {

  Composition composition;

  CompositionController({
    required this.composition,
  }) {
    // Prepare every pitch this composition uses in the background, so
    // playback never has to wait for a sound to be built — see
    // NoteSoundService.warmUp.
    repairTempoBeats();
    warmUpSounds();
    _lastState = _snapshot();
  }

  // ---------------- UNDO / REDO ----------------
  //
  // Every change to the composition (notes, measures, scales, tempo,
  // repeats, pen marks…) can be undone. Instead of each editing method
  // remembering what it changed, the whole composition is remembered:
  // after a change has settled (no further change for a moment — so a
  // drag, or a burst of changes from one action, is ONE step), its
  // previous state is pushed on the undo list.

  /// How many steps can be undone.
  static const int maxUndoSteps = 50;

  final List<String> _undoStates = [];
  final List<String> _redoStates = [];

  /// The composition as it was after the last recorded change.
  String? _lastState;
  Timer? _historyTimer;
  bool _restoringState = false;

  String _snapshot() => jsonEncode(composition.toJson());

  /// (A change still settling counts too.)
  bool get canUndo => _undoStates.isNotEmpty || _historyTimer != null;

  bool get canRedo => _redoStates.isNotEmpty;

  @override
  void notifyListeners() {
    if (!_restoringState) {
      // Record a little later, once the change has settled.
      _historyTimer?.cancel();
      _historyTimer = Timer(const Duration(milliseconds: 400), _flushHistory);
    }
    super.notifyListeners();
  }

  /// Records the current state if it differs from the last recorded one.
  void _flushHistory() {
    _historyTimer?.cancel();
    _historyTimer = null;
    if (_restoringState) return;
    final now = _snapshot();
    final last = _lastState;
    if (last == null) {
      _lastState = now;
      return;
    }
    if (now == last) return;
    _undoStates.add(last);
    if (_undoStates.length > maxUndoSteps) _undoStates.removeAt(0);
    _redoStates.clear();
    _lastState = now;
  }

  /// Goes back to the composition as it was before the last change.
  /// Returns false when there is nothing to undo.
  bool undo() {
    _flushHistory();
    if (_undoStates.isEmpty) return false;
    _redoStates.add(_lastState ?? _snapshot());
    _restoreState(_undoStates.removeLast());
    return true;
  }

  /// Does again what [undo] took back. Returns false when there is
  /// nothing to redo.
  bool redo() {
    _flushHistory();
    if (_redoStates.isEmpty) return false;
    _undoStates.add(_lastState ?? _snapshot());
    _restoreState(_redoStates.removeLast());
    return true;
  }

  void _restoreState(String state) {
    _restoringState = true;
    try {
      composition = Composition.fromJson(
        jsonDecode(state) as Map<String, dynamic>,
        id: composition.id,
      );
      // Picks that point at notes that may no longer exist.
      pasteMode = false;
      _graceNoteAnchor = null;
      _graceNoteTypeBeingAdded = null;
      _pendingGlissandoNote = null;
      timeline.rebuild();
      _lastState = state;
      warmUpSounds();
      super.notifyListeners();
    } finally {
      _restoringState = false;
    }
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    super.dispose();
  }

  /// Fixes measures whose remembered tempo beat makes them play at a
  /// different speed from other measures with the SAME time signature
  /// (left by uniting beats and splitting them again with an older
  /// version of the app). Every measure gets the tempo beat of the
  /// FIRST measure with its time signature, so identical measures
  /// always scroll at the same speed. Returns how many were fixed.
  int repairTempoBeats() {
    final reference = <String, NoteDuration?>{};
    int fixed = 0;
    for (int i = 0; i < measures.length; i++) {
      final m = measures[i];
      final key =
          '${m.timeSignature.beats}/${m.timeSignature.beatDuration.name}';
      if (!reference.containsKey(key)) {
        reference[key] = m.tempoBeatDuration;
        continue;
      }
      final wanted = reference[key];
      if (m.tempoBeatDuration != wanted) {
        measures[i] = m.copyWith(tempoBeatDuration: wanted);
        fixed++;
      }
    }
    return fixed;
  }

  /// Hands NoteSoundService every distinct pitch currently in the
  /// composition (ordinary notes, glissando run notes and ornament
  /// neighbors) to synthesize and load ahead of time. Cheap to call
  /// again — pitches already prepared are skipped.
  void warmUpSounds() {
    try {
      // Grouped by the sound of each hand's instrument, so every
      // (instrument, pitch) pair that playback needs is ready.
      final byTimbre = <SoundTimbre, Set<double>>{};
      for (final note in notes) {
        final frequencies =
        byTimbre.putIfAbsent(timbreForHand(note.hand), () => <double>{});
        if (note.glissandoSourceId != null) {
          frequencies.add(getWhiteKeyFrequencyHz(note.row));
          continue;
        }
        final base = getNoteFrequencyHz(note);
        frequencies.add(base);
        final ornament = note.ornament;
        if (ornament != null) {
          for (final entry in ornament.shiftMap) {
            final shift = ((entry as Map)['shift'] as num).toInt();
            frequencies.add(base * math.pow(2, shift / 12));
          }
        }
      }
      () async {
        for (final entry in byTimbre.entries) {
          await NoteSoundService.instance
              .warmUp(entry.value, timbre: entry.key);
        }
      }();
    } catch (_) {
      // Warm-up is only an optimization — never let it break opening
      // a composition.
    }
  }



  // =====================================================
  // EDITOR STATE
  // =====================================================

  Hand currentHand = Hand.right;

  /// Sets [currentHand] directly to [hand] — used by [handDialog]
  /// (Left/Right/Additional) since three choices can't be cycled
  /// through with a single toggle the way [toggleHand] cycles
  /// between just Left and Right. The Hand toolbar button always
  /// opens [handDialog] now (there's no separate "Additional Hand
  /// Mode" gate anymore), so this is the button's only path for
  /// changing [currentHand].
  void setCurrentHand(Hand hand) {
    currentHand = hand;
    notifyListeners();
  }

  // Duration of newly created notes
  NoteDuration currentDuration = DefaultValues.defaultDuration;

  // Grid snapping resolution
  NoteDuration gridResolution = NoteDuration.sixtyFourth;


  // =====================================================
  // CLIPBOARD
  // =====================================================

  Note? copiedNote;

  bool pasteMode = false;

  bool get canPaste =>
      copiedNote != null;


  // =====================================================
  // DATA ACCESS
  // =====================================================

  Timeline get timeline => composition.timeline;

  List<Measure> get measures => timeline.measures;

  List<Note> get notes => composition.notes;

  int get maxTicks => composition.timeline.totalTicks;

  String durationLabel(Note note) {
    final duration = NoteDuration.values.firstWhere(
          (d) => d.ticks == note.durationTicks,
      orElse: () => NoteDuration.quarter,
    );
    return duration.label;
  }

  // =====================================================
  // TIMELINE
  // =====================================================

  int _noteIdCounter = 0;

  int generateNoteId() {
    _noteIdCounter++;
    return DateTime.now().microsecondsSinceEpoch + _noteIdCounter;
  }

  void fixDuplicateNoteIds() {
    final used = <int>{};
    for (int i = 0; i < notes.length; i++) {
      var note = notes[i];
      while (used.contains(note.id)) {
        note = note.copyWith(
          id: generateNoteId(),
        );
      }
      notes[i] = note;
      used.add(note.id);
    }
  }


  /// The number of the measure [note] starts in (a temporary reprise
  /// copy shows the number of the measure it copies — see
  /// [measureNumbers]).
  int getMeasureNumber(Note note) {
    final index = measures.indexWhere( (m) =>
    note.startTick >= m.startTick && note.startTick < m.endTick,
    );
    return index < 0 ? 0 : displayMeasureNumber(index);
  }


  Measure getMeasureAtTick(int tick){
    return measures.firstWhere(
          (measure) =>
      tick >= measure.startTick &&
          tick < measure.endTick,
      orElse: () => measures.last,
    );
  }

  void addMeasure(
      TimeSignature signature,
      String scaleName,
      ) {
    timeline.addMeasure(signature, scaleName,);
    notifyListeners();
  }

  /// Inserts a brand-new (empty) measure at [index] — pushing that
  /// measure and everything after it later in time — unlike
  /// [addMeasure], which only appends one at the very end.
  ///
  /// Timeline.rebuild() (called by Timeline.insertMeasure) only
  /// recalculates each Measure's own startTick from ordering. It does
  /// NOT know about notes, tempo/dynamic/dynamic-change events, the
  /// timeline's own beatEvents, or a pushed-back measure's *internal*
  /// beatEvents (which store absolute ticks too — see how copyBeat
  /// uses them) — all of those have their own independent tick numbers
  /// that need shifting forward by the new measure's duration too, or
  /// they'd silently end up misaligned with the measures around them.
  void insertMeasureAt(
      int index,
      TimeSignature signature,
      String scaleName,
      ) {
    if (index < 0 || index > measures.length) {
      return;
    }

    final insertTick = index == 0 ? 0 : measures[index - 1].endTick;
    _shiftTicksFrom(insertTick, signature.durationTicks);

    timeline.insertMeasure(index, signature, scaleName);

    // The new measure landed at [index] — anything that was pointing
    // at a measure at or after that position should keep pointing at
    // the same logical measure, now one slot later.
    if (selectedMeasureIndex >= index) {
      selectedMeasureIndex++;
    }

    notifyListeners();
  }

  /// Shifts every tick-based thing at or after [fromTick] by
  /// [shiftAmount] — positive when time was inserted (see
  /// [insertMeasureAt]), negative when time was removed (see
  /// [removeBeatFromMeasure] and [deleteMeasure]): notes, tempo events
  /// (except the tick-0 anchor, which never moves), dynamic events,
  /// dynamic-change events, the timeline's own beatEvents, and every
  /// measure's own internal beatEvents (which store absolute ticks
  /// too — see how copyBeat uses them). Doesn't touch
  /// Measure.startTick itself — callers follow up with
  /// timeline.rebuild() (directly or via a Timeline method that calls
  /// it) for that. Callers are also responsible for removing/adding
  /// whatever actually occupied the affected range beforehand — this
  /// only repositions what's left.
  void _shiftTicksFrom(int fromTick, int shiftAmount) {
    if (shiftAmount == 0) return;

    for (final t in _temporaryEvents) {
      if (t.tick >= fromTick) t.tick += shiftAmount;
    }

    for (final measure in measures) {
      for (int i = 0; i < measure.beatEvents.length; i++) {
        final event = measure.beatEvents[i];
        if (event.tick >= fromTick) {
          measure.beatEvents[i] =
              event.copyWith(tick: event.tick + shiftAmount);
        }
      }
    }

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (note.startTick >= fromTick) {
        notes[i] = note.copyWith(startTick: note.startTick + shiftAmount);
      }
    }

    for (int i = 0; i < timeline.tempoEvents.length; i++) {
      final event = timeline.tempoEvents[i];
      if (event.tick != 0 && event.tick >= fromTick) {
        timeline.tempoEvents[i] =
            event.copyWith(tick: event.tick + shiftAmount);
      }
    }
    timeline.tempoEvents.sort((a, b) => a.tick.compareTo(b.tick));

    for (final event in timeline.dynamicEvents) {
      if (event.tick >= fromTick) {
        event.tick += shiftAmount;
      }
    }
    timeline.dynamicEvents.sort((a, b) => a.tick.compareTo(b.tick));

    for (final event in timeline.dynamicChangeEvents) {
      if (event.tick >= fromTick) {
        event.tick += shiftAmount;
      }
    }
    timeline.dynamicChangeEvents.sort((a, b) => a.tick.compareTo(b.tick));

    for (int i = 0; i < timeline.beatEvents.length; i++) {
      final event = timeline.beatEvents[i];
      if (event.tick >= fromTick) {
        timeline.beatEvents[i] =
            event.copyWith(tick: event.tick + shiftAmount);
      }
    }
    timeline.beatEvents.sort((a, b) => a.tick.compareTo(b.tick));
  }

  int selectedMeasureIndex = 0;

  Measure get currentMeasure {
    if (measures.isEmpty) {
      throw Exception("No measures initialized.");
    }
    // selectedMeasureIndex can go stale after measures are removed or a
    // whole new composition is loaded — clamp defensively so this never
    // throws a RangeError (e.g. crashing the pitch column mid-build).
    final safeIndex = selectedMeasureIndex.clamp(0, measures.length - 1);
    return measures[safeIndex];
  }

  /// Selects whichever measure contains [tick] as the "current" measure
  /// — this is what the persistent pitch column reads its scale from, so
  /// tapping anywhere in a measure switches the column to that measure's
  /// scale.
  void selectMeasureAtTick(int tick) {
    if (measures.isEmpty) {
      return;
    }
    final measure = getMeasureAtTick(tick);
    final index = measures.indexOf(measure);
    if (index != -1 && index != selectedMeasureIndex) {
      selectedMeasureIndex = index;
      notifyListeners();
    }
  }


  void updateCurrentMeasureScale(String newScaleName) {
    if (measures.isEmpty) return;
    final oldMeasure = currentMeasure;
    measures[selectedMeasureIndex] =
        oldMeasure.copyWith(
          scaleName: newScaleName,
          // A deliberate pick becomes the new reset target, not just a
          // transient raise/lower step.
          originalScaleName: newScaleName,
        );
    notifyListeners();
  }


  void updateMeasureScale(
      int measureIndex,
      String newScaleName,
      ) {
    if(measureIndex < 0 || measureIndex >= measures.length) {
      return;
    }
    measures[measureIndex] = measures[measureIndex].copyWith(
      scaleName: newScaleName,
      originalScaleName: newScaleName,
    );
    notifyListeners();
  }


  /// Sets [newScaleName] on every measure from [fromIndex] to
  /// [toIndex] (either order).
  void updateMeasureScaleRange(
      int fromIndex,
      int toIndex,
      String newScaleName,
      ) {
    final start = fromIndex <= toIndex ? fromIndex : toIndex;
    final end = fromIndex <= toIndex ? toIndex : fromIndex;
    for (int i = start; i <= end; i++) {
      if (i < 0 || i >= measures.length) continue;
      measures[i] = measures[i].copyWith(
        scaleName: newScaleName,
        originalScaleName: newScaleName,
      );
    }
    notifyListeners();
  }


  int getBeatNumber(Note note) {
    final measure = getMeasureAtTick(note.startTick);
    final tickInsideMeasure =
        note.startTick - measure.startTick;
    return tickInsideMeasure ~/
        measure.timeSignature.ticksPerBeat +
        1;
  }

  bool _validMeasure(int index){
    return index >= 0 &&
        index < measures.length;
  }

  void addBeatToMeasure(int measureIndex) {
    if(!_validMeasure(measureIndex)){
      return;
    }
    final measure = measures[measureIndex];
    measure.addBeat();
    timeline.rebuild();
    notifyListeners();
  }

  /// Maps a "measureIndex_beatIndex" key to the number-of-beats
  /// multiplier currently applied there via a fermata (see
  /// [applyFermataToBeat]) — lets the grid know how much wider than
  /// an ordinary beat this column actually is (so its beat line and
  /// "fz" label are drawn in the right place — see grid_widget.dart)
  /// and lets [deleteFermata] revert it back to a normal-width beat
  /// exactly. Session-scoped only — not persisted with the
  /// composition itself.
  final Map<String, int> fermataMultipliers = {};

  String _fermataKey(int measureIndex, int beatIndex) =>
      '${measureIndex}_$beatIndex';

  /// The fermata multiplier currently applied to
  /// [measureIndex]/[beatIndex], or null if that beat has no fermata.
  int? getFermataMultiplier(int measureIndex, int beatIndex) =>
      fermataMultipliers[_fermataKey(measureIndex, beatIndex)];

  /// Stretches beat [beatIndex] of measure [measureIndex] (a fermata)
  /// so it lasts as long as [numberOfBeats] ordinary beats instead of
  /// just 1 — every note whose startTick falls within the ORIGINAL
  /// beat is repositioned and lengthened by that same factor, keeping
  /// its proportional position within the beat (a note that started
  /// halfway through the beat still starts halfway through the
  /// stretched beat) and its proportional duration relative to the
  /// beat's own new length. Everything at or after the beat's END —
  /// later beats in this measure, and every later measure — is
  /// pushed forward by the extra time added, via [_shiftTicksFrom],
  /// the same helper [insertMeasureAt]/[removeBeatFromMeasure] use
  /// for the same kind of "make room" shift. [numberOfBeats] <= 1 is
  /// a no-op (fermata must actually lengthen the beat).
  ///
  /// If this beat already has a fermata applied (see
  /// [fermataMultipliers]), that one is fully reverted first via
  /// [deleteFermata] before the new multiplier is applied — otherwise
  /// calling this again with a different number would compound on
  /// top of the previous stretch rather than replacing it.
  void applyFermataToBeat(
      int measureIndex,
      int beatIndex,
      int numberOfBeats,
      ) {
    if (measureIndex < 0 || measureIndex >= measures.length) return;
    if (numberOfBeats <= 1) return;

    if (getFermataMultiplier(measureIndex, beatIndex) != null) {
      deleteFermata(measureIndex, beatIndex);
    }

    final measure = measures[measureIndex];
    final ticksPerBeat = measure.timeSignature.ticksPerBeat;
    // getBeatTick (not the naive startTick + beatIndex*ticksPerBeat)
    // — correctly accounts for any EARLIER beat in this same measure
    // that's already fermata-stretched, so this beat's own start is
    // computed from where it actually sits now, not where it would
    // sit if every beat were a uniform width.
    final beatStart = getBeatTick(measureIndex, beatIndex);
    final beatEnd = beatStart + ticksPerBeat;
    final extraTicks = ticksPerBeat * (numberOfBeats - 1);

    // Make room for the extra time first — everything from the
    // beat's original END onward (later beats, later measures, tempo/
    // dynamic/dynamic-change events, etc.) shifts later. Notes INSIDE
    // this beat (startTick < beatEnd) are untouched by this call, so
    // they're still at their original ticks for the loop below.
    _shiftTicksFrom(beatEnd, extraTicks);

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (note.startTick >= beatStart && note.startTick < beatEnd) {
        final offsetFromBeatStart = note.startTick - beatStart;
        final newStartTick = beatStart + offsetFromBeatStart * numberOfBeats;
        final newDuration = note.durationTicks * numberOfBeats;
        notes[i] = note.copyWith(
          startTick: newStartTick,
          durationTicks: newDuration,
        );
      }
    }

    fermataMultipliers[_fermataKey(measureIndex, beatIndex)] = numberOfBeats;
    // Folds the extra time into the MEASURE's own duration too — see
    // Measure.fermataExtraTicks — and rebuilds the timeline so every
    // LATER measure's startTick correctly shifts forward as well.
    // Without this, only the notes/events themselves would have moved
    // (via _shiftTicksFrom above); the measure's own boundary and
    // every later measure's position would stay stale, cutting off or
    // squeezing the rest of this measure's beats and misaligning
    // everything after it.
    measure.fermataExtraTicks += extraTicks;
    timeline.rebuild();
    notifyListeners();
  }

  /// Reverses whatever fermata is currently applied to
  /// [measureIndex]/[beatIndex] (if any) — the exact inverse of
  /// [applyFermataToBeat]: every note within the STRETCHED beat is
  /// un-scaled and repositioned back to where it was before the
  /// fermata, the beat's own width reverts to a normal single beat,
  /// and everything after it shifts back by the extra ticks that are
  /// now being removed. A no-op if no fermata is currently applied to
  /// this beat.
  void deleteFermata(int measureIndex, int beatIndex) {
    final multiplier = getFermataMultiplier(measureIndex, beatIndex);
    if (multiplier == null || multiplier <= 1) return;
    if (measureIndex < 0 || measureIndex >= measures.length) return;

    final measure = measures[measureIndex];
    final ticksPerBeat = measure.timeSignature.ticksPerBeat;
    final beatStart = getBeatTick(measureIndex, beatIndex);
    final stretchedBeatEnd = beatStart + ticksPerBeat * multiplier;
    final extraTicks = ticksPerBeat * (multiplier - 1);

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (note.startTick >= beatStart && note.startTick < stretchedBeatEnd) {
        final offsetFromBeatStart = note.startTick - beatStart;
        final originalOffset = offsetFromBeatStart ~/ multiplier;
        final originalDuration =
        (note.durationTicks ~/ multiplier).clamp(1, 1 << 30);
        notes[i] = note.copyWith(
          startTick: beatStart + originalOffset,
          durationTicks: originalDuration,
        );
      }
    }

    // Everything after the STRETCHED beat's end shifts back by the
    // extra ticks the fermata had added.
    _shiftTicksFrom(stretchedBeatEnd, -extraTicks);

    fermataMultipliers.remove(_fermataKey(measureIndex, beatIndex));
    // Inverse of the same fold applyFermataToBeat does — shrinks the
    // measure's own duration back down and rebuilds the timeline so
    // every later measure's startTick shifts back correctly too.
    measure.fermataExtraTicks -= extraTicks;
    timeline.rebuild();
    notifyListeners();
  }


  int getBeatTick(
      int measureIndex,
      int beatIndex,
      ) {
    if(measureIndex < 0 ||
        measureIndex >= measures.length){
      return 0;
    }
    final measure = measures[measureIndex];
    final ticksPerBeat = measure.timeSignature.ticksPerBeat;
    // Walks beat-by-beat rather than assuming every beat in this
    // measure is the same width — a fermata-stretched EARLIER beat
    // (see getFermataMultiplier/applyFermataToBeat) is wider than an
    // ordinary one, so every beat after it sits further along than
    // the naive `beatIndex * ticksPerBeat` would put it.
    int tick = measure.startTick;
    for (int b = 0; b < beatIndex; b++) {
      final multiplier = getFermataMultiplier(measureIndex, b) ?? 1;
      tick += ticksPerBeat * multiplier;
    }
    return tick;
  }

  // =====================================================
  // SPLIT BEATS (triplets, quintuplets…)
  // =====================================================
  //
  // A beat can be split into 2–13 equal columns (Measure.beatDivisions).
  // Ticks are whole numbers (a quarter is 16), so a column usually
  // isn't a whole number of ticks: a note is STORED at the column's
  // start rounded to a tick, and SHOWN and PLAYED at the exact
  // position (see [displayTick]) — so the columns look and sound
  // exactly equal.

  /// The index of the measure containing [tick] (binary search).
  int measureIndexAtTick(int tick) {
    final list = measures;
    if (list.isEmpty) return -1;
    int lo = 0, hi = list.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (list[mid].startTick <= tick) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The split beat containing [tick]: its start, length in ticks and
  /// number of columns — or null when that beat isn't split.
  ({int start, int ticks, int columns})? dividedBeatAt(int tick) {
    final mi = measureIndexAtTick(tick);
    if (mi < 0) return null;
    final measure = measures[mi];
    if (measure.beatDivisions.isEmpty) return null;
    if (tick < measure.startTick || tick >= measure.endTick) return null;
    final beatTicks = measure.timeSignature.ticksPerBeat;
    int cursor = measure.startTick;
    for (int b = 0; b < measure.timeSignature.beats; b++) {
      final width = beatTicks * (getFermataMultiplier(mi, b) ?? 1);
      if (tick < cursor + width) {
        final n = measure.beatDivisions[b];
        if (n == null || n < 2) return null;
        return (start: cursor, ticks: width, columns: n);
      }
      cursor += width;
    }
    return null;
  }

  /// The tick where column [k] of a split beat starts (rounded).
  static int _columnTick(({int start, int ticks, int columns}) d, int k) =>
      d.start + (k * d.ticks / d.columns).round();

  /// The exact (fractional) position of [tick] for showing and playing
  /// notes: in a split beat, a column's (rounded) start tick is its
  /// exact start, and a tick INSIDE a column — e.g. a grace note carved
  /// from the start of a triplet note — lies proportionally between
  /// that column's exact start and end, so grace notes keep their own
  /// place and length there too; elsewhere the tick itself.
  double displayTick(int tick) {
    final d = dividedBeatAt(tick);
    if (d == null) return tick.toDouble();
    for (int k = d.columns - 1; k >= 0; k--) {
      final start = _columnTick(d, k);
      if (tick >= start) {
        final end = _columnTick(d, k + 1);
        final exactStart = d.start + k * d.ticks / d.columns;
        final exactWidth = d.ticks / d.columns;
        if (end <= start) return exactStart;
        return exactStart + (tick - start) * exactWidth / (end - start);
      }
    }
    return d.start.toDouble();
  }

  /// The column of a split beat that [tick] falls in (start tick and
  /// length in ticks, both rounded), or null when the beat isn't split.
  /// Uses the stored (rounded) column ticks, so a note's own start
  /// tick always finds its own column.
  ({int start, int ticks})? columnAt(int tick) {
    final d = dividedBeatAt(tick);
    if (d == null) return null;
    for (int k = d.columns - 1; k >= 0; k--) {
      final start = _columnTick(d, k);
      if (tick >= start) {
        return (start: start, ticks: _columnTick(d, k + 1) - start);
      }
    }
    return (start: d.start, ticks: _columnTick(d, 1) - d.start);
  }

  /// The column of a split beat at the exact (fractional) position
  /// [position] (in ticks) — where the finger tapped, as the columns
  /// are drawn exactly equal. Null when the beat isn't split.
  ({int start, int ticks})? columnAtPosition(double position) {
    final d = dividedBeatAt(position.floor());
    if (d == null) return null;
    final k = ((position - d.start) * d.columns / d.ticks)
        .floor()
        .clamp(0, d.columns - 1);
    final start = _columnTick(d, k);
    return (start: start, ticks: _columnTick(d, k + 1) - start);
  }

  /// Splits beat [beatIndex] of measure [measureIndex] into [columns]
  /// equal columns (1 = not split). Notes in the beat move to the
  /// nearest column. Returns a warning, or null when it worked.
  String? setBeatDivision(int measureIndex, int beatIndex, int columns) {
    final warning = _setBeatDivision(measureIndex, beatIndex, columns);
    timeline.rebuild();
    notifyListeners();
    return warning;
  }

  /// Splits every beat of the measures [fromIndex]..[toIndex] into
  /// [columns] columns. Returns warnings for beats that couldn't be.
  List<String> setBeatDivisionForMeasureRange(
      int fromIndex, int toIndex, int columns) {
    final warnings = <String>[];
    if (measures.isEmpty) return warnings;
    final start = fromIndex <= toIndex ? fromIndex : toIndex;
    final end = fromIndex <= toIndex ? toIndex : fromIndex;
    if (start < 0 || end >= measures.length) return warnings;
    for (int i = start; i <= end; i++) {
      for (int b = 0; b < measures[i].timeSignature.beats; b++) {
        final w = _setBeatDivision(i, b, columns);
        if (w != null && !warnings.contains(w)) warnings.add(w);
      }
    }
    timeline.rebuild();
    notifyListeners();
    return warnings;
  }

  String? _setBeatDivision(int measureIndex, int beatIndex, int columns) {
    if (measureIndex < 0 || measureIndex >= measures.length) return null;
    final measure = measures[measureIndex];
    if (beatIndex < 0 || beatIndex >= measure.timeSignature.beats) return null;
    if (columns <= 1) {
      measure.beatDivisions.remove(beatIndex);
      return null;
    }
    final width = measure.timeSignature.ticksPerBeat *
        (getFermataMultiplier(measureIndex, beatIndex) ?? 1);
    // Each column needs at least one tick (1/64).
    if (columns > width) {
      return 'Measure ${measureIndex + 1}: a ${measure.timeSignature.beatDuration.label} '
          'beat can be split into at most $width columns.';
    }
    measure.beatDivisions[beatIndex] = columns;
    final d = (
    start: getBeatTick(measureIndex, beatIndex),
    ticks: width,
    columns: columns,
    );
    final beatEnd = d.start + d.ticks;
    int nearestColumnTick(int tick) {
      final k = ((tick - d.start) * columns / width).round().clamp(0, columns);
      return _columnTick(d, k);
    }
    // Notes starting in the beat move to the nearest column (their end
    // too, when it is inside the beat).
    for (int i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (n.startTick < d.start || n.startTick >= beatEnd) continue;
      var newStart = nearestColumnTick(n.startTick);
      if (newStart >= beatEnd) newStart = _columnTick(d, columns - 1);
      var newEnd = n.startTick + n.durationTicks;
      if (newEnd <= beatEnd) newEnd = nearestColumnTick(newEnd);
      if (newEnd <= newStart) {
        newEnd = columnAt(newStart) == null
            ? newStart + 1
            : newStart + columnAt(newStart)!.ticks;
      }
      if (newStart != n.startTick || newEnd != n.startTick + n.durationTicks) {
        notes[i] = n.copyWith(
          startTick: newStart,
          durationTicks: newEnd - newStart,
        );
      }
    }
    return null;
  }

  /// Doubles the beat-count "subdivision" of every measure from
  /// [fromIndex] through [toIndex] (inclusive, 0-based) — e.g. 3
  /// beats of a quarter note each becomes 6 beats of an eighth note
  /// each. Purely a re-notation: since NoteDuration's own ticks
  /// values are a strict halving sequence (see that enum), doubling
  /// beats while halving beatDuration always leaves the measure's
  /// TOTAL duration in ticks exactly unchanged
  /// (2*beats * (ticksPerBeat/2) == beats * ticksPerBeat) — so no
  /// note, tempo/dynamic/dynamic-change event, or later measure needs
  /// to shift in time at all; only the affected measure's own
  /// TimeSignature changes.
  ///
  /// [fromIndex]/[toIndex] are treated as (min, max) regardless of
  /// which is actually larger; out-of-range indices (or an empty
  /// composition) make this a no-op. A measure whose beatDuration is
  /// already the shortest available (NoteDuration.sixtyFourth) can't
  /// be halved further and is skipped (with a warning); a measure
  /// carrying an existing fermata on any of its beats is also skipped
  /// (with its own warning) rather than silently producing a wrong
  /// result — [fermataMultipliers] is keyed by beat index, which this
  /// operation would invalidate by changing how many beats the
  /// measure has and what each one means.
  ///
  /// Returns a list of short messages describing anything that was
  /// skipped and why — empty if every measure in the range was
  /// converted successfully.
  List<String> doubleSubdivisionForMeasureRange(int fromIndex, int toIndex) {
    final warnings = <String>[];
    if (measures.isEmpty) return warnings;
    final start = fromIndex <= toIndex ? fromIndex : toIndex;
    final end = fromIndex <= toIndex ? toIndex : fromIndex;
    if (start < 0 || end >= measures.length) return warnings;

    for (int i = start; i <= end; i++) {
      final measure = measures[i];
      final oldDuration = measure.timeSignature.beatDuration;
      final oldIndex = NoteDuration.values.indexOf(oldDuration);
      if (oldIndex >= NoteDuration.values.length - 1) {
        warnings.add(
          'Measure ${i + 1}: already at the shortest duration '
              '(${oldDuration.label}) — skipped.',
        );
        continue;
      }
      // Any beat in this measure carrying a fermata makes the
      // transform ambiguous — see the method doc.
      final hasFermata =
      fermataMultipliers.keys.any((key) => key.startsWith('${i}_'));
      if (hasFermata) {
        warnings.add(
          'Measure ${i + 1}: has a fermata — remove it first, then '
              'try again.',
        );
        continue;
      }

      final newDuration = NoteDuration.values[oldIndex + 1];
      measures[i] = measure.copyWith(
        // Split beats (triplets…) don't survive a change of the beat.
        beatDivisions: <int, int>{},
        timeSignature: measure.timeSignature.copyWith(
          beats: measure.timeSignature.beats * 2,
          beatDuration: newDuration,
        ),
        // The tempo keeps counting the ORIGINAL beat, so splitting
        // beats never changes how fast the measure plays.
        tempoBeatDuration: measure.effectiveTempoBeat == newDuration
            ? null
            : measure.effectiveTempoBeat,
      );
    }

    notifyListeners();
    return warnings;
  }

  /// The exact inverse of [doubleSubdivisionForMeasureRange] — halves
  /// the beat count and doubles each beat's own duration for every
  /// measure from [fromIndex] through [toIndex] (inclusive,
  /// 0-based) — e.g. 6 beats of an eighth note each becomes 3 beats
  /// of a quarter note each. Same "purely a re-notation" reasoning as
  /// the doubling direction: the measure's TOTAL duration in ticks is
  /// exactly unchanged, so nothing needs to shift in time.
  ///
  /// [fromIndex]/[toIndex] are treated as (min, max) regardless of
  /// which is actually larger; out-of-range indices (or an empty
  /// composition) make this a no-op. Only possible when it's
  /// actually exact — a measure is skipped (with a warning) rather
  /// than silently rounding or producing a wrong result whenever:
  /// - its beat COUNT is odd (halving it wouldn't be a whole number
  ///   of beats);
  /// - its beatDuration is already the longest available
  ///   (NoteDuration.whole — nothing longer to double into); or
  /// - it carries an existing fermata on any of its beats (same
  ///   reasoning as the doubling direction — [fermataMultipliers] is
  ///   keyed by beat index, which changing the beat count would
  ///   invalidate).
  ///
  /// Returns a list of short messages describing anything that was
  /// skipped and why — empty if every measure in the range was
  /// converted successfully.
  List<String> halveSubdivisionForMeasureRange(int fromIndex, int toIndex) {
    final warnings = <String>[];
    if (measures.isEmpty) return warnings;
    final start = fromIndex <= toIndex ? fromIndex : toIndex;
    final end = fromIndex <= toIndex ? toIndex : fromIndex;
    if (start < 0 || end >= measures.length) return warnings;

    for (int i = start; i <= end; i++) {
      final measure = measures[i];
      final beats = measure.timeSignature.beats;

      if (beats % 2 != 0) {
        warnings.add(
          'Measure ${i + 1}: beat count ($beats) is odd — can\'t '
              'halve evenly — skipped.',
        );
        continue;
      }

      final oldDuration = measure.timeSignature.beatDuration;
      final oldIndex = NoteDuration.values.indexOf(oldDuration);
      if (oldIndex <= 0) {
        warnings.add(
          'Measure ${i + 1}: already at the longest duration '
              '(${oldDuration.label}) — skipped.',
        );
        continue;
      }

      // Any beat in this measure carrying a fermata makes the
      // transform ambiguous — see the method doc.
      final hasFermata =
      fermataMultipliers.keys.any((key) => key.startsWith('${i}_'));
      if (hasFermata) {
        warnings.add(
          'Measure ${i + 1}: has a fermata — remove it first, then '
              'try again.',
        );
        continue;
      }

      final newDuration = NoteDuration.values[oldIndex - 1];
      // The tempo keeps counting the beat it counted BEFORE uniting
      // (e.g. 6/8 united to 3/4 still counts eighths), so uniting
      // never changes how fast the measure plays. Once the measure is
      // back at that beat there's nothing to remember.
      final remembered = measure.effectiveTempoBeat;
      measures[i] = measure.copyWith(
        // Split beats (triplets…) don't survive a change of the beat.
        beatDivisions: <int, int>{},
        timeSignature: measure.timeSignature.copyWith(
          beats: beats ~/ 2,
          beatDuration: newDuration,
        ),
        tempoBeatDuration: remembered == newDuration ? null : remembered,
      );
    }

    notifyListeners();
    return warnings;
  }


  void removeBeatFromMeasure(
      int measureIndex,
      int beatIndex,
      ) {
    if (measureIndex < 0 || measureIndex >= measures.length) {
      return;
    }
    final measure = measures[measureIndex];
    // If this is the last beat, delete the whole measure.
    if (measure.timeSignature.beats == 1) {
      deleteMeasure(measureIndex);
      return;
    }
    // Remove notes that belong to the deleted beat.
    final beatTicks = measure.timeSignature.ticksPerBeat;
    final beatStart = measure.startTick + beatIndex * beatTicks;
    final beatEnd = beatStart + beatTicks;
    notes.removeWhere(
          (note) =>
      note.startTick >= beatStart &&
          note.startTick < beatEnd,
    );
    // Close the gap: everything from beatEnd onward — later beats in
    // this measure, and every measure after it — shifts back by one
    // beat's worth of ticks. Without this, only capacity gets trimmed
    // off the very END of the measure while whatever was actually
    // after the deleted beat stays at its old, now-wrong absolute
    // tick — which looks like the wrong beat got deleted.
    _shiftTicksFrom(beatEnd, -beatTicks);
    measure.removeBeat();
    // Split beats after the deleted one move one beat back.
    if (measure.beatDivisions.isNotEmpty) {
      final shifted = <int, int>{
        for (final e in measure.beatDivisions.entries)
          if (e.key < beatIndex) e.key: e.value
          else if (e.key > beatIndex) e.key - 1: e.value,
      };
      measure.beatDivisions
        ..clear()
        ..addAll(shifted);
    }
    timeline.rebuild();
    notifyListeners();
  }


  /// Removes all notes inside the given beat WITHOUT deleting the beat
  /// itself (unlike [removeBeatFromMeasure], which also shrinks the
  /// measure). Use this for a "Clean Beat" action. With [hands], only
  /// the notes of those hands are removed (null = every hand).
  void clearBeatNotes(
      int measureIndex,
      int beatIndex, {
        Set<Hand>? hands,
      }) {
    if (measureIndex < 0 || measureIndex >= measures.length) {
      return;
    }
    final measure = measures[measureIndex];
    final beatStart = measure.startTick +
        beatIndex * measure.timeSignature.ticksPerBeat;
    final beatEnd = beatStart +
        measure.timeSignature.ticksPerBeat;
    notes.removeWhere(
          (note) =>
      note.startTick >= beatStart &&
          note.startTick < beatEnd &&
          (hands == null || hands.contains(note.hand)),
    );
    notifyListeners();
  }


  /// Removes all notes inside the given measure WITHOUT deleting the
  /// measure itself (unlike [deleteMeasure]). Use this for a "Clean
  /// Measure" action. Also removes any dynamic events (piano/forte/
  /// etc.) and dynamic-change events — crescendo/diminuendo start &
  /// finish markers AND pedal down/up markers, which share that same
  /// storage (see DynamicChange.pedalDown/pedalUp) — that fall within
  /// the measure. Tempo events are left untouched.
  ///
  /// With [hands], only the notes of those hands are removed and the
  /// dynamics / pedal (which belong to no hand) stay; null (or all
  /// three hands) cleans everything as before.
  void clearMeasureNotes(
      int measureIndex, {
        Set<Hand>? hands,
      }) {
    if (measureIndex < 0 || measureIndex >= measures.length) {
      return;
    }
    final measure = measures[measureIndex];
    notes.removeWhere(
          (note) =>
      note.startTick >= measure.startTick &&
          note.startTick < measure.endTick &&
          (hands == null || hands.contains(note.hand)),
    );
    if (hands != null && !hands.containsAll(Hand.values)) {
      notifyListeners();
      return;
    }
    timeline.dynamicEvents.removeWhere(
          (event) =>
      event.tick >= measure.startTick &&
          event.tick < measure.endTick,
    );
    timeline.dynamicChangeEvents.removeWhere(
          (event) =>
      event.tick >= measure.startTick &&
          event.tick < measure.endTick,
    );
    notifyListeners();
  }



  // =====================================================
  // REPRISES
  // =====================================================
  //
  // In EDIT mode a reprise is only signs on measures (Measure.
  // repriseMarks): 𝄆 𝄇, voltas, 𝄋 Segno, Fine, To Coda, Coda, D.S.
  // In PLAYBACK mode (Scroll Lock on) the repeated measures are
  // inserted as temporary copies (Measure.isTemporary) right where the
  // music goes back, so playback simply plays straight through; the
  // copies show the numbers of the measures they copy, in red. Going
  // back to edit mode removes the copies again.

  /// The number shown on every measure, in grid order: its position,
  /// counting only real measures; a temporary copy shows the number of
  /// the measure it copies.
  List<int> measureNumbers() {
    final out = <int>[];
    int n = 0;
    for (final m in measures) {
      if (m.isTemporary) {
        out.add(m.copiedNumber ?? n);
      } else {
        n++;
        out.add(n);
      }
    }
    return out;
  }

  /// The number shown on the measure at grid position [index].
  int displayMeasureNumber(int index) {
    final numbers = measureNumbers();
    if (index < 0 || index >= numbers.length) return index + 1;
    return numbers[index];
  }

  /// Whether the measure at [index] is a temporary reprise copy.
  bool isTemporaryMeasure(int index) =>
      index >= 0 && index < measures.length && measures[index].isTemporary;

  /// Where the temporary repeat measures of the last playback layout
  /// were inserted: (tick in the edit layout, length, tick of the
  /// measures they copy). Kept after going back to edit mode, so a
  /// position can be carried over in both directions.
  final List<(int, int, int)> _layoutInsertions = [];

  /// A tick of the edit layout -> the same place in the playback
  /// layout (with the repeated measures inserted). The measure the
  /// person was at stays the same measure (its first time through).
  double editTickToPlayback(double t) {
    double shift = 0;
    for (final (at, length, _) in _layoutInsertions) {
      if (t >= at) shift += length;
    }
    return t + shift;
  }

  /// A tick of the playback layout -> the same place in the edit layout.
  /// A place inside a temporary repeated measure goes to the measure it
  /// copies.
  double playbackTickToEdit(double t) {
    double shift = 0;
    for (final (at, length, source) in _layoutInsertions) {
      final start = at + shift;
      if (t < start) break;
      if (t < start + length) return source + (t - start);
      shift += length;
    }
    return t - shift;
  }

  /// True while the reprises are played out (temporary copies exist).
  bool get repriseExpanded => measures.any((m) => m.isTemporary);

  /// True while anything is changed for playback (reprises played out
  /// or arpeggios spread) — the composition is then not as in edit
  /// mode, so it must not be saved like that.
  bool get playbackExpanded => repriseExpanded || _arpeggiosApplied;

  bool _has(int i, RepriseMark mark) =>
      i >= 0 && i < measures.length && measures[i].repriseMarks.contains(mark);

  /// Every reprise set in the composition (edit mode), in order.
  List<Reprise> get reprises {
    final out = <Reprise>[];
    final n = measures.length;
    int? pendingStart;
    int afterLastEnd = 0;
    for (int i = 0; i < n; i++) {
      if (measures[i].isTemporary) continue;
      if (_has(i, RepriseMark.start)) pendingStart = i;
      if (_has(i, RepriseMark.end)) {
        // A lone 𝄇 goes back to the start of the piece (or to just
        // after the previous 𝄇).
        final s = pendingStart ?? afterLastEnd;
        if (_has(i, RepriseMark.volta1)) {
          int v1 = i;
          while (v1 - 1 >= s && _has(v1 - 1, RepriseMark.volta1)) {
            v1--;
          }
          int v2 = i;
          while (v2 + 1 < n && _has(v2 + 1, RepriseMark.volta2)) {
            v2++;
          }
          out.add(Reprise(RepriseType.voltas,
              start: s, end: i, volta1Start: v1, volta2End: v2));
        } else {
          out.add(Reprise(RepriseType.simple, start: s, end: i));
        }
        pendingStart = null;
        afterLastEnd = i + 1;
      }
    }
    int lastBefore(int i, RepriseMark mark) {
      for (int k = i; k >= 0; k--) {
        if (_has(k, mark)) return k;
      }
      return -1;
    }

    int firstIn(int from, int to, RepriseMark mark) {
      for (int k = from; k <= to; k++) {
        if (_has(k, mark)) return k;
      }
      return -1;
    }

    for (int i = 0; i < n; i++) {
      if (_has(i, RepriseMark.dalSegnoAlFine)) {
        final segno = lastBefore(i, RepriseMark.segno);
        final fine = segno < 0 ? -1 : firstIn(segno, i, RepriseMark.fine);
        if (segno >= 0 && fine >= 0) {
          out.add(Reprise(RepriseType.segnoFine,
              segno: segno, fine: fine, dalSegno: i));
        }
      }
      if (_has(i, RepriseMark.dalSegnoAlCoda)) {
        final segno = lastBefore(i, RepriseMark.segno);
        final toCoda = segno < 0 ? -1 : firstIn(segno, i, RepriseMark.toCoda);
        final coda = firstIn(i + 1, n - 1, RepriseMark.coda);
        if (segno >= 0 && toCoda >= 0) {
          out.add(Reprise(RepriseType.segnoCoda,
              segno: segno, toCoda: toCoda, dalSegno: i, coda: coda < 0 ? null : coda));
        }
      }
    }
    return out;
  }

  String? _checkEditable(List<int> indices) {
    if (playbackExpanded) return 'Go back to edit mode first.';
    for (final i in indices) {
      if (i < 0 || i >= measures.length) {
        return 'Measure ${i + 1} is not in the composition '
            '(it has ${measures.length} measures).';
      }
    }
    return null;
  }

  void _mark(int i, RepriseMark mark) => measures[i].repriseMarks.add(mark);

  /// Option 1, simple reprise: measures [start]..[end] (0-based) are
  /// played twice.
  String? addSimpleReprise(int start, int end) {
    final error = _checkEditable([start, end]);
    if (error != null) return error;
    if (end < start) return 'The reprise must end after it starts.';
    _mark(start, RepriseMark.start);
    _mark(end, RepriseMark.end);
    notifyListeners();
    return null;
  }

  /// Option 2, reprise with voltas: the reprise runs from [start] to
  /// the end of volta 1 ([volta1Start]..[volta1End]); the second time
  /// volta 2 ([volta2Start]..[volta2End]) is played instead.
  String? addVoltaReprise(int start, int volta1Start, int volta1End,
      int volta2Start, int volta2End) {
    final error =
    _checkEditable([start, volta1Start, volta1End, volta2Start, volta2End]);
    if (error != null) return error;
    if (!(start < volta1Start && volta1Start <= volta1End)) {
      return 'Volta 1 must start after the reprise starts, and end after it starts.';
    }
    if (volta2Start != volta1End + 1) {
      return 'Volta 2 must start right after volta 1 '
          '(measure ${volta1End + 2}).';
    }
    if (volta2End < volta2Start) return 'Volta 2 must end after it starts.';
    _mark(start, RepriseMark.start);
    _mark(volta1End, RepriseMark.end);
    for (int i = volta1Start; i <= volta1End; i++) {
      _mark(i, RepriseMark.volta1);
    }
    for (int i = volta2Start; i <= volta2End; i++) {
      _mark(i, RepriseMark.volta2);
    }
    notifyListeners();
    return null;
  }

  /// Option 3, D.S. al Fine: at [dalSegno] go back to [segno] and play
  /// up to [fine].
  String? addSegnoFine(int segno, int fine, int dalSegno) {
    final error = _checkEditable([segno, fine, dalSegno]);
    if (error != null) return error;
    if (!(segno <= fine && fine < dalSegno)) {
      return 'The order must be: Segno, then Fine, then D.S. al Fine.';
    }
    _mark(segno, RepriseMark.segno);
    _mark(fine, RepriseMark.fine);
    _mark(dalSegno, RepriseMark.dalSegnoAlFine);
    notifyListeners();
    return null;
  }

  /// Option 4, D.S. al Coda: at [dalSegno] go back to [segno], play up
  /// to [toCoda], then jump to the Coda at [coda].
  String? addSegnoCoda(int segno, int toCoda, int dalSegno, int coda) {
    final error = _checkEditable([segno, toCoda, dalSegno, coda]);
    if (error != null) return error;
    if (!(segno <= toCoda && toCoda < dalSegno && dalSegno < coda)) {
      return 'The order must be: Segno, then To Coda, then D.S. al Coda, '
          'then Coda.';
    }
    _mark(segno, RepriseMark.segno);
    _mark(toCoda, RepriseMark.toCoda);
    _mark(dalSegno, RepriseMark.dalSegnoAlCoda);
    _mark(coda, RepriseMark.coda);
    notifyListeners();
    return null;
  }

  /// Removes the signs of reprise [r].
  void removeReprise(Reprise r) {
    void unmark(int? i, RepriseMark mark) {
      if (i != null && i >= 0 && i < measures.length) {
        measures[i].repriseMarks.remove(mark);
      }
    }

    switch (r.type) {
      case RepriseType.simple:
        unmark(r.start, RepriseMark.start);
        unmark(r.end, RepriseMark.end);
        break;
      case RepriseType.voltas:
        unmark(r.start, RepriseMark.start);
        unmark(r.end, RepriseMark.end);
        for (int i = r.volta1Start!; i <= r.end!; i++) {
          unmark(i, RepriseMark.volta1);
        }
        for (int i = r.end! + 1; i <= r.volta2End!; i++) {
          unmark(i, RepriseMark.volta2);
        }
        break;
      case RepriseType.segnoFine:
        unmark(r.segno, RepriseMark.segno);
        unmark(r.fine, RepriseMark.fine);
        unmark(r.dalSegno, RepriseMark.dalSegnoAlFine);
        break;
      case RepriseType.segnoCoda:
        unmark(r.segno, RepriseMark.segno);
        unmark(r.toCoda, RepriseMark.toCoda);
        unmark(r.dalSegno, RepriseMark.dalSegnoAlCoda);
        unmark(r.coda, RepriseMark.coda);
        break;
    }
    notifyListeners();
  }

  /// PLAYBACK mode: inserts the measures each reprise plays again as
  /// temporary copies right where the music goes back, so playback
  /// plays straight through. Called when Scroll Lock turns on.
  void expandReprises() {
    if (measures.isEmpty) return;
    if (repriseExpanded) {
      if (!_arpeggiosApplied) _applyArpeggios();
      notifyListeners();
      return;
    }
    _layoutInsertions.clear();
    // (insert after, copy from, copy to) — 0-based measure positions.
    final insertions = <(int, int, int)>[];
    for (final r in reprises) {
      switch (r.type) {
        case RepriseType.simple:
          insertions.add((r.end!, r.start!, r.end!));
          break;
        case RepriseType.voltas:
        // Second time: from the 𝄆 up to just before volta 1, then
        // straight on into volta 2.
          if (r.volta1Start! > r.start!) {
            insertions.add((r.end!, r.start!, r.volta1Start! - 1));
          }
          break;
        case RepriseType.segnoFine:
          insertions.add((r.dalSegno!, r.segno!, r.fine!));
          break;
        case RepriseType.segnoCoda:
          insertions.add((r.dalSegno!, r.segno!, r.toCoda!));
          break;
      }
    }
    // From the last place to the first, so earlier positions stay valid.
    insertions.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (after, from, to) in insertions) {
      _insertTemporaryCopies(after, from, to);
    }
    // Arpeggios last, so the repeated measures' chords are spread too.
    if (!_arpeggiosApplied) _applyArpeggios();
    notifyListeners();
  }

  /// EDIT mode: removes the temporary copies made by [expandReprises].
  /// Called when Scroll Lock turns off, and around saving.
  void collapseReprises() {
    _restoreArpeggios();
    _removeTemporaryEvents();
    for (int i = measures.length - 1; i >= 0; i--) {
      if (measures[i].isTemporary) deleteMeasure(i);
    }
    notifyListeners();
  }

  /// Inserts copies of measures [from]..[to] (with their notes) right
  /// after measure [after], marked as temporary.
  void _insertTemporaryCopies(int after, int from, int to) {
    if (from < 0 || to < from || after < to || after >= measures.length) return;
    final insertIndex = after + 1;
    final insertTick = measures[after].endTick;
    final srcStart = measures[from].startTick;
    final srcEnd = measures[to].endTick;
    final offset = insertTick - srcStart;
    // Snapshots BEFORE anything moves (the source lies before the
    // insertion point, so shifting below never touches it).
    final sources = measures.sublist(from, to + 1).toList();
    final sourceNotes = notes
        .where((n) => n.startTick >= srcStart && n.startTick < srcEnd)
        .toList();
    // Insertions go from the last to the first, so insertTick is a tick
    // of the edit-mode layout.
    _layoutInsertions
      ..add((insertTick, srcEnd - srcStart, srcStart))
      ..sort((a, b) => a.$1.compareTo(b.$1));
    bool inSource(int tick) => tick >= srcStart && tick < srcEnd;
    final sourceTempos = [
      for (final e in timeline.tempoEvents)
        if (inSource(e.tick)) (e.tick, e.tempo)
    ];
    final sourceDynamics = [
      for (final e in timeline.dynamicEvents)
        if (inSource(e.tick)) (e.tick, e.musical_dynamic)
    ];
    final sourceChanges = [
      for (final e in timeline.dynamicChangeEvents)
        if (inSource(e.tick)) (e.tick, e.dynamic_change)
    ];
    // Tempo / dynamic in effect: at the start of the repeated part, at
    // the end of it, just before the copy goes in, and for the music
    // that follows the copy.
    final tempoAtSourceStart = getActiveTempoAtTick(srcStart)?.tempo;
    final tempoAtSourceEnd = getActiveTempoAtTick(srcEnd - 1)?.tempo;
    final tempoBeforeCopy = getActiveTempoAtTick(insertTick - 1)?.tempo;
    final tempoAfterCopy = getActiveTempoAtTick(insertTick)?.tempo;
    final dynamicAtSourceStart = _activeDynamicAt(srcStart);
    final dynamicAtSourceEnd = _activeDynamicAt(srcEnd - 1);
    final dynamicBeforeCopy = _activeDynamicAt(insertTick - 1);
    final dynamicAfterCopy = _activeDynamicAt(insertTick);
    final hadTempoAtInsert = timeline.tempoEvents.any((e) => e.tick == insertTick);
    final hadDynamicAtInsert =
    timeline.dynamicEvents.any((e) => e.tick == insertTick);

    _shiftTicksFrom(insertTick, srcEnd - srcStart);

    for (int k = 0; k < sources.length; k++) {
      final m = sources[k];
      measures.insert(
        insertIndex + k,
        m.copyWith(
          id: measures.length + k,
          startTick: m.startTick + offset,
          beatEvents: m.beatEvents
              .map((e) => e.copyWith(tick: e.tick + offset))
              .toList(),
          inkStrokes: <InkStroke>[],
          repriseMarks: <RepriseMark>{},
          isTemporary: true,
          copiedNumber: from + k + 1,
        ),
      );
    }

    // Copy the notes, keeping glissando / grace-note links inside the
    // copy pointing at the copied notes.
    final idMap = <int, int>{
      for (final note in sourceNotes) note.id: generateNoteId(),
    };
    notes.addAll(sourceNotes.map((note) => note.copyWith(
      id: idMap[note.id],
      startTick: note.startTick + offset,
      glissandoSourceId: note.glissandoSourceId == null
          ? null
          : (idMap[note.glissandoSourceId] ?? note.glissandoSourceId),
      graceOfNoteId: note.graceOfNoteId == null
          ? null
          : (idMap[note.graceOfNoteId] ?? note.graceOfNoteId),
    )));

    // Tempo, dynamics, crescendo/diminuendo and pedal marks of the
    // repeated part are copied too (all temporary, see
    // [_temporaryEvents]).
    final copyStart = insertTick;
    final copyEnd = insertTick + (srcEnd - srcStart);
    void addTempo(int tick, Tempo tempo) {
      if (timeline.tempoEvents.any((e) => e.tick == tick)) return;
      timeline.tempoEvents.add(TempoEvent(tick: tick, tempo: tempo));
      _temporaryEvents.add(_TemporaryEvent(_TemporaryEventKind.tempo, tick));
    }

    void addDynamic(int tick, MusicalDynamic level) {
      if (timeline.dynamicEvents.any((e) => e.tick == tick)) return;
      timeline.dynamicEvents.add(DynamicEvent(tick: tick, musical_dynamic: level));
      _temporaryEvents.add(_TemporaryEvent(_TemporaryEventKind.dynamic, tick));
    }

    for (final (tick, tempo) in sourceTempos) {
      addTempo(tick + offset, tempo);
    }
    // The repeated part starts in its own tempo, even when that tempo
    // was set before it…
    if (tempoAtSourceStart != null && tempoAtSourceStart != tempoBeforeCopy) {
      addTempo(copyStart, tempoAtSourceStart);
    }
    // …and the music after it goes on in the tempo it had before.
    if (!hadTempoAtInsert &&
        tempoAfterCopy != null &&
        tempoAfterCopy != tempoAtSourceEnd) {
      addTempo(copyEnd, tempoAfterCopy);
    }

    for (final (tick, level) in sourceDynamics) {
      addDynamic(tick + offset, level);
    }
    if (dynamicAtSourceStart != null && dynamicAtSourceStart != dynamicBeforeCopy) {
      addDynamic(copyStart, dynamicAtSourceStart);
    }
    if (!hadDynamicAtInsert &&
        dynamicAfterCopy != null &&
        dynamicAfterCopy != dynamicAtSourceEnd) {
      addDynamic(copyEnd, dynamicAfterCopy);
    }

    for (final (tick, change) in sourceChanges) {
      timeline.dynamicChangeEvents
          .add(DynamicChangeEvent(tick: tick + offset, dynamic_change: change));
      _temporaryEvents.add(_TemporaryEvent(
          _TemporaryEventKind.dynamicChange, tick + offset, change));
    }

    timeline.tempoEvents.sort((a, b) => a.tick.compareTo(b.tick));
    timeline.dynamicEvents.sort((a, b) => a.tick.compareTo(b.tick));
    timeline.dynamicChangeEvents.sort((a, b) => a.tick.compareTo(b.tick));

    timeline.rebuild();
  }

  // =====================================================
  // ARPEGGIOS
  // =====================================================

  /// Puts repeat signs and arpeggios read from an imported
  /// transcription (see notation_marks.dart) on the measures.
  /// [reprise]: (0-based measure, sign); [arpeggios]: (0-based measure,
  /// beat as written — 1, 2.5…, hand). Arpeggios of both hands on the
  /// same beat become one "both hands" arpeggio.
  void applyNotationMarks(
      List<(int, RepriseMark)> reprise,
      List<(int, double, Hand)> arpeggios,
      ) {
    for (final (i, mark) in reprise) {
      if (i >= 0 && i < measures.length) measures[i].repriseMarks.add(mark);
    }
    for (final (i, beat, hand) in arpeggios) {
      if (i < 0 || i >= measures.length || beat < 1) continue;
      final m = measures[i];
      final whole = beat.floor();
      final tick = getBeatTick(i, whole - 1) +
          ((beat - whole) * m.timeSignature.ticksPerBeat).round();
      final offset = tick - m.startTick;
      final hands = <Hand>{
        for (final a in m.arpeggios)
          if (a.offset == offset) ...a.hands,
        hand,
      };
      m.arpeggios
        ..removeWhere((a) => a.offset == offset)
        ..add(Arpeggio(offset, hands))
        ..sort((a, b) => a.offset.compareTo(b.offset));
    }
    notifyListeners();
  }

  /// Removes every measure with its notes, dynamics, pedal marks and
  /// tempo changes (the starting tempo stays) — used to REPLACE the
  /// whole composition with an imported transcription.
  void clearAllMeasures() {
    if (measures.isEmpty) return;
    clearMeasureRangeNotes(0, measures.length - 1);
    timeline.tempoEvents.removeWhere((e) => e.tick != 0);
    deleteMeasureRange(0, measures.length - 1);
    timeline.dynamicEvents.clear();
    timeline.dynamicChangeEvents.clear();
    notes.clear();
    notifyListeners();
  }

  /// The arpeggio on the chord at [tick] (null if none).
  Arpeggio? arpeggioAt(int tick) {
    if (measures.isEmpty) return null;
    final m = getMeasureAtTick(tick);
    for (final a in m.arpeggios) {
      if (m.startTick + a.offset == tick) return a;
    }
    return null;
  }

  /// Puts an arpeggio on the chord at [tick] for [hands] (left, right
  /// or both); an empty [hands] removes it. Edit mode only.
  String? setArpeggio(int tick, Set<Hand> hands) {
    if (measures.isEmpty) return null;
    if (playbackExpanded) return 'Go back to edit mode first.';
    final m = getMeasureAtTick(tick);
    final offset = tick - m.startTick;
    m.arpeggios.removeWhere((a) => a.offset == offset);
    if (hands.isNotEmpty) {
      m.arpeggios
        ..add(Arpeggio(offset, Set<Hand>.from(hands)))
        ..sort((a, b) => a.offset.compareTo(b.offset));
    }
    notifyListeners();
    return null;
  }

  /// The notes an arpeggio at [tick] spreads: the chord notes of its
  /// hands starting exactly there (not grace notes or glissando runs),
  /// lowest first.
  List<Note> arpeggioNotes(int tick, Set<Hand> hands) {
    final chord = [
      for (final n in notes)
        if (n.startTick == tick &&
            hands.contains(n.hand) &&
            n.graceOfNoteId == null &&
            n.glissandoSourceId == null)
          n
    ]..sort((a, b) => a.row.compareTo(b.row));
    return chord;
  }

  bool _arpeggiosApplied = false;

  /// The chord notes as they were before [_applyArpeggios] spread them.
  final List<Note> _arpeggioOriginals = [];

  /// PLAYBACK mode: every arpeggiated chord is played one note after
  /// another, lowest first. The chord's duration (its shortest note) is
  /// shared equally between its notes. Each spread note keeps its id,
  /// so grace notes and other links still find it.
  void _applyArpeggios() {
    _arpeggioOriginals.clear();
    for (final m in measures) {
      for (final a in m.arpeggios) {
        final tick = m.startTick + a.offset;
        final chord = arpeggioNotes(tick, a.hands);
        if (chord.length < 2) continue;
        final total = chord
            .map((n) => n.durationTicks)
            .reduce((x, y) => x < y ? x : y);
        final k = chord.length;
        for (int i = 0; i < k; i++) {
          final n = chord[i];
          final start = tick + (i * total) ~/ k;
          final end = tick + ((i + 1) * total) ~/ k;
          final index = notes.indexWhere((x) => identical(x, n));
          if (index < 0 || end <= start) continue;
          _arpeggioOriginals.add(n);
          notes[index] = n.copyWith(startTick: start, durationTicks: end - start);
        }
      }
    }
    _arpeggiosApplied = true;
  }

  /// EDIT mode: puts the arpeggiated chords back as chords.
  void _restoreArpeggios() {
    if (!_arpeggiosApplied) return;
    final ids = {for (final n in _arpeggioOriginals) n.id};
    notes.removeWhere((n) => ids.contains(n.id));
    notes.addAll(_arpeggioOriginals);
    _arpeggioOriginals.clear();
    _arpeggiosApplied = false;
  }

  /// The dynamic (p, f…) in effect at [tick] (null before the first).
  MusicalDynamic? _activeDynamicAt(int tick) {
    MusicalDynamic? active;
    for (final e in timeline.dynamicEvents) {
      if (e.tick <= tick) {
        active = e.musical_dynamic;
      } else {
        break; // kept sorted by tick
      }
    }
    return active;
  }

  /// Tempo / dynamic / crescendo / pedal events added only for playing
  /// the reprises — removed again by [collapseReprises]. Their ticks
  /// follow every later insert/removal (see [_shiftTicksFrom]).
  final List<_TemporaryEvent> _temporaryEvents = [];

  void _removeTemporaryEvents() {
    for (final t in _temporaryEvents) {
      switch (t.kind) {
        case _TemporaryEventKind.tempo:
          timeline.tempoEvents.removeWhere((e) => e.tick == t.tick);
          break;
        case _TemporaryEventKind.dynamic:
          timeline.dynamicEvents.removeWhere((e) => e.tick == t.tick);
          break;
        case _TemporaryEventKind.dynamicChange:
          final i = timeline.dynamicChangeEvents.indexWhere(
                  (e) => e.tick == t.tick && e.dynamic_change == t.change);
          if (i >= 0) timeline.dynamicChangeEvents.removeAt(i);
          break;
      }
    }
    _temporaryEvents.clear();
  }

  void deleteMeasure(int index) {
    if (index < 0 || index >= measures.length) {
      return;
    }
    final startTick = measures[index].startTick;
    final endTick = measures[index].endTick;
    notes.removeWhere(
          (note) =>
      note.startTick >= startTick &&
          note.startTick < endTick,
    );
    // Close the gap: everything after the deleted measure shifts back
    // by its full duration — same reasoning as removeBeatFromMeasure.
    // Done before timeline.deleteMeasure() removes it from the list;
    // shifting the doomed measure's own beatEvents too is harmless
    // wasted work since it's about to be discarded anyway.
    _shiftTicksFrom(endTick, -(endTick - startTick));
    timeline.deleteMeasure(index);
    // Keep selectedMeasureIndex valid — it may have been pointing at the
    // measure we just deleted (or one after it), which would otherwise
    // leave it out of range and crash the next read of currentMeasure
    // (used by the pitch column).
    if (measures.isEmpty) {
      selectedMeasureIndex = 0;
    } else if (selectedMeasureIndex >= measures.length) {
      selectedMeasureIndex = measures.length - 1;
    }
    notifyListeners();
  }



  /// Duplicates measure [index]: the copy goes RIGHT AFTER it (the
  /// measures after it move one place later), with all its notes,
  /// dynamics, pedal / crescendo marks, tempo changes and arpeggios.
  void copyMeasure(int index) {
    duplicateMeasureRange(index, index);
  }

  /// Duplicates measures [fromIndex]..[toIndex] (inclusive, 0-based,
  /// either order): the copy goes right after [toIndex], with all the
  /// notes, dynamics, pedal / crescendo marks, tempo changes and
  /// arpeggios of the range. Glissando / grace-note links inside the
  /// range point at the copied notes. Repeat signs and red-pen marks
  /// stay on the originals.
  void duplicateMeasureRange(int fromIndex, int toIndex) {
    if (measures.isEmpty) return;
    final start = fromIndex <= toIndex ? fromIndex : toIndex;
    final end = fromIndex <= toIndex ? toIndex : fromIndex;
    if (start < 0 || end >= measures.length) return;
    // In playback mode the measures are not as written — go back to
    // edit mode first (the copies would otherwise mix with the
    // temporary repeat measures).
    if (playbackExpanded) return;

    final srcStart = measures[start].startTick;
    final srcEnd = measures[end].endTick;
    final length = srcEnd - srcStart;
    final insertTick = srcEnd;
    final offset = insertTick - srcStart;

    // Snapshots BEFORE anything moves (the source lies before the
    // insertion point, so the shift below never touches it).
    final sources = measures.sublist(start, end + 1).toList();
    bool inSource(int tick) => tick >= srcStart && tick < srcEnd;
    final sourceNotes = notes.where((n) => inSource(n.startTick)).toList();
    final sourceTempos = [
      for (final e in timeline.tempoEvents)
        if (inSource(e.tick) && e.tick != 0) (e.tick, e.tempo)
    ];
    final sourceDynamics = [
      for (final e in timeline.dynamicEvents)
        if (inSource(e.tick)) (e.tick, e.musical_dynamic)
    ];
    final sourceChanges = [
      for (final e in timeline.dynamicChangeEvents)
        if (inSource(e.tick)) (e.tick, e.dynamic_change)
    ];

    // Make room: everything after the range moves later.
    _shiftTicksFrom(insertTick, length);

    for (int k = 0; k < sources.length; k++) {
      final m = sources[k];
      measures.insert(
        end + 1 + k,
        m.copyWith(
          id: measures.length + k,
          startTick: m.startTick + offset,
          beatEvents: m.beatEvents
              .map((e) => e.copyWith(tick: e.tick + offset))
              .toList(),
          inkStrokes: <InkStroke>[],
          repriseMarks: <RepriseMark>{},
          isTemporary: false,
          copiedNumber: null,
          arpeggios: List<Arpeggio>.from(m.arpeggios),
        ),
      );
    }

    final idMap = <int, int>{
      for (final note in sourceNotes) note.id: generateNoteId(),
    };
    notes.addAll(sourceNotes.map((note) => note.copyWith(
      id: idMap[note.id],
      startTick: note.startTick + offset,
      glissandoSourceId: note.glissandoSourceId == null
          ? null
          : (idMap[note.glissandoSourceId] ?? note.glissandoSourceId),
      graceOfNoteId: note.graceOfNoteId == null
          ? null
          : (idMap[note.graceOfNoteId] ?? note.graceOfNoteId),
    )));

    for (final (tick, tempo) in sourceTempos) {
      timeline.tempoEvents.add(TempoEvent(tick: tick + offset, tempo: tempo));
    }
    for (final (tick, level) in sourceDynamics) {
      timeline.dynamicEvents
          .add(DynamicEvent(tick: tick + offset, musical_dynamic: level));
    }
    for (final (tick, change) in sourceChanges) {
      timeline.dynamicChangeEvents
          .add(DynamicChangeEvent(tick: tick + offset, dynamic_change: change));
    }
    timeline.tempoEvents.sort((a, b) => a.tick.compareTo(b.tick));
    timeline.dynamicEvents.sort((a, b) => a.tick.compareTo(b.tick));
    timeline.dynamicChangeEvents.sort((a, b) => a.tick.compareTo(b.tick));

    if (selectedMeasureIndex > end) selectedMeasureIndex += sources.length;
    timeline.rebuild();
    notifyListeners();
  }


  /// Deletes every measure from [fromIndex] through [toIndex]
  /// (inclusive, 0-based) — [fromIndex]/[toIndex] are treated as
  /// (min, max) regardless of which is actually larger, so callers
  /// don't need to sort them first; out-of-range indices (or an empty
  /// composition) make this a no-op. Implemented as repeated calls to
  /// the existing single-measure [deleteMeasure], working from the
  /// HIGHEST index down to the lowest — deleting a measure shifts
  /// every LATER measure's index down by one, so working backward
  /// means indices still to be deleted never move out from under this
  /// loop. Reuses [deleteMeasure]'s own note-removal/tick-shifting/
  /// selectedMeasureIndex-clamping logic exactly as-is for each
  /// measure, rather than duplicating it here.
  void deleteMeasureRange(int fromIndex, int toIndex) {
    if (measures.isEmpty) return;
    final start = fromIndex <= toIndex ? fromIndex : toIndex;
    final end = fromIndex <= toIndex ? toIndex : fromIndex;
    if (start < 0 || end >= measures.length) return;
    for (int i = end; i >= start; i--) {
      deleteMeasure(i);
    }
  }


  /// Removes all notes (and dynamic/dynamic-change/pedal events — see
  /// [clearMeasureNotes]) inside every measure from [fromIndex]
  /// through [toIndex] (inclusive, 0-based), WITHOUT deleting any of
  /// the measures themselves — generalizes [clearMeasureNotes] to a
  /// whole range, the same way [duplicateMeasureRange] generalizes
  /// [copyMeasure]. [fromIndex]/[toIndex] are treated as (min, max)
  /// regardless of which is actually larger; out-of-range indices (or
  /// an empty composition) make this a no-op.
  void clearMeasureRangeNotes(int fromIndex, int toIndex,
      {Set<Hand>? hands}) {
    if (measures.isEmpty) return;
    final start = fromIndex <= toIndex ? fromIndex : toIndex;
    final end = fromIndex <= toIndex ? toIndex : fromIndex;
    if (start < 0 || end >= measures.length) return;
    for (int i = start; i <= end; i++) {
      clearMeasureNotes(i, hands: hands);
    }
  }


  void copyBeat(
      int measureIndex,
      int beatIndex,
      ) {
    if(measureIndex < 0 ||
        measureIndex >= measures.length){
      return;
    }
    final measure = measures[measureIndex];
    final beatStart = measure.startTick + beatIndex *
        measure.timeSignature.ticksPerBeat;
    final beatEnd = beatStart + measure.timeSignature.ticksPerBeat;
    // Copy notes inside this beat
    final copiedNotes = notes.where((note) => note.startTick >= beatStart &&
        note.startTick < beatEnd,
    )
        .map(
          (note) {
        return note.copyWith(
          id: generateNoteId(),
          // place copied beat after original beat
          startTick:
          note.startTick +
              measure.timeSignature.ticksPerBeat,
        );
      },
    )
        .toList();
    notes.addAll(copiedNotes);
    // The copy gets the same split columns (triplet…) as the original.
    final division = measure.beatDivisions[beatIndex];
    if (beatIndex + 1 < measure.timeSignature.beats) {
      if (division != null) {
        measure.beatDivisions[beatIndex + 1] = division;
      } else {
        measure.beatDivisions.remove(beatIndex + 1);
      }
    }
    // Copy beat events
    final beatEvents = measure.beatEvents.where((event)=>
    event.tick >= beatStart && event.tick < beatEnd,
    )
        .map(
          (event){
        return event.copyWith(
          tick: event.tick + measure.timeSignature.ticksPerBeat,
        );
      },
    )
        .toList();
    measure.beatEvents.addAll(beatEvents);
    notifyListeners();
  }

  // =====================================================
// TEMPO
// =====================================================

  void setTempoAtBeat(
      int measureIndex,
      int beatIndex,
      Tempo tempo,
      ) {
    final tick = getBeatTick(
      measureIndex,
      beatIndex,
    );
    timeline.addTempoEvent(
      TempoEvent(
        tick: tick,
        tempo: tempo,
      ),
    );
    notifyListeners();
  }


  void removeTempoAtBeat(
      int measureIndex,
      int beatIndex,
      ) {
    final tick = getBeatTick(
      measureIndex,
      beatIndex,
    );
    timeline.removeTempoEvent(
      TempoEvent(
        tick: tick,
        tempo: Tempo.moderato,
      ),
    );
    notifyListeners();
  }


  void setTempoAtTick(
      int tick,
      Tempo tempo,
      ) {
    timeline.addTempoEvent(
      TempoEvent(
        tick: tick,
        tempo: tempo,
      ),
    );
    notifyListeners();
  }
  TempoEvent? getTempoAtTick(int tick) {
    try {
      return timeline.tempoEvents.firstWhere(
            (e) => e.tick == tick,
      );
    }
    catch(e) {
      return null;
    }
  }

  /// The tempo actually in effect AT [tick] — i.e. the latest tempo
  /// event at or before it — as opposed to [getTempoAtTick], which only
  /// matches an exact tick. tempoEvents always has at least the tick-0
  /// entry (guaranteed by Timeline), so this never returns null as long
  /// as there's at least one tempo event.
  TempoEvent? getActiveTempoAtTick(int tick) {
    if (timeline.tempoEvents.isEmpty) {
      return null;
    }
    TempoEvent active = timeline.tempoEvents.first;
    for (final event in timeline.tempoEvents) {
      if (event.tick <= tick) {
        active = event;
      } else {
        break; // tempoEvents is kept sorted ascending by tick
      }
    }
    return active;
  }


  void updateTempoEvent(
      int tick,
      Tempo tempo,
      ) {
    final index = timeline.tempoEvents.indexWhere(
          (e) => e.tick == tick,
    );
    if (index >= 0) {
      timeline.tempoEvents[index] =
          timeline.tempoEvents[index].copyWith(
            tempo: tempo,
          );
    } else {
      timeline.addTempoEvent(
        TempoEvent(
          tick: tick,
          tempo: tempo,
        ),
      );
    }
    notifyListeners();
  }

  void deleteTempoEvent(int tick) {
    timeline.removeTempoEvent(
      TempoEvent(
        tick: tick,
        tempo: Tempo.moderato, // value does not matter, only tick is used
      ),
    );
    notifyListeners();
  }


  // =====================================================
  // DYNAMICS
  // =====================================================

  DynamicEvent? getDynamicAtTick(int tick) {
    try {
      return timeline.dynamicEvents.firstWhere(
            (e) => e.tick == tick,
      );
    }
    catch (e) {
      return null;
    }
  }

  void updateDynamicEvent(
      int tick,
      MusicalDynamic dynamic,
      ) {
    final index = timeline.dynamicEvents.indexWhere(
          (e) => e.tick == tick,
    );
    if (index >= 0) {
      timeline.dynamicEvents[index].musical_dynamic = dynamic;
    } else {
      timeline.addDynamicEvent(
        DynamicEvent(
          tick: tick,
          musical_dynamic: dynamic,
        ),
      );
    }
    notifyListeners();
  }

  void deleteDynamicEvent(int tick) {
    timeline.removeDynamicEvent(tick);
    notifyListeners();
  }

// =====================================================
  // DYNAMIC CHANGES (crescendo / diminuendo)
  // =====================================================

  DynamicChangeEvent? getDynamicChangeAtTick(int tick) {
    try {
      return timeline.dynamicChangeEvents.firstWhere(
            (e) => e.tick == tick,
      );
    }
    catch (e) {
      return null;
    }
  }

  /// Sets [dChange] at [tick]. Only replaces an EXISTING event at that
  /// tick if it's the SAME category (pedal vs crescendo/diminuendo) as
  /// [dChange] itself — a pedal event and a hairpin event can
  /// otherwise share the exact same tick without one silently
  /// overwriting the other, since [Timeline.dynamicChangeEvents]
  /// doesn't reserve a tick exclusively for one type or the other.
  void updateDynamicChangeEvent(
      int tick,
      DynamicChange dChange,
      ) {
    // Timeline.addDynamicChangeEvent is itself category-aware now
    // (only replaces an existing event of the SAME category — pedal
    // vs crescendo/diminuendo — at this tick), so it's always safe to
    // call directly here without checking for an existing event
    // first.
    timeline.addDynamicChangeEvent(
      DynamicChangeEvent(
        tick: tick,
        dynamic_change: dChange,
      ),
    );
    notifyListeners();
  }

  /// Removes whichever event is at [tick] — [isPedal] selects which
  /// CATEGORY to remove (a pedal event or a crescendo/diminuendo
  /// event), since both can coexist at the same tick (see
  /// [updateDynamicChangeEvent]'s doc) and deleting one must never
  /// remove the other. Called with isPedal: false from
  /// dynamicChangeDialog's Delete button, and isPedal: true from
  /// pedalDialog's.
  void deleteDynamicChangeEvent(int tick, {required bool isPedal}) {
    timeline.removeDynamicChangeEvent(tick, isPedal: isPedal);
    notifyListeners();
  }

  // =====================================================
  // SUSTAIN PEDAL
  // =====================================================
  //
  // Pedal marks (pedalDown/pedalUp) share the same
  // DynamicChangeEvent/timeline.dynamicChangeEvents storage as
  // crescendo/diminuendo above — same shape (a tick + a DynamicChange
  // value), same persistence semantics (a state holds from its event
  // forward until the next one). GridPainter draws them as their own
  // thin red connecting line rather than the green crescendo/
  // diminuendo line, and dynamicChangeDialog's picker excludes them
  // entirely — pedal is only ever set via pedalDialog. Both types can
  // coexist at the exact same tick without one overwriting or deleting
  // the other — see updateDynamicChangeEvent / deleteDynamicChangeEvent's
  // own docs for how that's kept safe.

  /// Whether the sustain pedal is currently held down AT [tick] — the
  /// latest pedal event (pedalDown or pedalUp) at or before [tick] is
  /// pedalDown. Crescendo/diminuendo events are ignored entirely.
  bool isPedalDownAtTick(int tick) {
    DynamicChangeEvent? latest;
    for (final event in timeline.dynamicChangeEvents) {
      if (event.dynamic_change != DynamicChange.pedalDown &&
          event.dynamic_change != DynamicChange.pedalUp) {
        continue;
      }
      if (event.tick > tick) continue;
      if (latest == null || event.tick > latest.tick) {
        latest = event;
      }
    }
    return latest?.dynamic_change == DynamicChange.pedalDown;
  }

  /// Toggles the sustain pedal at [tick]: writes pedalUp if it's
  /// currently down there (per [isPedalDownAtTick]), or pedalDown
  /// otherwise. Reuses [updateDynamicChangeEvent], which already
  /// inserts a new event or updates one already sitting at this exact
  /// tick (e.g. flipping an existing pedal marker at this beat rather
  /// than duplicating it).
  void togglePedalAtTick(int tick) {
    final newState = isPedalDownAtTick(tick)
        ? DynamicChange.pedalUp
        : DynamicChange.pedalDown;
    updateDynamicChangeEvent(tick, newState);
  }

  // =====================================================
  // GRID / SNAP
  // =====================================================

  static const double defaultCellWidth = 10.0;
  static const double defaultZoomY = 1.0;

  double zoomX = defaultCellWidth;
  double zoomY = defaultZoomY;

  /// Whether the grid's cell HEIGHT is currently BIGGER than its
  /// default — used to color the Zoom In toolbar icon blue, per
  /// request.
  bool get isZoomedIn => zoomY > defaultZoomY;

  /// Same as [isZoomedIn] but for the ZOOMED-OUT direction — lights
  /// up the Zoom Out toolbar icon when the cell HEIGHT is currently
  /// SMALLER than its default.
  bool get isZoomedOut => zoomY < defaultZoomY;

  /// Whether the grid's cell width currently differs from its default
  /// (in either direction) — used to color the Cell Width toolbar
  /// icon blue, per request. Checks [zoomX] (cell WIDTH) only —
  /// deliberately independent of [isZoomedIn]/[isZoomedOut] (which
  /// check [zoomY], cell HEIGHT), so the Zoom In/Out buttons never
  /// light this icon up; only actually changing the width (via the
  /// Cell Width dialog) does. Cleared the moment
  /// [resetCellWidth]/[resetZoom] restores [zoomX] to
  /// [defaultCellWidth].
  bool get isCellWidthChanged => zoomX != defaultCellWidth;

  double get pixelsPerTick => zoomX;

  int get totalRows => composition.numberOfOctaves * 7;


  void changeCellWidth(double amount){
    zoomX = (zoomX + amount).clamp(2, 50,);
    notifyListeners();
  }


  void resetCellWidth() {
    zoomX = defaultCellWidth;
    notifyListeners();
  }

  void setMinimumCellWidth(){
    zoomX = 2;
    notifyListeners();
  }

  double getCellHeight(BuildContext context) {
    final availableHeight =
        MediaQuery.of(context).size.height
            - kToolbarHeight;
    return (availableHeight / totalRows) * zoomY;
  }

  int snapTick(int rawTick) {
    final step = gridResolution.ticks;
    if (step <= 1) {
      return rawTick;
    }
    return ((rawTick + step / 2) ~/ step) * step;
  }

  // =====================================================
  // ZOOM
  // =====================================================

  void setZoom(
      double x,
      double y,
      ){
    // Clamp range fixed to (2, 50) — matches changeCellWidth's own
    // range and, critically, actually INCLUDES defaultCellWidth (10).
    // The previous (20, 500) range excluded the default entirely, so
    // the very first Zoom In OR Zoom Out tap (10+1=11, or 10-1=9)
    // both got clamped UP to the same floor (20) regardless of
    // direction — silently turning "Zoom Out" into a zoom-in on the
    // very first tap and confusing which toolbar icon should light up.
    zoomX = x.clamp(2, 50);
    zoomY = y.clamp(0.5, 3);
    notifyListeners();
  }

  void resetZoom() {
    zoomX = defaultCellWidth;
    zoomY = defaultZoomY;
    notifyListeners();

  }


  // =====================================================
  // NOTE CREATION
  // =====================================================

  void addNoteAtGridPosition(
      int tick,
      int row, {
        int? durationTicks,
      }){
    final newDuration = durationTicks ?? currentDuration.ticks;
    // Prevent any horizontal overlap
    final overlaps = notes.any(
          (note) {
        if(note.row != row){
          return false;
        }
        final existingStart = note.startTick;
        final existingEnd = note.startTick + note.durationTicks;
        final newStart = tick;
        final newEnd = tick + newDuration;
        return newStart < existingEnd && newEnd > existingStart;
      },
    );
    if(overlaps){
      return;
    }
    var note = Note(
      id: generateNoteId(),
      startTick: tick,
      durationTicks:
      newDuration,
      row: row,
      hand: currentHand,
    );
    composition.notes.add(note);
    // If an accidental is already in effect on this row at this point
    // in the measure (from an earlier note), the new note is born
    // carrying that same accidental — not left null and merely
    // "computed as correct" via getEffectiveAccidental.
    //
    // Uses _accidentalInEffectAt (tick/row), NOT getEffectiveAccidental
    // (note) — the note was just added to composition.notes above, so
    // by this point getEffectiveAccidental would find the note itself
    // (own startTick, own still-null accidental) as the "nearest"
    // note on this row and incorrectly return null every time,
    // silently preventing inheritance entirely. _accidentalInEffectAt
    // is built specifically to search strictly-earlier notes only,
    // sidestepping this exact problem.
    final inherited = _accidentalInEffectAt(tick, row);
    if (inherited != null) {
      final index = composition.notes.indexWhere((n) => n.id == note.id);
      note = note.copyWith(accidental: inherited);
      composition.notes[index] = note;
    }
    playNoteSound(note);
    notifyListeners();
  }


  /// Imports a measure-by-measure transcription (see ImportMeasure /
  /// ImportEvent / ImportNoteSpec in note_import.dart) into real Note
  /// objects — the code counterpart to the manual, verified
  /// transcription process: each event's beat position is converted
  /// to a tick (whole-beat part via getBeatTick, any half-beat
  /// fraction added on top), each event's durationParts are summed
  /// the same way CombinedDurationDialog does, and each pitch's
  /// degree+octave is converted to a row the same way the rest of
  /// the app does (ImportNoteSpec.row). A rest (empty pitches) is
  /// simply skipped — no Note object needed for silence. A chord
  /// (pitches.length > 1) creates one Note per pitch, all sharing the
  /// same startTick/durationTicks.
  ///
  /// Unlike addNoteAtGridPosition, this does NOT read
  /// currentDuration/currentHand — every note's duration, hand,
  /// accidental, articulation, and legato come explicitly from its
  /// own ImportNoteSpec/ImportEvent, since a transcription generally
  /// mixes many different values across a single import rather than
  /// sharing the controller's current single "next note" settings.
  ///
  /// An overlapping note (same row, overlapping tick range as an
  /// existing note) is skipped rather than aborting the whole import
  /// — every skip is collected into the returned warning list instead,
  /// so the caller can report exactly what didn't make it in and why.

  /// Imports [batch] via [importTranscribedMeasures] — a thin
  /// pass-through that exists so callers can hand over an
  /// [ImportBatch] (label + measures) directly, e.g.
  /// sheet_music_transcription_dialog.dart's own paste-and-import
  /// flow. The label itself carries no special meaning here anymore
  /// — the old named-batch registry (import_batches.dart) and its
  /// one-time-import-per-label dedupe tracking have been removed, per
  /// request, along with the fixed-batch picker UI that used them.
  List<ImportWarning> importBatch(ImportBatch batch) {
    return importTranscribedMeasures(batch.measures);
  }

  /// The inverse of [importTranscribedMeasures] — reads the ACTUAL
  /// notes currently in the composition, within
  /// [fromMeasureIndex]..[toMeasureIndex] inclusive (both 0-based),
  /// and converts them back into the same ImportMeasure/ImportEvent/
  /// ImportNoteSpec structure a transcription is built from. Meant
  /// for round-tripping: after correcting an import's mistakes
  /// directly on the grid, export the corrected range back out to
  /// compare against the original transcription and see exactly
  /// where it went wrong.
  ///
  /// Notes sharing the exact same startTick are grouped into ONE
  /// ImportEvent with multiple pitches (a chord) — matching how a
  /// chord is represented on the way in. [beat] and [durationParts]
  /// are derived directly from each note's own startTick/
  /// durationTicks (via decomposeDurationTicks for the latter), so a
  /// note whose duration doesn't decompose exactly into standard
  /// values will just show whatever decomposeDurationTicks finds
  /// (same caveat as that function's own doc).
  List<ImportMeasure> exportMeasureRange(
      int fromMeasureIndex,
      int toMeasureIndex,
      ) {
    final result = <ImportMeasure>[];

    for (int m = fromMeasureIndex; m <= toMeasureIndex; m++) {
      if (m < 0 || m >= measures.length) continue;
      final measure = measures[m];

      // Every note starting within this measure's tick range,
      // grouped by (startTick, hand) — notes sharing BOTH are
      // treated as one chord event. Hand is part of the key, not
      // just tick: a right-hand and left-hand note commonly share
      // the exact same startTick without being a chord together at
      // all (e.g. Measure 4/5/7/8 of the reference score, where RH
      // and LH both start on beat 1) — grouping by tick alone would
      // silently merge them into a single mislabeled event.
      // A note with grace notes BEFORE it is written from where its
      // grace notes start, with its whole length ("gs(l5) l4 d4"); the
      // grace notes themselves are written with it, not as notes.
      int startOf(Note n) =>
          n.graceOriginalDurationTicks != null && !n.graceIsAfter
              ? n.startTick + n.durationTicks - n.graceOriginalDurationTicks!
              : n.startTick;
      int lengthOf(Note n) => n.graceOriginalDurationTicks ?? n.durationTicks;

      final notesInMeasure = notes.where(
            (n) => n.graceOfNoteId == null &&
            startOf(n) >= measure.startTick &&
            startOf(n) < measure.endTick,
      ).toList()
        ..sort((a, b) => startOf(a).compareTo(startOf(b)));

      final byStartTickAndHand = <String, List<Note>>{};
      for (final n in notesInMeasure) {
        final key = '${startOf(n)}_${n.hand}';
        byStartTickAndHand.putIfAbsent(key, () => []).add(n);
      }

      final events = <ImportEvent>[];
      final sortedGroups = byStartTickAndHand.values.toList()
        ..sort((a, b) => startOf(a.first).compareTo(startOf(b.first)));
      for (final chordNotes in sortedGroups) {
        chordNotes.sort((a, b) => a.row.compareTo(b.row));
        final tick = startOf(chordNotes.first);
        var beat = 1 +
            (tick - measure.startTick) / measure.timeSignature.ticksPerBeat;
        // A chord's notes could in principle have different
        // durations; the first note's duration is used for the
        // whole event, matching how a chord is always specified on
        // the way in (one shared durationParts list per event).
        var durationParts = decomposeDurationTicks(
          lengthOf(chordNotes.first),
        );
        var tuplet = 1;
        // A note in a split beat (triplet…): its exact position, and its
        // written length with ":3" (see the transcription parser).
        final split = dividedBeatAt(tick);
        if (split != null) {
          final first = chordNotes.first;
          final exactStart = displayTick(tick);
          final exactLength =
              displayTick(tick + lengthOf(first)) - exactStart;
          beat = 1 +
              (exactStart - measure.startTick) /
                  measure.timeSignature.ticksPerBeat;
          // (a length that is a whole number of 1/64s is written as is)
          final ordinary = (exactLength - exactLength.round()).abs() < 1e-6;
          for (final k in ordinary ? const <int>{} : {split.columns, 3, 6, 5, 7, 2}) {
            if (k < 2) continue;
            final written = exactLength / tupletFactor(k);
            final rounded = written.round();
            if ((written - rounded).abs() < 1e-6 && rounded > 0) {
              final parts = decomposeDurationTicks(rounded);
              if (parts.length <= 2) {
                durationParts = parts;
                tuplet = k;
                break;
              }
            }
          }
        }
        // Grace notes before a note of the chord.
        GraceNoteType? graceType;
        var graces = const <ImportNoteSpec>[];
        var graceAfter = false;
        for (final n in chordNotes.reversed) {
          if (n.graceOriginalDurationTicks == null) continue;
          final gs = notes.where((g) => g.graceOfNoteId == n.id).toList()
            ..sort((a, b) => a.startTick.compareTo(b.startTick));
          if (gs.isEmpty) continue;
          graceType = gs.first.graceNoteType;
          graceAfter = n.graceIsAfter;
          graces = [
            for (final g in gs)
              ImportNoteSpec(
                degree: getDegree(g),
                octave: g.row ~/ 7,
                accidental: g.accidental,
                hand: g.hand,
              ),
          ];
          break;
        }
        events.add(
          ImportEvent(
            beat: beat,
            tuplet: tuplet,
            durationParts: durationParts,
            // The ornament and grace notes (of the chord's top note).
            ornament: chordNotes
                .lastWhere((n) => n.ornament != null,
                orElse: () => chordNotes.last)
                .ornament,
            graceType: graceType,
            graces: graces,
            graceAfter: graceAfter,
            pitches: [
              for (final n in chordNotes)
                ImportNoteSpec(
                  degree: getDegree(n),
                  octave: n.row ~/ 7,
                  accidental: n.accidental,
                  hand: n.hand,
                  articulation: n.articulation,
                  legato: n.legato,
                ),
            ],
          ),
        );
      }

      result.add(
        ImportMeasure(measureIndex: m, events: events),
      );
    }

    return result;
  }

  /// Exports dynamic (p/f/mf/etc) and dynamic-change (crescendo/
  /// diminuendo hairpin) markers within [fromMeasureIndex]..
  /// [toMeasureIndex] inclusive, as readable text — the counterpart
  /// to [exportMeasureRange], which only covers Note objects.
  /// Dynamics and hairpins are stored entirely separately from Note
  /// (as DynamicEvent/DynamicChangeEvent on the timeline — see
  /// grid_widget.dart's GridPainter, which draws them independently
  /// of any note), so they need their own export path rather than
  /// showing up as part of a Note's own data. Pedal markers (which
  /// share DynamicChangeEvent's storage — see the doc on
  /// updateDynamicChangeEvent) are deliberately excluded here,
  /// matching how they're excluded from dynamicChangeDialog's own
  /// picker.
  String exportDynamicsAndHairpinsText(
      int fromMeasureIndex,
      int toMeasureIndex,
      ) {
    if (fromMeasureIndex < 0 ||
        toMeasureIndex < fromMeasureIndex ||
        toMeasureIndex >= measures.length) {
      return '';
    }

    final startTick = measures[fromMeasureIndex].startTick;
    final endTick = measures[toMeasureIndex].endTick;

    String describeTick(int tick) {
      final measure = getMeasureAtTick(tick);
      final measureIndex = measures.indexOf(measure);
      final beat = 1 +
          (tick - measure.startTick) / measure.timeSignature.ticksPerBeat;
      return 'Measure ${displayMeasureNumber(measureIndex)}, beat $beat';
    }

    // (tick, text) pairs, sorted by tick before formatting — sorting
    // the finished text lines directly would sort alphabetically
    // ("Measure 10" before "Measure 2"), not chronologically.
    final entries = <(int, String)>[];

    for (final event in timeline.dynamicEvents) {
      if (event.tick < startTick || event.tick >= endTick) continue;
      entries.add((
      event.tick,
      '${describeTick(event.tick)}: Dynamic '
          '${event.musical_dynamic.abbreviation}',
      ));
    }

    for (final event in timeline.dynamicChangeEvents) {
      if (event.tick < startTick || event.tick >= endTick) continue;
      if (event.dynamic_change == DynamicChange.pedalDown ||
          event.dynamic_change == DynamicChange.pedalUp) {
        continue;
      }
      entries.add((
      event.tick,
      '${describeTick(event.tick)}: ${event.dynamic_change.name}',
      ));
    }

    entries.sort((a, b) => a.$1.compareTo(b.$1));

    return entries.isEmpty
        ? 'No dynamics or dynamic changes in this range.'
        : entries.map((e) => e.$2).join('\n');
  }

  List<ImportWarning> importTranscribedMeasures(
      List<ImportMeasure> importMeasures,
      ) {
    final warnings = <ImportWarning>[];

    for (final importMeasure in importMeasures) {
      if (importMeasure.measureIndex < 0 ||
          importMeasure.measureIndex >= measures.length) {
        warnings.add(
          ImportWarning(
            measureIndex: importMeasure.measureIndex,
            beat: 0,
            message: 'Measure ${importMeasure.measureIndex + 1} '
                "doesn't exist in this composition (only "
                '${measures.length} measures).',
          ),
        );
        continue;
      }

      final measure = measures[importMeasure.measureIndex];
      final ticksPerBeat = measure.timeSignature.ticksPerBeat;
      final mi = importMeasure.measureIndex;
      final beatCount = measure.timeSignature.beats;

      // TUPLETS (triplets…): a beat holding a note that starts or ends
      // between its 1/64 steps is split into equal columns — the
      // fewest (2–13) that every note start and end in it falls on.
      final fractionsByBeat = <int, List<double>>{};
      final offGridBeats = <int>{};
      void addPosition(double pos) {
        final b = (pos + 1e-9).floor();
        if (b < 0 || b >= beatCount) return;
        final f = pos - b;
        if (f.abs() < 1e-9) return;
        fractionsByBeat.putIfAbsent(b, () => []).add(f);
        final t = f * ticksPerBeat;
        if ((t - t.round()).abs() > 1e-6) offGridBeats.add(b);
      }
      for (final event in importMeasure.events) {
        final start = event.beat - 1;
        addPosition(start);
        addPosition(start + event.exactDurationTicks / ticksPerBeat);
      }
      bool fits(int n, List<double> fs) =>
          fs.every((f) => ((f * n) - (f * n).round()).abs() < 1e-6);
      for (final b in offGridBeats) {
        final fs = fractionsByBeat[b]!;
        final current = measure.beatDivisions[b];
        if (current != null && fits(current, fs)) continue;
        for (int n = 2; n <= 13; n++) {
          if (fits(n, fs)) {
            _setBeatDivision(mi, b, n);
            break;
          }
        }
      }

      // The tick of a position (in beats from the measure's start):
      // in a split beat, the start of its column.
      int tickAt(double pos) {
        var b = (pos + 1e-9).floor();
        var f = pos - b;
        if (b >= beatCount) {
          b = beatCount - 1;
          f = 1;
        }
        if (b < 0) {
          b = 0;
          f = 0;
        }
        final start = getBeatTick(mi, b);
        final n = measure.beatDivisions[b];
        if (n != null && n > 1) {
          final width = ticksPerBeat * (getFermataMultiplier(mi, b) ?? 1);
          return start + ((f * n).round() * width / n).round();
        }
        return start + (f * ticksPerBeat).round();
      }

      for (final event in importMeasure.events) {
        if (event.pitches.isEmpty) continue; // rest — nothing to create

        final startPos = event.beat - 1;
        final endPos = startPos + event.exactDurationTicks / ticksPerBeat;
        final tick = tickAt(startPos);
        final int durationTicks = event.durationTicks <= 0
            ? 0
            : math.max(
          1,
          endPos <= beatCount + 1e-9
              ? tickAt(endPos) - tick
              : event.exactDurationTicks.round(),
        );

        if (durationTicks <= 0) {
          warnings.add(
            ImportWarning(
              measureIndex: importMeasure.measureIndex,
              beat: event.beat,
              message: 'No duration specified — skipped.',
            ),
          );
          continue;
        }

        final createdNotes = <Note>[];
        for (final pitch in event.pitches) {
          final row = pitch.row;
          if (row < 0 || row >= totalRows) {
            warnings.add(
              ImportWarning(
                measureIndex: importMeasure.measureIndex,
                beat: event.beat,
                message: 'Degree ${pitch.degree}, octave ${pitch.octave} '
                    'is off the grid — skipped.',
              ),
            );
            continue;
          }

          final overlaps = notes.any((n) {
            if (n.row != row) return false;
            final existingStart = n.startTick;
            final existingEnd = n.startTick + n.durationTicks;
            final newStart = tick;
            final newEnd = tick + durationTicks;
            return newStart < existingEnd && newEnd > existingStart;
          });
          if (overlaps) {
            warnings.add(
              ImportWarning(
                measureIndex: importMeasure.measureIndex,
                beat: event.beat,
                message: 'Degree ${pitch.degree}, octave ${pitch.octave} '
                    'overlaps an existing note — skipped.',
              ),
            );
            continue;
          }

          final created = Note(
            id: generateNoteId(),
            startTick: tick,
            durationTicks: durationTicks,
            row: row,
            hand: pitch.hand,
            accidental: pitch.accidental,
            articulation: pitch.articulation,
            legato: pitch.legato,
          );
          composition.notes.add(created);
          createdNotes.add(created);
        }
        _importOrnamentAndGraces(
            event, createdNotes, importMeasure.measureIndex, warnings);
      }
    }

    notifyListeners();
    return warnings;
  }


  /// The ornament ("trill"…) and grace notes ("gs(l5)") of an imported
  /// [event], put on the top note of [created] (the chord's highest).
  void _importOrnamentAndGraces(
      ImportEvent event,
      List<Note> created,
      int measureIndex,
      List<ImportWarning> warnings,
      ) {
    if (created.isEmpty) return;
    final top = created.reduce((a, b) => a.row >= b.row ? a : b);
    var idx = notes.indexWhere((n) => n.id == top.id);
    if (idx == -1) return;
    if (event.ornament != null) {
      notes[idx] = notes[idx].copyWith(ornament: event.ornament);
    }
    final type = event.graceType;
    if (type == null || event.graces.isEmpty) return;
    final anchor = notes[idx];
    final valid = [
      for (final g in event.graces)
        if (g.row >= 0 && g.row < totalRows) g,
    ];
    final max = maxGraceNotesForType(anchor, type);
    if (valid.length > max) {
      warnings.add(ImportWarning(
        measureIndex: measureIndex,
        beat: event.beat,
        message: max == 0
            ? 'The note is too short for ${type.label} grace notes — skipped.'
            : 'At most $max ${type.label} grace notes on this note — '
            'the others were skipped.',
      ));
    }
    final use = valid.take(max).toList();
    if (use.isEmpty) return;
    notes[idx] = anchor.copyWith(
      graceOriginalDurationTicks: anchor.durationTicks,
      // "l4 d4 gs(l5)": after the note; "gs(l5) l4 d4": before it.
      graceIsAfter: event.graceAfter,
    );
    for (final g in use) {
      notes.add(Note(
        id: generateNoteId(),
        startTick: anchor.startTick,
        durationTicks: 1,
        row: g.row,
        hand: anchor.hand,
        accidental: g.accidental,
        graceOfNoteId: anchor.id,
        graceNoteType: type,
      ));
    }
    _redistributeGraceNotes(anchor.id);
  }

  void removeNote(Note note){
    composition.notes.removeWhere(
          (n)=>n.id == note.id,
    );
    // If the removed note itself HAD a glissando (see Note.glissando,
    // the anchor-only marker), its generated run notes no longer have
    // a main note to run from — remove them too rather than leaving
    // them orphaned.
    if (note.glissando != null) {
      composition.notes.removeWhere(
            (n) => n.glissandoSourceId == note.id,
      );
    }
    // If the removed note itself HAD grace notes (was an anchor —
    // see Note.graceOriginalDurationTicks, the anchor-only marker),
    // they no longer have a main note to precede/follow — a grace
    // note without its main note doesn't make musical sense, so
    // remove them too rather than leaving them orphaned.
    if (note.graceOriginalDurationTicks != null) {
      composition.notes.removeWhere(
            (n) => n.graceOfNoteId == note.id,
      );
    }
    // If the removed note WAS a grace note, its remaining siblings
    // need to re-expand to fill the time that's now freed up (the
    // group's fixed total span is divided across however many
    // currently exist — see _redistributeGraceNotes).
    if (note.graceOfNoteId != null) {
      _redistributeGraceNotes(note.graceOfNoteId!);
    }
    notifyListeners();
  }

  /// Returns a short message explaining why [note] can't be dragged
  /// to a new position on the grid right now, or null if it's fine to
  /// move. Checked from NoteBlockWidget's drag handling before
  /// calling [updateNote].
  ///
  /// A note carrying a glissando or grace notes can't be moved
  /// directly — a glissando's generated run and a note's grace notes
  /// are positioned relative to THIS note's own current tick/row, so
  /// moving it out from under them would break the invariants their
  /// own generation logic depends on. Likewise, a note that IS itself
  /// a glissando run note or a grace note can't be moved
  /// independently — its own position is entirely managed by the
  /// anchor note it belongs to, and would just get silently
  /// overwritten back to where the anchor puts it the next time
  /// anything about that anchor changes. An ornament, unlike those
  /// two, is NOT similarly protected — its ghost sequence is
  /// recomputed fresh from the note's own row every time it's
  /// displayed (see displayNotes), so moving an ornamented note just
  /// works correctly without any extra handling.
  String? moveBlockedReason(Note note) {
    if (note.glissando != null) {
      return 'This note has a glissando. Delete it first to move this note.';
    }
    if (note.graceOriginalDurationTicks != null) {
      return 'This note has grace notes. Delete them first to move this note.';
    }
    if (note.glissandoSourceId != null) {
      return 'This note belongs to a glissando and moves with its main note.';
    }
    if (note.graceOfNoteId != null) {
      return 'This is a grace note and moves with its main note.';
    }
    return null;
  }

  int getDegree(Note note) {
    return note.row % 7 + 1;
  }

  String getDegreeLabel(Note note) {
    switch (getDegree(note)) {
      case 1:
        return 'C';
      case 2:
        return 'D';
      case 3:
        return 'E';
      case 4:
        return 'F';
      case 5:
        return 'G';
      case 6:
        return 'A';
      case 7:
        return 'B';
      default:
        return '';
    }
  }


  int getOctave(Note note) {
    return note.row ~/ 7;
  }


  String getOctaveName(int octave) {
    switch (octave) {
      case 0:
        return 'Sub-contra';
      case 1:
        return 'Contra';
      case 2:
        return 'Great';
      case 3:
        return 'Small';
      case 4:
        return 'One-line';
      case 5:
        return 'Two-line';
      case 6:
        return 'Three-line';
      case 7:
        return 'Four-line';
      default:
        return '';
    }
  }
  // =====================================================
  // NOTE MOVEMENT
  // =====================================================


  Note? getNoteAtPosition(
      int tick,
      int row,
      ){
    for(final note in notes){
      final end = note.startTick + note.durationTicks;
      if(note.row == row && tick >= note.startTick &&
          tick < end){
        return note;
      }
    }
    return null;
  }


  void handleGridTap(
      int rawTick,
      int row,
      ) {
    if(rawTick < 0 ||
        rawTick >= maxTicks) {
      return;
    }
    if(row < 0 ||
        row >= totalRows) {
      return;
    }
    // In a split beat (triplet…) the note starts at the column and
    // lasts one column.
    final column = columnAt(rawTick);
    if (column != null) {
      addNoteAtGridPosition(column.start, row, durationTicks: column.ticks);
      return;
    }
    addNoteAtGridPosition(
      snapTick(rawTick),
      row,
    );
  }



  void updateNote(
      Note oldNote,
      int newTick,
      int newRow,
      ) {
    final index = composition.notes.indexWhere(
          (n) => n.id == oldNote.id,
    );
    if(index == -1) {
      return;
    }
    // keep note inside timeline
    newTick =
        newTick.clamp(
          0,
          maxTicks - oldNote.durationTicks,
        );
    newRow =
        newRow.clamp(
          0,
          totalRows - 1,
        ).toInt();
    final overlaps = notes.any(
          (note) {
        if(note.id == oldNote.id) {
          return false;
        }
        if(note.row != newRow) {
          return false;
        }
        final existingStart =
            note.startTick;
        final existingEnd =
            note.startTick +
                note.durationTicks;
        final newStart =
            newTick;
        final newEnd =
            newTick +
                oldNote.durationTicks;
        return newStart < existingEnd &&
            newEnd > existingStart;
      },
    );
    if(overlaps) {
      return;
    }
    final updated = oldNote.copyWith(
      startTick:
      newTick,
      row:
      newRow,
    );
    composition.notes[index] = updated;
    notifyListeners();
  }



  void _replaceNote(Note updated) {
    final index = notes.indexWhere(
          (n) => n.id == updated.id,
    );
    if (index == -1) return;
    notes[index] = updated;
    notifyListeners();
  }


  /// Sets [note]'s hand — and, if [note] is an anchor with its own
  /// glissando run and/or grace notes (see [Note.glissandoSourceId] /
  /// [Note.graceOfNoteId]), updates THEIR hand to match too, since a
  /// glissando/grace note is meant to always play with the same hand
  /// as the main note it belongs to, not an independently-set one.
  void setNoteHand(
      Note note,
      Hand hand,
      ) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    notes[index] = notes[index].copyWith(hand: hand);
    for (int i = 0; i < notes.length; i++) {
      if (notes[i].glissandoSourceId == note.id ||
          notes[i].graceOfNoteId == note.id) {
        notes[i] = notes[i].copyWith(hand: hand);
      }
    }
    notifyListeners();
  }

  void setNoteFinger(
      Note note,
      Finger? finger,
      ) {
    _replaceNote(
      note.copyWith(finger: finger),
    );
  }

  void setNoteAccidental(
      Note note,
      Accidental? accidental,
      ) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    final updated = note.copyWith(accidental: accidental);
    notes[index] = updated;
    // Write the accidental onto every later note on this same row for
    // the rest of the measure too — not just this one — so the data
    // itself (not just playback/display lookups) reflects that it
    // holds through the measure. A later explicit call to this method
    // on one of those notes (including clearing back to natural) will
    // itself propagate forward from that point, which is how
    // "cancelling" an accidental partway through the measure works.
    _propagateAccidentalForward(updated, accidental);
    notifyListeners();
  }

  /// Overwrites `.accidental` on every later note sharing [editedNote]'s
  /// row within the same measure, so the accidental is actually stored
  /// on each note rather than only derived at lookup time. Does not
  /// call notifyListeners() itself — callers do that once after.
  void _propagateAccidentalForward(Note editedNote, Accidental? accidental) {
    final measure = getMeasureAtTick(editedNote.startTick);
    for (int i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (n.id == editedNote.id) continue;
      if (n.row != editedNote.row) continue;
      if (n.startTick <= editedNote.startTick) continue;
      if (n.startTick >= measure.endTick) continue;
      notes[i] = n.copyWith(accidental: accidental);
    }
  }

  void setNoteDuration(
      Note note,
      NoteDuration duration,
      ) {
    _replaceNote(
      note.copyWith(
        durationTicks: duration.ticks,
      ),
    );
  }

  /// Sets [note]'s duration directly to [ticks], rather than to one
  /// of the standard [NoteDuration] enum values — for a note whose
  /// duration is really a COMBINATION of two or more standard
  /// durations summed together (e.g. an eighth note tied across a
  /// barline into a half note, written as two separate tied symbols
  /// in standard notation but representing one continuous sustained
  /// pitch). This app's grid is duration-based rather than glyph-
  /// based, so a tie doesn't need two separate Note objects — one
  /// Note with the combined duration is both simpler and more
  /// accurate to what's actually being played. See
  /// combined_duration_dialog.dart, which sums a person's picks and
  /// calls this. [ticks] is clamped to at least 1 to avoid an invalid
  /// zero/negative-duration note.
  void setNoteDurationTicks(Note note, int ticks) {
    _replaceNote(
      note.copyWith(
        durationTicks: ticks.clamp(1, 1 << 30),
      ),
    );
  }


  void setNoteArticulation(
      Note note,
      Articulation? articulation,
      ) {
    _replaceNote(
      note.copyWith(articulation: articulation),
    );
  }


  // =====================================================
  // LEGATO MODE
  // =====================================================

  /// When on, tapping a note (in NoteBlockWidget) toggles that note's
  /// [Note.legato] flag instead of opening the note-edit dialog — a
  /// separate interaction mode, the same way Scroll Lock and paste
  /// mode change what a tap does. Independent of
  /// [Note.articulation]: legato used to be one of the mutually
  /// exclusive Articulation values, but is now its own flag, so a
  /// note can be legato AND carry an articulation (e.g. sforzando) at
  /// the same time.
  bool legatoMode = false;

  void toggleLegatoMode() {
    legatoMode = !legatoMode;
    notifyListeners();
  }

  /// Flips [note]'s legato flag. Called from NoteBlockWidget's tap
  /// handler while [legatoMode] is on.
  void toggleNoteLegato(Note note) {
    _replaceNote(
      note.copyWith(legato: !note.legato),
    );
  }


  /// When on, every note with a non-null [Note.accidental] is drawn
  /// green (in NoteBlockWidget) instead of its usual hand-based color
  /// — purely a display toggle, the same way
  /// [showCompensatedNotation] is: no note data changes, so switching
  /// this back off instantly restores every note's normal color with
  /// no risk of data loss. Ghost notes (an ornament's expanded
  /// sequence — see displayNotes) are included too, since they carry
  /// the same underlying note's accidental.
  bool highlightAccidentalNotes = false;

  void toggleHighlightAccidentalNotes() {
    highlightAccidentalNotes = !highlightAccidentalNotes;
    notifyListeners();
  }


  // =====================================================
  // GLISSANDO
  // =====================================================

  // The note a glissando is currently being set up for, and which
  // direction was chosen — non-null while waiting for the person to
  // tap the grid to choose the end row (see [startGlissandoPick] /
  // [finishGlissandoPick]). Mirrors the existing copy/paste pattern
  // ([copiedNote]/[pasteMode]): a pending interaction that the next
  // relevant grid tap completes.
  // No direction is chosen any more: the end row tapped on the grid
  // shows it (above the note = up, below = down).
  Note? _pendingGlissandoNote;

  /// Whether the grid's next tap should be interpreted as choosing a
  /// glissando's end row (see [finishGlissandoPick]) rather than its
  /// normal behavior (creating a note, opening a label dialog, etc.).
  bool get isPickingGlissandoEndRow => _pendingGlissandoNote != null;

  /// Begins the "pick the end row" interaction for a glissando
  /// starting at [note] — call this from NoteDialog's Glissando field,
  /// then
  /// close any dialogs so the person can tap the target row on the
  /// grid. GridWidget checks [isPickingGlissandoEndRow] and routes
  /// its next tap to [finishGlissandoPick] instead of normal tap
  /// handling.
  void startGlissandoPick(Note note) {
    _pendingGlissandoNote = note;
    notifyListeners();
  }

  /// Cancels a pending [startGlissandoPick] without generating
  /// anything — e.g. if the person wants to back out before tapping
  /// an end row.
  void cancelGlissandoPick() {
    _pendingGlissandoNote = null;
    notifyListeners();
  }

  /// Completes a pending [startGlissandoPick]: generates the run of
  /// 1/64-duration notes from [_pendingGlissandoNote]'s own row to
  /// [endRow] and stamps the direction onto the anchor note. Called
  /// by GridWidget with the row that was tapped while
  /// [isPickingGlissandoEndRow] is true.
  ///
  /// The run starts at the row NEXT TO the anchor (not a duplicate
  /// note at the anchor's own row/pitch, since the anchor itself
  /// already sounds that pitch) and continues, one note per row, to
  /// [endRow] INCLUSIVE. An [endRow] above the anchor's row makes the
  /// glissando go up, below it down; the anchor's own row is rejected
  /// without generating anything or clearing the pending pick, so the
  /// person can just tap again. Returns a short message to show (e.g.
  /// via a SnackBar) on rejection, or null on success.
  ///
  /// Each generated note's pitch always reads as the plain natural
  /// degree number for its row (1-7, cycling — see
  /// [getDisplayPitchLabel]) and sounds at the plain "white key"
  /// pitch for that row (see [getWhiteKeyFrequencyHz]), deliberately
  /// ignoring the composition's current scale — the same way a piano
  /// glissando runs straight across the white keys regardless of key
  /// signature. Generated notes are marked via
  /// [Note.glissandoSourceId] pointing back at the anchor's id, so a
  /// later [clearNoteGlissando] (or a re-pick, which calls it
  /// internally first) can find and remove the whole run together.
  ///
  /// Overlaps with whatever notes already occupy that space aren't
  /// checked for — the generated run is simply added on top.
  String? finishGlissandoPick(int endRow) {
    final pendingNote = _pendingGlissandoNote;
    if (pendingNote == null) return null;

    if (endRow < 0 || endRow >= totalRows) {
      return 'That row is outside the grid';
    }
    if (endRow == pendingNote.row) {
      return 'Tap a row above or below the note';
    }

    // The direction comes from the end row: above the note = up,
    // below the note = down.
    final isUp = endRow > pendingNote.row;
    final direction = isUp
        ? GlissandoDirection.up
        : GlissandoDirection.values
        .firstWhere((d) => d != GlissandoDirection.up);

    final anchorIndex = notes.indexWhere((n) => n.id == pendingNote.id);
    if (anchorIndex == -1) {
      _pendingGlissandoNote = null;
      notifyListeners();
      return 'That note no longer exists';
    }

    // Work from the current, live copy of the anchor (it may have
    // moved/changed since startGlissandoPick was called), and remove
    // any previous run belonging to it first — covers both "clear and
    // re-pick with a new direction/end row" and simple regeneration.
    final anchor = notes[anchorIndex];
    notes.removeWhere((n) => n.glissandoSourceId == anchor.id);
    final refreshedIndex = notes.indexWhere((n) => n.id == anchor.id);
    notes[refreshedIndex] = anchor.copyWith(glissando: direction);

    final stepTicks = NoteDuration.sixtyFourth.ticks;
    int runningTick = notes[refreshedIndex].endTick;
    final rows = isUp
        ? [for (int r = anchor.row + 1; r <= endRow; r++) r]
        : [for (int r = anchor.row - 1; r >= endRow; r--) r];

    for (final row in rows) {
      notes.add(Note(
        id: generateNoteId(),
        startTick: runningTick,
        durationTicks: stepTicks,
        row: row,
        hand: anchor.hand,
        glissandoSourceId: anchor.id,
      ));
      runningTick += stepTicks;
    }

    _pendingGlissandoNote = null;
    notifyListeners();
    return null;
  }

  /// Removes [note]'s glissando entirely: clears its
  /// [Note.glissando] field and deletes every generated run note that
  /// points back at it (see [Note.glissandoSourceId]). Called from
  /// wherever the glissando field's dialog offers a "Delete"/clear
  /// action.
  void clearNoteGlissando(Note note) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    notes[index] = notes[index].copyWith(glissando: null);
    notes.removeWhere((n) => n.glissandoSourceId == note.id);
    notifyListeners();
  }

  /// The frequency (Hz) of the plain, unaltered "white key" pitch at
  /// [row] — the scale's own alteration for that degree and any
  /// accidental are both deliberately ignored, unlike
  /// [getNoteFrequencyHz]. Used only for glissando run notes (see
  /// [Note.glissandoSourceId]), which are meant to sound like a real
  /// piano glissando sweeping straight across the white keys
  /// regardless of the composition's current scale.
  double getWhiteKeyFrequencyHz(int row) {
    // _naturalAbsoluteSemitone is already absolute from octave 0
    // degree 1 ("do"); _referenceFrequencyC4 anchors octave 4 degree
    // 1 — i.e. absolute semitone 4*12 — so subtracting that lines the
    // two up the same way getNoteFrequencyHz's octaveShift does.
    final totalSemitonesFromC4 = _naturalAbsoluteSemitone(row) - 4 * 12;
    return _referenceFrequencyC4 * math.pow(2, totalSemitonesFromC4 / 12);
  }


  // =====================================================
  // GRACE NOTES
  // =====================================================

  /// An outer sanity ceiling regardless of duration — the REAL limit
  /// is duration-based (see [maxGraceNotesForType]); this just guards
  /// against a pathological case (a very long note combined with a
  /// very short grace type) producing an unreasonably large count.
  static const int maxGraceNotesPerNote = 32;

  // The note "Add Grace Note" mode is currently adding grace notes
  // for, and which type each new tap creates — both non-null while
  // the mode is on (see [isAddingGraceNotes]). Mirrors the glissando
  // pending-pick pattern, except this stays active across MANY grid
  // taps (each one adds another grace note) rather than being
  // consumed by a single tap, so it needs an explicit stop rather
  // than auto-clearing.
  Note? _graceNoteAnchor;
  GraceNoteType? _graceNoteTypeBeingAdded;

  /// Whether the grid's next tap(s) should add grace notes to
  /// whichever note [startAddingGraceNotes] was last called with,
  /// rather than their normal behavior (creating an ordinary note,
  /// opening a label dialog, etc.). Checked by GridWidget.
  bool get isAddingGraceNotes => _graceNoteAnchor != null;

  /// How many grace notes of [type] can fit in [note]'s own ORIGINAL
  /// duration (see [Note.graceOriginalDurationTicks], falling back to
  /// the note's current duration if grace notes haven't been started
  /// yet on it) without their fixed total exceeding it — i.e. the
  /// anchor's own remaining duration must never end up less than the
  /// sum of all its grace notes' durations. A longer note allows
  /// more; a shorter note allows fewer (zero, if the note is shorter
  /// than even a single grace note of this type). Also respects the
  /// type's own [GraceNoteType.maxCountOverride] (Appoggiatura: only
  /// 1 ever, regardless of what the duration math alone would allow)
  /// — whichever of the two limits is stricter wins. Direction
  /// ([Note.graceIsAfter]) doesn't affect this at all — the
  /// available duration to carve from is the same either way, only
  /// WHICH end it's carved from differs (see
  /// [_redistributeGraceNotes]).
  int maxGraceNotesForType(Note note, GraceNoteType type) {
    final originalDuration =
        note.graceOriginalDurationTicks ?? note.durationTicks;
    final perNote = type.durationTicksFor(originalDuration);
    if (perNote <= 0) return 0;
    // The main note always keeps at least one tick of its own (on a
    // very short note, fewer grace notes fit than the type allows).
    final durationBasedMax = ((originalDuration - 1) / perNote).floor();
    final cap = type.maxCountOverride ?? maxGraceNotesPerNote;
    return durationBasedMax.clamp(0, cap);
  }

  /// Begins "Add Grace Note" mode for [note], with every subsequent
  /// grid tap adding one grace note of [type] (see
  /// [addGraceNoteAtRow]) — call this from wherever the type is
  /// chosen (NoteDialog's Grace Notes field), then close any dialogs
  /// so the person can start tapping the grid. The mode stays on
  /// until [stopAddingGraceNotes] is called (the app-bar toggle).
  ///
  /// [isAfter] chooses which side of [note] the grace notes sit on —
  /// false (the default) places them BEFORE it, carved from the
  /// START of its original span (its own END tick stays fixed); true
  /// places them AFTER it instead, carved from the END of its
  /// original span (its own START tick stays fixed). See
  /// [Note.graceIsAfter] and [_redistributeGraceNotes] for exactly
  /// how each direction is laid out.
  ///
  /// A note can only have ONE type of grace note, on ONE side, active
  /// at a time — if [note] already has grace notes of a DIFFERENT
  /// type than [type], OR on the OTHER side than [isAfter], they're
  /// deleted first (which also reverts [note] back toward its
  /// original duration, via [_redistributeGraceNotes]'s zero-
  /// remaining case) before the new group takes over. Calling this
  /// again with the SAME type AND SAME side [note] already has just
  /// continues adding more of it — nothing is deleted in that case.
  ///
  /// The first time a grace note is EVER added to [note] (or
  /// immediately after switching type/side, since that clears it),
  /// its CURRENT durationTicks is captured into
  /// [Note.graceOriginalDurationTicks] and never touched again
  /// afterward — this is the fixed reference [maxGraceNotesForType]
  /// and [_redistributeGraceNotes] both use — and [isAfter] is
  /// stamped onto [Note.graceIsAfter] at the same time.
  void startAddingGraceNotes(
      Note note,
      GraceNoteType type, {
        bool isAfter = false,
      }) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;

    final existingGraceNotes =
    notes.where((n) => n.graceOfNoteId == note.id).toList();
    final existingType =
    existingGraceNotes.isNotEmpty ? existingGraceNotes.first.graceNoteType : null;
    final existingIsAfter = notes[index].graceIsAfter;

    if (existingGraceNotes.isNotEmpty &&
        (existingType != type || existingIsAfter != isAfter)) {
      // Only one type of grace note, on one side, is allowed per note
      // at a time — switching EITHER one deletes whatever was there
      // before. This also reverts the note's own start/duration back
      // toward its original span, since there's nothing left of the
      // old group to make room for.
      notes.removeWhere((n) => n.graceOfNoteId == note.id);
      _redistributeGraceNotes(note.id);
    }

    final refreshedIndex = notes.indexWhere((n) => n.id == note.id);
    final refreshed = notes[refreshedIndex];
    if (refreshed.graceOriginalDurationTicks == null) {
      notes[refreshedIndex] = refreshed.copyWith(
        graceOriginalDurationTicks: refreshed.durationTicks,
        graceIsAfter: isAfter,
      );
    }
    _graceNoteAnchor = notes[refreshedIndex];
    _graceNoteTypeBeingAdded = type;
    notifyListeners();
  }

  /// Turns "Add Grace Note" mode off without touching any notes —
  /// whatever grace notes already exist stay exactly as they are.
  /// This is the only way to leave the mode (see the app-bar toggle);
  /// it does NOT get triggered automatically by any single tap, since
  /// the mode is meant to stay on across many taps.
  void stopAddingGraceNotes() {
    _graceNoteAnchor = null;
    _graceNoteTypeBeingAdded = null;
    notifyListeners();
  }

  /// Adds one new grace note, at [row], of whichever type
  /// [startAddingGraceNotes] was last called with, for whichever note
  /// "Add Grace Note" mode is currently active for — its hand is
  /// copied from the anchor; its own start/duration are placeholders,
  /// immediately overwritten by [_redistributeGraceNotes] (called at
  /// the end of this method) along with every sibling's and the
  /// anchor's own. Returns a short message to show (e.g. via a
  /// SnackBar) if nothing was added — already at
  /// [maxGraceNotesForType] for this note's duration and the current
  /// type (including the note being too short for even one), the
  /// anchor no longer exists, or [row] is off-grid — or null on
  /// success. A no-op (returns null) if the mode isn't currently on
  /// at all.
  String? addGraceNoteAtRow(int row) {
    final anchorRef = _graceNoteAnchor;
    final type = _graceNoteTypeBeingAdded;
    if (anchorRef == null || type == null) return null;

    final anchorIndex = notes.indexWhere((n) => n.id == anchorRef.id);
    if (anchorIndex == -1) {
      _graceNoteAnchor = null;
      _graceNoteTypeBeingAdded = null;
      notifyListeners();
      return 'That note no longer exists';
    }
    final anchor = notes[anchorIndex];

    if (row < 0 || row >= totalRows) {
      return 'That row is outside the grid';
    }

    final existingCount =
        notes.where((n) => n.graceOfNoteId == anchor.id).length;
    final maxForType = maxGraceNotesForType(anchor, type);
    if (existingCount >= maxForType) {
      return maxForType == 0
          ? 'This note is too short for ${type.label} grace notes'
          : 'Maximum of $maxForType ${type.label} grace notes for this note';
    }

    // startTick/durationTicks here are placeholders only —
    // _redistributeGraceNotes below overwrites them (along with every
    // sibling's, AND the anchor's own) immediately.
    notes.add(Note(
      id: generateNoteId(),
      startTick: anchor.startTick,
      durationTicks: 1,
      row: row,
      hand: anchor.hand,
      graceOfNoteId: anchor.id,
      graceNoteType: type,
    ));

    _redistributeGraceNotes(anchor.id);
    notifyListeners();
    return null;
  }

  /// Recomputes the anchor note's own start/duration AND every one of
  /// its grace notes', for the note with id [anchorId].
  ///
  /// Branches on [Note.graceIsAfter] — the anchor's grace notes are
  /// either all BEFORE it (false, the default) or all AFTER it
  /// (true); a single anchor is never split across both sides at
  /// once (see [startAddingGraceNotes], which clears one side before
  /// starting the other). The two directions are exact mirror images
  /// of each other:
  ///
  /// BEFORE (false): the grace region is carved out of the START of
  /// the anchor's own ORIGINAL span (see
  /// [Note.graceOriginalDurationTicks]). The anchor's end tick
  /// (startTick + durationTicks) never moves, no matter how many
  /// grace notes exist — only its start tick (and thus its own
  /// duration) shifts to make room, later as grace notes are added,
  /// back toward its original position as they're removed. The
  /// anchor's original start tick is DERIVED rather than stored
  /// separately: `(current end tick) - graceOriginalDurationTicks` —
  /// exactly right because the end tick is the one thing this branch
  /// guarantees never changes.
  ///
  /// AFTER (true): the exact mirror — the grace region is carved out
  /// of the END of the anchor's own ORIGINAL span instead. The
  /// anchor's START tick never moves this time; only its end tick
  /// (and thus its own duration) shifts to make room, growing back
  /// toward its original END as grace notes are removed. The
  /// anchor's original end tick is similarly DERIVED:
  /// `(current start tick) + graceOriginalDurationTicks`.
  ///
  /// In both directions: every grace note's duration is always
  /// exactly its own [GraceNoteType.durationTicks] — a FIXED,
  /// absolute value that is NEVER shrunk or scaled. Grace notes are
  /// placed back-to-back in the order they appear in [notes] (i.e.
  /// the order they were tapped in), earliest-tapped placed earliest
  /// in time, filling the carved-out region starting from its own
  /// edge nearest the anchor's remaining span (right after the
  /// anchor's own shrunken end, in BEFORE mode that's "immediately
  /// before the anchor's start"; in AFTER mode that's "immediately
  /// after the anchor's shrunken end"). The anchor is still
  /// guaranteed at least 1 tick of its own duration — but if the
  /// grace notes' fixed total would leave less than that (which
  /// [maxGraceNotesForType] is meant to prevent at add-time, but this
  /// stays robust even if it somehow happens, e.g. the anchor's own
  /// duration changing by some other means afterward), the anchor's
  /// moving endpoint is clamped rather than any grace note's duration
  /// being compressed — the grace notes may then end up overlapping
  /// the anchor, which is accepted rather than fought.
  ///
  /// If NO grace notes remain (the last one was just removed), the
  /// anchor reverts exactly to its original start tick and duration,
  /// and both [Note.graceOriginalDurationTicks] and
  /// [Note.graceIsAfter] are cleared/reset — there's nothing left for
  /// them to describe. A no-op if the anchor no longer exists or has
  /// no [Note.graceOriginalDurationTicks] (already fully reverted, or
  /// never had grace notes in the first place).
  void _redistributeGraceNotes(int anchorId) {
    final anchorIndex = notes.indexWhere((n) => n.id == anchorId);
    if (anchorIndex == -1) return;
    final anchor = notes[anchorIndex];
    final originalDuration = anchor.graceOriginalDurationTicks;
    if (originalDuration == null) return;

    final graceIndices = <int>[];
    for (int i = 0; i < notes.length; i++) {
      if (notes[i].graceOfNoteId == anchorId) graceIndices.add(i);
    }
    final count = graceIndices.length;

    if (anchor.graceIsAfter) {
      // AFTER mode — mirror image of the BEFORE branch below: the
      // anchor's own START never moves; grace notes are carved out
      // of the END of its original span instead, placed immediately
      // after the anchor's own (shrunken) end, filling up to the
      // original end tick.
      final fixedStartTick = anchor.startTick;
      final originalEndTick = fixedStartTick + originalDuration;

      if (count == 0) {
        notes[anchorIndex] = anchor.copyWith(
          startTick: fixedStartTick,
          durationTicks: originalDuration,
          graceOriginalDurationTicks: null,
          graceIsAfter: false,
        );
        return;
      }

      final graceDurations = <int>[];
      int totalGraceDuration = 0;
      for (final idx in graceIndices) {
        final graceType = notes[idx].graceNoteType;
        final fixedDuration =
            graceType?.durationTicksFor(originalDuration) ?? 1;
        graceDurations.add(fixedDuration);
        totalGraceDuration += fixedDuration;
      }
      // AFTER the main note: the LONGEST grace note comes first, right
      // after the main note (the pitches keep their tapped order —
      // only the lengths are arranged).
      graceDurations.sort((a, b) => b.compareTo(a));

      final newAnchorEnd = (originalEndTick - totalGraceDuration)
          .clamp(fixedStartTick + 1, originalEndTick);

      int runningTick = newAnchorEnd;
      for (int k = 0; k < count; k++) {
        final idx = graceIndices[k];
        notes[idx] = notes[idx].copyWith(
          startTick: runningTick,
          durationTicks: graceDurations[k],
        );
        runningTick += graceDurations[k];
      }

      notes[anchorIndex] = anchor.copyWith(
        startTick: fixedStartTick,
        durationTicks: newAnchorEnd - fixedStartTick,
      );
      return;
    }

    // BEFORE mode (the default/original behavior) — never moves, by
    // construction of this very branch — safe to treat as the fixed
    // reference point regardless of how many times this has already
    // run for this anchor.
    final fixedEndTick = anchor.startTick + anchor.durationTicks;
    final originalStartTick = fixedEndTick - originalDuration;

    if (count == 0) {
      // Nothing left to make room for — revert fully and clear the
      // marker, since there's no longer any grace-note state to
      // track.
      notes[anchorIndex] = anchor.copyWith(
        startTick: originalStartTick,
        durationTicks: originalDuration,
        graceOriginalDurationTicks: null,
        graceIsAfter: false,
      );
      return;
    }

    // BEFORE the main note: the LONGEST grace note comes last, right
    // before the main note (the pitches keep their tapped order —
    // only the lengths are arranged).
    final graceDurations = [
      for (final idx in graceIndices)
        notes[idx].graceNoteType?.durationTicksFor(originalDuration) ?? 1,
    ]..sort();

    int runningTick = originalStartTick;
    for (int k = 0; k < count; k++) {
      final idx = graceIndices[k];
      final fixedDuration = graceDurations[k];
      notes[idx] = notes[idx].copyWith(
        startTick: runningTick,
        durationTicks: fixedDuration,
      );
      runningTick += fixedDuration;
    }

    final newAnchorStart =
    runningTick.clamp(originalStartTick, fixedEndTick - 1);

    notes[anchorIndex] = anchor.copyWith(
      startTick: newAnchorStart,
      durationTicks: fixedEndTick - newAnchorStart,
    );
  }

  /// Removes [note]'s grace notes entirely: deletes every grace note
  /// that points back at it (see [Note.graceOfNoteId]), which — via
  /// [_redistributeGraceNotes] hitting its zero-remaining case — also
  /// reverts [note] itself back to its original start tick/duration
  /// and clears its [Note.graceOriginalDurationTicks]/
  /// [Note.graceIsAfter]. Called from wherever the Grace Notes
  /// field's dialog offers a "Delete"/clear action.
  void clearAllGraceNotes(Note note) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    notes.removeWhere((n) => n.graceOfNoteId == note.id);
    _redistributeGraceNotes(note.id);
    notifyListeners();
  }


  void setNoteOrnament(
      Note note,
      Ornament? ornament,
      ) {
    _replaceNote(
      note.copyWith(ornament: ornament),
    );
  }


  void setNotePlayingTechnique(
      Note note,
      PlayingTechnique? playingTechnique,
      ) {
    _replaceNote(
      note.copyWith(playingTechnique: playingTechnique),
    );
  }


  // =====================================================
  // =====================================================
  // SOUND
  // =====================================================

  /// Hands whose notes are silent ("cut off") during playback — set
  /// in the Audio dialog (audio_hands_dialog.dart). By default the
  /// right and left hands are heard and the additional hand is silent.
  final Set<Hand> mutedHands = {Hand.additional};

  /// The hands that actually have notes in this composition, in the
  /// order right, left, additional.
  List<Hand> get handsInComposition {
    final present = notes.map((n) => n.hand).toSet();
    return [Hand.right, Hand.left, Hand.additional]
        .where(present.contains)
        .toList();
  }

  bool isHandMuted(Hand hand) => mutedHands.contains(hand);

  void setHandMuted(Hand hand, bool muted) {
    if (muted) {
      mutedHands.add(hand);
    } else {
      mutedHands.remove(hand);
    }
    notifyListeners();
  }

  /// Silences ([muted] true) or turns on several hands at once (one
  /// redraw instead of one per hand).
  void setHandsMuted(Iterable<Hand> hands, bool muted) {
    for (final hand in hands) {
      if (muted) {
        mutedHands.add(hand);
      } else {
        mutedHands.remove(hand);
      }
    }
    notifyListeners();
  }

  /// Makes exactly [muted] the silent hands (the others are heard).
  void setMutedHandsTo(Set<Hand> muted) {
    mutedHands
      ..clear()
      ..addAll(muted);
    notifyListeners();
  }

  // ---------------- INSTRUMENT PER HAND ----------------

  /// The composition's Target Instrument as an [Instrument] ('any' and
  /// unknown names play the piano).
  Instrument get targetInstrument {
    final value = composition.instrument.toLowerCase();
    for (final i in Instrument.values) {
      if (i.label.toLowerCase() == value || i.name.toLowerCase() == value) {
        return i == Instrument.any ? Instrument.piano : i;
      }
    }
    return Instrument.piano;
  }

  /// The instrument [hand] is played with — chosen in the Audio dialog
  /// and saved with the composition; by default the Target Instrument.
  Instrument instrumentForHand(Hand hand) {
    final name = composition.handInstruments[hand.name];
    if (name != null) {
      for (final i in Instrument.values) {
        if (i.name == name) return i;
      }
    }
    return targetInstrument;
  }

  /// Plays [hand] with [instrument] from now on (saved with the
  /// composition) and prepares that instrument's sounds.
  void setHandInstrument(Hand hand, Instrument instrument) {
    composition.handInstruments[hand.name] = instrument.name;
    warmUpSounds();
    notifyListeners();
  }

  /// Sets the instruments of several hands at once (the Audio dialog's
  /// Set button).
  void setHandInstruments(Map<Hand, Instrument> instruments) {
    instruments.forEach((hand, instrument) {
      composition.handInstruments[hand.name] = instrument.name;
    });
    warmUpSounds();
    notifyListeners();
  }

  SoundTimbre timbreForHand(Hand hand) =>
      timbreForInstrument(instrumentForHand(hand));

  /// The kind of sound each instrument is played with.
  static SoundTimbre timbreForInstrument(Instrument instrument) {
    switch (instrument) {
      case Instrument.any:
      case Instrument.piano:
        return SoundTimbre.piano;
      case Instrument.keyboard:
        return SoundTimbre.electricPiano;
      case Instrument.organ:
        return SoundTimbre.organ;
      case Instrument.accordion:
      case Instrument.bayan:
        return SoundTimbre.reed;
      case Instrument.guitar6Strings:
      case Instrument.guitar7Strings:
        return SoundTimbre.guitar;
      case Instrument.guitarElectro:
        return SoundTimbre.electricGuitar;
      case Instrument.guitarBass:
        return SoundTimbre.bassGuitar;
      case Instrument.cello:
        return SoundTimbre.bowedLow;
      case Instrument.violin:
        return SoundTimbre.bowed;
      case Instrument.ukelele:
      case Instrument.balalaika:
      case Instrument.banjo:
        return SoundTimbre.bright;
      case Instrument.harp:
        return SoundTimbre.harp;
      case Instrument.clarinet:
        return SoundTimbre.clarinet;
      case Instrument.cornet:
      case Instrument.trumpet:
      case Instrument.trombone:
        return SoundTimbre.brass;
      case Instrument.horn:
        return SoundTimbre.horn;
      case Instrument.flute:
        return SoundTimbre.flute;
      case Instrument.saxophone:
        return SoundTimbre.saxophone;
      case Instrument.xylophone:
        return SoundTimbre.xylophone;
    }
  }

  void setAllHandsMuted(bool muted) {
    if (muted) {
      mutedHands.addAll(Hand.values);
    } else {
      mutedHands.clear();
    }
    notifyListeners();
  }

  /// True while at least one hand that has notes is heard.
  bool get soundEnabled =>
      handsInComposition.any((h) => !mutedHands.contains(h));

  /// True when some hands are heard and some are cut off.
  bool get isSoundPartial =>
      soundEnabled &&
          handsInComposition.any((h) => mutedHands.contains(h));

  // =====================================================
  // PLAYBACK SPEED
  // =====================================================

  /// Multiplier on the speed the tempo requires — 1.0 plays exactly
  /// at the tempo. Set in steps ([playbackSpeedLevel]) via the Scroll
  /// Speed dialog that opens from the Play icon (see
  /// scroll_speed_dialog.dart), and applied to both the scrolling and
  /// the length of each note's sound, so they always stay in step. Not
  /// saved with the composition — it's a practice setting, not part of
  /// the music.
  double get playbackSpeed => speedForLevel(playbackSpeedLevel);

  /// Steps of 25%: +1 = 125% faster (1.25× speed) … +4 = 200% faster
  /// (twice as fast); −1 = 125% slower (the music takes 1.25× as long)
  /// … −4 = 200% slower (half the speed). 0 = the tempo.
  int playbackSpeedLevel = 0;
  static const int minPlaybackSpeedLevel = -4;
  static const int maxPlaybackSpeedLevel = 4;

  /// The speed multiplier of a [level] (see [playbackSpeedLevel]).
  static double speedForLevel(int level) =>
      level >= 0 ? 1 + 0.25 * level : 1 / (1 + 0.25 * -level);

  /// Whether the speed differs from the tempo — used to color the
  /// Play icon blue, the same way the Cell Width icon shows a changed
  /// width.
  bool get isPlaybackSpeedChanged => playbackSpeedLevel != 0;

  /// One step faster (+1) or slower (−1).
  void changePlaybackSpeedLevel(int delta) {
    playbackSpeedLevel = (playbackSpeedLevel + delta)
        .clamp(minPlaybackSpeedLevel, maxPlaybackSpeedLevel);
    notifyListeners();
  }

  /// Sets the speed step (see [playbackSpeedLevel]).
  void setPlaybackSpeedLevel(int level) {
    final l = level.clamp(minPlaybackSpeedLevel, maxPlaybackSpeedLevel);
    if (l == playbackSpeedLevel) return;
    playbackSpeedLevel = l;
    notifyListeners();
  }

  /// Back to the speed the tempo requires.
  void resetPlaybackSpeed() {
    playbackSpeedLevel = 0;
    notifyListeners();
  }

  /// Turns every hand on, or — if any hand is heard — every hand off.
  void toggleSound() {
    setAllHandsMuted(soundEnabled);
  }

  // Semitone offset of each natural scale degree (1..7 = do..si) from
  // the octave's root, matching a standard major scale.
  static const List<int> _naturalDegreeSemitones = [0, 2, 4, 5, 7, 9, 11];

  // Tuning reference: octave 4 ("One-line" per getOctaveName), degree 6
  // (la), natural = 440 Hz — standard concert pitch A440. Everything
  // else is derived from that (in standard 12-tone equal temperament)
  // by converting it back to the equivalent degree-1 (do) frequency at
  // that same octave, since the rest of the math below is anchored on
  // the octave's root note.
  static final double _referenceFrequencyC4 =
  (440 * math.pow(2, -_naturalDegreeSemitones[5] / 12)).toDouble();

  // Semitone shift for accidental signs. These four keys are exactly
  // what Accidental.sign produces (see enums/accidental.dart):
  // sharp='+', doubleSharp='++', flat='-', doubleFlat='--'.
  // Unrecognized signs contribute no shift.
  static const Map<String, int> _accidentalSemitoneShift = {
    '+': 1,
    '++': 2,
    '-': -1,
    '--': -2,
    'x': 0,
  };

  /// The accidental actually in effect for [note], accounting for
  /// measure-persistence: an explicit accidental set on an earlier note
  /// sharing the same row (same octave + degree) stays in effect for
  /// the rest of the measure until a later note on that same row is
  /// given a different explicit accidental — including being cleared
  /// back to natural, which is honored as-is here rather than skipped
  /// past. In practice, since [setNoteAccidental] and
  /// [addNoteAtGridPosition] already keep every note's own
  /// `.accidental` field correctly propagated, the nearest note at or
  /// before [note]'s tick is always [note] itself — so this mostly
  /// just returns [note].accidental — but the search stays measure-
  /// and row-aware as a safety net for notes that reached the list by
  /// some other path.
  Accidental? getEffectiveAccidental(Note note) {
    final measure = getMeasureAtTick(note.startTick);
    Note? nearest;
    for (final n in notes) {
      if (n.row != note.row) continue;
      if (n.startTick < measure.startTick || n.startTick >= measure.endTick) {
        continue;
      }
      if (n.startTick > note.startTick) continue;
      if (n.startTick == note.startTick && n.id != note.id) continue;
      if (nearest == null ||
          n.startTick > nearest.startTick ||
          (n.startTick == nearest.startTick && n.id == note.id)) {
        nearest = n;
      }
    }
    return nearest?.accidental;
  }

  /// Whichever accidental (if any) is currently in effect at [row] for
  /// a position at [tick] within its measure, based on the *closest
  /// earlier* note on that row — used only to decide what a brand-new
  /// note should be created with. Unlike [getEffectiveAccidental], this
  /// takes raw tick/row rather than an existing Note, specifically so a
  /// note being created can't end up referencing its own (not-yet-set)
  /// value while searching.
  Accidental? _accidentalInEffectAt(int tick, int row) {
    final measure = getMeasureAtTick(tick);
    Note? nearest;
    for (final n in notes) {
      if (n.row != row) continue;
      if (n.startTick < measure.startTick || n.startTick >= measure.endTick) {
        continue;
      }
      if (n.startTick >= tick) continue; // strictly earlier only
      if (nearest == null || n.startTick > nearest.startTick) {
        nearest = n;
      }
    }
    return nearest?.accidental;
  }


  /// The exact frequency (Hz) an ornament ghost should sound at:
  /// [baseNote]'s own ACTUAL frequency (see [getNoteFrequencyHz] —
  /// this already correctly includes the scale degree's own
  /// alteration AND [baseNote]'s own effective accidental, exactly as
  /// it would sound as an ordinary note) shifted by [shift] semitones
  /// on top. Deriving from the base note's real frequency (rather
  /// than the bare scale degree) matters whenever [baseNote] itself
  /// carries an accidental — the ornament's auxiliary note is a
  /// semitone offset from what the base note ACTUALLY sounds like,
  /// not from its unaltered scale degree. Computed directly from the
  /// semitone count rather than converting [shift] to an [Accidental]
  /// first, since a raw shiftMap value can exceed what a single
  /// accidental sign can represent (e.g. ±3) — going through an
  /// [Accidental] would silently lose a semitone in that case. The
  /// DISPLAYED accidental (see [getOrnamentGhostDisplay]) may be a
  /// simplified representation of the combined shift, but the actual
  /// sound always reflects it exactly.
  double getOrnamentFrequencyHz({
    required Note baseNote,
    required int shift,
  }) {
    return getNoteFrequencyHz(baseNote) * math.pow(2, shift / 12);
  }

  /// The absolute frequency (Hz) [note] should sound at: the scale
  /// degree's own +/- alteration (from the measure's current scale
  /// pattern) combined with whichever accidental is actually in effect
  /// on that row at this point in the measure (see
  /// [getEffectiveAccidental]), then shifted by octave. See
  /// [_referenceFrequencyC4] for the tuning reference this is built on.
  double getNoteFrequencyHz(Note note) {
    return _frequencyForRowAndAccidental(
      row: note.row,
      startTick: note.startTick,
      accidental: getEffectiveAccidental(note),
    );
  }

  /// The exact frequency of an ornament ghost is now computed by
  /// [getOrnamentFrequencyHz] directly from its base note's own
  /// actual frequency and raw shiftMap shift (see that method's doc)
  /// — a ghost no longer carries a pre-baked, walked row/accidental
  /// of its own (see [displayNotes]), so there's nothing left to read
  /// off the ghost Note object itself for pitch purposes.

  /// Shared pitch computation behind [getNoteFrequencyHz] and
  /// [getOrnamentFrequencyHz]: the scale degree's own +/- alteration
  /// at [row] (from whichever measure contains [startTick]) combined
  /// with [accidental], then shifted by octave. See
  /// [_referenceFrequencyC4] for the tuning reference this is built
  /// on.
  double _frequencyForRowAndAccidental({
    required int row,
    required int startTick,
    required Accidental? accidental,
  }) {
    final semitones = _semitonesForRowAndAccidental(
      row: row,
      startTick: startTick,
      accidental: accidental,
    );
    if (semitones == null) return 0;
    return _referenceFrequencyC4 * math.pow(2, semitones / 12);
  }

  /// The pitch in semitones from Do4 (C4) of [row] at [startTick] with
  /// [accidental] in effect — null when the measure's scale is unknown.
  int? _semitonesForRowAndAccidental({
    required int row,
    required int startTick,
    required Accidental? accidental,
  }) {
    final measure = getMeasureAtTick(startTick);
    final shiftedScale = ScaleResolver.transposeScale(
      measure.scaleName,
      measure.pitchOffsetSemitones,
    );
    final scale = ScaleResolver.getScale(shiftedScale);
    if (scale.isEmpty) {
      return null;
    }

    final degreeIndex = row % scale.length;
    final degreeToken = scale[degreeIndex];

    // A natural cancels ANY alteration in effect — that includes one
    // baked into the scale itself for this degree, not just a
    // previous accidental. So unlike a normal +/- (which is additive
    // on top of the scale's own sign), natural forces the scale's
    // contribution to 0 rather than adding 0 to it.
    int scaleAlteration = 0;
    if (accidental != Accidental.natural) {
      if (degreeToken.endsWith('+')) {
        scaleAlteration = 1;
      } else if (degreeToken.endsWith('-')) {
        scaleAlteration = -1;
      }
    }

    final naturalSemitone = _naturalDegreeSemitones[
    degreeIndex % _naturalDegreeSemitones.length];

    final accidentalShift =
    accidental != null ? (_accidentalSemitoneShift[accidental.sign] ?? 0) : 0;

    final octave = row ~/ 7;
    final octaveShift = (octave - 4) * 12;

    return naturalSemitone + scaleAlteration + accidentalShift + octaveShift;
  }

  /// How long [note] actually lasts in real time — same tempo/beat-unit
  /// formula the playback ticker uses, evaluated at the note's own
  /// start so it's correct even if tempo changes partway through.
  double getNoteDurationSeconds(Note note) {
    final measure = getMeasureAtTick(note.startTick);
    final activeTempo = getActiveTempoAtTick(note.startTick);
    final beatTicks = measure.effectiveTempoBeat.ticks;
    final bpm = activeTempo?.tempo.value ?? 0;
    if (bpm <= 0 || beatTicks <= 0) {
      return 0.3; // sane fallback rather than dividing by zero
    }
    // Same playback-speed multiplier the scrolling uses, so each
    // note's sound lasts exactly as long as it takes to scroll past.
    final ticksPerSecond = beatTicks * bpm / 60.0 * playbackSpeed;
    return note.durationTicks / ticksPerSecond;
  }

  /// Plays [note]'s tone if sound is currently enabled. Public so both
  /// this controller (on note creation) and the playback loop
  /// (composition_screen.dart, as it scrolls past each note's start
  /// tick) can trigger it. A glissando run note (see
  /// [Note.glissandoSourceId]) sounds at its plain "white key" pitch
  /// (see [getWhiteKeyFrequencyHz]) rather than the scale-driven pitch
  /// [getNoteFrequencyHz] would give it — this is what makes the
  /// playback loop, which already calls this for every ordinary note
  /// including generated glissando run notes, play them correctly
  /// with no changes needed on the playback side itself.
  void playNoteSound(Note note) {
    if (mutedHands.contains(note.hand)) return;
    final frequencyHz = note.glissandoSourceId != null
        ? getWhiteKeyFrequencyHz(note.row)
        : getNoteFrequencyHz(note);
    // While the sustain pedal is down at this note's start, let it
    // keep ringing (until its sound naturally dies away) instead of
    // stopping at the end of its written duration — the same thing a
    // real piano's sustain pedal does.
    final durationSeconds = isPedalDownAtTick(note.startTick)
        ? 10.0
        : getNoteDurationSeconds(note);
    NoteSoundService.instance.playTone(
      frequencyHz: frequencyHz,
      durationSeconds: durationSeconds,
      timbre: timbreForHand(note.hand),
    );
  }

  /// Plays an ornament "ghost" note's tone if sound is currently
  /// enabled — same idea as [playNoteSound], but computing the exact
  /// frequency via [getOrnamentFrequencyHz] (from [baseNote]'s own
  /// ACTUAL frequency — accidental included — plus the raw semitone
  /// [shift] from its shiftMap entry) rather than calling
  /// [getNoteFrequencyHz] directly on [ghost] (which was never added
  /// to [notes], so its own effective-accidental lookup wouldn't work
  /// — and which, going through an [Accidental] representation,
  /// couldn't represent a shift beyond ±2 semitones exactly anyway).
  /// [getNoteDurationSeconds] itself only depends on
  /// [ghost]'s own startTick/durationTicks/tempo, so that's still
  /// read from [ghost] — its own (much shorter) durationTicks already
  /// gives the right sub-note length. Public so the playback loop
  /// (composition_screen.dart) can trigger each note of an ornament's
  /// sequence individually, at its own onset, as playback crosses it.
  void playGhostNoteSound(Note ghost, Note baseNote, int shift) {
    if (mutedHands.contains(baseNote.hand)) return;
    NoteSoundService.instance.playTone(
      frequencyHz: getOrnamentFrequencyHz(
        baseNote: baseNote,
        shift: shift,
      ),
      durationSeconds: getNoteDurationSeconds(ghost),
      timbre: timbreForHand(baseNote.hand),
    );
  }


  // =====================================================
  // SCALE SYSTEM
  // =====================================================

  String getNotePitchName(Note note) {
    final measure = getMeasureAtTick(
      note.startTick,
    );
    final shiftedScale = ScaleResolver.transposeScale(
      measure.scaleName,
      measure.pitchOffsetSemitones,
    );
    final scale = ScaleResolver.getScale(
      shiftedScale,
    );
    if (scale.isEmpty) {
      return '';
    }
    return scale[note.row % scale.length];
  }



  String getPitchNameForRow(int row, [Measure? measure]) {
    final m = measure ?? (measures.isNotEmpty ? currentMeasure : null);
    if (m == null) {
      return '';
    }
    final shiftedScale = ScaleResolver.transposeScale(
      m.scaleName,
      m.pitchOffsetSemitones,
    );
    final scale = ScaleResolver.getScale(shiftedScale);
    if (scale.isEmpty) {
      return '';
    }
    // Row increases with pitch (row 0 = lowest, octave 0 degree 1) —
    // kept in direct correspondence with getDegree/getOctave/
    // getNoteFrequencyHz, which all treat row the same way. Flipping
    // this for display (e.g. so the lowest row renders at the bottom
    // of the screen) is a layout concern handled by the calling
    // widgets, not here.
    return scale[row % scale.length];
  }


  /// Whether notes are currently shown in "compensated" notation — this
  /// governs the pitch+accidental display of ORDINARY notes only (see
  /// [getDisplayPitchLabel] / [getCompensatedDisplay]). It no longer
  /// affects whether an ornament expands into its ghost sequence —
  /// that now always happens (see [displayNotes]), since ornaments are
  /// no longer drawn as a sign above the note. Purely a display switch:
  /// toggling this never touches note.row or note.accidental, so
  /// switching back to normal notation is instant and lossless.
  bool showCompensatedNotation = false;

  void toggleCompensatedNotation() {
    showCompensatedNotation = !showCompensatedNotation;
    notifyListeners();
  }

  // =====================================================
  // INPUT LOCK / DRAW MODE
  // =====================================================

  /// When on, tapping the grid never creates/moves notes — lets a
  /// person scroll around the composition without accidentally adding
  /// a note on every tap.
  ///
  /// Scroll Lock is also the PLAYBACK mode (starting playback turns it
  /// on): turning it on plays reprises by inserting the repeated
  /// measures as temporary copies; turning it off (edit mode) removes
  /// them again and the reprise signs reappear.
  bool _inputLocked = false;

  bool get inputLocked => _inputLocked;

  set inputLocked(bool value) {
    if (value == _inputLocked) return;
    _inputLocked = value;
    if (value) {
      expandReprises();
    } else {
      collapseReprises();
    }
  }

  void toggleInputLocked() {
    inputLocked = !inputLocked;
    notifyListeners();
  }

  /// When on, the pitch text drawn inside each note cell is rotated
  /// 90° — purely cosmetic, useful when cells are narrow (zoomed in
  /// tightly) and a vertical label reads more comfortably than a
  /// horizontal one squeezed into a thin box.
  ///
  /// Toggling this ALSO drives [showCompensatedNotation] (Easy Read
  /// mode) and [inputLocked] (Scroll Lock) to the same new state —
  /// turning rotation on turns both of those on too, and turning
  /// rotation off turns both back off, per request. There's no
  /// independent way to have rotation on with either of the other two
  /// off — all three move together, driven by this single toggle.
  bool rotatePitchText = false;

  void toggleRotatePitchText() {
    rotatePitchText = !rotatePitchText;
    showCompensatedNotation = rotatePitchText;
    inputLocked = rotatePitchText;
    notifyListeners();
  }

  /// When on, the finger number strip normally drawn above a note
  /// (see NoteBlockWidget) is hidden for every note, regardless of
  /// its own Note.finger value — purely a display toggle, the same
  /// way [showCompensatedNotation] is: no note data changes, so
  /// switching this back off instantly restores every finger number
  /// with no risk of data loss.
  bool hideFingerNumbers = false;

  void toggleHideFingerNumbers() {
    hideFingerNumbers = !hideFingerNumbers;
    notifyListeners();
  }

  /// Shared font size for every grid annotation label — finger
  /// number, time signature, pedal sign, dynamic, tempo, scale name,
  /// and measure number (see GridWidget/NoteBlockWidget, which all
  /// read this instead of a hardcoded const style now). Starts at
  /// [DefaultValues.gridFontSize] and toggles up to
  /// [DefaultValues.gridFontSizeLarge] and back.
  // Large labels by default; the icon switches to the smaller size.
  double gridFontSize = DefaultValues.gridFontSizeLarge;

  void toggleGridFontSize() {
    gridFontSize = gridFontSize == DefaultValues.gridFontSize
        ? DefaultValues.gridFontSizeLarge
        : DefaultValues.gridFontSize;
    notifyListeners();
  }

  /// Whether the app is currently in dark mode — every screen/dialog
  /// that reads AppColors (see app_colors.dart) instead of a
  /// hardcoded white/black now flips consistently in response to
  /// this, rather than each file managing its own light/dark state.
  bool isDarkMode = false;

  void toggleDarkMode() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  /// Whether grid taps/drags should currently be blocked from
  /// creating/editing notes — true under compensated notation (a
  /// read-only simplified view) or while input is locked
  /// (scrolling-only mode).
  bool get editingBlocked => showCompensatedNotation || inputLocked;

  /// The message to show when a grid/note interaction is blocked by
  /// [editingBlocked] — names whichever mode is actually responsible,
  /// so the person knows which toggle to turn off.
  String get editingBlockedMessage {
    if (showCompensatedNotation) {
      return 'Turn off Compensated Notation to edit notes';
    }
    if (inputLocked) {
      return 'Turn off Scroll Lock to edit notes';
    }
    return 'Editing is currently disabled';
  }

  /// The pitch label to actually display for [note]: a glissando run
  /// note (see [Note.glissandoSourceId]) always shows the plain
  /// natural degree number for its row (1-7, cycling — via
  /// [getDegree]), regardless of [showCompensatedNotation] or the
  /// composition's scale — matching how a real piano glissando runs
  /// straight across the white keys. Otherwise: under compensated
  /// notation this is the full computed word from
  /// [getCompensatedDisplay] — e.g. scale sign "1+" plus accidental
  /// "+" becomes "2", or "1+" plus accidental "-" stays "1" at the
  /// same row. Outside compensated mode it's just the plain scale
  /// label for the row (e.g. "4+"); the accidental itself is drawn
  /// separately by the caller in that mode.
  String getDisplayPitchLabel(Note note) {
    if (note.glissandoSourceId != null) {
      return getDegree(note).toString();
    }
    if (showCompensatedNotation) {
      return getCompensatedDisplay(note).label;
    }
    return getPitchNameForRow(note.row, getMeasureAtTick(note.startTick));
  }

  /// Computes, WITHOUT mutating [note] (note.row and note.accidental
  /// are never touched — this is a pure display computation), the row
  /// and full pitch word ("1", "1+", "2", "7-", etc.) to show for it
  /// under compensated notation.
  ///
  /// The scale's own sign for the note's row and its effective
  /// accidental are combined into one net semitone offset. If that's
  /// zero, it displays as a plain digit at the same row (opposing
  /// signs cancel, e.g. "1+" + "-" → "1"). If it's not zero, it's
  /// walked toward the adjacent degree in that direction, comparing
  /// against the REAL semitone gap between the two degrees — half a
  /// step at 3→4 and 7→1, a whole step everywhere else — rather than
  /// assuming every degree is the same distance apart. A gap that
  /// exactly absorbs the remaining offset lands on that row as a plain
  /// digit (e.g. "1+" + "+" → "2", since the 1→2 gap is a whole step
  /// and a scale-sign-plus-accidental "+" is exactly 2 semitones).
  /// A gap that doesn't fully absorb it keeps walking (so a 3-semitone
  /// total can cross two rows), and whatever's left after the walk
  /// stops is shown as a plain sign on the digit at that row (e.g.
  /// "3++" → "4+", since only 1 of the 2 semitones is absorbed by the
  /// half-step 3→4 gap).
  /// The combined semitone offset from [note]'s row's OWN natural
  /// pitch, contributed by the scale's own alteration for that degree
  /// plus [note]'s effective accidental — the exact "net shift"
  /// [getCompensatedDisplay] walks to build its merged label, and
  /// also what an ornament ghost's own raw shift (see
  /// [getOrnamentGhostDisplay]) needs added on top of, so an ornament
  /// note's displayed/sounded pitch is relative to the base note's
  /// ACTUAL pitch (accidental included) rather than the bare scale
  /// degree. A natural effective accidental cancels BOTH
  /// contributions (not just its own) — same rule [getNoteFrequencyHz]
  /// uses.
  int _netScaleAndAccidentalShift(Note note) {
    final effectiveAccidental = getEffectiveAccidental(note);
    if (effectiveAccidental == Accidental.natural) return 0;

    final measure = getMeasureAtTick(note.startTick);
    final shiftedScale = ScaleResolver.transposeScale(
      measure.scaleName,
      measure.pitchOffsetSemitones,
    );
    final scale = ScaleResolver.getScale(shiftedScale);
    if (scale.isEmpty) return 0;

    final degreeToken = scale[note.row % scale.length];
    int scaleAlteration = 0;
    if (degreeToken.endsWith('+')) {
      scaleAlteration = 1;
    } else if (degreeToken.endsWith('-')) {
      scaleAlteration = -1;
    }

    final accidentalShift = effectiveAccidental != null
        ? (_accidentalSemitoneShift[effectiveAccidental.sign] ?? 0)
        : 0;

    return scaleAlteration + accidentalShift;
  }

  ({int row, String label}) getCompensatedDisplay(Note note) {
    final measure = getMeasureAtTick(note.startTick);
    final netShift = _netScaleAndAccidentalShift(note);

    final walked = _walkToRow(note.row, netShift);
    final baseDigit = _stripSign(getPitchNameForRow(walked.row, measure));

    return (row: walked.row, label: '$baseDigit${_signStringFor(walked.remainingShift)}');
  }

  /// The row + label to display for a genuinely-shifted ornament
  /// ghost (raw shiftMap `shift` != 0) belonging to [baseNote] —
  /// combines the SAME net semitone offset an ordinary note's
  /// compensated display uses ([_netScaleAndAccidentalShift]:
  /// [baseNote]'s scale degree's own alteration plus its effective
  /// accidental) with the ornament's own raw [shift] on top, then
  /// ALWAYS walks (see [_walkOrnamentShift]) to a genuinely different
  /// row — matching how mordents/turns/etc. are actually notated: the
  /// auxiliary note's pitch is relative to the main note's ACTUAL
  /// sounding pitch (accidental included), not the bare scale degree.
  /// A `shift` of 0 (the ornament's own unaltered note) is handled
  /// separately by the caller (NoteBlockWidget), which renders it
  /// exactly like an ordinary note instead of going through this
  /// method at all.
  ({int row, String label}) getOrnamentGhostDisplay(Note baseNote, int shift) {
    final netShift = _netScaleAndAccidentalShift(baseNote) + shift;
    final measure = getMeasureAtTick(baseNote.startTick);
    final walked = _walkOrnamentShift(baseNote.row, netShift);
    final baseDigit = _stripSign(getPitchNameForRow(walked.row, measure));
    return (row: walked.row, label: '$baseDigit${_signStringFor(walked.remainingShift)}');
  }

  /// Walks from [startRow] toward the degree in whichever direction
  /// [netShift] semitones points, comparing against the REAL semitone
  /// gap between adjacent degrees at each step (not assuming every
  /// degree is the same distance apart — see [_naturalAbsoluteSemitone]).
  /// A gap that exactly absorbs what's left lands there with nothing
  /// left over; a gap that doesn't fully absorb it keeps walking, so a
  /// large shift can cross more than one row. Returns wherever the walk
  /// stops, plus whatever's left of [netShift] that couldn't be
  /// absorbed by a whole-row step.
  ({int row, int remainingShift}) _walkToRow(int startRow, int netShift) {
    int remaining = netShift;
    int currentRow = startRow;
    if (remaining != 0) {
      final direction = remaining > 0 ? 1 : -1;
      while (remaining != 0) {
        final nextRow = currentRow + direction;
        if (nextRow < 0 || nextRow >= totalRows) break;
        final stepInterval = (_naturalAbsoluteSemitone(nextRow) -
            _naturalAbsoluteSemitone(currentRow))
            .abs();
        if (stepInterval == 0 || remaining.abs() < stepInterval) break;
        currentRow = nextRow;
        remaining -= direction * stepInterval;
      }
    }
    return (row: currentRow, remainingShift: remaining);
  }

  /// Like [_walkToRow], but for ornament ghost notes specifically —
  /// where a different rule applies: any nonzero shift should land on
  /// a DIFFERENT row whenever one is available, showing whatever's
  /// left over as an accidental there, rather than staying on the
  /// same row with the accidental (which is what [_walkToRow] prefers
  /// for the pitch+accidental compensation display). E.g. pitch "2"
  /// shifted by 1 semitone becomes the row above shown as "3-" (the
  /// 2->3 gap is a whole tone, so 1 of its 2 semitones is left over as
  /// a flat) -- not "2+" on the same row.
  ///
  /// The FIRST row-step is always taken, regardless of how it
  /// compares to [shift]'s magnitude — that's the "always land on a
  /// different row" rule above. After that forced first step, the
  /// walk continues like [_walkToRow]: crossing further rows as long
  /// as what's left still fully covers the next row's real semitone
  /// gap. But a forced first step (or any step) can OVERSHOOT — e.g.
  /// shift -1 from a degree whose neighbor below is a whole tone (2
  /// semitones) away leaves a remainder of +1, since only 1 of the 2
  /// semitones absorbed was actually wanted. Once that happens
  /// (remaining's sign no longer matches the walk direction), the
  /// walk stops immediately rather than continuing further in the
  /// same direction — continuing would only push the leftover further
  /// from zero, never toward it, since the correction now needed
  /// points the opposite way. That leftover is exactly representable
  /// as a single accidental sign on the row just reached.
  ({int row, int remainingShift}) _walkOrnamentShift(int startRow, int shift) {
    if (shift == 0) return (row: startRow, remainingShift: 0);

    final direction = shift > 0 ? 1 : -1;
    int remaining = shift;
    int currentRow = startRow;
    bool firstStep = true;

    while (remaining != 0) {
      if (!firstStep) {
        // A previous step already overshot — the leftover now points
        // the OPPOSITE way from `direction`, so continuing to walk
        // that way would only diverge further. Stop; the leftover
        // belongs on the row we're already at.
        final sameSignAsDirection = (remaining > 0) == (direction > 0);
        if (!sameSignAsDirection) break;
      }

      final nextRow = currentRow + direction;

      if (nextRow < 0 || nextRow >= totalRows) {
        if (!firstStep) {
          // Ran out of grid partway through a multi-row walk — leave
          // whatever's left on the row we'd already reached.
          break;
        }
        // Blocked at the edge of the grid in the requested direction
        // on the very first step — fall back to the opposite
        // direction so the ornament still lands on a genuinely
        // different row (with a correspondingly adjusted leftover
        // accidental) instead of silently collapsing onto the same
        // row as the un-shifted entries.
        final oppositeDirection = -direction;
        final oppositeRow = currentRow + oppositeDirection;
        if (oppositeRow < 0 || oppositeRow >= totalRows) {
          // Truly nowhere to go either way (a degenerate 1-row grid).
          return (row: currentRow, remainingShift: remaining);
        }
        final stepInterval = (_naturalAbsoluteSemitone(oppositeRow) -
            _naturalAbsoluteSemitone(currentRow))
            .abs();
        return (
        row: oppositeRow,
        remainingShift: remaining - oppositeDirection * stepInterval,
        );
      }

      final stepInterval = (_naturalAbsoluteSemitone(nextRow) -
          _naturalAbsoluteSemitone(currentRow))
          .abs();
      if (stepInterval == 0) break;

      // Every step after the first only crosses if what's left still
      // fully covers (or exceeds) this row's real gap — same
      // condition [_walkToRow] uses. The first step ignores this and
      // always crosses (see doc comment above).
      if (!firstStep && remaining.abs() < stepInterval) {
        break;
      }

      currentRow = nextRow;
      remaining -= direction * stepInterval;
      firstStep = false;
    }

    return (row: currentRow, remainingShift: remaining);
  }

  /// The +/- suffix for a leftover semitone amount after [_walkToRow]
  /// — only ±1/±2 are representable as a single accidental sign; a
  /// larger leftover (rare — e.g. an ornament shift bigger than any
  /// available accidental) has no sign to show and is dropped rather
  /// than displayed wrong.
  String _signStringFor(int remainingShift) {
    return switch (remainingShift) {
      0 => '',
      1 => '+',
      2 => '++',
      -1 => '-',
      -2 => '--',
      _ => '',
    };
  }

  String _stripSign(String token) {
    if (token.endsWith('+') || token.endsWith('-')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  /// The row's natural (unaltered) semitone position, absolute across
  /// octaves — i.e. ignoring any scale-specific alteration for that
  /// degree. Used only to measure the real gap between adjacent
  /// degrees when walking in [_walkToRow].
  int _naturalAbsoluteSemitone(int row) {
    final octave = row ~/ 7;
    final degreeIndex = row % 7;
    return octave * 12 + _naturalDegreeSemitones[degreeIndex];
  }

  /// The notes to actually draw on the grid right now. Any note
  /// carrying an [Ornament] (see Ornament.shiftMap) is expanded into
  /// the short sequence of display-only "ghost" notes its shiftMap
  /// describes — this ALWAYS happens, regardless of
  /// [showCompensatedNotation]: ornaments are no longer drawn as a
  /// sign above the note, so the shifted-pitch ghost sequence is the
  /// only presentation an ornament gets.
  ///
  /// Each ghost keeps the underlying note's own, UNCHANGED row and
  /// carries the shiftMap entry's raw semitone `shift` alongside it
  /// in the returned record, plus `interactionNote` set to the REAL
  /// underlying note (always, regardless of clickability — see
  /// below). Both the caller (NoteBlockWidget) and playback
  /// (playGhostNoteSound) derive a ghost's actual pitch from that
  /// real note's own ACTUAL pitch (its effective accidental and the
  /// scale's own alteration for its degree — see
  /// [_netScaleAndAccidentalShift]) with the raw `shift` added on top
  /// — NOT from the bare, unaltered scale degree — so an ornament on
  /// a note that itself carries an accidental sounds and displays
  /// correctly relative to that note's real pitch. A `shift` of 0
  /// (the ornament's own unaltered note) renders identically to how
  /// the real note would display on its own, respecting
  /// [showCompensatedNotation] exactly like an ordinary note would; a
  /// nonzero `shift` ALWAYS walks (see [getOrnamentGhostDisplay] /
  /// [_walkOrnamentShift]) to a genuinely different row regardless of
  /// that toggle — e.g. pitch "3" shifted a semitone below shows as
  /// "2+" on the row below, never "3-" on the same row — matching how
  /// mordents/turns/etc. are actually notated (the auxiliary note
  /// gets its own staff position, not an accidental on the same
  /// line).
  ///
  /// Within one note's ghost sequence, only ghosts whose raw shiftMap
  /// `shift` is 0 (i.e. sitting at the ornament's unaltered/base
  /// pitch) are clickable — every other ghost (any nonzero shift) is
  /// display-only. A shiftMap can have more than one `shift: 0` entry
  /// (e.g. the trill alternates back to it repeatedly); all of those
  /// are clickable. Every clickable ghost's `interactionNote` points
  /// back at the SAME real underlying note (not its own synthetic
  /// copy, which was never added to [notes] and whose id nothing else
  /// can look up), so tapping/dragging any of them actually edits the
  /// real note.
  ///
  /// Ghosts are marked (isGhost: true) so NoteBlockWidget can render
  /// them literally — using their own precomputed row/accidental
  /// directly — rather than running them back through the normal
  /// note/measure lookups, which wouldn't find them since they were
  /// never added to [notes]. The real note's own startTick/
  /// durationTicks/row/ornament are never touched; this is purely a
  /// read-only view. Playback always uses the real [notes] list
  /// regardless of this.
  // ================= TRILL =================

  /// How long each short note of a trill lasts, in seconds — about 10
  /// notes per second, a speed a pianist can comfortably play by
  /// alternating the two keys. Every trill uses this same speed, no
  /// matter how long the trilled note is: a longer note simply gets
  /// more alternations. Raise it for a slower trill, lower it for a
  /// faster one.
  static const double trillNoteSeconds = 0.1;

  /// Upper limit on short notes in one trill (ghost ids are
  /// note.id * 100 + index, so it must stay below 100).
  static const int _maxTrillNotes = 98;

  static bool _isTrill(Ornament ornament) =>
      ornament == Ornament.trillDiatonic ||
          ornament == Ornament.trillChromatic ||
          ornament == Ornament.trillChromaticSharp;

  /// The trill for [note] as a shiftMap of equal short notes, each
  /// lasting about [trillNoteSeconds] at the note's tempo. Alternates
  /// the auxiliary note and the main note in the order the ornament
  /// defines and always ends with a part of the note's own pitch
  /// (see the comment below). Computed at the written tempo, not
  /// the Scroll Speed setting, so the grid looks the same at any
  /// playback speed.
  List _trillShiftMap(Note note, Ornament ornament) {
    final first = ((ornament.shiftMap[0] as Map)['shift'] as num).toInt();
    final second = ((ornament.shiftMap[1] as Map)['shift'] as num).toInt();

    final measure = getMeasureAtTick(note.startTick);
    final bpm = getActiveTempoAtTick(note.startTick)?.tempo.value ?? 0;
    final beatTicks = measure.effectiveTempoBeat.ticks;

    int count;
    if (bpm <= 0 || beatTicks <= 0) {
      count = 8; // no tempo known — the old fixed 8-note trill
    } else {
      final seconds = note.durationTicks / beatTicks * 60.0 / bpm;
      count = (seconds / trillNoteSeconds).round();
    }
    // A trill ALWAYS ends on the note's own pitch (shift 0):
    // - if the trill alternates with the main note, the number of parts
    //   is chosen so that the last one is the main note;
    // - if neither of its two pitches is the main note itself, one
    //   part of the main pitch is added at the end.
    // (The last part also takes any ticks left over when the note
    // can't be divided exactly — see displayNotes.)
    final endsOnFirst = first == 0;
    final endsOnSecond = second == 0 && !endsOnFirst;
    final addMainAtEnd = !endsOnFirst && !endsOnSecond;

    count = count.clamp(2, _maxTrillNotes);
    if (endsOnFirst && count.isEven) count += 1; // odd: ends on first
    if (endsOnSecond && count.isOdd) count += 1; // even: ends on second
    // Never shorter than one tick per short note (keeping the parity
    // that makes the trill end on the main pitch).
    while (count > 3 && count > note.durationTicks) {
      count -= 2;
    }
    final alternating = addMainAtEnd ? count - 1 : count;

    return [
      for (int i = 0; i < alternating; i++)
        {'coeff': 1.0, 'shift': i.isEven ? first : second},
      if (addMainAtEnd) {'coeff': 1.0, 'shift': 0},
    ];
  }

  List<({Note note, bool isGhost, bool isClickable, Note? interactionNote, int shift})>
  get displayNotes {
    final result =
    <({Note note, bool isGhost, bool isClickable, Note? interactionNote, int shift})>[];

    for (final note in notes) {
      final ornament = note.ornament;
      if (ornament == null || ornament.shiftMap.isEmpty) {
        result.add((
        note: note,
        isGhost: false,
        isClickable: true,
        interactionNote: note,
        shift: 0,
        ));
        continue;
      }

      // shiftMap coefficients are trusted to describe RELATIVE
      // proportions, not necessarily ones that already sum to exactly
      // 1 (e.g. the trill entries sum to 0.5 as authored) — normalize
      // so the ghost sequence always exactly fills the original
      // note's duration regardless of what the raw coefficients add
      // up to.
      // Trills are rebuilt from the note's real length (see
      // _trillShiftMap) so every trill alternates at the same speed;
      // every other ornament uses its own shiftMap as before.
      final shiftMap = _isTrill(ornament)
          ? _trillShiftMap(note, ornament)
          : ornament.shiftMap;

      final totalCoeff = shiftMap.fold<double>(
        0.0,
            (sum, e) => sum + ((e as Map)['coeff'] as num).toDouble(),
      );
      if (totalCoeff <= 0) {
        result.add((
        note: note,
        isGhost: false,
        isClickable: true,
        interactionNote: note,
        shift: 0,
        ));
        continue;
      }

      // Whole ticks for every part. When the note can't be divided
      // exactly (e.g. a trill or tremolo of 8 parts on a 12-tick
      // note), every part gets its share rounded DOWN and the VERY
      // LAST part takes the ticks left over — so the extra length is
      // always at the end of the ornament, never a longer part
      // somewhere in the middle.
      final partTicks = <int>[];
      int usedTicks = 0;
      for (int i = 0; i < shiftMap.length; i++) {
        final coeff =
            ((shiftMap[i] as Map)['coeff'] as num).toDouble() / totalCoeff;
        final ticks = i == shiftMap.length - 1
            ? note.durationTicks - usedTicks
            : (note.durationTicks * coeff + 1e-9).floor();
        partTicks.add(ticks);
        usedTicks += ticks;
      }

      int runningTick = note.startTick;
      for (int i = 0; i < shiftMap.length; i++) {
        final entry = shiftMap[i] as Map;
        final shift = (entry['shift'] as num).toInt();

        final startTickRounded = runningTick;
        final subDuration = partTicks[i];
        runningTick += subDuration;
        if (subDuration <= 0) continue;

        // Only the ornament's unaltered/base-pitch entries (raw
        // shift == 0) are clickable — an ornament note actually
        // altered in pitch (shift != 0) is display-only.
        final isClickable = shift == 0;

        // Row stays the note's own, UNCHANGED row — no walking here.
        // The ghost's own `.accidental` field is left null (rather
        // than baking the raw shift into it) since nothing reads it
        // anymore for display or sound purposes — see the getter's
        // doc comment above and interactionNote below, which is what
        // both NoteBlockWidget and playback actually use.
        final ghost = note.copyWith(
          id: note.id * 100 + i,
          startTick: startTickRounded,
          durationTicks: subDuration,
          row: note.row,
          accidental: null,
          ornament: null,
        );

        result.add((
        note: ghost,
        isGhost: true,
        isClickable: isClickable,
        // Always the REAL underlying note (not just when clickable):
        // both NoteBlockWidget's display computation and playback
        // need the actual note — including its own accidental — to
        // get this ghost's pitch right, regardless of whether this
        // particular ghost happens to be the clickable one.
        interactionNote: note,
        shift: shift,
        ));
      }
    }
    return result;
  }

  List<String> get availableScales => [
    'do major',
    'do sharp major',
    're flat major',
    're major',
    'mi flat major',
    'mi major',
    'fa major',
    'fa sharp major',
    'sol flat major',
    'sol major',
    'la flat major',
    'la major',
    'si flat major',
    'si major',

    'do minor',
    'do sharp minor',
    're minor',
    're sharp minor',
    'mi flat minor',
    'mi minor',
    'fa minor',
    'fa sharp minor',
    'sol minor',
    'sol sharp minor',
    'la flat minor',
    'la minor',
    'la sharp minor',
    'si flat minor',
    'si minor',
  ];

  get dynamicChangeEvents => null;

  String getScaleAsTextArray(String scale) {
    List<String> scaleArray = ScaleResolver.getScale(scale);
    return scaleArray.join(' ');
  }


  /// Each tap moves every measure's scale one step up the chromatic
  /// circle from wherever it currently is — landing on the next
  /// *defined* scale for that mode (major/minor), skipping any
  /// enharmonic spelling that has no scale defined for it.
  /// Net rows each note has been shifted by raiseAllScales/
  /// lowerAllScales since the last commit/reset, keyed by note id.
  /// Tracked per-note (not as one global counter) because a shift only
  /// happens for notes in a measure whose scale root LETTER actually
  /// changed that round — see [_shiftNotesForScaleChange] — so
  /// different notes can accumulate different amounts, including notes
  /// added partway through a sequence of raises/lowers.
  final Map<int, int> _noteRowShiftLog = {};

  /// Each note's accidental before the first raise/lower (since the
  /// last commit/reset), keyed by note id — [_keepIntervals] may change
  /// accidentals, and [resetAllScales] puts them back.
  final Map<int, Accidental?> _noteAccidentalLog = {};

  /// Every note's sounding pitch (semitones), for [_keepIntervals].
  Map<int, int> _soundingSemitones() => {
    for (final n in notes)
      if (_semitonesForRowAndAccidental(
        row: n.row,
        startTick: n.startTick,
        accidental: getEffectiveAccidental(n),
      ) case final int st)
        n.id: st,
  };

  /// After the scales (and note rows) moved by [direction] semitones:
  /// every note must sound exactly [direction] semitones from where it
  /// sounded before ([before]), so the distances between the notes stay
  /// the same. Where the new scale doesn't give that by itself (a
  /// natural sign, a degree the new scale alters differently…), the
  /// note gets the accidental that does. Notes are fixed in time order,
  /// because an accidental also holds for the later notes of its row in
  /// the measure.
  void _keepIntervals(Map<int, int> before, int direction) {
    final order = [for (int i = 0; i < notes.length; i++) i]
      ..sort((a, b) {
        final c = notes[a].startTick.compareTo(notes[b].startTick);
        return c != 0 ? c : notes[a].id.compareTo(notes[b].id);
      });
    int? soundingNow(int i) => _semitonesForRowAndAccidental(
      row: notes[i].row,
      startTick: notes[i].startTick,
      accidental: getEffectiveAccidental(notes[i]),
    );
    for (final i in order) {
      final note = notes[i];
      final was = before[note.id];
      if (was == null) continue;
      final target = was + direction;
      if (soundingNow(i) == target) continue;
      final original = note.accidental;
      // Try: no accidental of its own, then each sign.
      Accidental? found;
      var ok = false;
      for (final candidate in <Accidental?>[null, ...Accidental.values]) {
        notes[i] = note.copyWith(accidental: candidate);
        if (soundingNow(i) == target) {
          found = candidate;
          ok = true;
          break;
        }
      }
      if (!ok) {
        notes[i] = note.copyWith(accidental: original);
        continue;
      }
      _noteAccidentalLog.putIfAbsent(note.id, () => original);
      notes[i] = note.copyWith(accidental: found);
    }
  }

  void raiseAllScales(){
    final before = _soundingSemitones();
    final oldScaleNames = measures.map((m) => m.scaleName).toList();
    for(int i = 0; i < measures.length; i++){
      measures[i] = measures[i].copyWith(
        scaleName: ScaleResolver.transposeScale(
          measures[i].scaleName,
          1,
        ),
      );
    }
    _shiftNotesForScaleChange(oldScaleNames, 1);
    _keepIntervals(before, 1);
    notifyListeners();
  }


  /// Same as [raiseAllScales] but one step down instead of up.
  void lowerAllScales(){
    final before = _soundingSemitones();
    final oldScaleNames = measures.map((m) => m.scaleName).toList();
    for(int i = 0; i < measures.length; i++){
      measures[i] = measures[i].copyWith(
        scaleName: ScaleResolver.transposeScale(
          measures[i].scaleName,
          -1,
        ),
      );
    }
    _shiftNotesForScaleChange(oldScaleNames, -1);
    _keepIntervals(before, -1);
    notifyListeners();
  }

  /// Shifts each note by [direction] (+1 or -1) ONLY if the root
  /// LETTER of its measure's scale actually changed this round — i.e.
  /// the scale's first word (do/re/mi/fa/sol/la/si) differs between
  /// [oldScaleNames] (what each measure's scale was before this
  /// change, indexed the same as [measures]) and that measure's scale
  /// now. A pure sharp/flat respelling of the same letter (e.g. "re
  /// flat major" -> "re major") keeps the note on the same staff
  /// position, so no shift; an actual letter change (e.g. "do major"
  /// -> "re flat major") does. Every shift applied is logged per note
  /// id in [_noteRowShiftLog] so [resetAllScales] can undo exactly
  /// what each individual note actually experienced.
  void _shiftNotesForScaleChange(List<String> oldScaleNames, int direction) {
    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      final measureIndex = measures.indexWhere(
            (m) => note.startTick >= m.startTick && note.startTick < m.endTick,
      );
      if (measureIndex == -1 || measureIndex >= oldScaleNames.length) continue;

      final oldRoot = _scaleFirstWord(oldScaleNames[measureIndex]);
      final newRoot = _scaleFirstWord(measures[measureIndex].scaleName);
      if (oldRoot == newRoot) continue; // same letter — no shift

      final newRow = (note.row + direction).clamp(0, totalRows - 1);
      if (newRow != note.row) {
        notes[i] = note.copyWith(row: newRow);
        _noteRowShiftLog[note.id] = (_noteRowShiftLog[note.id] ?? 0) + direction;
      }
    }
  }

  /// The scale's root letter alone (do/re/mi/fa/sol/la/si), stripped
  /// of any sharp/flat and mode — used only to detect an actual letter
  /// change vs a same-letter respelling in [_shiftNotesForScaleChange].
  String _scaleFirstWord(String scaleName) {
    final normalized = ScaleResolver.normalizeScaleName(scaleName);
    final spaceIndex = normalized.indexOf(' ');
    return spaceIndex == -1 ? normalized : normalized.substring(0, spaceIndex);
  }


  /// Restores every measure's scale back to whatever it was originally
  /// created with (or last deliberately picked via the scale selector),
  /// and restores every note to the row it had before any
  /// raiseAllScales/lowerAllScales drift — using each note's own
  /// logged shift, not a single global amount, so this stays correct
  /// even for notes added partway through a sequence of raises/lowers.
  void resetAllScales(){
    for(int i = 0; i < measures.length; i++){
      measures[i] = measures[i].copyWith(
        scaleName: measures[i].originalScaleName,
      );
    }
    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      final shift = _noteRowShiftLog[note.id];
      if (shift != null && shift != 0) {
        final restoredRow = (note.row - shift).clamp(0, totalRows - 1);
        notes[i] = note.copyWith(row: restoredRow);
      }
      // The accidentals added to keep the distances between notes.
      if (_noteAccidentalLog.containsKey(note.id)) {
        notes[i] = notes[i].copyWith(accidental: _noteAccidentalLog[note.id]);
      }
    }
    _noteRowShiftLog.clear();
    _noteAccidentalLog.clear();
    notifyListeners();
  }


  /// Indices of every measure whose current scale no longer matches
  /// what it was originally created with / last deliberately picked —
  /// i.e. it's been raised/lowered since then. Used to warn before
  /// saving.
  List<int> measuresWithScaleDrift() {
    final indices = <int>[];
    for (int i = 0; i < measures.length; i++) {
      if (measures[i].scaleName != measures[i].originalScaleName) {
        indices.add(i);
      }
    }
    return indices;
  }

  /// How many semitones up (positive) or down (negative) measure
  /// [index]'s current scale sits relative to its original scale. Both
  /// scales are assumed to share the same mode (raise/lower never
  /// changes major↔minor), so this is just the shortest signed
  /// distance between their roots on that mode's 12-slot chromatic
  /// circle.
  int semitoneDeltaForMeasure(int index) {
    if (index < 0 || index >= measures.length) {
      return 0;
    }
    return ScaleResolver.semitoneDelta(
      measures[index].originalScaleName,
      measures[index].scaleName,
    );
  }

  /// Whether ANY measure's current scale sits ABOVE (raised from) its
  /// own original scale — used to color the Raise Scale toolbar icon
  /// blue, per request. Checks every measure's own
  /// [semitoneDeltaForMeasure] rather than just the first, since
  /// [raiseAllScales]/[lowerAllScales] apply uniformly to every
  /// measure together, but an individual measure's own scale picker
  /// ([updateMeasureScale]) can independently reset just THAT
  /// measure's drift back to zero, leaving the rest of the
  /// composition still raised/lowered.
  bool get isScaleRaised {
    for (int i = 0; i < measures.length; i++) {
      if (semitoneDeltaForMeasure(i) > 0) return true;
    }
    return false;
  }

  /// Same as [isScaleRaised] but for the LOWERED direction — used to
  /// color the Lower Scale toolbar icon blue.
  bool get isScaleLowered {
    for (int i = 0; i < measures.length; i++) {
      if (semitoneDeltaForMeasure(i) < 0) return true;
    }
    return false;
  }

  /// Accepts every measure's current (possibly raised/lowered) scale as
  /// the new baseline — i.e. "Reset Scales" will no longer undo it, and
  /// it won't be flagged as drift again on the next save.
  void commitScaleChanges() {
    for (int i = 0; i < measures.length; i++) {
      measures[i] = measures[i].copyWith(
        originalScaleName: measures[i].scaleName,
      );
    }
    _noteRowShiftLog.clear();
    _noteAccidentalLog.clear();
    notifyListeners();
  }


  // =====================================================
  // COPY / PASTE
  // =====================================================


  String noteNumber (Note note) {
    return '${getMeasureNumber(note).toString()} '
        '${getBeatNumber(note).toString()} '
        '${getOctave(note).toString()} '
        '${getDegree(note)}';
  }

  void pasteNoteAt(
      int tick,
      int row,
      ) {
    if(copiedNote == null) {
      return;
    }
    final newNote = copiedNote!.copyWith(
      id: generateNoteId(),
      startTick: snapTick(tick),
      row: row,
    );
    final overlaps = notes.any((note) {
      if(note.row != row) {
        return false;
      }
      return newNote.startTick <
          note.endTick &&
          newNote.endTick >
              note.startTick;
    },
    );
    if(overlaps) {
      return;
    }
    notes.add(newNote);
    playNoteSound(newNote);
    // pasteMode = false;
    notifyListeners();
  }


  void copyNote(Note note){
    copiedNote = note.copyWith();
    notifyListeners();
  }

  void enterPasteMode(){
    if(copiedNote != null){
      pasteMode = true;
      notifyListeners();
    }
  }

  void exitPasteMode(){
    pasteMode = false;
    notifyListeners();
  }

  // =====================================================
  // SETTINGS
  // =====================================================


  void setDuration(
      NoteDuration duration,
      ){
    currentDuration = duration;
    notifyListeners();
  }

  void setGridResolution(
      NoteDuration duration,
      ){
    gridResolution = duration;
    notifyListeners();
  }



  void toggleHand(){
    currentHand = currentHand == Hand.right
        ? Hand.left
        : Hand.right;
    notifyListeners();
  }


  // =====================================================
  // COMPOSITION REPLACEMENT
  // =====================================================

  // ================= RED PEN (marks to check later) =================

  /// While on, one finger draws red marks on the grid instead of
  /// scrolling or editing (see InkLayer in ink_layer_widget.dart).
  bool penMode = false;

  /// While Pen mode is on: true = the finger erases marks it touches.
  bool inkEraser = false;

  /// Strokes in the order they were drawn, for Undo.
  final List<InkStroke> _inkHistory = [];

  void togglePenMode() {
    penMode = !penMode;
    inkEraser = false;
    notifyListeners();
  }

  void setInkEraser(bool value) {
    inkEraser = value;
    notifyListeners();
  }

  int get inkStrokeCount =>
      measures.fold(0, (sum, m) => sum + m.inkStrokes.length);

  /// Every mark as absolute grid points (dx = tick, dy = row).
  List<List<Offset>> get absoluteInkStrokes => [
    for (final m in measures)
      for (final s in m.inkStrokes)
        [for (final p in s.points) Offset(p.dx + m.startTick, p.dy)],
  ];

  /// Saves a finished stroke given in absolute grid points
  /// (dx = tick, dy = row) into the measure where it starts.
  void addInkStroke(List<Offset> absolutePoints) {
    if (absolutePoints.isEmpty || measures.isEmpty) return;
    final startTick = absolutePoints.first.dx;
    var index = measures.indexWhere(
          (m) => startTick >= m.startTick && startTick < m.endTick,
    );
    if (index < 0) index = startTick < 0 ? 0 : measures.length - 1;
    final measure = measures[index];
    final stroke = InkStroke([
      for (final p in absolutePoints)
        Offset(p.dx - measure.startTick, p.dy),
    ]);
    measure.inkStrokes.add(stroke);
    _inkHistory.add(stroke);
    notifyListeners();
  }

  /// Erases every mark passing within [radiusPx] screen pixels of
  /// [absolutePoint] (dx = tick, dy = row). Returns true if any was
  /// erased.
  bool eraseInkAt(
      Offset absolutePoint, {
        required double pixelsPerTick,
        required double cellHeight,
        double radiusPx = 22,
      }) {
    final target = Offset(
      absolutePoint.dx * pixelsPerTick,
      absolutePoint.dy * cellHeight,
    );
    bool erased = false;
    for (final m in measures) {
      m.inkStrokes.removeWhere((stroke) {
        final px = [
          for (final p in stroke.points)
            Offset(
              (p.dx + m.startTick) * pixelsPerTick,
              p.dy * cellHeight,
            ),
        ];
        final hit = _strokeNear(px, target, radiusPx);
        if (hit) {
          _inkHistory.remove(stroke);
          erased = true;
        }
        return hit;
      });
    }
    if (erased) {
      // Nothing left to erase — back to the pen.
      if (inkStrokeCount == 0) inkEraser = false;
      notifyListeners();
    }
    return erased;
  }

  static bool _strokeNear(List<Offset> pts, Offset target, double radius) {
    if (pts.isEmpty) return false;
    if (pts.length == 1) return (pts.first - target).distance <= radius;
    for (int i = 0; i + 1 < pts.length; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      double t = 0;
      if (len2 > 0) {
        final ap = target - a;
        t = ((ap.dx * ab.dx + ap.dy * ab.dy) / len2).clamp(0.0, 1.0);
      }
      final closest = a + ab * t;
      if ((closest - target).distance <= radius) return true;
    }
    return false;
  }

  /// Removes the most recently drawn mark that still exists.
  void undoLastInk() {
    while (_inkHistory.isNotEmpty) {
      final last = _inkHistory.removeLast();
      for (final m in measures) {
        if (m.inkStrokes.remove(last)) {
          notifyListeners();
          return;
        }
      }
    }
  }

  bool get canUndoInk => _inkHistory.isNotEmpty;

  void clearAllInk() {
    for (final m in measures) {
      m.inkStrokes.clear();
    }
    _inkHistory.clear();
    inkEraser = false;
    notifyListeners();
  }

  void updateComposition(
      Composition newComposition,
      ){
    composition = newComposition;
    selectedMeasureIndex = 0;
    _inkHistory.clear();
    repairTempoBeats();
    warmUpSounds();
    notifyListeners();
  }

}


/// The four kinds of reprise (see the Repeats dialog).
enum RepriseType { simple, voltas, segnoFine, segnoCoda }

/// One reprise, read from the signs on the measures. All positions are
/// 0-based measure positions (edit mode).
class Reprise {
  final RepriseType type;

  /// simple / voltas: 𝄆 at [start], 𝄇 at [end] (the end of volta 1).
  final int? start;
  final int? end;

  /// voltas: volta 1 is [volta1Start]..[end], volta 2 is
  /// [end] + 1..[volta2End].
  final int? volta1Start;
  final int? volta2End;

  /// segnoFine / segnoCoda.
  final int? segno;
  final int? fine;
  final int? toCoda;
  final int? dalSegno;
  final int? coda;

  Reprise(
      this.type, {
        this.start,
        this.end,
        this.volta1Start,
        this.volta2End,
        this.segno,
        this.fine,
        this.toCoda,
        this.dalSegno,
        this.coda,
      });
}

enum _TemporaryEventKind { tempo, dynamic, dynamicChange }

/// An event added only while the reprises are played out.
class _TemporaryEvent {
  final _TemporaryEventKind kind;
  int tick;
  final DynamicChange? change;
  _TemporaryEvent(this.kind, this.tick, [this.change]);
}