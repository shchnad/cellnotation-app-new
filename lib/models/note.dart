import '../enums/hand.dart';

class Note {
  final int row;

  final int startTick;
  final int durationTicks;

  final Hand hand;

  const Note({
    required this.row,
    required this.startTick,
    required this.durationTicks,
    required this.hand,
  });
}