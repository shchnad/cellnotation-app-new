import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:music_composer/dialogs/save_exit_dialog.dart';
import 'package:music_composer/utils/default_values.dart';

import '../controllers/composition_controller.dart';

import '../models/note_import.dart';

import '../dialogs/measure_range_dialog.dart';
import '../dialogs/cell_width_dialog.dart';
import '../dialogs/new_composition_dialog.dart';
import '../dialogs/global_duration_dialog.dart';
import '../dialogs/add_measures_dialog.dart';
import '../dialogs/hand_dialog.dart';

import '../dialogs/simple_message_dialog.dart';
import '../dialogs/edit_composition_dialog.dart';
import '../dialogs/scale_change_warning_dialog.dart';
import '../dialogs/sheet_music_transcription_dialog.dart';
import '../enums/hand.dart';

import '../services/composition_service.dart';
import '../widgets/grid_widget.dart';
import '../widgets/pitch_column_widget.dart';


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
    with TickerProviderStateMixin {

  CompositionController get controller => widget.controller;

  final ScrollController _gridVerticalController = ScrollController();
  final ScrollController _pitchVerticalController = ScrollController();

  final ScrollController _gridHorizontalController = ScrollController();

  Ticker? _playbackTicker;
  Duration _lastTickerElapsed = Duration.zero;
  double _playbackTick = 0;
  bool _isPlaying = false;
  bool _toShowTitle = false;

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
      _startPlayback();
    }
  }

  void _startPlayback() {
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
    if (!controller.inputLocked) {
      controller.toggleInputLocked();
    }
    if (!controller.showCompensatedNotation) {
      controller.toggleCompensatedNotation();
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
    final tickFromScroll = _gridHorizontalController.hasClients
        ? (_gridHorizontalController.offset - oldEffectivePadding) /
        controller.pixelsPerTick
        : 0.0;

    if (tickFromScroll <= 0 || tickFromScroll >= controller.maxTicks) {
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
    setState(() => _isPlaying = true);
    _playbackTicker = createTicker(_onPlaybackTick)..start();
  }

  void _pausePlayback() {
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

  void _onPlaybackTick(Duration elapsed) {
    final dtSeconds =
        (elapsed - _lastTickerElapsed).inMicroseconds / 1000000.0;
    _lastTickerElapsed = elapsed;

    final currentTickInt =
    _playbackTick.floor().clamp(0, controller.maxTicks - 1);
    final measure = controller.getMeasureAtTick(currentTickInt);
    final activeTempo = controller.getActiveTempoAtTick(currentTickInt);

    final beatTicks = measure.timeSignature.beatDuration.ticks;
    final bpm = activeTempo?.tempo.value ?? 0;
    final ticksPerSecond = beatTicks * bpm / 60.0;

    final previousTickInt = _playbackTick.floor();

    _playbackTick += ticksPerSecond * dtSeconds;

    if (controller.soundEnabled) {
      final newTickInt = _playbackTick.floor();
      if (newTickInt > previousTickInt) {
        for (final entry in controller.displayNotes) {
          final n = entry.note;
          if (n.startTick >= previousTickInt && n.startTick < newTickInt) {
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
      }
    }

    // Which rows currently have a note actively sounding (startTick
    // <= current tick < endTick) — highlighted green in the pitch
    // column (see PitchColumnWidget). Computed every frame regardless
    // of soundEnabled, since this is a visual indicator independent
    // of whether sound itself is on.
    final currentTickForHighlight = _playbackTick.floor();
    final newActiveRows = <int>{};
    for (final entry in controller.displayNotes) {
      final n = entry.note;
      if (n.startTick <= currentTickForHighlight &&
          currentTickForHighlight < n.endTick) {
        newActiveRows.add(n.row);
      }
    }
    _activeNoteRows.value = newActiveRows;

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

  @override
  void initState() {
    super.initState();
    _gridVerticalController.addListener(_syncPitchColumn);
  }

  void _syncPitchColumn() {
    if (_pitchVerticalController.hasClients) {
      _pitchVerticalController.jumpTo(_gridVerticalController.offset);
    }
  }

  @override
  void dispose() {
    _gridVerticalController.removeListener(_syncPitchColumn);
    _gridVerticalController.dispose();
    _pitchVerticalController.dispose();
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

    try {
      final newId = await service.saveComposition(controller.composition);

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
            final tickBeforeChange = _gridHorizontalController.hasClients
                ? (_gridHorizontalController.offset - oldEffectivePadding) /
                controller.pixelsPerTick
                : 0.0;
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [

                          SizedBox(
                            height: 30,
                          ),

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
                              // Help Mode and Scroll Lock now move
                              // together in both directions, per request
                              // — turning Help Mode on locks editing, and
                              // turning it back off releases the lock
                              // too, rather than leaving it stuck on.
                              if (_helpMode && !controller.inputLocked) {
                                controller.toggleInputLocked();
                              } else if (!_helpMode && controller.inputLocked) {
                                controller.toggleInputLocked();
                              }
                            },
                          ),

                          // TO SHOW TITLE
                          IconButton(
                            icon: Transform.rotate(
                              angle: controller.rotatePitchText ? -pi / 2 : 0,
                              child: Icon(
                                Icons.info_outline,
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


                          SizedBox(
                            height: 30,
                          ),


                          // HIDE FINGER
                          IconButton(
                            icon: Transform.rotate(
                              angle: controller.rotatePitchText ? -pi / 2 : 0,
                              child: Icon(
                                Icons.touch_app,
                                color: controller.hideFingerNumbers
                                    ? Colors.red
                                    : Colors.black,
                              ),
                            ),
                            tooltip: controller.hideFingerNumbers
                                ? 'Finger Numbers off'
                                : 'Finger Numbers on',
                            onPressed: _withHelp(
                                'Fingers Mode: \nHides fingering numbers.',
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
                                    ? Colors.red
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
                                  // Raising the scale forces Lock Mode
                                  // on, per request — it stays locked
                                  // until Reset Scale brings the
                                  // composition back to its original
                                  // scale (see the Reset Scale button
                                  // and the Lock Mode button's own
                                  // guard against turning off early).
                                  if (!controller.inputLocked) {
                                    controller.toggleInputLocked();
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
                                  // original is the ONLY way to
                                  // release the Lock Mode that raising
                                  // or lowering the scale forces on —
                                  // see the RAISE/LOWER SCALE buttons
                                  // and the Lock Mode button's own
                                  // guard.
                                  if (controller.inputLocked) {
                                    controller.toggleInputLocked();
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
                                  // Lowering the scale forces Lock
                                  // Mode on, per request — same as
                                  // raising it (see RAISE SCALE above)
                                  // — it stays locked until Reset
                                  // Scale brings the composition back
                                  // to its original scale.
                                  if (!controller.inputLocked) {
                                    controller.toggleInputLocked();
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


                          SizedBox(
                            height: 30,
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

                          // MAGIC MODE
                          IconButton(
                            icon: Transform.rotate(
                              angle: controller.rotatePitchText ? -pi / 2 : 0,
                              child: Icon(Icons.auto_fix_high,
                                color: controller.showCompensatedNotation
                                    ? Colors.red
                                    : Colors.black,
                              ),
                            ),
                            tooltip: controller.showCompensatedNotation
                                ? 'Easy Read Mode on'
                                : 'Easy Read Mode off',
                            onPressed: _withHelp(
                                'Easy Read Mode: \nShows a simplified notation.',
                                    () {
                                  controller.toggleCompensatedNotation();
                                  // Keep Scroll Lock in sync with Easy Read
                                  // Mode, per request — turning Easy Read on
                                  // turns Scroll Lock on too, and turning Easy
                                  // Read off turns Scroll Lock off too.
                                  if (controller.showCompensatedNotation !=
                                      controller.inputLocked) {
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
                                  // Lock Mode can't be turned OFF while
                                  // Easy Read Mode is on, per request —
                                  // Easy Read Mode requires Lock Mode
                                  // to stay on (see the Easy Read
                                  // button's own toggle, which turns
                                  // Lock Mode on together with it).
                                  // Only the OFF direction is blocked;
                                  // turning Lock Mode ON while Easy
                                  // Read is off still works normally.
                                  if (controller.inputLocked &&
                                      controller.showCompensatedNotation) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        duration: Duration(seconds: 1),
                                        content: Text(
                                          'Turn off Easy Read Mode first.',
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
                                  if (controller.inputLocked &&
                                      (controller.isScaleRaised ||
                                          controller.isScaleLowered)) {
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
                                  controller.toggleInputLocked();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 1),
                                      content: Text(
                                        controller.inputLocked
                                            ? 'Lock Mode on.'
                                            : 'Lock Mode off.',
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  );
                                }),
                          ),


                          SizedBox(
                            height: 30,
                          ),


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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [

                          SizedBox(height: 30),

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

                          SizedBox(height: 30),

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

                          SizedBox(height: 30),

                          // PLAYBACK - PAUSE
                          IconButton(
                            icon: Transform.rotate(
                              angle: controller.rotatePitchText ? -pi / 2 : 0,
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                // Pause icon (shown while scrolling) is
                                // always red. Play icon (shown while paused)
                                // is red only for an actual mid-piece pause
                                // with Lock Mode on — black if back at the
                                // beginning, or Lock Mode is off.
                                color: _isPlaying
                                    ? Colors.red
                                    : ((!_isAtBeginning && controller.inputLocked)
                                    ? Colors.red
                                    : Colors.black),
                              ),
                            ),
                            tooltip: _isPlaying ? 'Pause' : 'Play',
                            onPressed: _withHelp(
                              'Play/Pause: \nStarts or Pauses playback of the composition.',
                              hasMeasures ? _togglePlayback : null,
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

                          // SOUND
                          IconButton(
                            icon: Transform.rotate(
                              angle: controller.rotatePitchText ? -pi / 2 : 0,
                              child: Icon(
                                controller.soundEnabled
                                    ? Icons.volume_up
                                    : Icons.volume_off,
                                color: Colors.black,
                              ),
                            ),
                            tooltip: controller.soundEnabled
                                ? 'Sound On'
                                : 'Sound Off',
                            onPressed: _withHelp(
                                'Sound: \nSet audio off/on.',
                                    () {
                                  controller.toggleSound();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 1),
                                      content: Text(
                                        controller.soundEnabled ? 'Sound on.' : 'Sound off.',
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  );
                                }),
                          ),

                          SizedBox(height: 30),

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
                                    actionColor: Colors.black,
                                    onConfirm: (from, to) {
                                      final exported =
                                      controller.exportMeasureRange(from, to);
                                      final dynamicsText = controller
                                          .exportDynamicsAndHairpinsText(from, to);
                                      final text =
                                          formatImportMeasuresAsText(exported) +
                                              '\nDynamics / Dynamic Changes\n' +
                                              dynamicsText;
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
                                                  text,
                                                  style: const TextStyle(
                                                      fontSize: 18),
                                                ),
                                              ),
                                            ),
                                            actions: [
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
                    color: Colors.black,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showEditDialog(context),
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            '${controller.composition.composer} - ${controller.composition.title}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                      : SizedBox(),

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

              // Icon help labels — placed here, in the OUTER Stack
              // (painted AFTER the whole Row above, so always on
              // top), rather than nested inside the toolbar's own
              // narrow column — see _toolbarLabel's doc for why.
              if (_helpMode) _toolbarLabel(_handIconLink, 'Hand Set'),
              if (_helpMode) _toolbarLabel(_durationIconLink, 'Note Duration'),
              if (_helpMode) _toolbarLabel(_pasteIconLink, 'Paste Mode'),
              if (_helpMode) _toolbarLabel(_graceNotesIconLink, 'Grace Notes'),
            ],
          );


        },

      ),

    );

  }

}