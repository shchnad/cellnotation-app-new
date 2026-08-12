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
import '../enums/note_duration.dart';

import '../models/composition.dart';
import '../models/dynamic_event.dart';
import '../models/note.dart';
import '../models/measure.dart';
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
  });



  // =====================================================
  // EDITOR STATE
  // =====================================================

  Hand currentHand = Hand.right;

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


  int getMeasureNumber(Note note) {
    return measures.indexWhere( (m) =>
    note.startTick >= m.startTick && note.startTick < m.endTick,
    ) + 1;
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


  int getBeatTick(
      int measureIndex,
      int beatIndex,
      ) {
    if(measureIndex < 0 ||
        measureIndex >= measures.length){
      return 0;
    }
    final measure =
    measures[measureIndex];
    return measure.startTick +
        beatIndex *
            measure.timeSignature.ticksPerBeat;
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
    timeline.rebuild();
    notifyListeners();
  }


  /// Removes all notes inside the given beat WITHOUT deleting the beat
  /// itself (unlike [removeBeatFromMeasure], which also shrinks the
  /// measure). Use this for a "Clean Beat" action.
  void clearBeatNotes(
      int measureIndex,
      int beatIndex,
      ) {
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
          note.startTick < beatEnd,
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
  void clearMeasureNotes(
      int measureIndex,
      ) {
    if (measureIndex < 0 || measureIndex >= measures.length) {
      return;
    }
    final measure = measures[measureIndex];
    notes.removeWhere(
          (note) =>
      note.startTick >= measure.startTick &&
          note.startTick < measure.endTick,
    );
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



  void copyMeasure(
      int index,
      ) {
    if(index < 0 ||
        index >= measures.length){
      return;
    }
    final original =
    measures[index];
    final newStart = timeline.totalTicks;
    final copiedMeasure = original.copyWith(
      id: measures.length,
      startTick: newStart,
      beatEvents:
      original.beatEvents.map(
            (e)=>e.copyWith(
          tick: e.tick - original.startTick + newStart,
        ),
      ).toList(),
    );
    measures.add(copiedMeasure,);
    // copy notes inside measure
    final copiedNotes =
    notes.where( (note) =>
    note.startTick >= original.startTick &&
        note.startTick < original.endTick,
    )
        .map(
          (note) {
        return note.copyWith(
          id: generateNoteId(),
          startTick:  newStart + (note.startTick - original.startTick),
        );
      },
    )
        .toList();
    notes.addAll(
      copiedNotes,
    );
    timeline.rebuild();
    notifyListeners();
  }


  /// Duplicates every measure from [fromIndex] through [toIndex]
  /// (inclusive, 0-based) as one new contiguous block appended at the
  /// end of the composition — generalizes [copyMeasure] to a whole
  /// range instead of a single measure. [fromIndex]/[toIndex] are
  /// treated as (min, max) regardless of which is actually larger, so
  /// callers don't need to sort them first; out-of-range indices (or
  /// an empty composition) make this a no-op.
  ///
  /// Each measure in the range keeps its own time signature/scale and
  /// its own beatEvents (shifted by the same total offset as
  /// everything else). Every note whose startTick falls anywhere
  /// within the ORIGINAL range is copied too, shifted by that same
  /// offset, so the whole block lands intact at the end. Unlike
  /// [copyMeasure], this ALSO remaps [Note.glissandoSourceId] /
  /// [Note.graceOfNoteId] so that an anchor note and its own
  /// glissando run / grace notes — when BOTH are duplicated together
  /// within the same range — end up correctly pointing at each
  /// other's NEW copies rather than dangling back to the originals.
  /// (If only one half of such a pair falls inside the range, the
  /// copy's reference is left pointing at the original outside note,
  /// same as it always did — there's no other note in the new block
  /// for it to point at instead.)
  ///
  /// Like [copyMeasure], this does NOT duplicate any tempo/dynamic/
  /// dynamic-change events that happen to fall within the range.
  void duplicateMeasureRange(int fromIndex, int toIndex) {
    if (measures.isEmpty) return;
    final start = fromIndex <= toIndex ? fromIndex : toIndex;
    final end = fromIndex <= toIndex ? toIndex : fromIndex;
    if (start < 0 || end >= measures.length) return;

    final rangeStartTick = measures[start].startTick;
    final rangeEndTick = measures[end].endTick;
    // Computed once, before any measures are appended below — those
    // appends grow timeline.totalTicks, which this offset is derived
    // from, so it must be captured up front rather than recomputed
    // mid-loop.
    final offset = timeline.totalTicks - rangeStartTick;

    // Snapshot the range before mutating `measures` — appending to it
    // below would otherwise shift indices out from under an in-place
    // iteration.
    final originalRange = measures.sublist(start, end + 1).toList();
    for (final original in originalRange) {
      final newStart = original.startTick + offset;
      measures.add(original.copyWith(
        id: measures.length,
        startTick: newStart,
        beatEvents: original.beatEvents
            .map((e) => e.copyWith(tick: e.tick + offset))
            .toList(),
      ));
    }

    final originalNotesInRange = notes
        .where((note) =>
    note.startTick >= rangeStartTick && note.startTick < rangeEndTick)
        .toList();

    // Maps each duplicated note's OLD id to its brand-new copy's id
    // — used below to correctly relink glissando/grace-note
    // relationships that fall entirely within this range (see the
    // method doc above).
    final idMap = <int, int>{
      for (final note in originalNotesInRange) note.id: generateNoteId(),
    };

    final copiedNotes = originalNotesInRange.map((note) {
      final newGlissandoSourceId = note.glissandoSourceId == null
          ? null
          : (idMap[note.glissandoSourceId] ?? note.glissandoSourceId);
      final newGraceOfNoteId = note.graceOfNoteId == null
          ? null
          : (idMap[note.graceOfNoteId] ?? note.graceOfNoteId);
      return note.copyWith(
        id: idMap[note.id],
        startTick: note.startTick + offset,
        glissandoSourceId: newGlissandoSourceId,
        graceOfNoteId: newGraceOfNoteId,
      );
    }).toList();

    notes.addAll(copiedNotes);

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
  void clearMeasureRangeNotes(int fromIndex, int toIndex) {
    if (measures.isEmpty) return;
    final start = fromIndex <= toIndex ? fromIndex : toIndex;
    final end = fromIndex <= toIndex ? toIndex : fromIndex;
    if (start < 0 || end >= measures.length) return;
    for (int i = start; i <= end; i++) {
      clearMeasureNotes(i);
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

  void updateDynamicChangeEvent(
      int tick,
      DynamicChange dChange,
      ) {
    final index = timeline.dynamicChangeEvents.indexWhere(
          (e) => e.tick == tick,
    );
    if (index >= 0) {
      timeline.dynamicChangeEvents[index].dynamic_change = dChange;
    } else {
      timeline.addDynamicChangeEvent(
        DynamicChangeEvent(
          tick: tick,
          dynamic_change: dChange,
        ),
      );
    }
    notifyListeners();
  }

  void deleteDynamicChangeEvent(int tick) {
    timeline.removeDynamicChangeEvent(tick);
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
  // forward until the next one). They're kept independent everywhere
  // they're READ or DRAWN, though: GridPainter draws them as their
  // own thin red connecting line rather than the green crescendo/
  // diminuendo line, and dynamicChangeDialog's picker excludes them
  // entirely — pedal is only ever set via the single toggle button in
  // editMeasureBeatDialog (see [togglePedalAtTick]), never via that
  // dialog, so there's exactly one way to set it and no risk of the
  // two getting out of sync with each other.

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
    zoomX = x.clamp(20, 500);
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
      int row,
      ){
    final newDuration = currentDuration.ticks;
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
    final inherited = getEffectiveAccidental(note);
    if (inherited != null) {
      final index = composition.notes.indexWhere((n) => n.id == note.id);
      note = note.copyWith(accidental: inherited);
      composition.notes[index] = note;
    }
    playNoteSound(note);
    notifyListeners();
  }


  void removeNote(Note note){
    composition.notes.removeWhere(
          (n)=>n.id == note.id,
    );
    // If the removed note itself HAD grace notes (was an anchor —
    // see Note.graceOriginalDurationTicks, the anchor-only marker),
    // they no longer have a main note to precede — a grace note
    // without its main note doesn't make musical sense, so remove
    // them too rather than leaving them orphaned.
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


  void setNoteHand(
      Note note,
      Hand hand,
      ) {
    _replaceNote(
      note.copyWith(hand: hand),
    );
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


  // =====================================================
  // GLISSANDO
  // =====================================================

  // The note a glissando is currently being set up for, and which
  // direction was chosen — non-null while waiting for the person to
  // tap the grid to choose the end row (see [startGlissandoPick] /
  // [finishGlissandoPick]). Mirrors the existing copy/paste pattern
  // ([copiedNote]/[pasteMode]): a pending interaction that the next
  // relevant grid tap completes.
  Note? _pendingGlissandoNote;
  GlissandoDirection? _pendingGlissandoDirection;

  /// Whether the grid's next tap should be interpreted as choosing a
  /// glissando's end row (see [finishGlissandoPick]) rather than its
  /// normal behavior (creating a note, opening a label dialog, etc.).
  bool get isPickingGlissandoEndRow => _pendingGlissandoNote != null;

  /// Begins the "pick the end row" interaction for a glissando
  /// starting at [note] in [direction] — call this from wherever the
  /// direction is chosen (e.g. NoteDialog's Glissando field), then
  /// close any dialogs so the person can tap the target row on the
  /// grid. GridWidget checks [isPickingGlissandoEndRow] and routes
  /// its next tap to [finishGlissandoPick] instead of normal tap
  /// handling.
  void startGlissandoPick(Note note, GlissandoDirection direction) {
    _pendingGlissandoNote = note;
    _pendingGlissandoDirection = direction;
    notifyListeners();
  }

  /// Cancels a pending [startGlissandoPick] without generating
  /// anything — e.g. if the person wants to back out before tapping
  /// an end row.
  void cancelGlissandoPick() {
    _pendingGlissandoNote = null;
    _pendingGlissandoDirection = null;
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
  /// [endRow] INCLUSIVE. "Up" requires [endRow] to be above the
  /// anchor's row and "down" requires it to be below — an [endRow] on
  /// the wrong side (or equal to the anchor's own row) is rejected
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
    final direction = _pendingGlissandoDirection;
    if (pendingNote == null || direction == null) return null;

    if (endRow < 0 || endRow >= totalRows) {
      return 'That row is outside the grid';
    }

    final isUp = direction == GlissandoDirection.up;
    if (isUp && endRow <= pendingNote.row) {
      return 'Glissando Up needs an end row above the note';
    }
    if (!isUp && endRow >= pendingNote.row) {
      return 'Glissando Down needs an end row below the note';
    }

    final anchorIndex = notes.indexWhere((n) => n.id == pendingNote.id);
    if (anchorIndex == -1) {
      _pendingGlissandoNote = null;
      _pendingGlissandoDirection = null;
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
    _pendingGlissandoDirection = null;
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
  /// — whichever of the two limits is stricter wins.
  int maxGraceNotesForType(Note note, GraceNoteType type) {
    final originalDuration =
        note.graceOriginalDurationTicks ?? note.durationTicks;
    final perNote = type.durationTicksFor(originalDuration);
    if (perNote <= 0) return 0;
    final durationBasedMax = (originalDuration / perNote).floor();
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
  /// A note can only have ONE type of grace note active at a time —
  /// if [note] already has grace notes of a DIFFERENT type than
  /// [type], they're deleted first (which also reverts [note] back
  /// toward its original duration, via [_redistributeGraceNotes]'s
  /// zero-remaining case) before the new type takes over. Calling
  /// this again with the SAME type [note] already has just continues
  /// adding more of it — nothing is deleted in that case.
  ///
  /// The first time a grace note is EVER added to [note] (or
  /// immediately after switching types, since that clears it), its
  /// CURRENT durationTicks is captured into
  /// [Note.graceOriginalDurationTicks] and never touched again
  /// afterward — this is the fixed reference [maxGraceNotesForType]
  /// and [_redistributeGraceNotes] both use.
  void startAddingGraceNotes(Note note, GraceNoteType type) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;

    final existingGraceNotes =
    notes.where((n) => n.graceOfNoteId == note.id).toList();
    final existingType =
    existingGraceNotes.isNotEmpty ? existingGraceNotes.first.graceNoteType : null;

    if (existingType != null && existingType != type) {
      // Only one type of grace note allowed per note at a time —
      // switching types deletes whatever was there before. This also
      // reverts the note's own start/duration back toward its
      // original span, since there's nothing left of the old type to
      // make room for.
      notes.removeWhere((n) => n.graceOfNoteId == note.id);
      _redistributeGraceNotes(note.id);
    }

    final refreshedIndex = notes.indexWhere((n) => n.id == note.id);
    final refreshed = notes[refreshedIndex];
    if (refreshed.graceOriginalDurationTicks == null) {
      notes[refreshedIndex] = refreshed.copyWith(
        graceOriginalDurationTicks: refreshed.durationTicks,
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
  /// The grace region is carved out of the START of the anchor's own
  /// ORIGINAL span (see [Note.graceOriginalDurationTicks]) rather
  /// than the space before it: the anchor's end tick
  /// (startTick + durationTicks) never moves, no matter how many
  /// grace notes exist — only its start tick (and thus its own
  /// duration) shifts to make room, later as grace notes are added,
  /// back toward its original position as they're removed. The
  /// anchor's original start tick is DERIVED rather than stored
  /// separately: `(current end tick) - graceOriginalDurationTicks` —
  /// this is exactly right because the end tick is the one thing this
  /// method itself guarantees never changes, so it's always safe to
  /// read back from the anchor's current values, however many times
  /// this has already run.
  ///
  /// Every grace note's duration is always exactly its own
  /// [GraceNoteType.durationTicks] — a FIXED, absolute value that is
  /// NEVER shrunk or scaled, unlike an earlier design. Grace notes
  /// are placed back-to-back in the order they appear in [notes]
  /// (i.e. the order they were tapped in), earliest-tapped placed
  /// earliest in time. The anchor is still guaranteed at least 1 tick
  /// of its own duration — but if the grace notes' fixed total would
  /// leave less than that (which [maxGraceNotesForType] is meant to
  /// prevent at add-time, but this stays robust even if it somehow
  /// happens, e.g. the anchor's own duration changing by some other
  /// means afterward), the anchor's start is clamped rather than any
  /// grace note's duration being compressed — the last grace note(s)
  /// may then end after that clamped start, overlapping the anchor,
  /// which is accepted rather than fought.
  ///
  /// If NO grace notes remain (the last one was just removed), the
  /// anchor reverts exactly to its original start tick and duration,
  /// and [Note.graceOriginalDurationTicks] is cleared — there's
  /// nothing left for it to describe. A no-op if the anchor no longer
  /// exists or has no [Note.graceOriginalDurationTicks] (already
  /// fully reverted, or never had grace notes in the first place).
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

    // Never moves, by construction of this very method — safe to
    // treat as the fixed reference point regardless of how many times
    // this has already run for this anchor.
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
      );
      return;
    }

    int runningTick = originalStartTick;
    for (int k = 0; k < count; k++) {
      final idx = graceIndices[k];
      final graceType = notes[idx].graceNoteType;
      final fixedDuration =
          graceType?.durationTicksFor(originalDuration) ?? 1;
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
  /// and clears its [Note.graceOriginalDurationTicks]. Called from
  /// wherever the Grace Notes field's dialog offers a "Delete"/clear
  /// action.
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

  bool soundEnabled = true;

  void toggleSound() {
    soundEnabled = !soundEnabled;
    NoteSoundService.instance.enabled = soundEnabled;
    notifyListeners();
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
    final measure = getMeasureAtTick(startTick);
    final shiftedScale = ScaleResolver.transposeScale(
      measure.scaleName,
      measure.pitchOffsetSemitones,
    );
    final scale = ScaleResolver.getScale(shiftedScale);
    if (scale.isEmpty) {
      return 0;
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

    final totalSemitonesFromC4 =
        naturalSemitone + scaleAlteration + accidentalShift + octaveShift;

    return _referenceFrequencyC4 * math.pow(2, totalSemitonesFromC4 / 12);
  }

  /// How long [note] actually lasts in real time — same tempo/beat-unit
  /// formula the playback ticker uses, evaluated at the note's own
  /// start so it's correct even if tempo changes partway through.
  double getNoteDurationSeconds(Note note) {
    final measure = getMeasureAtTick(note.startTick);
    final activeTempo = getActiveTempoAtTick(note.startTick);
    final beatTicks = measure.timeSignature.beatDuration.ticks;
    final bpm = activeTempo?.tempo.value ?? 0;
    if (bpm <= 0 || beatTicks <= 0) {
      return 0.3; // sane fallback rather than dividing by zero
    }
    final ticksPerSecond = beatTicks * bpm / 60.0;
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
    if (!soundEnabled) return;
    final frequencyHz = note.glissandoSourceId != null
        ? getWhiteKeyFrequencyHz(note.row)
        : getNoteFrequencyHz(note);
    NoteSoundService.instance.playTone(
      frequencyHz: frequencyHz,
      durationSeconds: getNoteDurationSeconds(note),
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
    if (!soundEnabled) return;
    NoteSoundService.instance.playTone(
      frequencyHz: getOrnamentFrequencyHz(
        baseNote: baseNote,
        shift: shift,
      ),
      durationSeconds: getNoteDurationSeconds(ghost),
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
  bool inputLocked = false;

  void toggleInputLocked() {
    inputLocked = !inputLocked;
    notifyListeners();
  }

  /// When on, the pitch text drawn inside each note cell is rotated
  /// 90° — purely cosmetic, useful when cells are narrow (zoomed in
  /// tightly) and a vertical label reads more comfortably than a
  /// horizontal one squeezed into a thin box.
  bool rotatePitchText = false;

  void toggleRotatePitchText() {
    rotatePitchText = !rotatePitchText;
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
      final totalCoeff = ornament.shiftMap.fold<double>(
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

      double runningTick = note.startTick.toDouble();
      for (int i = 0; i < ornament.shiftMap.length; i++) {
        final entry = ornament.shiftMap[i] as Map;
        final coeff = (entry['coeff'] as num).toDouble() / totalCoeff;
        final shift = (entry['shift'] as num).toInt();

        final rawDuration = note.durationTicks * coeff;
        final startTickRounded = runningTick.round();
        final endTickRounded = (runningTick + rawDuration).round();
        final subDuration = endTickRounded - startTickRounded;
        runningTick += rawDuration;
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

  void raiseAllScales(){
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
    notifyListeners();
  }


  /// Same as [raiseAllScales] but one step down instead of up.
  void lowerAllScales(){
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
    }
    _noteRowShiftLog.clear();
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

  void updateComposition(
      Composition newComposition,
      ){
    composition = newComposition;
    selectedMeasureIndex = 0;
    notifyListeners();
  }

}