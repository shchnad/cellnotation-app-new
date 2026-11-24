import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:music_composer/dialogs/save_exit_dialog.dart';
import 'package:music_composer/utils/default_values.dart';

import '../controllers/composition_controller.dart';

import '../models/note_import.dart';
import '../models/note.dart';
import '../models/measure.dart';

import '../dialogs/measure_range_dialog.dart';
import '../dialogs/go_to_measure_dialog.dart';
import '../dialogs/cell_width_dialog.dart';
import '../dialogs/scroll_speed_dialog.dart';
import '../dialogs/audio_hands_dialog.dart';
import '../dialogs/repeats_dialog.dart';
import '../dialogs/new_composition_dialog.dart';
import '../dialogs/global_duration_dialog.dart';
import '../dialogs/add_measures_dialog.dart';
import '../dialogs/hand_dialog.dart';

import '../dialogs/simple_message_dialog.dart';
import '../dialogs/edit_composition_dialog.dart';
import '../dialogs/scale_change_warning_dialog.dart';
import '../dialogs/sheet_music_transcription_dialog.dart';
import '../enums/hand.dart';
import '../enums/note_duration.dart';
import '../utils/cellnotation_transcription_parser.dart';

import '../services/composition_service.dart';
import '../services/note_sound_service.dart';
import '../widgets/grid_widget.dart';
import '../widgets/letter_name_column_widget.dart';
import '../widgets/pitch_column_widget.dart';
import '../widgets/transcription_column_widget.dart';


class CompositionScreen extends StatefulWidget {

  final CompositionController controller;


  const CompositionScreen({
    super.key,
    required this.controller,
  });

  @override
  State<CompositionScreen> createState() => _CompositionScreenState();
}

