import 'note.dart';
import 'timeline.dart';

class Composition {
  final String title;
  final String composer;
  final String style;
  final String instrument;

  final int userId;

  final DateTime createdAt;
  final DateTime editedAt;

  final int numberOfOctaves;
  final String scaleName;

  final Timeline timeline;
  final List<Note> notes;

  Composition({
    required this.title,
    required this.composer,
    required this.style,
    required this.instrument,
    required this.userId,
    DateTime? createdAt,
    DateTime? editedAt,
    required this.numberOfOctaves,
    required this.scaleName,
    required this.timeline,
    required this.notes,
  })  : createdAt = createdAt ?? DateTime.now(),
        editedAt = editedAt ?? DateTime.now();

  Composition copyWith({
    String? title,
    String? composer,
    String? style,
    String? instrument,
    int? userId,
    DateTime? createdAt,
    DateTime? editedAt,
    int? numberOfOctaves,
    String? scaleName,
    Timeline? timeline,
    List<Note>? notes,
  }) {
    return Composition(
      title: title ?? this.title,
      composer: composer ?? this.composer,
      style: style ?? this.style,
      instrument: instrument ?? this.instrument,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      numberOfOctaves: numberOfOctaves ?? this.numberOfOctaves,
      scaleName: scaleName ?? this.scaleName,
      timeline: timeline ?? this.timeline,
      notes: notes ?? this.notes,
    );
  }
}