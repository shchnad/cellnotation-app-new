import '../enums/accidental.dart';
import '../enums/articulation.dart';
import '../enums/finger.dart';
import '../enums/glissando_direction.dart';
import '../enums/grace_note_type.dart';
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

  /// Set on the "anchor" note a glissando starts from — null means no
  /// glissando. Set via CompositionController.startGlissandoPick (which
  /// begins the "tap the grid to choose the end row" interaction) and
  /// CompositionController.finishGlissandoPick (which actually
  /// generates the run of notes and stamps this field on the anchor).
  /// Cleared (along with the generated run — see [glissandoSourceId])
  /// via CompositionController.clearNoteGlissando.
  final GlissandoDirection? glissando;

  /// Set ONLY on the auto-generated notes that make up a glissando
  /// run (see CompositionController.finishGlissandoPick) — never on
  /// an ordinary note, and never on the anchor note itself (the
  /// anchor instead carries [glissando]). Points back at the anchor
  /// note's [id], so the whole run can be found and removed together
  /// — e.g. when the glissando is cleared, or regenerated with a
  /// different direction/end row. A run note's pitch is always shown
  /// as the plain natural degree number (1-7) and sounds at the plain
  /// "white key" pitch for its row (see
  /// CompositionController.getWhiteKeyFrequencyHz /
  /// getDisplayPitchLabel) — deliberately ignoring the composition's
  /// scale and this note's own [accidental]/[row]'s scale-degree sign,
  /// the same way a piano glissando runs straight across the white
  /// keys regardless of key signature.
  final int? glissandoSourceId;

  /// Set ONLY on grace notes themselves (never on an ordinary note,
  /// and never on the anchor note they precede/follow). All of one
  /// anchor's grace notes share the SAME type at any given time —
  /// switching to a different type (see
  /// CompositionController.startAddingGraceNotes) deletes whatever
  /// grace notes were already there first, since a note can only have
  /// one type of grace note active at once. This grace note's own
  /// duration is always exactly [GraceNoteType.durationTicks] — a
  /// FIXED, absolute value (not a fraction of the anchor's own
  /// duration) — see CompositionController._redistributeGraceNotes /
  /// maxGraceNotesForType for the full placement and count-limiting
  /// logic.
  final GraceNoteType? graceNoteType;

  /// Set ONLY on the anchor note that grace notes precede or follow
  /// (see [graceIsAfter]) — null means this note currently has no
  /// grace notes. This note's own [durationTicks] as it was BEFORE
  /// any grace notes existed, captured once the first time a grace
  /// note is added (see CompositionController.startAddingGraceNotes)
  /// and never touched again afterward, even as [durationTicks]
  /// itself keeps shrinking with each grace note added. This is the
  /// fixed reference every grace note's own
  /// [GraceNoteType.durationDivisor] divides, and — combined with
  /// this note's own fixed endpoint (its end tick when [graceIsAfter]
  /// is false, its start tick when true — see [graceIsAfter]) — is
  /// what lets CompositionController._redistributeGraceNotes derive
  /// exactly where this note's other, moving endpoint originally was,
  /// so removing all its grace notes shifts it back with no drift.
  /// Cleared (along with every grace note — see [graceOfNoteId]) via
  /// CompositionController.clearAllGraceNotes, or automatically once
  /// the last grace note is individually deleted.
  final int? graceOriginalDurationTicks;

  /// Set ONLY on the anchor note, alongside
  /// [graceOriginalDurationTicks] (meaningless — and left at its
  /// default — on any note where that field is null). False (the
  /// default) places this anchor's grace notes BEFORE it, carved out
  /// of the START of its original span — its own END tick never
  /// moves. True places them AFTER it instead, carved out of the END
  /// of its original span — its own START tick never moves this time.
  /// Set once, the first time grace notes are started on this anchor
  /// (see CompositionController.startAddingGraceNotes), from whichever
  /// side was chosen there; switching to the OTHER side later is
  /// treated the same as switching [graceNoteType] — the existing
  /// group is cleared first, since a single anchor's grace notes are
  /// always all on the same side at once.
  final bool graceIsAfter;

  /// Set ONLY on grace notes themselves (never on an ordinary note,
  /// and never on the anchor note — the anchor instead carries
  /// [graceOriginalDurationTicks]/[graceIsAfter]). Points back at the
  /// anchor note's [id], so all of one note's grace notes can be
  /// found, redistributed, or removed together. A grace note is
  /// otherwise an entirely ordinary [Note] — same fields, same
  /// [note_dialog.dart] for editing — only its position/duration are
  /// managed automatically (see [graceNoteType]'s doc) rather than
  /// set directly by the person.
  final int? graceOfNoteId;

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
    this.glissando,
    this.glissandoSourceId,
    this.graceNoteType,
    this.graceOriginalDurationTicks,
    this.graceIsAfter = false,
    this.graceOfNoteId,
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
    Object? glissando = _keep,
    Object? glissandoSourceId = _keep,
    Object? graceNoteType = _keep,
    Object? graceOriginalDurationTicks = _keep,
    bool? graceIsAfter,
    Object? graceOfNoteId = _keep,
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
      glissando: glissando == _keep
          ? this.glissando
          : glissando as GlissandoDirection?,
      glissandoSourceId: glissandoSourceId == _keep
          ? this.glissandoSourceId
          : glissandoSourceId as int?,
      graceNoteType: graceNoteType == _keep
          ? this.graceNoteType
          : graceNoteType as GraceNoteType?,
      graceOriginalDurationTicks: graceOriginalDurationTicks == _keep
          ? this.graceOriginalDurationTicks
          : graceOriginalDurationTicks as int?,
      graceIsAfter: graceIsAfter ?? this.graceIsAfter,
      graceOfNoteId: graceOfNoteId == _keep
          ? this.graceOfNoteId
          : graceOfNoteId as int?,
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
      if (glissando != null) 'glissando': glissando!.name,
      if (glissandoSourceId != null) 'glissandoSourceId': glissandoSourceId,
      if (graceNoteType != null) 'graceNoteType': graceNoteType!.name,
      if (graceOriginalDurationTicks != null)
        'graceOriginalDurationTicks': graceOriginalDurationTicks,
      'graceIsAfter': graceIsAfter,
      if (graceOfNoteId != null) 'graceOfNoteId': graceOfNoteId,
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
  /// error. Returns null if [key] is absent/null.
  static int? _readIntOrNull(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw == null) return null;
    return (raw as num).toInt();
  }

  /// Same as [_readIntOrNull] but for a required field — throws (via
  /// the underlying cast) if [key] is genuinely absent, same as the
  /// original direct `as int` casts did.
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


      glissando:
      _enumByNameOrNull(GlissandoDirection.values, json['glissando']),


      glissandoSourceId:
      _readIntOrNull(json, 'glissandoSourceId'),


      graceNoteType:
      _enumByNameOrNull(GraceNoteType.values, json['graceNoteType']),


      graceOriginalDurationTicks:
      _readIntOrNull(json, 'graceOriginalDurationTicks'),


      graceIsAfter:
      json['graceIsAfter'] as bool? ?? false,


      graceOfNoteId:
      _readIntOrNull(json, 'graceOfNoteId'),


    );


  }


  // The final tick position where the note ends.
  int get endTick => startTick + durationTicks;

}