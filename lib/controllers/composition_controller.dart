import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:music_composer/enums/articulation.dart';
import 'package:music_composer/utils/default_values.dart';

import '../enums/accidental.dart';
import '../enums/dynamic_change.dart';
import '../enums/finger.dart';
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
  /// Measure" action.
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

  /// The absolute frequency (Hz) [note] should sound at: the scale
  /// degree's own +/- alteration (from the measure's current scale
  /// pattern) combined with whichever accidental is actually in effect
  /// on that row at this point in the measure (see
  /// [getEffectiveAccidental]), then shifted by octave. See
  /// [_referenceFrequencyC4] for the tuning reference this is built on.
  double getNoteFrequencyHz(Note note) {
    final measure = getMeasureAtTick(note.startTick);
    final shiftedScale = ScaleResolver.transposeScale(
      measure.scaleName,
      measure.pitchOffsetSemitones,
    );
    final scale = ScaleResolver.getScale(shiftedScale);
    if (scale.isEmpty) {
      return 0;
    }

    final degreeIndex = note.row % scale.length;
    final degreeToken = scale[degreeIndex];

    final effectiveAccidental = getEffectiveAccidental(note);

    // A natural cancels ANY alteration in effect for this note — that
    // includes one baked into the scale itself for this degree, not
    // just a previous accidental. So unlike a normal +/- (which is
    // additive on top of the scale's own sign), natural forces the
    // scale's contribution to 0 rather than adding 0 to it.
    int scaleAlteration = 0;
    if (effectiveAccidental != Accidental.natural) {
      if (degreeToken.endsWith('+')) {
        scaleAlteration = 1;
      } else if (degreeToken.endsWith('-')) {
        scaleAlteration = -1;
      }
    }

    final naturalSemitone = _naturalDegreeSemitones[
    degreeIndex % _naturalDegreeSemitones.length];

    final accidentalShift = effectiveAccidental != null
        ? (_accidentalSemitoneShift[effectiveAccidental.sign] ?? 0)
        : 0;

    final octaveShift = (getOctave(note) - 4) * 12;

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
  /// tick) can trigger it.
  void playNoteSound(Note note) {
    if (!soundEnabled) return;
    NoteSoundService.instance.playTone(
      frequencyHz: getNoteFrequencyHz(note),
      durationSeconds: getNoteDurationSeconds(note),
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


  /// Whether notes are currently shown in "compensated" notation — see
  /// [getCompensatedDisplay]. Purely a display switch: toggling this
  /// never touches note.row or note.accidental, so switching back to
  /// normal notation is instant and lossless.
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

  /// The pitch label to actually display for [note]: under compensated
  /// notation this is the full computed word from
  /// [getCompensatedDisplay] — e.g. scale sign "1+" plus accidental "+"
  /// becomes "2", or "1+" plus accidental "-" stays "1" at the same
  /// row. Outside compensated mode it's just the plain scale label for
  /// the row (e.g. "4+"); the accidental itself is drawn separately by
  /// the caller in that mode.
  String getDisplayPitchLabel(Note note) {
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
  ({int row, String label}) getCompensatedDisplay(Note note) {
    final effectiveAccidental = getEffectiveAccidental(note);
    final measure = getMeasureAtTick(note.startTick);

    // A natural cancels ANY alteration in effect — the scale's own
    // sign for this degree included, not just the accidental itself —
    // same as getNoteFrequencyHz treats it. So regardless of what the
    // scale says for this row (5+, 5-, or plain), a natural always
    // displays as the plain digit at the note's own row.
    if (effectiveAccidental == Accidental.natural) {
      return (
      row: note.row,
      label: _stripSign(getPitchNameForRow(note.row, measure)),
      );
    }

    final shiftedScale = ScaleResolver.transposeScale(
      measure.scaleName,
      measure.pitchOffsetSemitones,
    );
    final scale = ScaleResolver.getScale(shiftedScale);
    if (scale.isEmpty) {
      return (row: note.row, label: getPitchNameForRow(note.row, measure));
    }

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

    final walked = _walkToRow(note.row, scaleAlteration + accidentalShift);
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

  /// The single-accidental equivalent of a leftover semitone amount
  /// after [_walkToRow] — same representable range as
  /// [_signStringFor], returning null (no accidental) for 0 or for
  /// anything too large to represent as one sign.
  Accidental? _accidentalForShift(int remainingShift) {
    return switch (remainingShift) {
      1 => Accidental.sharp,
      2 => Accidental.doubleSharp,
      -1 => Accidental.flat,
      -2 => Accidental.doubleFlat,
      _ => null,
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

  /// The notes to actually draw on the grid right now. Normally just
  /// [notes] itself — but under compensated notation, any note
  /// carrying an [Ornament] (see Ornament.shiftMap) is expanded into
  /// the short sequence of display-only "ghost" notes its shiftMap
  /// describes: one ghost per shiftMap entry, `coeff` scaling that
  /// ghost's slice of the original note's duration and `shift` giving
  /// its pitch offset in semitones from the original (walked to a row
  /// + leftover accidental the same way [getCompensatedDisplay] does).
  /// Ghosts are marked (isGhost: true) so NoteBlockWidget can render
  /// them literally — using their own precomputed row/accidental
  /// directly — rather than running them back through the normal
  /// note/measure lookups, which wouldn't find them since they were
  /// never added to [notes]. The real note's own startTick/
  /// durationTicks/row/ornament are never touched; this is purely a
  /// read-only view, same as every other compensated-notation
  /// computation, and playback always uses the real [notes] list
  /// regardless of this.
  List<({Note note, bool isGhost})> get displayNotes {
    if (!showCompensatedNotation) {
      return [for (final n in notes) (note: n, isGhost: false)];
    }

    final result = <({Note note, bool isGhost})>[];
    for (final note in notes) {
      final ornament = note.ornament;
      if (ornament == null || ornament.shiftMap.isEmpty) {
        result.add((note: note, isGhost: false));
        continue;
      }

      double runningTick = note.startTick.toDouble();
      for (int i = 0; i < ornament.shiftMap.length; i++) {
        final entry = ornament.shiftMap[i] as Map;
        final coeff = (entry['coeff'] as num).toDouble();
        final shift = (entry['shift'] as num).toInt();

        final rawDuration = note.durationTicks * coeff;
        final startTickRounded = runningTick.round();
        final endTickRounded = (runningTick + rawDuration).round();
        final subDuration = endTickRounded - startTickRounded;
        runningTick += rawDuration;
        if (subDuration <= 0) continue;

        final walked = _walkToRow(note.row, shift);
        result.add((
        note: note.copyWith(
          id: note.id * 100 + i,
          startTick: startTickRounded,
          durationTicks: subDuration,
          row: walked.row,
          accidental: _accidentalForShift(walked.remainingShift),
          ornament: null,
        ),
        isGhost: true,
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