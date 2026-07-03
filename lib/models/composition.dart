import 'note.dart';

class Composition {
  final String title;
  final int numberOfMeasures;
  final int beatsPerMeasure;
  final int numberOfOctaves;

  final List<Note> notes;

  Composition({
    required this.title,
    required this.numberOfMeasures,
    required this.beatsPerMeasure,
    required this.numberOfOctaves,
    required this.notes,
  });
}