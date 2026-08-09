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

  /// Whether this note is played legato. Previously this lived as a
  /// value inside the [Articulation] enum (mutually exclusive with
  /// staccato/tenuto/marcato/accent/sforzando); it's now a separate,
  /// independent flag, so a note can be legato AND carry an
  /// articulation at the same time (e.g. a legato sforzando note).
  /// Toggled via CompositionController.toggleNoteLegato while Legato
  /// Mode is on (see CompositionController.legatoMode).
  final bool legato;

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
    this.legato = false,
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
    bool? legato,
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
      legato: legato ?? this.legato,
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
      'legato': legato,
    };
  }




  // ================= FROM JSON =================

  /// Looks up [raw] (expected to be the enum member's `.name` string,
  /// as written by [toJson]) in [values], returning null instead of
  /// throwing if it's missing or no longer matches any member —
  /// e.g. after an enum member gets renamed or removed following a
  /// code change, an OLDER saved composition may still reference the
  /// old name. Without this, [Enum.values.byName] throws
  /// ArgumentError for an unrecognized name, which — since this runs
  /// inside a Firestore snapshot's .map() in CompositionService —
  /// would crash the ENTIRE composition list stream, not just fail to
  /// load the one bad note. Losing just that one field (falling back
  /// to null/unset) is far preferable to that.
  static T? _enumByNameOrNull<T extends Enum>(List<T> values, dynamic raw) {
    if (raw == null) return null;
    try {
      return values.byName(raw as String);
    } catch (_) {
      return null;
    }
  }

  /// Reads [key] as an int, tolerating it having been stored as a
  /// double (Firestore's numeric type can vary depending on how a
  /// value was originally written) rather than throwing a type-cast
  /// error.
  static int _readInt(Map<String, dynamic> json, String key) {
    return (json[key] as num).toInt();
  }

  factory Note.fromJson(
      Map<String, dynamic> json,
      ) {


    return Note(


      id:
      _readInt(json, 'id'),


      startTick:
      _readInt(json, 'startTick'),


      durationTicks:
      _readInt(json, 'durationTicks'),


      row:
      _readInt(json, 'row'),



      hand:
      // hand is required/non-nullable, so an unrecognized or missing
      // value falls back to a sane default (right hand) rather than
      // having nothing to fall back to.
      _enumByNameOrNull(Hand.values, json['hand']) ?? Hand.right,



      finger:
      _enumByNameOrNull(Finger.values, json['finger']),



      accidental:
      _enumByNameOrNull(Accidental.values, json['accidental']),



      ornament:
      _enumByNameOrNull(Ornament.values, json['ornament']),



      articulation:
      _enumByNameOrNull(Articulation.values, json['articulation']),



      playingTechnique:
      _enumByNameOrNull(PlayingTechnique.values, json['playingTechnique']),


      legato:
      json['legato'] as bool? ?? false,


    );


  }


  // The final tick position where the note ends.
  int get endTick => startTick + durationTicks;

}