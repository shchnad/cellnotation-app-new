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
    final beatStart = measure.startTick +
        beatIndex * measure.timeSignature.ticksPerBeat;
    final beatEnd = beatStart +
        measure.timeSignature.ticksPerBeat;
    notes.removeWhere(
          (note) =>
      note.startTick >= beatStart &&
          note.startTick < beatEnd,
    );
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
    timeline.deleteMeasure(index);
    notes.removeWhere(
          (note) =>
      note.startTick >= startTick &&
          note.startTick < endTick,
    );
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
    final note = Note(
      id: generateNoteId(),
      startTick: tick,
      durationTicks:
      newDuration,
      row: row,
      hand: currentHand,
    );
    composition.notes.add(note);
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
    return 7 - (note.row ~/ 7);
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
    _replaceNote(
      note.copyWith(accidental: accidental),
    );
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


  /// Same lookup as [getNotePitchName] but for a bare grid row instead of
  /// an existing [Note] — used by the persistent pitch column, which
  /// shows the scale of [measure] (defaults to [currentMeasure]).
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
    return scale[row % scale.length];
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
  void raiseAllScales(){
    for(int i = 0; i < measures.length; i++){
      measures[i] = measures[i].copyWith(
        scaleName: ScaleResolver.transposeScale(
          measures[i].scaleName,
          1,
        ),
      );
    }
    notifyListeners();
  }


  /// Same as [raiseAllScales] but one step down instead of up.
  void lowerAllScales(){
    for(int i = 0; i < measures.length; i++){
      measures[i] = measures[i].copyWith(
        scaleName: ScaleResolver.transposeScale(
          measures[i].scaleName,
          -1,
        ),
      );
    }
    notifyListeners();
  }


  /// Restores every measure's scale back to whatever it was originally
  /// created with (or last deliberately picked via the scale selector),
  /// undoing any raiseAllScales/lowerAllScales drift.
  void resetAllScales(){
    for(int i = 0; i < measures.length; i++){
      measures[i] = measures[i].copyWith(
        scaleName: measures[i].originalScaleName,
      );
    }
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