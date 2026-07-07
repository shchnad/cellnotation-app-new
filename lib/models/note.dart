import '../enums/accidental.dart';
import '../enums/articulation.dart';
import '../enums/finger.dart';
import '../enums/hand.dart';
import '../enums/ornament.dart';
import '../enums/playing_technique.dart';

class Note {
  final int id;
  final int startTick;
  final int durationTicks;
  final int row;

  final Hand hand;
  final Finger? finger;

  final Accidental accidental;
  final Ornament ornament;
  final Articulation articulation;
  final PlayingTechnique playingTechnique;

  const Note({
    required this.id,
    required this.startTick,
    required this.durationTicks,
    required this.row,
    required this.hand,
    this.finger,
    this.accidental = Accidental.none,
    this.ornament = Ornament.none,
    this.articulation = Articulation.none,
    this.playingTechnique = PlayingTechnique.none,
  });

  Note copyWith({
    int? startTick,
    int? durationTicks,
    int? row,
    Hand? hand,
    Finger? finger,
    Accidental? accidental,
    Ornament? ornament,
    Articulation? articulation,
    PlayingTechnique? playingTechnique,
  }) {
    return Note(
      id: id,
      startTick: startTick ?? this.startTick,
      durationTicks: durationTicks ?? this.durationTicks,
      row: row ?? this.row,
      hand: hand ?? this.hand,
      finger: finger ?? this.finger,
      accidental: accidental ?? this.accidental,
      ornament: ornament ?? this.ornament,
      articulation: articulation ?? this.articulation,
      playingTechnique: playingTechnique ?? this.playingTechnique,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTick': startTick,
      'durationTicks': durationTicks,
      'row': row,
      'hand': hand.name,
      'finger': finger?.name,
      'accidental': accidental.name,
      'ornament': ornament.name,
      'articulation': articulation.name,
      'playingTechnique': playingTechnique.name,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      startTick: json['startTick'],
      durationTicks: json['durationTicks'],
      row: json['row'],
      hand: Hand.values.byName(json['hand']),
      finger: json['finger'] == null
          ? null
          : Finger.values.byName(json['finger']),
      accidental: Accidental.values.byName(json['accidental']),
      ornament: Ornament.values.byName(json['ornament']),
      articulation: Articulation.values.byName(json['articulation']),
      playingTechnique:
      PlayingTechnique.values.byName(json['playingTechnique']),
    );
  }
}