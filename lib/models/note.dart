class Note {
  final int row;

  final int startBeat;
  final int duration;

  const Note({
    required this.row,
    required this.startBeat,
    required this.duration,
  });

  Note copyWith({
    int? row,
    int? startBeat,
    int? duration,
  }) {
    return Note(
      row: row ?? this.row,
      startBeat: startBeat ?? this.startBeat,
      duration: duration ?? this.duration,
    );
  }
}