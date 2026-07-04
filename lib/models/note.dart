import '../enums/duration.dart';
import '../enums/hand.dart';

class Note {
  final int row;
  final int startBeat;
  final NoteDuration duration;
  final Hand hand;

  const Note({
    required this.row,
    required this.startBeat,
    required this.duration,
    required this.hand,
  });

  Note copyWith({
    int? row,
    int? startBeat,
    NoteDuration? duration,
    Hand? hand,
  }) {
    return Note(
      row: row ?? this.row,
      startBeat: startBeat ?? this.startBeat,
      duration: duration ?? this.duration,
      hand: hand ?? this.hand,
    );
  }
}