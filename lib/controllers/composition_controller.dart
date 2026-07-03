import 'package:flutter/foundation.dart';
import '../models/composition.dart';
import '../models/note.dart';
import '../enums/hand.dart';

class CompositionController extends ChangeNotifier {
  final Composition composition;
  CompositionController(this.composition);

  Hand currentHand = Hand.right;

  void toggleHand() {
    currentHand =
    currentHand == Hand.right ? Hand.left : Hand.right;
    notifyListeners();
  }

  // ---------------- GRID CONFIG ----------------

  int get maxRows => composition.numberOfOctaves * 7;
  int get maxBeats =>
      composition.numberOfMeasures * composition.beatsPerMeasure;


  // ---------------- ZOOM ----------------

  double zoomX = 1.0;
  double zoomY = 1.0;
  void setZoom(double zx, double zy) {
    zoomX = zx.clamp(0.5, 3.0);
    zoomY = zy.clamp(0.5, 3.0);
    notifyListeners();
  }


  double _baseZoomX = 1.0;
  double _baseZoomY = 1.0;

  void applyGestureZoom(double scale) {
    zoomX = (_baseZoomX * scale).clamp(0.5, 3.0);
    zoomY = (_baseZoomY * scale).clamp(0.5, 3.0);
    notifyListeners();
  }

  void zoomIn() => setZoom(zoomX + 0.1, zoomY + 0.1);
  void zoomOut() => setZoom(zoomX - 0.1, zoomY - 0.1);
  void resetZoom() => setZoom(1.0, 1.0);
  void commitZoom() {
    _baseZoomX = zoomX;
    _baseZoomY = zoomY;
  }


  // ---------------- NOTES (DAW SYSTEM) ----------------
  final List<Note> notes = [];

  void addNote({
    required int beat,
    required int row,
  }) {
    final note = Note(
      row: row,
      startBeat: beat,
      duration: 1,
      hand: currentHand, // IMPORTANT
    );
    notes.add(note);
    notifyListeners();
  }

  void removeNote(Note note) {
    notes.remove(note);
    notifyListeners();
  }

  //for analysis or playback
  List<Note> getNotesAtBeat(int beat) {
    return notes.where((n) => n.startBeat == beat).toList();
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

    final clampedBeat = newBeat.clamp(0, maxBeats);
    final clampedRow = newRow.clamp(0, maxRows);

    notes[index] = Note(
      row: clampedRow,
      startBeat: clampedBeat,
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