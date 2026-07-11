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
  NoteDuration gridResolution = NoteDuration.sixteenth;

  // Visual zoom only
  double zoomX = 5.0;
  double zoomY = 1.0;
  double get pixelsPerTick => zoomX;

  double getCellHeight(BuildContext context) {
    final availableHeight =
        MediaQuery.of(context).size.height
            - kToolbarHeight;
    return (availableHeight / 28) * zoomY;
  }


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

  int get totalRows => composition.numberOfOctaves * 7;



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

  void addMeasure( TimeSignature signature, String scaleName,) {
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


  void addBeatToMeasure(int index){
    final measure = measures[index];
    measures[index] =
        measure.copyWith(
          timeSignature:
          measure.timeSignature.addBeat(),
        );
    timeline.rebuild();
    notifyListeners();
  }

  // =====================================================
  // GRID / SNAP
  // =====================================================


  int snapTick(int rawTick){
    final step = gridResolution.ticks;
    if(step <= 0){
      return rawTick;
    }
    return ((rawTick + step / 2) ~/ step) * step;
  }


  // =====================================================
  // NOTE CREATION
  // =====================================================

  void addNoteAtGridPosition(
      int tick,
      int row,
      ){
    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch,
      startTick: tick,
      durationTicks: currentDuration.ticks,
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

  int getOctave(Note note) {
    return note.row ~/ 7 + 1;
  }


  String getOctaveName(int octave) {
    switch (octave) {
      case 1:
        return 'Sub-contra';
      case 2:
        return 'Contra';
      case 3:
        return 'Great';
      case 4:
        return 'Small';
      case 5:
        return 'One-line';
      case 6:
        return 'Two-line';
      case 7:
        return 'Three-line';
      case 8:
        return 'Four-line';
      default:
        return '';
    }
  }
  // =====================================================
  // NOTE MOVEMENT
  // =====================================================

  void updateNote(
      Note oldNote,
      int newTick,
      int newRow,
      ){
    final index = composition.notes.indexWhere(
          (n)=>n.id == oldNote.id,
    );
    if(index == -1){
      return;
    }
    final updated =  oldNote.copyWith(
      startTick: newTick,
      row: newRow,
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


  void resetZoom(){
    zoomX = 100;
    zoomY = 1;
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