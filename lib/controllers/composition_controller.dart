import 'package:flutter/foundation.dart';

import '../models/composition.dart';
import '../models/note.dart';
import '../models/measure.dart';
import '../models/time_signature.dart';

import '../enums/hand.dart';
import '../enums/note_duration.dart';

import '../utils/scale_resolver.dart';


class CompositionController extends ChangeNotifier {
  Composition composition;

  CompositionController(this.composition);

  int _nextNoteId = 1;
  int _generateNoteId() => _nextNoteId++;


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
}