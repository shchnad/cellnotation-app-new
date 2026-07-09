import 'package:flutter/foundation.dart';
import 'package:music_composer/enums/articulation.dart';

import '../enums/accidental.dart';
import '../enums/finger.dart';
import '../enums/ornament.dart';
import '../enums/hand.dart';
import '../enums/note_duration.dart';
import '../enums/playing_technique.dart';

import '../models/composition.dart';
import '../models/note.dart';
import '../models/measure.dart';
import '../models/time_signature.dart';
import '../models/tempo_event.dart';

import '../utils/scale_resolver.dart';

import '../models/timeline.dart';

class CompositionController extends ChangeNotifier {
  Composition composition;

  CompositionController(this.composition) {
    if (composition.notes.isNotEmpty) {
      _nextNoteId = composition.notes
          .map((n) => n.id)
          .reduce((a, b) => a > b ? a : b) +
          1;
    }
  }

  // ================= NOTE ID =================

  int _nextNoteId = 1;

  int _generateNoteId() {
    return _nextNoteId++;
  }

  // ================= DURATION =================

  NoteDuration currentDuration = NoteDuration.quarter;

  void setDuration(NoteDuration duration) {
    currentDuration = duration;
    notifyListeners();
  }

  void setNoteDuration(Note note, NoteDuration duration) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;

