import '../enums/duration.dart';
import 'note.dart';

class Composition {
  final String title;
  final int numberOfMeasures;
  final int beatsPerMeasure;
  final int numberOfOctaves;
  final List<Note> notes;
  final String scaleName;

  final NoteDuration duration; // default tool setting

  Composition({
    required this.title,
    required this.numberOfMeasures,
    required this.beatsPerMeasure,
    required this.numberOfOctaves,
    required this.notes,
    required this.scaleName,
    this.duration = NoteDuration.quarter,
  });

  Composition copyWith({
    String? title,
    int? numberOfMeasures,
    int? beatsPerMeasure,
    int? numberOfOctaves,
    List<Note>? notes,
    String? scaleName,
    NoteDuration? duration,
  }) {
    return Composition(
      title: title ?? this.title,
      numberOfMeasures: numberOfMeasures ?? this.numberOfMeasures,
      beatsPerMeasure: beatsPerMeasure ?? this.beatsPerMeasure,
      numberOfOctaves: numberOfOctaves ?? this.numberOfOctaves,
      notes: notes ?? this.notes,
      scaleName: scaleName ?? this.scaleName,
      duration: duration ?? this.duration,
    );
  }
}