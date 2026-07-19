import 'package:flutter/material.dart';
import 'package:music_composer/enums/articulation.dart';

import '../enums/accidental.dart';
import '../enums/finger.dart';
import '../enums/ornament.dart';
import '../enums/playing_technique.dart';
import '../models/composition.dart';
import '../models/note.dart';
import '../models/measure.dart';
import '../models/time_signature.dart';
import '../models/timeline.dart';

import '../enums/hand.dart';
import '../enums/note_duration.dart';

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
  NoteDuration currentDuration = NoteDuration.quarter;

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
    return measures[selectedMeasureIndex];
  }

  void updateCurrentMeasureScale(String newScaleName) {
    if (measures.isEmpty) return;
    final oldMeasure = currentMeasure;
    measures[selectedMeasureIndex] =
        oldMeasure.copyWith(
          scaleName: newScaleName,
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
            scaleName: newScaleName
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


  List<String> get availableScales => [
    'major C',
    'major C sharp',
    'major D flat',
    'major D',
    'major E flat',
    'major E',
    'major F',
    'major F sharp',
    'major G flat',
    'major G',
    'major A flat',
    'major A',
    'major B flat',

    'minor C',
    'minor C sharp',
    'minor D',
    'minor D sharp',
    'minor E flat',
    'minor E',
    'minor F',
    'minor F sharp',
    'minor G',
    'minor G sharp',
    'minor A flat',
    'minor A',
    'minor A sharp',
    'minor B flat',
    'minor B',
  ];

  String getScaleAsTextArray(String scale) {
    List<String> scaleArray = ScaleResolver.getScale(scale);
    return scaleArray.join(' ');
  }


  void raiseAllScales(){
    for(int i = 0; i < measures.length; i++){
      measures[i] = measures[i].copyWith(
        pitchOffsetSemitones:
        measures[i].pitchOffsetSemitones + 1,
      );
    }
    notifyListeners();
  }


  void lowerAllScales(){
    for(int i = 0; i < measures.length; i++){
      measures[i] = measures[i].copyWith(
        pitchOffsetSemitones:
        measures[i].pitchOffsetSemitones - 1,
      );
    }
    notifyListeners();
  }


  // =====================================================
  // COPY / PASTE
  // =====================================================

  String titleOfMessageDialog = 'Note copying';

  String instructionToCopy = 'Long-tap the note to copy it. \n\n '
      'You can paste it then where ever you wish as many times as you wish. \n\n'
      'To stop pasting toggle this button.';

  String noteNumber (Note note) {
    return '${getMeasureNumber(note).toString()} '
        '${getBeatNumber(note).toString()} '
        '${getOctave(note).toString()} '
        '${getNotePitchName(note)}';
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
    notifyListeners();
  }

}