class _CompositionScreenState extends State<CompositionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  CompositionController get controller => widget.controller;

  final ScrollController _gridVerticalController = ScrollController();
  final ScrollController _pitchVerticalController = ScrollController();
  final ScrollController _transcriptionVerticalController = ScrollController();
  final ScrollController _letterNameVerticalController = ScrollController();

  final ScrollController _gridHorizontalController = ScrollController();

  Ticker? _playbackTicker;
  Duration _lastTickerElapsed = Duration.zero;
  double _playbackTick = 0;
  // Every note starting BEFORE this tick has already been sounded in
  // the current playback run. Advanced forward only — never re-checked
  // — so each note is triggered exactly once (the previous window math
  // could overlap two frames and play some notes twice).
  int _soundedUpToTick = 0;

  // ---- Playback caches (prepared once when the scrolling starts) ----
  /// All notes to play (ornaments expanded), sorted by start.
  List<({Note note, bool isGhost, bool isClickable, Note? interactionNote, int shift})>
  _playNotes = const [];
  /// The exact start of each note in [_playNotes] (in a split beat —
  /// triplet… — the exact column position, see
  /// CompositionController.displayTick).
  List<double> _playStarts = const [];
  /// The next note in [_playNotes] to sound / to highlight.
  int _soundIndex = 0;
  int _activeIndex = 0;
  /// Notes sounding now (for the green rows in the pitch column).
  final List<Note> _sounding = [];
  /// The measure playback was in at the last frame.
  Measure? _tickMeasure;

  /// Builds the playback caches from the current position.
  void _preparePlaybackCaches() {
    final list = controller.displayNotes.toList()
      ..sort((a, b) => a.note.startTick.compareTo(b.note.startTick));
    _playNotes = list;
    _playStarts = [for (final e in list) controller.displayTick(e.note.startTick)];
    _tickMeasure = null;
    _sounding.clear();
    int firstAtOrAfter(int tick) {
      int lo = 0, hi = list.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (list[mid].note.startTick < tick) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return lo;
    }
    final t = _playbackTick.floor();
    _soundIndex = firstAtOrAfter(_soundedUpToTick);
    // Notes that started before the position but still sound now.
    _activeIndex = firstAtOrAfter(t + 1);
    for (int i = 0; i < _activeIndex; i++) {
      final n = list[i].note;
      if (n.endTick > t) _sounding.add(n);
    }
  }
  bool _isPlaying = false;
  bool _toShowTitle = false;
  // Independent from _toShowTitle now, per request — previously the
  // letter-name and transcription columns appeared/disappeared
  // together with the title; a separate toggle (its own toolbar
  // icon, right under "Show Title") now controls them instead.
  bool _toShowReferenceColumns = false;

  // Anchors for the Hand/Note-Duration help labels — see
  // _toolbarLabel's doc. CompositedTransformTarget (wrapping each
  // icon) + CompositedTransformFollower (wrapping the label, placed
  // in an OUTER Stack on top of the whole Row) track the icon's real
  // rendered position regardless of the toolbar's own spaceEvenly
  // layout, and — critically — paint AFTER (on top of) the pitch
  // column/grid, which a plain Positioned overflowing the toolbar's
  // own 46px-wide Stack could not do (Row paints later siblings over
  // earlier ones' overflow, which is what was covering the labels).
  final LayerLink _handIconLink = LayerLink();
  final LayerLink _durationIconLink = LayerLink();
  final LayerLink _pasteIconLink = LayerLink();
  final LayerLink _graceNotesIconLink = LayerLink();

  // When on, tapping any toolbar icon shows a help dialog explaining
  // that button instead of performing its normal action. Toggled by
  // the new help icon below the theme-change icon.
  bool _helpMode = false;

  // Rows whose note is CURRENTLY sounding at the current playback
  // tick (startTick <= tick < endTick) — used to highlight those
  // rows green in the pitch column while a note is actively playing.
  // A ValueNotifier rather than a setState()-driving field: this
  // updates every single animation frame during playback, and a full
  // setState() at that frequency would rebuild this whole screen 60
  // times a second. PitchColumnWidget listens to this directly via
  // ValueListenableBuilder instead, so only IT rebuilds each frame.
  final ValueNotifier<Set<int>> _activeNoteRows = ValueNotifier<Set<int>>({});
  bool _pauseScheduled = false;

  // How many silent "ghost beats" of lead-in scroll through before
  // tick 0 (beat 1 of measure 1) actually reaches the pitch column,
  // when starting fresh from the beginning — per request, using the
  // SAME tempo/time-signature-paced scrolling as real playback (not
  // a fixed pause), so it visibly moves at the actual first
  // measure's speed rather than snapping or feeling arbitrary.
  static const int _ghostLeadInBeats = 4;

  // A NARROW, fixed leading gap — the SAME width regardless of which
  // composition is open (independent of its own tempo/time
  // signature/zoom) — shown by default (Scroll Lock off), including
  // right when a composition is first opened. This is the "resting"
  // width the grid always returns to once Scroll Lock is turned back
  // off, per request.
  static const double _narrowLeadingPadding = 20.0;

  // The WIDE "runway" leading space, sized to EXACTLY match
  // _ghostLeadInBeats worth of ticks in pixels — see GridWidget's own
  // leadingPadding doc. Deliberately varies from one composition to
  // another (a fixed BEAT count, not a fixed pixel width) — a fast
  // tempo, a different time signature, or a different zoom level all
  // naturally give this a different on-screen width, which is
  // expected: it needs to represent a consistent amount of musical
  // TIME to lead in with, not a consistent number of pixels. Only
  // applied while Scroll Lock is ON — see _effectiveLeadingPadding.
  // Updated every build(), since it depends on pixelsPerTick (zoom-
  // dependent) and the first measure's own ticksPerBeat.
  double _leadingPadding = 0;

  /// The leading padding actually applied right now — [_leadingPadding]
  /// (the wide, composition-dependent runway) while Scroll Lock is
  /// on, or [_narrowLeadingPadding] (the same narrow width for every
  /// composition) otherwise, including on first opening a
  /// composition — per request. Every place that reads a leading-
  /// padding value (scroll math, GridWidget's own prop) reads this,
  /// not [_leadingPadding] directly, so the whole screen stays
  /// internally consistent about how much leading space currently
  /// exists.
  double get _effectiveLeadingPadding =>
      controller.inputLocked ? _leadingPadding : _narrowLeadingPadding;

  // Tracks controller.inputLocked (Scroll Lock) across rebuilds so
  // build() can detect when it CHANGES (from any of the several
  // places that toggle it — the Scroll Lock button itself, Easy
  // Read, Help Mode, Rotate Pitch Text, or starting playback) and
  // re-anchor the scroll position afterward, since
  // _effectiveLeadingPadding's own width changes (narrow <-> runway)
  // exactly when this flips. Null until the very first build so that
  // build doesn't try to "correct" anything before there's a
  // previous value to compare against.
  bool? _lastKnownInputLocked;

  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      // Continuing by a tap on the screen: only a short pause.
      _startPlayback(delay: _tapStartPauseDuration);
    }
  }

  void _startPlayback({Duration delay = _startPauseDuration}) {
    if (controller.maxTicks <= 0) {
      return;
    }

    // Captured BEFORE toggling Scroll Lock below — the leading
    // padding's WIDTH tracks Scroll Lock (see
    // _effectiveLeadingPadding), and the grid widget tree hasn't
    // rebuilt with any new lock state yet at this point, so the
    // CURRENT scroll offset still means whatever it meant under the
    // OLD (pre-toggle) lock state.
    final hadWideLeadingPaddingBefore = controller.inputLocked;

    // Starting playback ("hitting the scroll icon") automatically
    // turns on Scroll Lock and Easy Read (Compensated Notation) if
    // they aren't already — per request. Scroll Lock being on is
    // what makes grid taps control playback pause/resume instead of
    // creating notes (see GridWidget's isPlaying parameter below);
    // neither is turned back off automatically on pause — they stay
    // on (and their icons stay red) until explicitly toggled off via
    // their own buttons, which is what actually returns the grid to
    // normal editing.
    // Easy Read is switched on only when playback starts from edit
    // mode (Scroll Lock still off). After that it is yours to switch
    // off and on (its icon) — continuing after a pause (tap) leaves it
    // as you set it.
    if (!controller.inputLocked) {
      controller.toggleInputLocked();
      if (!controller.showCompensatedNotation) {
        controller.toggleCompensatedNotation();
      }
    }

    _playbackTicker?.stop();
    _playbackTicker?.dispose();
    _playbackTicker = null;

    // Uses the OLD (pre-toggle) padding captured above, NOT
    // _effectiveLeadingPadding's current value — inputLocked may
    // have just flipped true above, but the actual on-screen scroll
    // offset still reflects whatever padding was in effect the LAST
    // time this screen actually rebuilt.
    final oldEffectivePadding = hadWideLeadingPaddingBefore
        ? _leadingPadding
        : _narrowLeadingPadding;
    var tickFromScroll = _gridHorizontalController.hasClients
        ? (_gridHorizontalController.offset - oldEffectivePadding) /
        controller.pixelsPerTick
        : 0.0;
    // Going from edit to playback mode inserts the repeated measures:
    // start from the SAME measure, wherever it moved to.
    if (!hadWideLeadingPaddingBefore && tickFromScroll > 0) {
      tickFromScroll = controller.editTickToPlayback(tickFromScroll);
    }

    // Continuing after a pause while the lead-in (the space before the
    // first measure) is still on screen: from exactly there too —
    // not back to the start of the lead-in, which was a jump.
    final leadInTicks = (_ghostLeadInBeats *
        controller.measures.first.timeSignature.ticksPerBeat)
        .toDouble();
    final resumingInLeadIn = hadWideLeadingPaddingBefore &&
        tickFromScroll <= 0 &&
        tickFromScroll > -leadInTicks;
    if (!resumingInLeadIn &&
        (tickFromScroll <= 0 || tickFromScroll >= controller.maxTicks)) {
      // Starting fresh from the very beginning (or resuming from
      // past the end, which _startPlayback already treated as "start
      // over") — begin at a NEGATIVE tick representing
      // _ghostLeadInBeats worth of silent lead-in, using measure 1's
      // own ticksPerBeat. _onPlaybackTick's normal per-frame
      // tempo-paced advancement (see below) carries this smoothly up
      // to and through tick 0, so the whole lead-in scrolls at the
      // ACTUAL first-measure speed — no separate pause/jump needed.
      final firstMeasure = controller.measures.first;
      _playbackTick =
      -(_ghostLeadInBeats * firstMeasure.timeSignature.ticksPerBeat)
          .toDouble();
    } else {
      _playbackTick = tickFromScroll;
    }

    _lastTickerElapsed = Duration.zero;
    // Start sounding from exactly where playback starts.
    _soundedUpToTick = _playbackTick.floor();
    setState(() => _isPlaying = true);
    // A 3-second pause before the scrolling starts, to get ready (the
    // grid already shows where it will start). Pausing during it
    // cancels the start.
    _startDelay?.cancel();
    // The grid takes the start position at once (the composition
    // moves to where playback begins), then waits [delay] — 3 seconds
    // from the Play dialog, half a second after a tap on the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isPlaying || _playbackTicker != null) return;
      _scrollTo(_playbackTick);
      // Once more after the Scroll Lock re-layout has settled.
      Timer(const Duration(milliseconds: 100), () {
        if (mounted && _isPlaying && _playbackTicker == null) {
          _scrollTo(_playbackTick);
        }
      });
    });
    void go() {
      _startDelay = null;
      if (!mounted || !_isPlaying) return;
      _lastTickerElapsed = Duration.zero;
      _preparePlaybackCaches();
      _playbackTicker = createTicker(_onPlaybackTick)..start();
    }
    // Continuing after a tap: at once — right after the screen has
    // been redrawn (pausing/continuing redraws it; started before, the
    // time that redraw takes would be scrolled in one jump).
    if (delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
    } else {
      _startDelay = Timer(delay, go);
    }
  }

  /// The pause between pressing Play and the scrolling starting.
  static const Duration _startPauseDuration = Duration(seconds: 3);

  /// The pause when playback continues after a tap on the screen: none.
  static const Duration _tapStartPauseDuration = Duration.zero;
  Timer? _startDelay;

  void _pausePlayback() {
    _startDelay?.cancel();
    _startDelay = null;
    _playbackTicker?.stop();
    _playbackTicker?.dispose();
    _playbackTicker = null;
    _activeNoteRows.value = {};
    // No scroll re-anchoring needed here — the leading padding's
    // width tracks Scroll Lock (see _effectiveLeadingPadding), not
    // playback state itself, and Scroll Lock deliberately stays ON
    // across a pause (see the comment in _startPlayback), so pausing
    // alone doesn't change the padding at all. The generic re-anchor
    // logic in build() (see _lastKnownInputLocked) handles it if/when
    // Scroll Lock itself is later toggled off via its own button.
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  /// How far ahead of the scroll position note sounds are started —
  /// compensates for the phone's own audio output delay so what you
  /// hear lines up with what you see. If notes still sound late,
  /// increase it a little (e.g. 0.15); if they sound early, decrease
  /// it.
  static const double _audioLookaheadSeconds = 0.06;

  void _onPlaybackTick(Duration elapsed) {
    // At most 1/20 s per frame: when a frame comes late (the screen
    // was busy), the scrolling doesn't jump ahead — it stays smooth.
    final dtSeconds = min(
      (elapsed - _lastTickerElapsed).inMicroseconds / 1000000.0,
      0.05,
    );
    _lastTickerElapsed = elapsed;

    final currentTickInt =
    _playbackTick.floor().clamp(0, controller.maxTicks - 1);
    // The measure is looked up only when playback leaves the previous
    // one (searching all measures every frame slowed long pieces).
    var measure = _tickMeasure;
    if (measure == null ||
        currentTickInt < measure.startTick ||
        currentTickInt >= measure.endTick) {
      measure = controller.getMeasureAtTick(currentTickInt);
      _tickMeasure = measure;
    }
    final activeTempo = controller.getActiveTempoAtTick(currentTickInt);

    // Scrolling speed from the beat and the tempo: one tempo beat
    // takes 60 / bpm seconds, so the grid advances one beat's worth
    // of ticks in that time. The beat is the measure's tempo beat
    // (see Measure.effectiveTempoBeat), which stays the ORIGINAL beat
    // even after the measure's beats are split, so splitting doesn't
    // slow playback down.
    final beatTicks = measure.effectiveTempoBeat.ticks;
    final bpm = activeTempo?.tempo.value ?? 0;
    // Multiplied by the speed chosen in the Scroll Speed dialog
    // (1.0 = exactly the tempo).
    final ticksPerSecond = beatTicks * bpm / 60.0 * controller.playbackSpeed;


    _playbackTick += ticksPerSecond * dtSeconds;

    if (controller.soundEnabled) {
      // Sounds are triggered a little AHEAD of the scroll position —
      // by [_audioLookaheadSeconds] — because the phone needs a short
      // moment between "play" being requested and the sound actually
      // coming out of the speaker. Without this, every note is heard
      // slightly after it visibly reaches the pitch column.
      final lookaheadTicks = ticksPerSecond * _audioLookaheadSeconds;
      final soundTo = _playbackTick + lookaheadTicks;
      _soundedUpToTick = soundTo.floor();
      {
        // The notes are sorted by start, so only the next few are
        // looked at — not every note of the piece every frame.
        final list = _playNotes;
        while (_soundIndex < list.length &&
            _playStarts[_soundIndex] < soundTo) {
          final entry = list[_soundIndex++];
          final n = entry.note;
          if (entry.isGhost) {
            controller.playGhostNoteSound(
              n,
              entry.interactionNote!,
              entry.shift,
            );
          } else {
            controller.playNoteSound(n);
          }
        }
      }
    } else {
      // Sound off: keep the position so turning it on doesn't replay.
      final list = _playNotes;
      final t = _playbackTick.floor();
      while (_soundIndex < list.length && list[_soundIndex].note.startTick < t) {
        _soundIndex++;
      }
      _soundedUpToTick = t;
    }

    // Which rows currently have a note actively sounding (startTick
    // <= current tick < endTick) — highlighted green in the pitch
    // column (see PitchColumnWidget). Computed every frame regardless
    // of soundEnabled, since this is a visual indicator independent
    // of whether sound itself is on.
    final currentTickForHighlight = _playbackTick.floor();
    final list = _playNotes;
    while (_activeIndex < list.length &&
        list[_activeIndex].note.startTick <= currentTickForHighlight) {
      _sounding.add(list[_activeIndex++].note);
    }
    _sounding.removeWhere((n) => n.endTick <= currentTickForHighlight);
    final newActiveRows = <int>{for (final n in _sounding) n.row};
    // Only when the rows really change (each change redraws the
    // pitch column).
    final old = _activeNoteRows.value;
    if (old.length != newActiveRows.length || !old.containsAll(newActiveRows)) {
      _activeNoteRows.value = newActiveRows;
    }

    if (_playbackTick >= controller.maxTicks) {
      _playbackTick = controller.maxTicks.toDouble();
      _scrollTo(_playbackTick);
      _pausePlayback();
      return;
    }

    _scrollTo(_playbackTick);
  }

  /// Whether the grid is CURRENTLY scrolled back to (or before) the
  /// very beginning — beat 1 of measure 1 at the pitch column, or
  /// still within the ghost lead-in padding before it. Used by the
  /// Play/Pause icon's color (see build()): red only applies to an
  /// actual mid-piece pause, not to sitting at the start.
  bool get _isAtBeginning {
    if (!_gridHorizontalController.hasClients) return true;
    return _gridHorizontalController.offset <= _effectiveLeadingPadding + 1;
  }

  void _scrollTo(double tick) {
    if (!_gridHorizontalController.hasClients) return;
    final offset = _effectiveLeadingPadding + tick * controller.pixelsPerTick;
    final maxScroll = _gridHorizontalController.position.maxScrollExtent;
    _gridHorizontalController.jumpTo(offset.clamp(0.0, maxScroll));
  }

  Future<void> _scrollToStart() async {
    if (!_gridHorizontalController.hasClients) return;
    // Targets 0 (not _leadingPadding) — per request, the grey leading
    // space must stay VISIBLE after scrolling to the start, rather
    // than being scrolled past so tick 0 sits flush against the
    // pitch column. At offset 0 the viewport shows the full leading
    // gap followed by the start of the grid's own content.
    await _gridHorizontalController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    // Without this, the Play/Pause icon's color (which depends on
    // _isAtBeginning, itself computed from the scroll controller's
    // own offset) wouldn't actually refresh until some unrelated
    // rebuild happened to occur — animateTo alone doesn't trigger a
    // setState() in this widget.
    if (mounted) setState(() {});
  }

  /// Scrolls the grid so the very end of the composition (the last
  /// measure's closing bar line) sits at the right edge of the screen.
  Future<void> _scrollToEnd() async {
    if (!_gridHorizontalController.hasClients) return;
    final position = _gridHorizontalController.position;
    final endOffset = _effectiveLeadingPadding +
        controller.maxTicks * controller.pixelsPerTick -
        position.viewportDimension +
        24; // a little space after the last bar line
    await _gridHorizontalController.animateTo(
      endOffset.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    if (mounted) setState(() {});
  }

  /// Scrolls the grid to the start of [measureIndex] (0-based) — used
  /// by the "Go to Measure" button, right under Scroll to Start.
  /// Animated (matching _scrollToStart's own feel) rather than an
  /// instant jump, and re-checks _isAtBeginning afterward the same
  /// way _scrollToStart does, since scrollTo doesn't otherwise
  /// trigger the Play/Pause icon's color to refresh on its own.
  Future<void> _scrollToMeasure(int measureIndex) async {
    if (!_gridHorizontalController.hasClients) return;
    if (measureIndex < 0 || measureIndex >= controller.measures.length) return;
    final tick = controller.measures[measureIndex].startTick;
    final offset = _effectiveLeadingPadding + tick * controller.pixelsPerTick;
    final maxScroll = _gridHorizontalController.position.maxScrollExtent;
    await _gridHorizontalController.animateTo(
      offset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    if (mounted) setState(() {});
  }


  /// Wraps a button's normal [action] so that, while help mode is on,
  /// tapping the button shows [helpText] in a dialog instead of
  /// performing [action]. When help mode is off, behaves exactly like
  /// [action] (including staying null/disabled if [action] is null).
  VoidCallback? _withHelp(String helpText, VoidCallback? action) {
    if (_helpMode) {
      return () => _showHelpDialog(helpText);
    }
    return action;
  }

  /// The guide to the application, shown as a pop-up when help mode is
  /// turned on (instead of banners on the grid). Each section is a
  /// heading (blue, bold) and its text.
  static const List<List<String>> _guideSections = [
    [
      'CREATE A COMPOSITION',
      "On the home screen tap 'Create Composition'. Type the title and the composer "
          "(always in capital letters), choose the Musical Style, the Target Instrument "
          "and the level, then tap 'Create'.\n"
          "The new composition is empty: tap the 'Add Measures' icon to add measures. "
          "Choose the scale, the time signature and how many measures to add, then tap 'Add'.",
    ],
    [
      'EDIT TITLE, COMPOSER, STYLE, INSTRUMENT, LEVEL',
      "On the 'My Compositions' screen tap the round pen button at the right of the "
          "composition, or tap its style, instrument or level. The Edit Composition dialog "
          "opens: change what you need and tap 'Save'.\n"
          "Inside a composition you can also tap the title on the left of the grid "
          "(see 'See the title and composer') to open the same dialog.",
    ],
    [
      'SHARE IN THE CLOUD LIBRARY',
      "To let all users see your composition, turn on 'Visible to all users in Cloud "
          "Library' in the Create Composition or Edit Composition dialog, then tap "
          "'Create' or 'Save'. Turn it off to make the composition private again.",
    ],
    [
      'LIKE A COMPOSITION IN THE CLOUD LIBRARY',
      "On the 'Cloud Library' screen tap the heart next to a composition. A red heart "
          "means you like it; tap it again to take your like back. Sort the list by "
          "'Most liked' to see the favourite compositions first. Tap the round import "
          "button to copy a composition into 'My Compositions'.",
    ],
    [
      'CREATE A NOTE',
      "First choose the hand with the 'Hand Set' icon and the length of the new notes "
          "with the 'Note Duration' icon. Then tap the grid on the right row (pitch) and "
          "beat (column): the note appears there.\n"
          "To move a note, drag it. To delete it, tap it and choose 'Delete'.",
    ],
    [
      'CHANGE THE VALUE OF A NOTE',
      "Tap the note to open the note dialog, tap 'Duration' and choose the new value. "
          "In the same dialog you can change its hand and accidental.",
    ],
    [
      'COPY A NOTE',
      "Press and hold the note, or tap it and choose 'Copy'. The 'Paste Mode' icon "
          "lights up: now every tap on the grid pastes a copy. Tap the 'Paste Mode' icon "
          "again to stop pasting.",
    ],
    [
      'ADD LEGATO',
      "Tap the 'Legato Mode' icon; it lights up. Now tap the notes that must be played "
          "legato. Tap the icon again to turn Legato Mode off.",
    ],
    [
      'SEE NOTES WITH ACCIDENTALS',
      "Tap the 'Accidentals' icon: every note with an accidental (a note that does not "
          "belong to the scale) turns red. Tap it again to show the notes normally.",
    ],
    [
      'EASY READ MODE',
      "Tap the 'Easy Read Mode' icon to show every note in the way that is easiest to read. "
          "It mainly changes notes with accidentals: the scale's own sign for the row and the "
          "note's accidental are put together into one sound, and the note is shown as simply "
          "as possible —\n"
          "• when they cancel each other, the note shows a plain number (1+ with a - shows 1);\n"
          "• when together they make a whole step, the note is shown on the next row as a plain "
          "number (1+ with a + shows 2).\n"
          "The notes themselves do not change — it is only the way they are shown, so turning "
          "Easy Read off brings the normal notation back at once. While it is on, notes cannot "
          "be entered or edited.\n"
          "Easy Read turns on by itself when you start playing from edit mode, when you rotate "
          "the labels and when you raise or lower the scale. You can turn it off whenever you "
          "want, also during playback, by tapping its icon.",
    ],
    [
      'HIDE FINGER NUMBERS',
      "Tap the 'No Fingers Mode' icon to hide the finger numbers on the notes. Tap it "
          "again to show them.",
    ],
    [
      'SEE THE TITLE AND COMPOSER',
      "Tap the 'Title Mode' icon (the face): the composer and the title are shown in a "
          "column on the left of the grid. Tap that column to edit them. Tap the icon "
          "again to hide them.",
    ],
    [
      'ADD A REPRISE (REPEATS)',
      "Write every measure only once, then tap the 'Repeats' icon and choose the kind "
          "of reprise: a simple reprise 𝄆 𝄇, a reprise with voltas 1. and 2., Segno al Fine "
          "or Segno al Coda. Enter the measure numbers and tap 'Add'. The repeat signs are "
          "shown in green. During playback the repeated measures are played out, with green "
          "numbers copying the measures they repeat. Repeats can be changed in edit mode only.",
    ],
    [
      'ADD GRACE NOTES',
      "Tap the main note, choose 'Grace Note', pick the type and whether it comes before "
          "or after the note. The 'Grace Notes' icon lights up: tap the grid on the rows "
          "(pitches) of the grace notes. Tap the icon again to stop adding.\n"
          "Each grace note takes a part of the main note: an appoggiatura a half (only 1 per "
          "note), an acciaccatura long a quarter (up to 3), medium a sixth (up to 4) and short "
          "an eighth (up to 6).",
    ],
    [
      'ADD AN ORNAMENT',
      "Tap the note, choose 'Ornament' and pick a trill, mordent, turn or tremolo. "
          "To remove it, open the same dialog again.",
    ],
    [
      'ADD AN ARTICULATION',
      "Tap the note, choose 'Articulation' and pick how the note is played: staccato, "
          "accent, tenuto, marcato, sforzando … The articulation is shown on the note. To "
          "remove it, choose 'Articulation' again and tap 'Delete'.",
    ],
    [
      'ADD A PLAYING TECHNIQUE',
      "Tap the note, choose 'Playing Technique' and pick the technique from the list. It "
          "is shown on the note. To remove it, choose 'Playing Technique' again and tap "
          "'Delete'.",
    ],
    [
      'MARK AN ARPEGGIO',
      "Double-tap the beat of the chord to open the beat-and-measure dialog and choose 'Set Arpeggio'. Choose the hand (left, right or both hands): a wavy line is shown "
          "before the chord, and during playback the chord is played spread out. To remove it, "
          "open the same dialog again.",
    ],
    [
      'ADD A GLISSANDO',
      "Tap the note where the glissando starts and choose 'Glissando', then tap the row "
          "(pitch) where the glissando must end: a row above the note makes it go up, a row "
          "below makes it go down. To change the end note or remove the glissando, tap the "
          "note and choose 'Glissando' again.",
    ],
    [
      'SET A FERMATA',
      "Double-tap the beat and choose 'Set Fermata'. Pick or enter how many beats this beat "
          "must last, then tap 'Set'. To remove it, open the same dialog and tap 'Delete'.",
    ],
    [
      'ADD A DYNAMIC',
      "Double-tap the beat where the dynamic starts and choose 'Set Dynamic'. Pick the "
          "dynamic (pp, p, mp, mf, f, ff …). It is used from that beat on, until the next "
          "dynamic. To remove it, open the same dialog and tap 'Delete'.",
    ],
    [
      'ADD A DYNAMIC CHANGE',
      "Double-tap the beat where the change starts and choose 'Set Dynamic Change'. Pick "
          "the change (crescendo, diminuendo …). To remove it, open the same dialog and tap "
          "'Delete'.",
    ],
    [
      'SET THE PEDAL',
      "Double-tap the beat and choose 'Set Pedal'. Pick the pedal marking (pedal down or "
          "up). To remove it, open the same dialog and tap 'Delete'.",
    ],
    [
      'CHANGE THE TIME SIGNATURE',
      "Tap the time signature label at the bottom of the grid, or double-tap the measure "
          "and choose 'Edit Time Signature'. The Change Time Signature dialog opens with two "
          "choices, each for 'This measure' or a 'Measure range':\n"
          "• 'Split each beat to halves' — twice as many beats, each half as long "
          "(for example 3/4 becomes 6/8);\n"
          "• 'Unite every two beats to one' — half as many beats, each twice as long "
          "(for example 6/8 becomes 3/4).\n"
          "The notes stay where they are.\n"
          "To split one beat into columns for triplets and other tuplets, double-tap the beat "
          "and choose 'Split beat'.",
    ],
    [
      'INSERT, DUPLICATE, CLEAN, DELETE A BEAT',
      "Double-tap the beat to open the beat-and-measure dialog. In the Beat column:\n"
          "• 'Insert Beat' adds one empty beat at the end of the measure;\n"
          "• 'Duplicate Beat' adds a copy of this beat with its notes after it;\n"
          "• 'Clean Beat' removes the notes of this beat and keeps the beat — first choose "
          "the right, left or additional hand, or all hands;\n"
          "• 'Delete Beat' removes the beat and its notes.",
    ],
    [
      'INSERT, DUPLICATE, CLEAN, DELETE A MEASURE',
      "Double-tap the measure to open the beat-and-measure dialog. In the Measure column:\n"
          "• 'Insert Measure' adds an empty measure before this one;\n"
          "• 'Duplicate Measure' adds a copy of this measure after it, and 'Duplicate Range' "
          "copies a range of measures;\n"
          "• 'Clean Measure' removes the notes of this measure, and 'Clean Range' those of a "
          "range of measures — the measures stay. First choose the right, left or additional "
          "hand, or all hands (all hands also removes the dynamics and pedal marks);\n"
          "• 'Delete Measure' removes the measure, and 'Delete Range' a range of measures.\n"
          "To add measures at the end, use the 'Add Measures' icon.",
    ],
    [
      'CHANGE THE SCALE',
      "Tap the scale name at the top of the grid, or double-tap the measure and choose "
          "'Set Scale' — for this measure or for a range of measures.\n"
          "To play the whole piece higher or lower, use the 'Scale up' and 'Scale Down' "
          "icons (a semitone each tap); 'Reset scale' brings back the original pitch.",
    ],
    [
      'CHANGE THE TEMPO',
      "Tap the tempo label at the bottom of the grid, or double-tap the beat and choose "
          "'Set Tempo'. Choose the new tempo in the Select Tempo dialog; it is used from "
          "that beat on.\n"
          "To play slower or faster without changing the tempo, tap the 'Play' icon and "
          "choose a speed.",
    ],
    [
      'CHANGE THE CELL SIZE',
      "Tap the 'Cell Width' icon to make the cells wider or narrower. 'Zoom In' and "
          "'Zoom Out' make the whole grid bigger or smaller; 'Reset Zoom' brings back the "
          "normal size.",
    ],
    [
      'SHOW LARGER LABELS',
      "Tap the 'Large Labels Mode' icon to make the labels on the grid (note names, "
          "measure numbers, tempo, scale) larger. Tap it again for the normal size.",
    ],
    [
      'DRAW ON THE GRID WITH THE PEN',
      "Tap the 'Pen' icon: it turns green and a bar appears at the top of the grid. Now "
          "one finger draws green marks on the grid — for example to mark places to practise "
          "or check later — and the grid does not scroll.\n"
          "In the bar: 'Pen' draws, 'Eraser' rubs out the marks you touch, 'Undo' takes back "
          "the last mark and 'Clear all' removes all marks.\n"
          "Tap the green 'Pen' icon again to finish. The marks are saved with the composition.",
    ],
    [
      'ROTATE THE LABELS',
      "Tap the 'Rotate' icon to turn all labels on the grid by 90°, so you can turn the "
          "tablet sideways and read the cellnotation like a piano roll, with the notes coming "
          "towards the keyboard. Rotate also turns Lock Mode and Easy Read Mode on. Tap the "
          "icon again to turn the labels back.",
    ],
    [
      'EXPORT A COMPOSITION',
      "Tap the 'Export' icon, choose the first and the last measure and tap 'Export'. The "
          "measures are shown as text in the transcription notation (scale, time signature, "
          "then every measure with its hands, beats and notes). Tap 'Copy' to put it on the clipboard to "
          "keep it, send it or paste it into another composition.",
    ],
    [
      'IMPORT A COMPOSITION',
      "Tap the 'Import' icon to open the Import Sheet Music Transcription dialog. Paste or "
          "type a transcription (for example one made with Export) and tap 'Import'. If the "
          "composition already has measures, choose 'Add after measure …' or 'Replace all "
          "measures'.\n"
          "'From PDF' reads the notes from a PDF of printed sheet music and puts the result in "
          "the box, so you can check it and then tap 'Import'. 'Help' explains the whole "
          "transcription notation, with examples.",
    ],
    [
      'SOUND AND INSTRUMENT OF EACH HAND',
      "Tap the 'Audio' icon. In the Off and On columns choose which hands are heard. In the "
          "Instrument column tap a hand's instrument and pick another one — each hand can be "
          "played with its own instrument, for example the right hand with a violin and the left "
          "hand with a piano. 'All hands' gives all three the same instrument. Tap 'Set'.\n"
          "The instruments are saved with the composition. At first every hand plays the "
          "composition's Target Instrument.",
    ],
    [
      'MORE HELP',
      "While Help Mode is on (the ? icon is red), tap any icon to see what it does. "
          "Tap the ? icon again to turn Help Mode off and use the icons normally.",
    ],
  ];

  void _showGuideDialog() {
    final size = MediaQuery.of(context).size;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'How to use Cellnotation',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: SizedBox(
          width: (size.width - 48).clamp(0.0, 700.0),
          height: size.height * 0.65,
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.separated(
              padding: const EdgeInsets.only(right: 12),
              itemCount: _guideSections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 20),
              itemBuilder: (_, i) {
                final heading = _guideSections[i][0];
                final text = _guideSections[i][1];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. $heading',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text,
                      style: const TextStyle(fontSize: 22, color: Colors.black),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          const Divider(thickness: 1.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(String text) {
    // Every help string here follows the pattern "Name: \nDescription"
    // (see every _withHelp call above) — split on that separator so
    // the button's own NAME becomes the dialog's title (in blue),
    // replacing the old generic "Help" title, per request.
    final separatorIndex = text.indexOf(': \n');
    final name = separatorIndex != -1 ? text.substring(0, separatorIndex) : text;
    final description =
    separatorIndex != -1 ? text.substring(separatorIndex + 3) : '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        content: Text(description, style: const TextStyle(fontSize: 22, color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Close',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A small label banner pointing at a specific toolbar icon while
  /// Help Mode is on. Uses CompositedTransformFollower (paired with a
  /// CompositedTransformTarget wrapping the icon itself) rather than
  /// a plain Positioned overflowing the toolbar's own narrow column —
  /// a plain Positioned got painted OVER by the pitch column/grid,
  /// since Row paints later siblings on top of earlier ones'
  /// overflow. This is placed directly in the OUTER Stack (wrapping
  /// the whole screen Row), which paints last, so it's always on top
  /// regardless of what's underneath, while still tracking the
  /// icon's exact real position via [link].
  Widget _toolbarLabel(LayerLink link, String text) {
    return CompositedTransformFollower(
      link: link,
      offset: const Offset(46, 0),
      // Reuses GridWidget's own speechBubble/BubblePointerSide (now
      // public — see that file), per request, pointing LEFT since
      // this label sits to the RIGHT of its own toolbar icon and
      // points back at it.
      child: speechBubble(
        text,
        pointerSide: BubblePointerSide.left,
      ),
    );
  }

  void _showTitle() {
    setState(() => _toShowTitle = !_toShowTitle);

  }
  /// Locks the device's own physical screen orientation to whichever
  /// one it's CURRENTLY in (portrait or landscape) when [locked] is
  /// true, or releases the lock (allowing all orientations again)
  /// when false. Called from the Rotate Pitch Text button — rotating
  /// the physical device WHILE the pitch digits are also rotated
  /// would be confusing (two independent rotations stacking), so the
  /// device orientation is pinned to whatever it already was at the
  /// moment that mode was turned on.
  /// One toolbar column of icons: spread evenly over the screen height
  /// when they fit, and scrollable when they don't (landscape, where
  /// the screen is too short for all of them) — so the lowest icons are
  /// never cut off.
  Widget _iconColumn(BuildContext context, List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight =
        constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  /// The blank space between groups of toolbar icons — smaller in
  /// landscape, where height is short.
  Widget _iconGap(BuildContext context) {
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return SizedBox(height: landscape ? 6 : 30);
  }

  /// Edit mode: not playing, no Scroll Lock, no Easy Read, no Rotate.
  bool get _inEditMode =>
      !_isPlaying &&
          !controller.inputLocked &&
          !controller.showCompensatedNotation &&
          !controller.rotatePitchText;

  /// The Edit Mode (pen) button: back to editing from playback in one
  /// tap.
  void _enterEditMode() {
    if (_inEditMode) return;
    // Same rule as unlocking with the lock icon: a raised/lowered
    // scale must be reset first.
    if (controller.isScaleRaised || controller.isScaleLowered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text(
            'To go back to edit mode reset the scale of the composition to original.',
            style: TextStyle(fontSize: 22),
          ),
        ),
      );
      return;
    }
    if (_isPlaying) _pausePlayback();
    if (controller.rotatePitchText) {
      // Turns Scroll Lock and Easy Read off too.
      controller.toggleRotatePitchText();
      _setOrientationLocked(context, false);
    }
    if (controller.inputLocked) controller.toggleInputLocked();
    if (controller.showCompensatedNotation) {
      controller.toggleCompensatedNotation();
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        content: Text('Edit mode.', style: TextStyle(fontSize: 22)),
      ),
    );
  }

  void _setOrientationLocked(BuildContext context, bool locked) {
    if (!locked) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      return;
    }
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    SystemChrome.setPreferredOrientations(
      isPortrait
          ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
          : [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
  }

  /// When the app comes back from the background, rebuild the note
  /// sounds — the system may have released the audio resources while
  /// the app was away, which otherwise leaves playback silent.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NoteSoundService.instance.recover().then((_) {
        if (mounted) controller.warmUpSounds();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gridVerticalController.addListener(_syncPitchColumn);
  }

  void _syncPitchColumn() {
    if (_pitchVerticalController.hasClients) {
      _pitchVerticalController.jumpTo(_gridVerticalController.offset);
    }
    if (_transcriptionVerticalController.hasClients) {
      _transcriptionVerticalController.jumpTo(_gridVerticalController.offset);
    }
    if (_letterNameVerticalController.hasClients) {
      _letterNameVerticalController.jumpTo(_gridVerticalController.offset);
    }
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _gridVerticalController.removeListener(_syncPitchColumn);
    _gridVerticalController.dispose();
    _pitchVerticalController.dispose();
    _transcriptionVerticalController.dispose();
    _letterNameVerticalController.dispose();
    _gridHorizontalController.dispose();
    _playbackTicker?.dispose();
    _activeNoteRows.dispose();
    // Safety net: release any orientation lock left on by Rotate
    // Pitch Text (see _setOrientationLocked) — leaving this screen
    // shouldn't leave the rest of the app stuck unable to rotate.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }



  void _openAppendMeasuresForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddMeasuresDialog(
        targetComposition: controller.composition,
        controller: controller,
        onMeasuresAppended: () {},
      ),
    );

  }



  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => NewCompositionDialog(
        onCompositionCreated: (newComp) {
          controller.updateComposition(newComp);
        },
      ),
    );

  }


  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditCompositionDialog(
        composition: controller.composition,
        allowDelete: false,
        onSaved: (updated) {
          controller.updateComposition(updated);
        },
        onDelete: () async {
          final service = CompositionService();
          final id = controller.composition.id;
          if (id != null) {
            try {
              await service.deleteComposition(id);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text('Delete failed: $e', style: const TextStyle(fontSize: 22)),
                ),
              );
              return;
            }
          }
          if (!context.mounted) return;
          Navigator.popUntil(context, (route) => route.isFirst);
        },
      ),
    );
  }



  Future<bool> _saveComposition(BuildContext context) async {
    final driftIndices = controller.measuresWithScaleDrift();

    if (driftIndices.isNotEmpty) {
      final keepChanges = await scaleChangeWarningDialog(
        context: context,
        controller: controller,
        driftMeasureIndices: driftIndices,
      );

      if (keepChanges == null) {
        return false;
      }

      if (keepChanges) {
        controller.commitScaleChanges();
      } else {
        controller.resetAllScales();
      }

      if (!context.mounted) return false;
    }

    await _performSave(context);
    return true;
  }

  Future<void> _performSave(BuildContext context) async {
    final service = CompositionService();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saving...', style: TextStyle(fontSize: 22)),
        duration: Duration(seconds: 1),
      ),
    );

    // Never save the temporary measures that play the repeats: save
    // the composition as in edit mode, then put them back.
    final repeatsPlayedOut = controller.playbackExpanded;
    if (repeatsPlayedOut) controller.collapseReprises();
    try {
      final newId = await service.saveComposition(controller.composition);
      if (repeatsPlayedOut) controller.expandReprises();

      if (controller.composition.id == null) {
        controller.updateComposition(
          controller.composition.copyWith(id: newId),
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Composition saved', style: TextStyle(fontSize: 22)),
        ),
      );
    } catch (e) {
      if (repeatsPlayedOut && !controller.playbackExpanded) {
        controller.expandReprises();
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text('Save failed: $e', style: const TextStyle(fontSize: 22)),
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final hasMeasures =
              controller.composition.timeline.measures.isNotEmpty;

          final cellHeight = controller.getCellHeight(context);

          // Sized to EXACTLY match _ghostLeadInBeats worth of ticks
          // in pixels — not an arbitrary screen fraction — so the
          // blank scrollable space here lines up precisely with
          // where _startPlayback's negative-tick lead-in actually
          // starts scrolling from. hasMeasures guards against
          // controller.measures.first throwing on an empty
          // composition.
          _leadingPadding = hasMeasures
              ? _ghostLeadInBeats *
              controller.measures.first.timeSignature.ticksPerBeat *
              controller.pixelsPerTick
              : 0;

          // Detects a CHANGE in controller.inputLocked (Scroll Lock)
          // since the last build, from ANY of the several places that
          // toggle it (the Scroll Lock button itself, Easy Read, Help
          // Mode, Rotate Pitch Text, or _startPlayback) — since the
          // leading padding's WIDTH tracks it directly (see
          // _effectiveLeadingPadding: narrow when off, the wide
          // runway when on), a change here means that width just
          // changed. Re-anchors the scroll position, once the grid
          // has actually rebuilt with the new padding (next frame),
          // to whatever tick the OLD padding value said was on
          // screen — so the visible content doesn't visually jump
          // purely because the gap's width changed.
          final currentInputLocked = controller.inputLocked;
          if (_lastKnownInputLocked != null &&
              _lastKnownInputLocked != currentInputLocked) {
            final oldEffectivePadding = _lastKnownInputLocked!
                ? _leadingPadding
                : _narrowLeadingPadding;
            var tickBeforeChange = _gridHorizontalController.hasClients
                ? (_gridHorizontalController.offset - oldEffectivePadding) /
                controller.pixelsPerTick
                : 0.0;
            // The repeated measures were just added (playback mode) or
            // removed (edit mode): keep the SAME measure on screen.
            if (tickBeforeChange > 0) {
              tickBeforeChange = currentInputLocked
                  ? controller.editTickToPlayback(tickBeforeChange)
                  : controller.playbackTickToEdit(tickBeforeChange);
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollTo(tickBeforeChange);
            });
          }
          _lastKnownInputLocked = currentInputLocked;

          return Stack(
            children: [
              Row(
                children: [

                  Container(
                    width: 46,
                    color: Colors.grey.shade300,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        iconButtonTheme: IconButtonThemeData(
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(44, 44),
                            iconSize: 28,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      child: _iconColumn(context, [

                        _iconGap(context),

                        // HOME
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Exit',
                          onPressed: _withHelp(
                              'Exit: \nSaves and exits the composition returning to the main menu.',
                                  () {
                                saveExitDialog(
                                  context,
                                  onSave: () => _saveComposition(context),
                                );
                              }),
                        ),

                        // GRID DARK MODE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(Icons.dark_mode,
                              color: controller.isDarkMode
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: controller.isDarkMode
                              ? 'Dark Mode on'
                              : 'Dark Mode off',
                          onPressed: _withHelp(
                              'Dark Mode: \nToggles a background color.',
                                  () {
                                controller.toggleDarkMode();
                                // ScaffoldMessenger.of(context).showSnackBar(
                                //   SnackBar(
                                //     duration: const Duration(seconds: 1),
                                //     content: Text(
                                //       controller.isDarkMode ? 'Dark Mode on.' : 'Dark Mode off.',
                                //       style: const TextStyle(fontSize: 22),
                                //     ),
                                //   ),
                                // );
                              }),
                        ),

                        // HELP MODE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.help_outline,
                              color: _helpMode ? Colors.red: Colors.black,
                            ),
                          ),
                          tooltip: _helpMode
                              ? 'Help Mode on'
                              : 'Help Mode off',
                          onPressed: () {
                            setState(() {
                              _helpMode = !_helpMode;
                            });
                            // Turning help mode on opens the guide
                            // to the application.
                            if (_helpMode) _showGuideDialog();
                            // No longer touches Lock Mode at all,
                            // per request — Help Mode is meant to
                            // be tried alongside actually editing
                            // the composition (note input, moving,
                            // etc.), with the guide banner and icon
                            // explanations layered on top, rather
                            // than forcing the grid read-only while
                            // it's on.
                          },
                        ),

                        // TO SHOW TITLE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.face_6_rounded,
                              color: _toShowTitle
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: _toShowTitle
                              ? 'Title is hidden'
                              : 'Title is shown',
                          onPressed: _withHelp(
                              'Title Mode: \nShows or hides the title of the composition.',
                                  () {
                                _showTitle();
                              }),
                        ),


                        _iconGap(context),


                        // HIDE FINGER
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.touch_app,
                              color: controller.hideFingerNumbers
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: controller.hideFingerNumbers
                              ? 'Finger Numbers off'
                              : 'Finger Numbers on',
                          onPressed: _withHelp(
                              'No Fingers Mode: \nHides fingering numbers.',
                                  () {
                                controller.toggleHideFingerNumbers();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 1),
                                    content: Text(
                                      controller.hideFingerNumbers ? 'Fingers hidden.' : 'Fingers visible.',
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }),
                        ),


                        // SHOW ACCIDENTAL
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.open_in_full_sharp,
                              color: controller.highlightAccidentalNotes
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: controller.highlightAccidentalNotes
                              ? 'Accidentals on'
                              : 'Accidentals off',
                          onPressed: _withHelp(
                              'Accidentals Mode: \nHighlights notes outside the current scale.',
                                  () {
                                controller.toggleHighlightAccidentalNotes();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 1),
                                    content: Text(
                                      controller.highlightAccidentalNotes
                                          ? 'Notes with accidentals are highlighted.'
                                          : 'Notes with accidentals are back to normal.',
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }),
                        ),

                        // RAISE SCALE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(Icons.arrow_upward,
                              color: controller.isScaleRaised
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: 'Scale up',
                          onPressed: _withHelp(
                              'Scale up: \nRaises composition up a semitone.',
                                  () {
                                controller.raiseAllScales();
                                // Raising the scale forces BOTH Lock
                                // Mode and Easy Read Mode on now, per
                                // request — while the scale is
                                // raised/lowered, editing must not be
                                // possible at all, and the notation
                                // must be shown compensated. Both
                                // stay forced on until Reset Scale
                                // brings the composition back to its
                                // original scale (see the Reset
                                // Scale button, which releases both).
                                if (!controller.inputLocked) {
                                  controller.toggleInputLocked();
                                }
                                if (!controller.showCompensatedNotation) {
                                  controller.toggleCompensatedNotation();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    duration: Duration(seconds: 2),
                                    content: Text(
                                      'Scale of composition is a semitone higher.',
                                      style: TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }),
                        ),


                        // RESET SCALE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(Icons.adjust,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Reset scale',
                          onPressed: _withHelp(
                              'Reset scale: \nReset scale of composition to original.',
                                  () {
                                // Captured BEFORE resetAllScales()
                                // runs — once that call completes,
                                // isScaleRaised/isScaleLowered are
                                // both always false, so this is the
                                // only way to tell whether there was
                                // actually anything to reset.
                                final wasAlreadyOriginal =
                                    !controller.isScaleRaised &&
                                        !controller.isScaleLowered;
                                controller.resetAllScales();
                                // Resetting the scale back to
                                // original releases BOTH Lock Mode
                                // and Easy Read Mode now, per request
                                // — once the scale is back to
                                // original, there's no longer any
                                // reason to force either on (see the
                                // RAISE/LOWER SCALE buttons, which
                                // force both on).
                                if (controller.inputLocked) {
                                  controller.toggleInputLocked();
                                }
                                if (controller.showCompensatedNotation) {
                                  controller.toggleCompensatedNotation();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 2),
                                    content: Text(
                                      wasAlreadyOriginal
                                          ? 'Scale of composition is already original.'
                                          : 'Scale of composition is reset to original.',
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }),
                        ),


                        // LOWER SCALE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(Icons.arrow_downward,
                              color: controller.isScaleLowered
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: 'Scale Down',
                          onPressed: _withHelp(
                              'Scale Down: \nLow composition down a semitone.',
                                  () {
                                controller.lowerAllScales();
                                // Lowering the scale forces BOTH Lock
                                // Mode and Easy Read Mode on, per
                                // request — same as raising it (see
                                // RAISE SCALE above) — both stay
                                // forced on until Reset Scale brings
                                // the composition back to its
                                // original scale.
                                if (!controller.inputLocked) {
                                  controller.toggleInputLocked();
                                }
                                if (!controller.showCompensatedNotation) {
                                  controller.toggleCompensatedNotation();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    duration: Duration(seconds: 2),
                                    content: Text(
                                      'Scale of composition is a semitone lower.',
                                      style: TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }),
                        ),


                        _iconGap(context),

                        // SCROLL LOCK
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              controller.inputLocked
                                  ? Icons.lock
                                  : Icons.lock_open,
                              color: controller.inputLocked
                                  ? Colors.red
                                  : Colors.black,
                            ),
                          ),
                          tooltip: controller.inputLocked
                              ? 'Lock Mode on'
                              : 'Lock Mode off',
                          onPressed: _withHelp(
                              'Lock Mode: \nPrevents from editing.',
                                  () {
                                if (!controller.inputLocked) {
                                  // Locking never breaks anything —
                                  // no guard needed for this
                                  // direction.
                                  controller.toggleInputLocked();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      duration: Duration(seconds: 1),
                                      content: Text(
                                        'Lock Mode on.',
                                        style: TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                // Trying to UNLOCK from here on.
                                // Blocked during playback, per
                                // request — Lock Mode is what makes
                                // grid taps pause/resume playback
                                // instead of editing (see
                                // isPlaying: controller.inputLocked
                                // passed to GridWidget below), so
                                // unlocking mid-playback would break
                                // that.
                                if (_isPlaying) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      duration: Duration(seconds: 2),
                                      content: Text(
                                        'Pause playback first.',
                                        style: TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                // Same guard for a raised/lowered
                                // scale, per request — the ONLY way
                                // to release the lock in this case is
                                // Reset Scale (see that button's own
                                // handler above).
                                if (controller.isScaleRaised ||
                                    controller.isScaleLowered) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      duration: Duration(seconds: 3),
                                      content: Text(
                                        'To disable Lock Mode reset the scale of the composition to original.',
                                        style: TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                // Unlocking also turns Easy Read Mode
                                // off at the same time, per request
                                // — tapping Unlock is now the ONLY
                                // way out of Easy Read Mode, rather
                                // than requiring Easy Read to be
                                // turned off first as a separate
                                // step.
                                controller.toggleInputLocked();
                                if (controller.showCompensatedNotation) {
                                  controller.toggleCompensatedNotation();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    duration: Duration(seconds: 1),
                                    content: Text(
                                      'Lock Mode off.',
                                      style: TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }),
                        ),

                        // EASY READ MODE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(Icons.auto_fix_high,
                              color: controller.showCompensatedNotation
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: controller.showCompensatedNotation
                              ? 'Easy Read Mode on'
                              : 'Easy Read Mode off',
                          onPressed: _withHelp(
                              'Easy Read Mode: \nShows a simplified notation.',
                                  () {
                                // Easy Read Mode can be switched off
                                // and on at any time, also while
                                // playing, per request.
                                // Same guard while the scale is
                                // raised/lowered, per request — it's
                                // already forced on by the RAISE/
                                // LOWER SCALE buttons, and the ONLY
                                // way to release it in this case is
                                // Reset Scale.
                                if (controller.isScaleRaised ||
                                    controller.isScaleLowered) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      duration: Duration(seconds: 3),
                                      content: Text(
                                        'To disable Easy Read Mode reset the scale of the composition to original.',
                                        style: TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                controller.toggleCompensatedNotation();
                                // In playback (Scroll Lock on) only the
                                // notation changes — the scrolling and
                                // tap-to-pause stay. In edit mode, turning
                                // Easy Read on also turns Scroll Lock on
                                // (as before), since notes can't be edited
                                // in Easy Read.
                                if (!_isPlaying &&
                                    controller.showCompensatedNotation &&
                                    !controller.inputLocked) {
                                  controller.toggleInputLocked();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 1),
                                    content: Text(
                                      controller.showCompensatedNotation
                                          ? 'Easy Read Mode on.'
                                          : 'Easy Read Mode off.',
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }),
                        ),

                        // ROTATE
                        IconButton(
                          // Icon itself rotated 180° while the mode is
                          // on, per request, so the button visually
                          // matches the rotated state it represents.
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(Icons.rotate_left,
                              color: controller.rotatePitchText
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: controller.rotatePitchText
                              ? 'Rotate on'
                              : 'Rotate off',
                          onPressed: _withHelp(
                              'Rotate Mode: \nRotates labels for reading with the device turned sideways.',
                                  () {
                                controller.toggleRotatePitchText();
                                _setOrientationLocked(
                                  context,
                                  controller.rotatePitchText,
                                );
                              }),
                        ),

                        // SHOW REFERENCE COLUMNS (letter name +
                        // transcription) — independent from Show
                        // Title, per request.
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.assist_walker_sharp,
                              color: _toShowReferenceColumns
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: _toShowReferenceColumns
                              ? 'Reference Columns shown'
                              : 'Reference Columns hidden',
                          onPressed: _withHelp(
                              'Reference Columns: \nShows or hides two columns: the letter name of each row (C4, A5#) and the staff line numbers (0 = the line of middle C, 1, 2 … above, -1, -2 … below; the rows between lines are empty).',
                                  () {
                                setState(() {
                                  _toShowReferenceColumns =
                                  !_toShowReferenceColumns;
                                });
                              }),
                        ),

                        // PEN — green marks for places to check later.
                        // Green while on; tapping it again finishes.
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.draw,
                              color: controller.penMode
                                  ? Colors.green
                                  : Colors.black,
                            ),
                          ),
                          tooltip: 'Pen',
                          onPressed: _withHelp(
                            'Pen: \nDraw green marks on the grid with your finger to mark places to check later. While it is on (green), one finger draws and the grid does not scroll; use Pen, Eraser, Undo or Clear all in the bar at the top of the grid. Tap this icon again to finish. Marks are saved with the composition.',
                            hasMeasures
                                ? () {
                              controller.togglePenMode();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 1),
                                  content: Text(
                                    controller.penMode
                                        ? 'Pen on — draw with your finger.'
                                        : 'Pen off.',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              );
                            }
                                : null,
                          ),
                        ),

                        // REPEATS — measure numbers as in the printed score
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.repeat,
                              color: controller.repriseExpanded ||
                                  controller.reprises.isNotEmpty
                              // green, like the repeat signs on the grid
                                  ? const Color(0xFF2E7D32)
                                  : Colors.black,
                            ),
                          ),
                          tooltip: 'Repeats',
                          onPressed: _withHelp(
                            'Repeats: \nSet reprises the way printed music writes them: a simple reprise 𝄆 𝄇, a reprise with voltas 1. and 2., 𝄋 Segno al Fine, or 𝄋 Segno al Coda. In edit mode you see the signs. While playing (Scroll Lock on) the repeated measures are added after the place where the music goes back, with green numbers copying the measures they repeat; turning Scroll Lock off removes them and the signs come back. Repeats can be changed in edit mode only.',
                            hasMeasures
                                ? () => repeatsDialog(context, controller)
                                : null,
                          ),
                        ),


                        _iconGap(context),


                        // ZOOM IN
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.zoom_in,
                              color: controller.isZoomedIn
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: 'Zoom In',
                          onPressed: _withHelp(
                              'Zoom In: \nEnlarges the grid.',
                                  () {
                                // Only zoomY (cell HEIGHT) changes
                                // here, per request — zoomX (cell
                                // WIDTH) is passed through
                                // unchanged, so Zoom In no longer
                                // touches width at all, keeping
                                // isCellWidthChanged's own icon
                                // independent of this button.
                                controller.setZoom(
                                  controller.zoomX,
                                  controller.zoomY + 0.1,
                                );
                              }),
                        ),

                        // ZOOM OUT
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.zoom_out,
                              color: controller.isZoomedOut
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: 'Zoom Out',
                          onPressed: _withHelp(
                              'Zoom Out: \nShrinks the grid.',
                                  () {
                                // Only zoomY (cell HEIGHT) changes
                                // here, per request — zoomX (cell
                                // WIDTH) is passed through
                                // unchanged, so Zoom Out no longer
                                // touches width at all, keeping
                                // isCellWidthChanged's own icon
                                // independent of this button.
                                controller.setZoom(
                                  controller.zoomX,
                                  controller.zoomY - 0.1,
                                );
                              }),
                        ),

                        // RESET
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(
                              Icons.center_focus_strong,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Reset Zoom',
                          onPressed: _withHelp(
                            'Reset Zoom: \nReturns the grid to default zoom level.',
                            controller.resetZoom,
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),


                  Container(
                    width: 46,
                    height: double.infinity,
                    color: Colors.grey.shade300,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        iconButtonTheme: IconButtonThemeData(
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(44, 44),
                            iconSize: 28,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      child: _iconColumn(context, [

                        _iconGap(context),

                        // SAVE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(Icons.save,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Save Composition',
                          onPressed: _withHelp(
                              'Save Composition: \nSaves the current composition.',
                                  () {
                                _saveComposition(context);
                              }),
                        ),

                        // NEW COMPOSITION
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(Icons.library_add,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'New Composition',
                          onPressed: _withHelp(
                              'New Composition: \nStarts a brand new composition.',
                                  () {
                                _showCreateDialog(context);
                              }),
                        ),

                        // ADD MEASURES
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(Icons.copy,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Add Measures',
                          onPressed: _withHelp(
                              'Add Measures: \nAppends more measures to the composition.',
                                  () {
                                _openAppendMeasuresForm(context);
                              }),
                        ),

                        // GRID FONT SIZE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.format_size,
                              color: controller.gridFontSize ==
                                  DefaultValues.gridFontSizeLarge
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: controller.gridFontSize ==
                              DefaultValues.gridFontSizeLarge
                              ? 'Large Labels Mode on'
                              : 'Large Labels Mode off',
                          onPressed: _withHelp(
                              'Large Labels Mode: \nToggles size of labels on the grid.',
                                  () {
                                controller.toggleGridFontSize();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 1),
                                    content: Text(
                                      controller.gridFontSize ==
                                          DefaultValues.gridFontSizeLarge
                                          ? 'Large Labels Mode on.'
                                          : 'Large Labels Mode off.',
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }),
                        ),

                        _iconGap(context),

                        // HAND
                        CompositedTransformTarget(
                          link: _handIconLink,
                          child: IconButton(
                            // Rotated the same way as every other toolbar
                            // icon now, matching request — my earlier
                            // exclusion of this one was wrong.
                            icon: Transform.rotate(
                              angle: controller.rotatePitchText ? -pi / 2 : 0,
                              child: Icon(Icons.pan_tool,
                                // Three states now that Hand.additional
                                // exists: right = black, left = blue,
                                // additional = green (per request).
                                color: controller.currentHand == Hand.right
                                    ? Colors.black
                                    : controller.currentHand == Hand.left
                                    ? Colors.blue
                                    : Colors.green,
                              ),
                            ),
                            tooltip: 'Hand Set',
                            onPressed: _withHelp(
                                'Hand Set: \nOpens a menu to set hand for newly entered notes.',
                                    () {
                                  // Always opens the 3-way picker now —
                                  // the separate "Additional Hand Mode"
                                  // gate was removed, per request, but
                                  // Hand.additional still needs a way
                                  // to be reached, so this dialog is
                                  // now the Hand button's only
                                  // behavior.
                                  handDialog(
                                    context: context,
                                    controller: controller,
                                  );
                                }),
                          ),
                        ),

                        // ADDITIONAL HAND MODE toggle removed, per
                        // request — Hand.additional stays in the enum
                        // and in handDialog's picker; the Hand button
                        // below now always opens that dialog instead
                        // of being gated by a separate mode toggle.

                        // DURATION
                        CompositedTransformTarget(
                          link: _durationIconLink,
                          child: IconButton(
                            icon: Transform.rotate(
                              angle: controller.rotatePitchText ? -pi / 2 : 0,
                              child: const Icon(Icons.av_timer,
                                color: Colors.black,
                              ),
                            ),
                            tooltip: 'Note Duration',
                            onPressed: _withHelp(
                                'Note Duration: \nOpens a menu to set duration for newly entered notes.',
                                    () {
                                  globalDurationDialog(
                                    context,
                                    controller,
                                  );
                                }),
                          ),
                        ),

                        // GRACE NOTES
                        CompositedTransformTarget(
                          link: _graceNotesIconLink,
                          child: IconButton(
                            icon: Transform.rotate(
                              angle: controller.rotatePitchText ? -pi / 2 : 0,
                              child: Icon(
                                Icons.grain,
                                color: controller.isAddingGraceNotes
                                    ? Colors.red
                                    : Colors.black,
                              ),
                            ),
                            tooltip: controller.isAddingGraceNotes
                                ? 'Grace Notes Mode on'
                                : 'Grace Notes Mode off',
                            onPressed: _withHelp(
                                'Grace Notes Mode: \nStops adding grace notes.',
                                    () {
                                  final wasOn = controller.isAddingGraceNotes;
                                  controller.stopAddingGraceNotes();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 1),
                                      content: Text(
                                        'Grace Notes Mode is disable.',
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  );
                                }),
                          ),
                        ),

                        // LEGATO
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.airline_stops_outlined,
                              color: controller.legatoMode
                                  ? Colors.red
                                  : Colors.black,
                            ),
                          ),
                          tooltip: controller.legatoMode
                              ? 'Legato Mode on'
                              : 'Legato Mode off',
                          onPressed: _withHelp(
                              'Legato Mode: \nSets legato on each tapped note.',
                                  () {
                                controller.toggleLegatoMode();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 1),
                                    content: Text(
                                      controller.legatoMode ? 'Legato Mode on.' : 'Legato Mode off.',
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                );
                              }),
                        ),


                        // PASTE
                        // if (controller.canPaste)
                        CompositedTransformTarget(
                          link: _pasteIconLink,
                          child: IconButton(
                            icon: Transform.rotate(
                              angle: controller.rotatePitchText ? -pi / 2 : 0,
                              child: Icon(Icons.control_point_duplicate,
                                color: controller.pasteMode
                                    ? Colors.red
                                    : Colors.black,
                              ),
                            ),
                            tooltip: 'Paste Mode',
                            onPressed: _withHelp(
                                'Paste Mode: \nStops pasting previously copied note.',
                                    () {
                                  if (controller.pasteMode) {
                                    controller.exitPasteMode();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        duration: const Duration(seconds: 1),
                                        content: Text(
                                          'Paste Mode is disable.',
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        duration: const Duration(seconds: 1),
                                        content: Text(
                                          'Paste Mode is disable',
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    );
                                  }

                                }),
                          ),
                        ),

                        _iconGap(context),

                        // EDIT MODE — back to editing from playback
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              Icons.edit,
                              color: _inEditMode ? Colors.blue : Colors.black,
                            ),
                          ),
                          tooltip: _inEditMode ? 'Edit Mode on' : 'Back to Edit Mode',
                          onPressed: _withHelp(
                            'Edit Mode: \nGoes back to editing from playback in one tap: stops playback and turns off Scroll Lock, Easy Read and Rotate. The repeated measures added for playback are removed, and repeat and arpeggio signs are shown again. Blue when you are already in edit mode.',
                            _enterEditMode,
                          ),
                        ),

                        // PLAYBACK - PAUSE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              // Blue in playback mode, black in edit
                              // mode (when the Edit Mode pen is blue).
                              color: _inEditMode ? Colors.black : Colors.blue,
                            ),
                          ),
                          tooltip: _isPlaying ? 'Pause' : 'Play',
                          onPressed: _withHelp(
                            'Play/Pause: \nOpens the Scroll Speed dialog to choose the speed and start playback. Tap again while playing to pause.',
                            hasMeasures
                                ? () {
                              // Pausing stays immediate; starting
                              // goes through the Scroll Speed dialog,
                              // whose Play button starts playback.
                              if (_isPlaying) {
                                _pausePlayback();
                              } else {
                                scrollSpeedDialog(
                                  context,
                                  controller,
                                  onPlay: _startPlayback,
                                );
                              }
                            }
                                : null,
                          ),
                        ),

                        // SCROLL TO START
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(
                              Icons.first_page,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Scroll to Start',
                          onPressed: _withHelp(
                            'Scroll to Start: \nJumps the grid back to the beginning.',
                            hasMeasures
                                ? () {
                              _scrollToStart();
                            }
                                : null,
                          ),
                        ),

                        // SCROLL TO END
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(
                              Icons.last_page,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Scroll to End',
                          onPressed: _withHelp(
                            'Scroll to End: \nJumps the grid to the very end of the composition.',
                            hasMeasures
                                ? () {
                              _scrollToEnd();
                            }
                                : null,
                          ),
                        ),

                        // GO TO MEASURE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(
                              Icons.airplanemode_active_sharp,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Go to Measure',
                          onPressed: _withHelp(
                            'Go to Measure: \nOpens a dialog to enter a measure number, then jumps the grid to it.',
                            hasMeasures
                                ? () {
                              goToMeasureDialog(
                                context: context,
                                controller: controller,
                                onConfirm: (measureIndex) {
                                  _scrollToMeasure(measureIndex);
                                },
                              );
                            }
                                : null,
                          ),
                        ),

                        // SOUND — opens the Audio dialog to choose
                        // which hands are heard and which are cut off.
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(
                              controller.soundEnabled
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              // Blue when only some hands are heard.
                              color: controller.isSoundPartial
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: 'Audio',
                          onPressed: _withHelp(
                              'Audio: \nChoose which hands are heard during playback (Audio) and which are silent (Cut off), so each hand can be listened to separately.',
                                  () {
                                audioHandsDialog(context, controller);
                              }),
                        ),

                        _iconGap(context),

                        // GRID SIZE
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: Icon(Icons.grid_on,
                              color: controller.isCellWidthChanged
                                  ? Colors.blue
                                  : Colors.black,
                            ),
                          ),
                          tooltip: 'Cell Width',
                          onPressed: _withHelp(
                              'Cell Width: \nAdjusts the width of cells.',
                                  () {
                                cellWidthDialog(
                                  context,
                                  controller,
                                );
                              }),
                        ),

                        // EXPORT
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(
                              Icons.file_upload,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Export',
                          onPressed: _withHelp(
                              'Export: \nExports a range of measures as plain text.',
                                  () {
                                measureRangeDialog(
                                  context: context,
                                  controller: controller,
                                  title: 'Export Measures',
                                  actionLabel: 'Export',
                                  actionColor: Colors.blue,
                                  onConfirm: (from, to) {
                                    final exported = controller.exportMeasureRange(from, to);
                                    // Round-trippable notation text —
                                    // the SAME line-position format
                                    // sheetMusicTranscriptionDialog
                                    // reads — the only thing shown
                                    // here now, per request (the
                                    // separate readable-summary
                                    // section was removed), so this
                                    // whole export can be copied
                                    // straight back into that
                                    // dialog. The scale/time-
                                    // signature header line is
                                    // taken from the FIRST measure in
                                    // the range (this notation has no
                                    // way to declare a mid-range
                                    // change, matching the parser's
                                    // own limitation).
                                    final firstMeasure = controller.measures[from];
                                    final denominator = NoteDuration.whole.ticks ~/
                                        firstMeasure.timeSignature.beatDuration.ticks;
                                    final transcriptionText =
                                    formatMeasuresAsCellnotationText(
                                      exported,
                                      scaleName: firstMeasure.scaleName,
                                      timeSignatureBeats:
                                      firstMeasure.timeSignature.beats,
                                      timeSignatureDenominator: denominator,
                                    );
                                    Future.delayed(Duration.zero, () {
                                      showDialog(
                                        context: context,
                                        builder: (resultContext) => AlertDialog(
                                          backgroundColor: Colors.white,
                                          surfaceTintColor: Colors.white,
                                          title: const Text(
                                            'Exported Measures',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: SizedBox(
                                            width: 400,
                                            height: 400,
                                            child: SingleChildScrollView(
                                              child: SelectableText(
                                                transcriptionText,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () async {
                                                await Clipboard.setData(
                                                  ClipboardData(text: transcriptionText),
                                                );
                                                if (!resultContext.mounted) return;
                                                ScaffoldMessenger.of(resultContext)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    duration: Duration(seconds: 2),
                                                    content: Text(
                                                      'transcription is copied to clipboard',
                                                      style: TextStyle(fontSize: 22),
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                'Copy',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(resultContext),
                                              child: const Text(
                                                'Close',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    });
                                  },
                                );
                              }),
                        ),

                        // IMPORT
                        IconButton(
                          icon: Transform.rotate(
                            angle: controller.rotatePitchText ? -pi / 2 : 0,
                            child: const Icon(
                              Icons.file_download,
                              color: Colors.black,
                            ),
                          ),
                          tooltip: 'Import',
                          onPressed: _withHelp(
                              'Import: \nImports a transcription pasted in the line-position notation.',
                                  () {
                                // The old fixed-batch list (and its
                                // whole intermediate picker dialog)
                                // has been removed, per request —
                                // this button now opens the paste-
                                // your-own dialog directly, since
                                // that dialog is the app's only
                                // remaining way to import a
                                // transcription.
                                sheetMusicTranscriptionDialog(
                                  context: context,
                                  controller: controller,
                                );
                              }),
                        ),



                      ],
                      ),
                    ),
                  ),

                  //INFO OF TITLE
                  _toShowTitle
                      ? Container(
                    width: 46,
                    color: Colors.white,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showEditDialog(context),
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            '${controller.composition.composer.toUpperCase()} - ${controller.composition.title.toUpperCase()}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                      : SizedBox(),

                  // Controlled by their own separate toggle now, per
                  // request — no longer tied to _toShowTitle. Both
                  // reference columns (letter name and line-position
                  // transcription) sit right after the title info
                  // block and before the existing pitch column,
                  // appearing/disappearing with
                  // _toShowReferenceColumns instead.
                  if (_toShowReferenceColumns)
                    SafeArea(
                      child: LetterNameColumnWidget(
                        controller: controller,
                        cellHeight: cellHeight,
                        scrollController: _letterNameVerticalController,
                      ),
                    ),

                  if (_toShowReferenceColumns)
                    SafeArea(
                      child: TranscriptionColumnWidget(
                        controller: controller,
                        cellHeight: cellHeight,
                        scrollController: _transcriptionVerticalController,
                      ),
                    ),

                  SafeArea(
                    child: PitchColumnWidget(
                      controller: controller,
                      cellHeight: cellHeight,
                      scrollController: _pitchVerticalController,
                      activeNoteRows: _activeNoteRows,
                    ),
                  ),


                  Expanded(
                    child: !hasMeasures
                        ? Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                        ),
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: const Icon(
                            Icons.copy,
                            size: 22,
                          ),
                        ),
                        label: const Text(
                          'Add Measures',
                          style: TextStyle(
                            fontSize: 22,
                          ),
                        ),
                        onPressed: () {
                          _openAppendMeasuresForm(context);
                        },
                      ),
                    )
                        : SafeArea(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (_isPlaying &&
                              notification.metrics.axis == Axis.horizontal &&
                              notification is ScrollUpdateNotification &&
                              notification.dragDetails != null) {
                            _playbackTicker?.stop();
                            _playbackTicker?.dispose();
                            _playbackTicker = null;

                            if (!_pauseScheduled) {
                              _pauseScheduled = true;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _pauseScheduled = false;
                                if (mounted) {
                                  setState(() => _isPlaying = false);
                                }
                              });
                            }
                          }
                          return false;
                        },
                        child: GridWidget(
                          controller: controller,
                          cellHeight: cellHeight,
                          verticalScrollController: _gridVerticalController,
                          horizontalScrollController: _gridHorizontalController,
                          leadingPadding: _effectiveLeadingPadding,
                          // Overlays help callouts on tempo/scale labels
                          // plus a general instructions banner, per
                          // request — see GridWidget's own helpMode doc.
                          helpMode: _helpMode,
                          // Scroll Lock is what controls this now — on
                          // means grid taps pause/resume playback
                          // instead of creating/editing notes; off means
                          // normal editing. Starting playback
                          // automatically turns Scroll Lock on (see
                          // _startPlayback); it stays on across a pause
                          // (so a second tap resumes) until explicitly
                          // turned off via its own button.
                          isPlaying: controller.inputLocked,
                          onTapWhilePlaying: _togglePlayback,
                        ),
                      ),
                    ),
                  ),

                ],

              ),

              // Help mode shows no banners or bubbles on the screen any
              // more: turning it on opens the guide pop-up
              // (_showGuideDialog), and tapping an icon shows what it
              // does.
            ],
          );


        },

      ),

    );

  }

}