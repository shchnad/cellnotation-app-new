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
  final String userName;
  final DateTime createdAt;
  final DateTime editedAt;
  final int numberOfOctaves;
  final bool isPublic;
  final List<String> likedBy;

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
    this.userName = 'Unknown',
    DateTime? createdAt,
    DateTime? editedAt,
    required this.numberOfOctaves,
    this.isPublic = false,
    List<String>? likedBy,
    required String scaleName,
    required this.timeline,
    required this.notes,
    List<TempoEvent>? tempoEvents,
    List<DynamicEvent>? dynamicEvents,
  })  : createdAt = createdAt ?? DateTime.now(),
        editedAt = editedAt ?? DateTime.now(),
        tempoEvents = tempoEvents ?? [],
        dynamicEvents = dynamicEvents ?? [],
        likedBy = likedBy ?? [],
        _scaleName = scaleName;

  // The Explicit Getter
  String get scaleName => _scaleName;

  // The Explicit Setter
  set scaleName(String newScale) {
    _scaleName = newScale;
  }

  int get likeCount => likedBy.length;

  bool isLikedBy(String? userId) =>
      userId != null && likedBy.contains(userId);

  Composition copyWith({
    String? id,
    String? title,
    String? composer,
    String? style,
    String? instrument,
    String? userId,
    String? userName,
    DateTime? createdAt,
    DateTime? editedAt,
    int? numberOfOctaves,
    bool? isPublic,
    List<String>? likedBy,
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
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      numberOfOctaves: numberOfOctaves ?? this.numberOfOctaves,
      isPublic: isPublic ?? this.isPublic,
      likedBy: likedBy ?? this.likedBy,
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
      'userName': userName,
      'createdAt': createdAt.toIso8601String(),
      'editedAt': editedAt.toIso8601String(),
      'numberOfOctaves': numberOfOctaves,
      'isPublic': isPublic,
      'likedBy': likedBy,
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
      userName: json['userName'] as String? ?? 'Unknown',
      createdAt: DateTime.parse(json['createdAt'] as String),
      editedAt: DateTime.parse(json['editedAt'] as String),
      numberOfOctaves: json['numberOfOctaves'] as int,
      isPublic: json['isPublic'] as bool? ?? false,
      likedBy: (json['likedBy'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
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