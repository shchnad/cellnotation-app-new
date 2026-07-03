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

  void zoomIn() => setZoom(zoomX + 0.1, zoomY + 0.1);

  void zoomOut() => setZoom(zoomX - 0.1, zoomY - 0.1);

  void resetZoom() => setZoom(1.0, 1.0);

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