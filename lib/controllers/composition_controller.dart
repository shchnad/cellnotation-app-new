import 'package:flutter/foundation.dart';
import '../models/composition.dart';
import '../models/note.dart';

class CompositionController extends ChangeNotifier {
  final Composition composition;

  CompositionController(this.composition);

  // ---------------- ZOOM ----------------

  double zoomX = 1.0;
  double zoomY = 1.0;

  void setZoom(double zx, double zy) {
    zoomX = zx.clamp(0.5, 3.0);
    zoomY = zy.clamp(0.5, 3.0);
    notifyListeners();
  }

  //gesture-safe zoom function

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
    );
    notes.add(note);
    notifyListeners();
  }

  void removeNote(Note note) {
    notes.remove(note);
    notifyListeners();
  }

  List<Note> getNotesAtBeat(int beat) {
    return notes.where((n) => n.startBeat == beat).toList();
  }

  void clearAll() {
    notes.clear();
    notifyListeners();
  }
}