    notes[index] = notes[index].copyWith(
      durationTicks: duration.ticks,
    );
    notifyListeners();
  }

  // ================= ORNAMENT =================

  void setNoteOrnament(Note note, Ornament? ornament) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;

    notes[index] = notes[index].copyWith(
      ornament: ornament,
    );
    notifyListeners();
  }

  // ================= FINGER =================

  void setNoteFinger(Note note, Finger? finger) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;

    notes[index] = notes[index].copyWith(
      finger: finger,
    );
    notifyListeners();
  }

  // ================= HAND =================

  Hand currentHand = Hand.right;

  void toggleHand() {
    currentHand = currentHand == Hand.right ? Hand.left : Hand.right;
    notifyListeners();
  }

  void setNoteHand(Note note, Hand hand) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    notes[index] = notes[index].copyWith(
      hand: hand,
    );
    notifyListeners();
  }

  // =========== ACCIDENTAL =============

  void setNoteAccidental(Note note, Accidental? accidental) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    notes[index] = notes[index].copyWith(
      accidental: accidental,
    );
    notifyListeners();
  }

  // ============ ARTICULATION ==========

  void setNoteArticulation(Note note, Articulation? articulation) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    notes[index] = notes[index].copyWith(
      articulation: articulation,
    );
    notifyListeners();
  }

  // ============ PLAYING TECHNIQUE ==========

  void setNotePlayingTechnique(Note note, PlayingTechnique? technique) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    notes[index] = notes[index].copyWith(
      playingTechnique: technique,
    );
    notifyListeners();
  }

  // ================= SCALE =================

  final List<String> availableScales = [
    'major C', 'major C sharp', 'major D flat', 'major D', 'major E flat',
    'major E', 'major F', 'major F sharp', 'major G flat', 'major G',
    'major A flat', 'major A', 'major B flat',
    'minor C', 'minor C sharp', 'minor D', 'minor D sharp', 'minor E flat',
    'minor E', 'minor F', 'minor G', 'minor G sharp', 'minor A flat',
    'minor A', 'minor A sharp', 'minor B flat', 'minor B',
  ];

  int _scaleIndex = 0;

  String get scaleName => availableScales[_scaleIndex];

  List<String> get currentScale => ScaleResolver.getScale(scaleName);

  String getDegree(int row) {
    final scale = currentScale;
    if (scale.isEmpty) return '';
    return scale[row % scale.length];
  }

  void setScale(int index) {
    if (index < 0 || index >= availableScales.length) return;
    _scaleIndex = index;
    notifyListeners();
  }

  void nextScale() {
    _scaleIndex = (_scaleIndex + 1) % availableScales.length;
    notifyListeners();
  }

  void previousScale() {
    _scaleIndex = (_scaleIndex - 1 + availableScales.length) % availableScales.length;
    notifyListeners();
  }

  // ================= TIMELINE =================

  Timeline get timeline => composition.timeline;

  int get maxTicks => timeline.totalTicks;

  int get maxRows => composition.numberOfOctaves * 7;

  List<Measure> get measures => timeline.measures;

  Set<int> get barLines => measures.map((m) => m.startTick).toSet();

  int get totalTicks => timeline.totalTicks;

  bool isBarLine(int tick) => barLines.contains(tick);

  void addMeasure(TimeSignature signature) {
    timeline.addMeasure(signature);
    notifyListeners();
  }

  void insertMeasure(int index, TimeSignature signature) {
    timeline.insertMeasure(index, signature);
    notifyListeners();
  }

  void deleteMeasure(int index) {
    timeline.deleteMeasure(index);
    notifyListeners();
  }

  void changeSignature(int index, TimeSignature signature) {
    timeline.changeSignature(index, signature);
    notifyListeners();
  }

  // ================= TEMPO TIMELINE OPERATIONS =================

  List<TempoEvent> get tempoEvents => timeline.tempoEvents;

  void addTempoEvent(TempoEvent event) {
    timeline.addTempoEvent(event);
    notifyListeners();
  }

  void removeTempoEvent(TempoEvent event) {
    timeline.removeTempoEvent(event);
    notifyListeners();
  }

  // ================= ZOOM =================

  double zoomX = 100.0;
  double zoomY = 1.0;

  void setZoom(double x, double y) {
    zoomX = x.clamp(20.0, 400.0);
    zoomY = y.clamp(0.5, 3.0);
    notifyListeners();
  }

  void resetZoom() {
    zoomX = 100.0;
    zoomY = 1.0;
    notifyListeners();
  }

  // ================= GRID =================

  double _gridScale = 1.0;

  double get gridScale => _gridScale;

  void setGridScale(double value) {
    _gridScale = value.clamp(0.125, 4.0);
    notifyListeners();
  }

  int snapTick(int rawTick) {
    final int stepTicks = currentDuration.ticks;
    if (stepTicks <= 0) return rawTick;
    return ((rawTick + stepTicks / 2) ~/ stepTicks) * stepTicks;
  }

  // ================= NOTE INFO =================

  int getOctave(Note note) => (composition.numberOfOctaves - 1) - (note.row ~/ 7);

  String getOctaveName(int octave) {
    switch (octave) {
      case 0: return 'Subcontra octave';
      case 1: return 'Contra octave';
      case 2: return 'Great octave';
      case 3: return 'Small octave';
      case 4: return '1st octave';
      case 5: return '2nd octave';
      case 6: return '3rd octave';
      case 7: return '4th octave';
      case 8: return '5th octave';
      default: return 'Octave $octave';
    }
  }

  int getMeasureNumber(Note note) {
    for (int i = 0; i < measures.length; i++) {
      final current = measures[i];
      final next = i + 1 < measures.length ? measures[i + 1].startTick : totalTicks;
      if (note.startTick >= current.startTick && note.startTick < next) {
        return i + 1;
      }
    }
    return 1;
  }

  int getBeatNumber(Note note) {
    for (final measure in measures) {
      final nextIndex = measures.indexOf(measure) + 1;
      final next = nextIndex < measures.length ? measures[nextIndex].startTick : totalTicks;

      if (note.startTick >= measure.startTick && note.startTick < next) {
        return ((note.startTick - measure.startTick) ~/ measure.timeSignature.ticksPerBeat) + 1;
      }
    }
    return 1;
  }

  String durationLabel(Note note) {
    return NoteDuration.values
        .firstWhere(
          (d) => d.ticks == note.durationTicks,
      orElse: () => NoteDuration.quarter,
    )
        .label;
  }

  // ================= NOTES =================

  List<Note> get notes => composition.notes;

  void addNote({required int row, required int tick}) {
    notes.add(
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
    notes.removeWhere((n) => n.id == note.id);
    notifyListeners();
  }

  Note? getNoteAt(int tick, int row) {
    try {
      return notes.firstWhere(
            (n) => row == n.row && tick >= n.startTick && tick < n.endTick,
      );
    } catch (_) {
      return null;
    }
  }

  void updateNote(Note note, int newTick, int newRow) {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;

    notes[index] = notes[index].copyWith(
      startTick: newTick,
      row: newRow,
    );
    notifyListeners();
  }

  void clearAll() {
    notes.clear();
    notifyListeners();
  }

  // ================= COPY PASTE =================

  Note? copiedNote;
  bool pasteMode = false;

  bool get canPaste => copiedNote != null;

  void copyNote(Note note) {
    copiedNote = note.copyWith();
  }

  void enterPasteMode() {
    if (!canPaste) return;
    pasteMode = true;
    notifyListeners();
  }

  void exitPasteMode() {
    pasteMode = false;
    notifyListeners();
  }

  void pasteNote({required int tick, required int row}) {
    if (!canPaste) return;

    notes.add(
      copiedNote!.copyWith(
        id: _generateNoteId(),
        startTick: tick,
        row: row,
      ),
    );
    notifyListeners();
  }

  void replaceNote(Note oldNote, Note newNote) {
    final index = notes.indexWhere((n) => n.id == oldNote.id);
    if (index == -1) return;

    notes[index] = newNote;
    notifyListeners();
  }
}