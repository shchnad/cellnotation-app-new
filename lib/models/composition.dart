import '../models/note.dart';
import '../models/timeline.dart';
import 'dynamic_event.dart';
import 'tempo_event.dart';

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
  final List<TempoEvent> tempoEvents;
  final List<DynamicEvent> dynamicEvents;

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
    List<TempoEvent>? tempoEvents,
    List<DynamicEvent>? dynamicEvents,
  })  : createdAt = createdAt ?? DateTime.now(),
        editedAt = editedAt ?? DateTime.now(),
        tempoEvents = tempoEvents ?? [],
        dynamicEvents = dynamicEvents ?? [];

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
    List<TempoEvent>? tempoEvents,
    List<DynamicEvent>? dynamicEvents,
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
      tempoEvents: tempoEvents ?? this.tempoEvents,
      dynamicEvents: dynamicEvents ?? this.dynamicEvents,
    );
  }
}