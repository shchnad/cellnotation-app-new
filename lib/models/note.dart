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
  //nullable
  final Finger? finger;
  final Accidental? accidental;
  final Ornament? ornament;
  final Articulation? articulation;
  final PlayingTechnique? playingTechnique;

  const Note({
    required this.id,
    required this.startTick,
    required this.durationTicks,
    required this.row,
    required this.hand,
    this.finger,
    this.accidental,
    this.ornament,
    this.articulation,
    this.playingTechnique,
  });

  // ================= COPY =================

  Note copyWith({
    int? id,
    int? startTick,
    int? durationTicks,
    int? row,
    Hand? hand,
    Object? finger = _keep,
    Object? accidental = _keep,
    Object? ornament = _keep,
    Object? articulation = _keep,
    Object? playingTechnique = _keep,
  }) {

    return Note(
      id: id ?? this.id,
      startTick: startTick ?? this.startTick,
      durationTicks: durationTicks ?? this.durationTicks,
      row: row ?? this.row,
      hand: hand ?? this.hand,
      finger: finger == _keep
          ? this.finger
          : finger as Finger?,
      accidental: accidental == _keep
          ? this.accidental
          : accidental as Accidental?,
      ornament: ornament == _keep
          ? this.ornament
          : ornament as Ornament?,
      articulation: articulation == _keep
          ? this.articulation
          : articulation as Articulation?,
      playingTechnique: playingTechnique == _keep
          ? this.playingTechnique
          : playingTechnique as PlayingTechnique?,
    );
  }

  static const Object _keep = Object();

  // ================= JSON =================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTick': startTick,
      'durationTicks': durationTicks,
      'row': row,
      'hand': hand.name,
      if (finger != null) 'finger': finger!.name,
      if (accidental != null) 'accidental': accidental!.name,
      if (ornament != null) 'ornament': ornament!.name,
      if (articulation != null) 'articulation': articulation!.name,
      if (playingTechnique != null) 'playingTechnique': playingTechnique!.name,
    };
  }




  // ================= FROM JSON =================


  factory Note.fromJson(
      Map<String, dynamic> json,
      ) {


    return Note(


      id:
      json['id'] as int,


      startTick:
      json['startTick'] as int,


      durationTicks:
      json['durationTicks'] as int,


      row:
      json['row'] as int,



      hand:
      Hand.values.byName(
        json['hand'],
      ),



      finger:
      json['finger'] == null
          ? null
          : Finger.values.byName(
        json['finger'],
      ),



      accidental:
      json['accidental'] == null
          ? null
          : Accidental.values.byName(
        json['accidental'],
      ),



      ornament:
      json['ornament'] == null
          ? null
          : Ornament.values.byName(
        json['ornament'],
      ),



      articulation:
      json['articulation'] == null
          ? null
          : Articulation.values.byName(
        json['articulation'],
      ),



      playingTechnique:
      json['playingTechnique'] == null
          ? null
          : PlayingTechnique.values.byName(
        json['playingTechnique'],
      ),


    );


  }


}