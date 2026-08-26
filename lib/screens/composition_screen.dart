import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:music_composer/dialogs/save_exit_dialog.dart';
import 'package:music_composer/utils/default_values.dart';

import '../controllers/composition_controller.dart';

import '../models/import_batches.dart';
import '../models/note_import.dart';

import '../dialogs/measure_range_dialog.dart';
import '../dialogs/cell_width_dialog.dart';
import '../dialogs/new_composition_dialog.dart';
import '../dialogs/global_duration_dialog.dart';
import '../dialogs/add_measures_dialog.dart';

import '../dialogs/simple_message_dialog.dart';
import '../dialogs/edit_composition_dialog.dart';
import '../dialogs/scale_change_warning_dialog.dart';
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
  static const int _ghostLeadInBeats = 2;

  // Blank scrollable space before tick 0, sized to EXACTLY match
  // _ghostLeadInBeats worth of ticks in pixels (not a fixed screen
  // fraction) — see GridWidget's own leadingPadding doc. Updated
  // every build(), since it depends on pixelsPerTick (zoom-
  // dependent) and the first measure's own ticksPerBeat.
  double _leadingPadding = 0;

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

    // Subtract leadingPadding before converting back to a tick — the
    // scroll offset now includes that leading blank space (see
    // _scrollTo), so the raw offset alone would overstate the tick.
    final tickFromScroll = _gridHorizontalController.hasClients
        ? (_gridHorizontalController.offset - _leadingPadding) /
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
    return _gridHorizontalController.offset <= _leadingPadding + 1;
  }

  void _scrollTo(double tick) {
    if (!_gridHorizontalController.hasClients) return;
    final offset = _leadingPadding + tick * controller.pixelsPerTick;
    final maxScroll = _gridHorizontalController.position.maxScrollExtent;
    _gridHorizontalController.jumpTo(offset.clamp(0.0, maxScroll));
  }

  Future<void> _scrollToStart() async {
    if (!_gridHorizontalController.hasClients) return;
    // Targets _leadingPadding (beat 1 at the pitch column), not 0
    // (which would show the blank leading padding itself) — this
    // button is for normal navigation/editing, not the pre-playback
    // "runway" moment (see _startPlayback for that).
    await _gridHorizontalController.animateTo(
      _leadingPadding,
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
          content: Text('Composition saved', style: TextStyle(fontSize: 22)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

          return Row(
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
                        tooltip: 'Home',
                        onPressed: () {
                          saveExitDialog(
                            context,
                            onSave: () => _saveComposition(context),
                          );
                        },
                      ),

                      // GRID DARK MODE
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: Icon(
                            controller.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: controller.isDarkMode
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                        tooltip: controller.isDarkMode
                            ? 'Grid Dark Mode: On'
                            : 'Grid Dark Mode: Off',
                        onPressed: () {
                          controller.toggleDarkMode();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.isDarkMode ? 'Dark mode on.' : 'Dark mode off.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 36),

                      // TO SHOW TITLE
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: Icon(
                            Icons.info_outline,
                            color: controller.gridFontSize ==
                                DefaultValues.gridFontSizeLarge
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                        tooltip: _toShowTitle
                            ? 'title is hidden'
                            : 'title is shown',
                        onPressed: () {
                          _showTitle();
                        },
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
                            ? 'Hide Finger Numbers: On'
                            : 'Hide Finger Numbers: Off',
                        onPressed: () {
                          controller.toggleHideFingerNumbers();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.hideFingerNumbers ? 'Fingers hidden.' : 'Fingers visible.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),


                      // SHOW ACCIDENTAL
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: Icon(
                            Icons.open_in_full_sharp,
                            color: controller.highlightAccidentalNotes
                                ? Colors.green
                                : Colors.black,
                          ),
                        ),
                        tooltip: controller.highlightAccidentalNotes
                            ? 'Highlight Accidental Notes: On'
                            : 'Highlight Accidental Notes: Off',
                        onPressed: () {
                          controller.toggleHighlightAccidentalNotes();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.highlightAccidentalNotes ? 'Highlight on.' : 'Highlight off.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),

                      // RAISE SCALE
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: const Icon(Icons.arrow_upward,
                            color: Colors.black,
                          ),
                        ),
                        tooltip: 'Raise scales',
                        onPressed: () {
                          controller.raiseAllScales();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Raised a semitone.',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),


                      // RESET SCALE
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: const Icon(Icons.adjust,
                            color: Colors.black,
                          ),
                        ),
                        tooltip: 'Reset scales',
                        onPressed: () {
                          controller.resetAllScales();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Scale reset.',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),


                      // LOWER SCALE
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: const Icon(Icons.arrow_downward,
                            color: Colors.black,
                          ),
                        ),
                        tooltip: 'Lower scales',
                        onPressed: () {
                          controller.lowerAllScales();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lowered a semitone.',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
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
                            ? 'Rotate Pitch Text: On'
                            : 'Rotate Pitch Text: Off',
                        onPressed: () {
                          controller.toggleRotatePitchText();
                          _setOrientationLocked(
                            context,
                            controller.rotatePitchText,
                          );
                        },
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
                            ? 'Compensated Notation: On'
                            : 'Compensated Notation: Off',
                        onPressed: () {
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
                              content: Text(
                                controller.showCompensatedNotation ? 'Easy Read on.' : 'Easy Read off.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
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
                            ? 'Scroll Lock: On'
                            : 'Scroll Lock: Off',
                        onPressed: () {
                          controller.toggleInputLocked();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.inputLocked ? 'Lock on.' : 'Lock off.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),


                      SizedBox(
                        height: 30,
                      ),


                      // ZOOM IN
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.black,
                          ),
                        ),
                        tooltip: 'Zoom In',
                        onPressed: () {
                          controller.setZoom(
                            controller.zoomX + 1,
                            controller.zoomY + 0.1,
                          );
                        },
                      ),

                      // ZOOM OUT
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: const Icon(
                            Icons.zoom_out,
                            color: Colors.black,
                          ),
                        ),
                        tooltip: 'Zoom Out',
                        onPressed: () {
                          controller.setZoom(
                            controller.zoomX - 1,
                            controller.zoomY - 0.1,
                          );
                        },
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
                        onPressed:
                        controller.resetZoom,
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
                        onPressed: () {
                          _saveComposition(context);
                        },
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
                        onPressed: () {
                          _showCreateDialog(context);
                        },
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
                        onPressed: () {
                          _openAppendMeasuresForm(context);
                        },
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
                            ? 'Grid Font Size: Large'
                            : 'Grid Font Size: Normal',
                        onPressed: () {
                          controller.toggleGridFontSize();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.gridFontSize ==
                                    DefaultValues.gridFontSizeLarge
                                    ? 'Labels larger.'
                                    : 'Labels normal.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 30),

                      // HAND
                      IconButton(
                        // Rotated the same way as every other toolbar
                        // icon now, matching request — my earlier
                        // exclusion of this one was wrong.
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: Icon(Icons.pan_tool,
                            color:  controller.currentHand == Hand.right
                                ? Colors.black
                                : Colors.blue,
                          ),
                        ),
                        tooltip: 'Hand',
                        onPressed: () {
                          controller.toggleHand();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.currentHand == Hand.right ? 'Right hand.' : 'Left hand.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),


                      // DURATION
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: const Icon(Icons.av_timer,
                            color: Colors.black,
                          ),
                        ),
                        tooltip: 'Note Duration',
                        onPressed: () {
                          globalDurationDialog(
                            context,
                            controller,
                          );
                        },
                      ),

                      // GRACE NOTES
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: Icon(
                            Icons.grain,
                            color: controller.isAddingGraceNotes
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                        tooltip: controller.isAddingGraceNotes
                            ? 'Add Grace Note Mode: On'
                            : 'Add Grace Note Mode: Off',
                        onPressed: () {
                          final wasOn = controller.isAddingGraceNotes;
                          controller.stopAddingGraceNotes();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                wasOn ? 'Grace note off.' : 'Tap a note to add.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
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
                            ? 'Legato Mode: On'
                            : 'Legato Mode: Off',
                        onPressed: () {
                          controller.toggleLegatoMode();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.legatoMode ? 'Legato on.' : 'Legato off.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),


                      // PASTE
                      // if (controller.canPaste)
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: Icon(Icons.control_point_duplicate,
                            color: controller.pasteMode
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                        tooltip: 'Paste',
                        onPressed: () {
                          if (controller.pasteMode) {
                            controller.exitPasteMode();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    DefaultValues.snackBarMessageForCopying.toString()
                                ),
                              ),
                            );
                          } else {
                            simpleMessageDialog(
                              context,
                              DefaultValues.titleOfMessageForCopying.toString(),
                              DefaultValues.messageForCopying.toString(),
                            );
                          }

                        },
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
                        onPressed: hasMeasures ? _togglePlayback : null,
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
                        onPressed: hasMeasures
                            ? () {
                          _scrollToStart();
                        }
                            : null,
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
                        onPressed: () {
                          controller.toggleSound();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.soundEnabled ? 'Sound on.' : 'Sound off.',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 30),

                      // GRID SIZE
                      IconButton(
                        icon: Transform.rotate(
                          angle: controller.rotatePitchText ? -pi / 2 : 0,
                          child: const Icon(Icons.grid_on,
                            color: Colors.black,
                          ),
                        ),
                        tooltip: 'Cell Width',
                        onPressed: () {
                          cellWidthDialog(
                            context,
                            controller,
                          );
                        },
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
                        tooltip: 'Export Measures as Text',
                        onPressed: () {
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
                        },
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
                        tooltip: 'Import Transcription',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              return StatefulBuilder(
                                builder: (dialogContext, setDialogState) {
                                  return AlertDialog(
                                    backgroundColor: Colors.white,
                                    surfaceTintColor: Colors.white,
                                    title: const Text(
                                      'Import Transcription',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: SizedBox(
                                      width: 400,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final batch
                                          in availableImportBatches)
                                            Builder(
                                              builder: (_) {
                                                final done = controller
                                                    .importedBatchLabels
                                                    .contains(
                                                    batch.label);
                                                return ListTile(
                                                  title: Text(
                                                    batch.label,
                                                    style: TextStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: done
                                                          ? Colors.grey
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                  trailing: Icon(
                                                    done
                                                        ? Icons
                                                        .check_circle
                                                        : Icons
                                                        .file_download,
                                                    color: done
                                                        ? Colors.green
                                                        : Colors.black,
                                                  ),
                                                  onLongPress: done
                                                      ? () {
                                                    controller
                                                        .resetImportedBatch(
                                                        batch.label);
                                                    setDialogState(
                                                            () {});
                                                    ScaffoldMessenger.of(
                                                        context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Can re-import.',
                                                          style: const TextStyle(
                                                              fontSize: 22),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                      : null,
                                                  onTap: done
                                                      ? null
                                                      : () {
                                                    final warnings =
                                                    controller
                                                        .importBatch(
                                                        batch);
                                                    setDialogState(
                                                            () {});
                                                    showDialog(
                                                      context:
                                                      dialogContext,
                                                      builder:
                                                          (resultContext) =>
                                                          AlertDialog(
                                                            backgroundColor:
                                                            Colors.white,
                                                            surfaceTintColor:
                                                            Colors.white,
                                                            title: Text(
                                                              warnings
                                                                  .isEmpty
                                                                  ? 'Import Complete'
                                                                  : 'Import Complete — '
                                                                  '${warnings.length} warning'
                                                                  '${warnings.length == 1 ? '' : 's'}',
                                                              style: const TextStyle(
                                                                fontSize: 22,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                            content: SizedBox(
                                                              width: 400,
                                                              child: warnings.isEmpty
                                                                  ? Text(
                                                                'All notes from ${batch.label} were created successfully.',
                                                                style: const TextStyle(fontSize: 22),
                                                              )
                                                                  : SingleChildScrollView(
                                                                child: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    for (final w in warnings)
                                                                      Padding(
                                                                        padding: const EdgeInsets.only(bottom: 8),
                                                                        child: Text(
                                                                          w.toString(),
                                                                          style: const TextStyle(fontSize: 18, color: Colors.red),
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.pop(resultContext),
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
                                                  },
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
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
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),



                    ],
                  ),
                ),
              ),

              //INFO OF TITLE
              _toShowTitle
                  ? Container(
                width: 46,
                color: Colors.grey.shade300,
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
                      leadingPadding: _leadingPadding,
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

          );


        },

      ),

    );

  }

}