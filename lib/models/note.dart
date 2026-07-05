import '../enums/hand.dart';
import '../enums/finger.dart';
import '../enums/accidental.dart';
import '../enums/articulation.dart';
import '../enums/ornament.dart';
import '../enums/playing_technique.dart';
import '../enums/playing_technique.dart';

class Note {
  final int id;

  final int startTick;
  final int durationTicks;
  final int row;

  final Hand hand;

  final Accidental accidental;
  final Ornament ornament;
  final Articulation articulation;
  final PlayingTechnique playingTechnique;

  final Finger? finger;

  const Note({
    required this.id,
    required this.startTick,
    required this.durationTicks,
    required this.row,
    required this.hand,

    this.accidental = Accidental.none,
    this.ornament = Ornament.none,
    this.articulation = Articulation.none,
    this.playingTechnique = PlayingTechnique.none,

    this.finger,
  });

  Note copyWith({
    int? startTick,
    int? durationTicks,
    int? row,
    Hand? hand,
    Accidental? accidental,
    Ornament? ornament,
    Articulation? articulation,
    PlayingTechnique? playingTechnique,
    Finger? finger,
  }) {
    return Note(
      id: id,
      startTick: startTick ?? this.startTick,
      durationTicks: durationTicks ?? this.durationTicks,
      row: row ?? this.row,
      hand: hand ?? this.hand,
      accidental: accidental ?? this.accidental,
      ornament: ornament ?? this.ornament,
      articulation: articulation ?? this.articulation,
      playingTechnique: playingTechnique ?? this.playingTechnique,
      finger: finger ?? this.finger,
    );
  }
}