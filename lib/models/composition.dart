import '../models/note.dart';
import '../models/timeline.dart';
import 'dynamic_event.dart';
import 'tempo_event.dart';

class Composition {
  final String? id; // Firestore document ID — null until first save
  final String title;
  final String composer;
  final String style;
  final String instrument;
  final String userId; // Firebase Auth UID
  final DateTime createdAt;
  final DateTime editedAt;
  final int numberOfOctaves;

  // Internal backing field for your mutable scaleName parameter
  String _scaleName;

  final Timeline timeline;
  final List<Note> notes;
  final List<TempoEvent> tempoEvents;
  final List<DynamicEvent> dynamicEvents;

  Composition({
    this.id,
    required this.title,
    required this.composer,
    required this.style,
    required this.instrument,
    required this.userId,
    DateTime? createdAt,
    DateTime? editedAt,
    required this.numberOfOctaves,
    required String scaleName,
    required this.timeline,
    required this.notes,
    List<TempoEvent>? tempoEvents,
    List<DynamicEvent>? dynamicEvents,
  })  : createdAt = createdAt ?? DateTime.now(),
        editedAt = editedAt ?? DateTime.now(),
        tempoEvents = tempoEvents ?? [],
        dynamicEvents = dynamicEvents ?? [],
        _scaleName = scaleName;

  // The Explicit Getter
  String get scaleName => _scaleName;

  // The Explicit Setter
  set scaleName(String newScale) {
    _scaleName = newScale;
  }

  Composition copyWith({
    String? id,
    String? title,
    String? composer,
    String? style,
    String? instrument,
    String? userId,
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
      id: id ?? this.id,
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

  // ================= JSON =================

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'composer': composer,
      'style': style,
      'instrument': instrument,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'editedAt': editedAt.toIso8601String(),
      'numberOfOctaves': numberOfOctaves,
      'scaleName': scaleName,
      'timeline': timeline.toJson(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'tempoEvents': tempoEvents.map((t) => t.toJson()).toList(),
      'dynamicEvents': dynamicEvents.map((d) => d.toJson()).toList(),
    };
  }

  factory Composition.fromJson(Map<String, dynamic> json, {String? id}) {
    return Composition(
      id: id,
      title: json['title'] as String,
      composer: json['composer'] as String,
      style: json['style'] as String,
      instrument: json['instrument'] as String,
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      editedAt: DateTime.parse(json['editedAt'] as String),
      numberOfOctaves: json['numberOfOctaves'] as int,
      scaleName: json['scaleName'] as String,
      timeline: Timeline.fromJson(json['timeline'] as Map<String, dynamic>),
      notes: (json['notes'] as List<dynamic>)
          .map((n) => Note.fromJson(n as Map<String, dynamic>))
          .toList(),
      tempoEvents: (json['tempoEvents'] as List<dynamic>)
          .map((t) => TempoEvent.fromJson(t as Map<String, dynamic>))
          .toList(),
      dynamicEvents: (json['dynamicEvents'] as List<dynamic>)
          .map((d) => DynamicEvent.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}