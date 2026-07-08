import 'package:flutter/foundation.dart';

import '../models/composition.dart';
import '../models/note.dart';
import '../models/measure.dart';
import '../models/time_signature.dart';

import '../enums/hand.dart';
import '../enums/note_duration.dart';

import '../utils/scale_resolver.dart';


class CompositionController extends ChangeNotifier {

  Composition composition; // Controller receives composition.

  // ======= NOTES ID CREATION ========================

  int _nextNoteId = 1;

  int _generateNoteId() {
    return _nextNoteId++;
  }

  // Looks at existing notes. Finds the highest ID.
  // Starts creating new notes from the next number.
  CompositionController(this.composition) {
    if (composition.notes.isNotEmpty) {
      _nextNoteId = composition.notes
          .map((n) => n.id)
          .reduce((a, b) => a > b ? a : b) +
          1;
    }
  }

  // ================= DURATION (UI STATE) =================

  NoteDuration currentDuration = NoteDuration.quarter;

  void setDuration(NoteDuration d) {
    currentDuration = d;
    notifyListeners();
  }

  // ================= HAND =================

  Hand currentHand = Hand.right;

  void toggleHand() {
    currentHand = currentHand == Hand.right
        ? Hand.left
        : Hand.right;
    notifyListeners();
  }

  // ================= SCALE =================

  final List<String> availableScales = [
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
    'minor G',
    'minor G sharp',
    'minor A flat',
    'minor A',
    'minor A sharp',
    'minor B flat',
    'minor B',
  ];

  int _scaleIndex = 0;

  String get scaleName => availableScales[_scaleIndex];

  List<String> get currentScale =>
      ScaleResolver.getScale(scaleName);

  String getDegree(int row) {
    final scale = currentScale;
    if (scale.isEmpty) return '';
    return scale[row % scale.length];
  }

  void setScale(int index) {
    _scaleIndex = index;
    notifyListeners();
  }

  void nextScale() {
    _scaleIndex = (_scaleIndex + 1) % availableScales.length;
    notifyListeners();
  }

  void previousScale() {
    _scaleIndex =
        (_scaleIndex - 1 + availableScales.length) %
            availableScales.length;
    notifyListeners();
  }

  int get maxTicks => composition.timeline.totalTicks;
  int get maxRows => composition.numberOfOctaves * 7;

  List<Measure> get measures => composition.timeline.measures;

  Set<int> get barLines =>
      composition.timeline.measures
          .map((m) => m.startTick)
          .toSet();

  int get totalTicks => composition.timeline.totalTicks;

  bool isBarLine(int tick) => barLines.contains(tick);

  void addMeasure(TimeSignature sig) {
    composition.timeline.addMeasure(sig);
    notifyListeners();
  }

  void insertMeasure(int index, TimeSignature sig) {
    composition.timeline.insertMeasure(index, sig);
    notifyListeners();
  }

  void deleteMeasure(int index) {
    composition.timeline.deleteMeasure(index);
    notifyListeners();
  }

  void changeSignature(int index, TimeSignature sig) {
    composition.timeline.changeSignature(index, sig);
    notifyListeners();
  }

  // ================= ZOOM =================

  double zoomX = 1.0;
  double zoomY = 1.0;

  void setZoom(double zx, double zy) {
    zoomX = zx.clamp(0.5, 3.0);
    zoomY = zy.clamp(0.5, 3.0);
    notifyListeners();
  }

  void resetZoom() {
    zoomX = 1.0;
    zoomY = 1.0;
    notifyListeners();
  }
 // ======= CELL WIDTH =================================

  double _gridScale = 1.0;

  double get gridScale => _gridScale;

  void setGridScale(double value) {
    _gridScale = value.clamp(0.125, 4.0);
    notifyListeners();
  }

// ================= NOTE INFORMATION =================

  int getOctave(Note note) {
    return (note.row ~/ 7) + 1;
  }

  int getMeasureNumber(Note note) {
    final measures = composition.timeline.measures;
    for (int i = 0; i < measures.length; i++) {
      final current = measures[i];
      final nextStart = i + 1 < measures.length
          ? measures[i + 1].startTick
          : composition.timeline.totalTicks;
      if (note.startTick >= current.startTick &&
          note.startTick < nextStart) {
        return i + 1; // user display starts from measure 1
      }
    }
    return 1;
  }


  int getBeatNumber(Note note) {
    final measures = composition.timeline.measures;
    for (int i = 0; i < measures.length; i++) {
      final measure = measures[i];
      final nextStart = i + 1 < measures.length
          ? measures[i + 1].startTick
          : composition.timeline.totalTicks;
      if (note.startTick >= measure.startTick &&
          note.startTick < nextStart) {
        final tickInsideMeasure =
            note.startTick - measure.startTick;
        return (tickInsideMeasure ~/
            measure.timeSignature.ticksPerBeat)
            + 1;
      }
    }
    return 1;
  }

  String durationLabel(Note note) {
    switch (note.durationTicks) {
      case 1:
        return '1/16';
      case 2:
        return '1/8';
      case 4:
        return '1/4';
      case 8:
        return '1/2';
      case 16:
        return '1';
      default:
        return '';
    }
  }

  // ================= NOTES (TICK-BASED) =================

  List<Note> get notes => composition.notes;

  void addNote({
    required int row,
    required int tick,
  }) {
    composition.notes.add(
      Note(
        id: _generateNoteId(),
        row: row,
        startTick: tick,
        durationTicks: currentDuration.ticks,
        hand: currentHand,
      ),
    );
    notifyListeners();
  }

  void removeNote(Note note) {
    composition.notes.remove(note);
    notifyListeners();
  }

  Note? getNoteAt(int tick, int row) {
    try {
      return composition.notes.firstWhere(
            (n) => n.startTick == tick && n.row == row,
      );
    } catch (_) {
      return null;
    }
  }

  void updateNote(Note note, int newTick, int newRow) {
    final index = composition.notes.indexOf(note);
    if (index == -1) return;
    composition.notes[index] = note.copyWith(
      startTick: newTick,
      row: newRow,
    );

    notifyListeners();
  }

  void clearAll() {
    composition.notes.clear();
    notifyListeners();
  }


  // ======= COPY AND PASTE NOTE =================

  Note? copiedNote;
  bool pasteMode = false;
  bool get canPaste => copiedNote != null;

  void copyNote(Note note) {
    copiedNote = note.copyWith();
  }

  void enterPasteMode() {
    if (copiedNote == null) return;
    pasteMode = true;
    notifyListeners();
  }

  void exitPasteMode() {
    pasteMode = false;
    notifyListeners();
  }

  void pasteNote({
    required int tick,
    required int row,
  }) {
    if (copiedNote == null) return;
    notes.add(
      copiedNote!.copyWith(
        id: _generateNoteId(),
        startTick: tick,
        row: row,
      ),
    );
    notifyListeners();
  }

// REPLACE NOTE

  void replaceNote(
      Note oldNote,
      Note newNote,
      ) {
    final index =
    notes.indexOf(oldNote);
    if (index == -1) return;
    notes[index] = newNote;
    notifyListeners();
  }

}