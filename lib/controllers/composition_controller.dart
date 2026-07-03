import 'package:flutter/foundation.dart';
import '../models/composition.dart';
import '../models/note.dart';
import '../enums/hand.dart';
import '../utils/scale_resolver.dart';

class CompositionController extends ChangeNotifier {
  final Composition composition;

  CompositionController(this.composition);

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
    //major
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
    //minor
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
    'minor B'
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

  // ================= GRID =================
  int get maxRows => composition.numberOfOctaves * 7;
  int get maxBeats =>
      composition.numberOfMeasures *
          composition.beatsPerMeasure;

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

  // ================= NOTES =================
  final List<Note> notes = [];

  void addNote({required int beat, required int row}) {
    notes.add(
      Note(
        row: row.clamp(0, maxRows),
        startBeat: beat.clamp(0, maxBeats),
        duration: 1,
        hand: currentHand,
      ),
    );
    notifyListeners();
  }

  void removeNote(Note note) {
    notes.remove(note);
    notifyListeners();
  }

  Note? getNoteAt(int beat, int row) {
    try {
      return notes.firstWhere(
            (n) => n.startBeat == beat && n.row == row,
      );
    } catch (_) {
      return null;
    }
  }

  void updateNote(Note note, int newBeat, int newRow) {
    final index = notes.indexOf(note);
    if (index == -1) return;

    notes[index] = Note(
      row: newRow.clamp(0, maxRows),
      startBeat: newBeat.clamp(0, maxBeats),
      duration: note.duration,
      hand: note.hand,
    );

    notifyListeners();
  }

  void clearAll() {
    notes.clear();
    notifyListeners();
  }
}