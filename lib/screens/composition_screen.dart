import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:music_composer/dialogs/save_exit_dialog.dart';
import 'package:music_composer/utils/default_values.dart';

import '../controllers/composition_controller.dart';

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

  // Drives the grid's vertical scroll; the pitch column mirrors it so
  // the pitch labels always line up with the rows currently on screen.
  final ScrollController _gridVerticalController = ScrollController();
  final ScrollController _pitchVerticalController = ScrollController();

  // Drives the grid's horizontal scroll — used for both normal manual
  // scrolling and, while playing, the auto-scroll below.
  final ScrollController _gridHorizontalController = ScrollController();

  // =====================================================
  // PLAYBACK (auto-scroll timed to tempo)
  // =====================================================

  Ticker? _playbackTicker;
  Duration _lastTickerElapsed = Duration.zero;
  double _playbackTick = 0; // fractional current tick position
  bool _isPlaying = false;
  bool _pauseScheduled = false; // prevents scheduling the deferred
  // pause below more than once per gesture

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

    // Defensive: tear down any ticker that's still alive before making
    // a new one. SingleTickerProviderStateMixin throws if createTicker
    // is called while a previous ticker from it hasn't been disposed —
    // which could otherwise happen if Play is pressed again in the
    // brief window before a deferred pause (see the drag-detection
    // listener below) has actually run.
    _playbackTicker?.stop();
    _playbackTicker?.dispose();
    _playbackTicker = null;

    // Resume from wherever the grid is currently scrolled to, so a
    // paused playback picks up right where it left off, and a person
    // can also manually position the view and then hit play.
    _playbackTick = _gridHorizontalController.hasClients
        ? _gridHorizontalController.offset / controller.pixelsPerTick
        : 0;

    if (_playbackTick >= controller.maxTicks) {
      _playbackTick = 0; // was already at the end — start over
    }

    _lastTickerElapsed = Duration.zero;
    setState(() => _isPlaying = true);
    _playbackTicker = createTicker(_onPlaybackTick)..start();
  }

  /// Halts the ticker without resetting [_playbackTick] — this is a
  /// pause, not a stop: the grid stays scrolled exactly where playback
  /// left off, so hitting Play again resumes from that same spot.
  void _pausePlayback() {
    _playbackTicker?.stop();
    _playbackTicker?.dispose();
    _playbackTicker = null;
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  void _onPlaybackTick(Duration elapsed) {
    final dtSeconds =
        (elapsed - _lastTickerElapsed).inMicroseconds / 1000000.0;
    _lastTickerElapsed = elapsed;

    // Speed = (ticks per beat, from whichever measure we're currently
    // in) × (BPM, from whichever tempo event is currently active) / 60
    // — re-evaluated every frame so it correctly follows tempo changes
    // and measures with a different beat unit as playback crosses them.
    final currentTickInt =
    _playbackTick.floor().clamp(0, controller.maxTicks - 1);
    final measure = controller.getMeasureAtTick(currentTickInt);
    final activeTempo = controller.getActiveTempoAtTick(currentTickInt);

    final beatTicks = measure.timeSignature.beatDuration.ticks;
    final bpm = activeTempo?.tempo.value ?? 0;
    final ticksPerSecond = beatTicks * bpm / 60.0;

    final previousTickInt = _playbackTick.floor();

    _playbackTick += ticksPerSecond * dtSeconds;

    // Play every note whose start tick falls in the range playback
    // just crossed this frame (half-open, so each note triggers
    // exactly once as the cursor passes it — never re-triggered on
    // later frames, never skipped on fast frames covering many ticks).
    if (controller.soundEnabled) {
      final newTickInt = _playbackTick.floor();
      if (newTickInt > previousTickInt) {
        for (final note in controller.notes) {
          if (note.startTick >= previousTickInt &&
              note.startTick < newTickInt) {
            controller.playNoteSound(note);
          }
        }
      }
    }

    if (_playbackTick >= controller.maxTicks) {
      _playbackTick = controller.maxTicks.toDouble();
      _scrollTo(_playbackTick);
      // Reached the end on its own — pause here too (rather than a
      // silent auto-rewind), since _startPlayback already resets to 0
      // when play is pressed again from an at-the-end position.
      _pausePlayback();
      return;
    }

    _scrollTo(_playbackTick);
  }

  void _scrollTo(double tick) {
    if (!_gridHorizontalController.hasClients) return;
    final offset = tick * controller.pixelsPerTick;
    final maxScroll = _gridHorizontalController.position.maxScrollExtent;
    _gridHorizontalController.jumpTo(offset.clamp(0.0, maxScroll));
  }

  void _scrollToStart() {
    if (!_gridHorizontalController.hasClients) return;
    _gridHorizontalController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
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



  /// Checks for any measure whose scale has drifted from its original
  /// (via raise/lower) and, if so, asks the user whether to keep or
  /// revert before actually saving. Proceeds straight to saving if
  /// there's no drift, or if the user cancels the whole save.
  Future<bool> _saveComposition(BuildContext context) async {
    final driftIndices = controller.measuresWithScaleDrift();

    if (driftIndices.isNotEmpty) {
      final keepChanges = await scaleChangeWarningDialog(
        context: context,
        controller: controller,
        driftMeasureIndices: driftIndices,
      );

      if (keepChanges == null) {
        // User cancelled the whole save — signal callers (e.g. the
        // save-and-exit flow) not to navigate away either.
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

    // Show a small non-blocking indicator while saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saving...', style: TextStyle(fontSize: 22)),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final newId = await service.saveComposition(controller.composition);

      // If this was a brand-new composition, attach the returned id
      // so future saves update it instead of creating duplicates.
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

          return Row(
            children: [

              // =====================================================
              // TITLE COLUMN
              // =====================================================

              Container(
                width: 45,
                color: Colors.black,
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



              // =====================================================
              // LEFT TOOLBAR
              // =====================================================

              Container(
                width: 70,
                color: Colors.grey.shade300,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // HOME
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                        tooltip: 'Home',
                        onPressed: () {
                          saveExitDialog(
                            context,
                            onSave: () => _saveComposition(context),
                          );
                        },
                      ),

                      // SAVE
                      IconButton(
                        icon: const Icon(Icons.save,
                          color: Colors.black,
                        ),
                        tooltip: 'Save Composition',
                        onPressed: () {
                          _saveComposition(context);
                        },
                      ),

                      // EDIT INFO
                      IconButton(
                        icon: const Icon(Icons.title,
                          color: Colors.black,
                        ),
                        tooltip: 'Edit Title / Composer / Style / Instrument',
                        onPressed: () {
                          _showEditDialog(context);
                        },
                      ),

                      // NEW COMPOSITION
                      IconButton(
                        icon: const Icon(Icons.library_add,
                          color: Colors.black,
                        ),
                        tooltip: 'New Composition',
                        onPressed: () {
                          _showCreateDialog(context);
                        },
                      ),

                      // ADD MEASURES
                      IconButton(
                        icon: const Icon(Icons.copy,
                          color: Colors.black,
                        ),
                        tooltip: 'Add Measures',
                        onPressed: () {
                          _openAppendMeasuresForm(context);
                        },
                      ),


                      // PLAY / PAUSE — auto-scrolls the grid left to
                      // right at a speed derived from tempo and beat
                      // duration. Pausing keeps the current position,
                      // so Play resumes right where it left off.
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: _isPlaying ? Colors.blue : Colors.black,
                        ),
                        tooltip: _isPlaying ? 'Pause' : 'Play',
                        onPressed: hasMeasures ? _togglePlayback : null,
                      ),

                      // SCROLL TO START — jumps the horizontal view
                      // back to the very beginning of the composition.
                      IconButton(
                        icon: const Icon(
                          Icons.first_page,
                          color: Colors.black,
                        ),
                        tooltip: 'Scroll to Start',
                        onPressed: hasMeasures ? _scrollToStart : null,
                      ),

                      // SOUND ON/OFF — notes play a synthesized tone
                      // when created (by tapping the grid) and while
                      // scroll playback passes them; this toggles that
                      // off without affecting anything else.
                      IconButton(
                        icon: Icon(
                          controller.soundEnabled
                              ? Icons.volume_up
                              : Icons.volume_off,
                          color: Colors.black,
                        ),
                        tooltip: controller.soundEnabled
                            ? 'Sound On'
                            : 'Sound Off',
                        onPressed: controller.toggleSound,
                      ),


                      const Divider(
                        color: Colors.white24,
                      ),


                      // RAISE SCALE
                      IconButton(
                        icon: const Icon(Icons.arrow_upward,
                          color: Colors.black,
                        ),
                        tooltip: 'Raise scales',
                        onPressed:
                        controller.raiseAllScales,
                      ),


                      // RESET SCALE
                      IconButton(
                        icon: const Icon(Icons.adjust,
                          color: Colors.black,
                        ),
                        tooltip: 'Reset scales',
                        onPressed:
                        controller.resetAllScales,
                      ),


                      // LOWER SCALE
                      IconButton(
                        icon: const Icon(Icons.arrow_downward,
                          color: Colors.black,
                        ),
                        tooltip: 'Lower scales',
                        onPressed:
                        controller.lowerAllScales,
                      ),


                      // COMPENSATED NOTATION TOGGLE — switches between
                      // normal notation (scale sign + accidental shown
                      // separately, e.g. "4+" plus a "-") and a
                      // simplified view where opposing signs cancel to
                      // a plain note and matching signs respell as the
                      // next degree over. Purely a display switch —
                      // note.row/note.accidental never change, so this
                      // toggles back instantly with no data loss.
                      IconButton(
                        icon: Icon(Icons.auto_fix_high,
                          color: controller.showCompensatedNotation
                              ? Colors.blue
                              : Colors.black,
                        ),
                        tooltip: controller.showCompensatedNotation
                            ? 'Compensated Notation: On'
                            : 'Compensated Notation: Off',
                        onPressed:
                        controller.toggleCompensatedNotation,
                      ),


                      // SCROLL LOCK — blocks tapping the grid from
                      // creating/editing notes, so the composition can
                      // be scrolled around without accidentally adding
                      // a note on every tap.
                      IconButton(
                        icon: Icon(
                          controller.inputLocked
                              ? Icons.lock
                              : Icons.lock_open,
                          color: controller.inputLocked
                              ? Colors.blue
                              : Colors.black,
                        ),
                        tooltip: controller.inputLocked
                            ? 'Scroll Lock: On'
                            : 'Scroll Lock: Off',
                        onPressed:
                        controller.toggleInputLocked,
                      ),


                      // DRAW MODE — lets a person mark up the
                      // composition with freehand red-ink strokes;
                      // editing is disabled while this is on, and
                      // dragging draws instead of scrolling.
                      IconButton(
                        icon: Icon(
                          Icons.brush,
                          color: controller.drawMode
                              ? Colors.red
                              : Colors.black,
                        ),
                        tooltip: controller.drawMode
                            ? 'Draw Mode: On'
                            : 'Draw Mode: Off',
                        onPressed:
                        controller.toggleDrawMode,
                      ),

                      // UNDO STROKE — removes the most recent drawn
                      // stroke; only shown while draw mode is active
                      // (same pattern as the Paste button below, which
                      // only appears once there's something to paste).
                      if (controller.drawMode)
                        IconButton(
                          icon: const Icon(
                            Icons.undo,
                            color: Colors.black,
                          ),
                          tooltip: 'Undo Stroke',
                          onPressed: controller.drawStrokes.isEmpty
                              ? null
                              : controller.undoLastDrawStroke,
                        ),


                      // DURATION
                      IconButton(
                        icon: const Icon(Icons.av_timer,
                          color: Colors.black,
                        ),
                        tooltip: 'Note Duration',
                        onPressed: () {
                          globalDurationDialog(
                            context,
                            controller,
                          );
                        },
                      ),


                      // HAND
                      IconButton(
                        icon: Icon(Icons.pan_tool,
                          color:  controller.currentHand == Hand.right
                              ? Colors.black
                              : Colors.blue,
                        ),
                        tooltip: 'Hand',
                        onPressed:
                        controller.toggleHand,
                      ),


                      const Divider(
                        color: Colors.white24,
                      ),


                      // GRID SIZE
                      IconButton(
                        icon: const Icon(Icons.grid_on,
                          color: Colors.black,
                        ),
                        tooltip: 'Cell Width',
                        onPressed: () {
                          cellWidthDialog(
                            context,
                            controller,
                          );
                        },
                      ),


                      // PASTE
                      if (controller.canPaste)
                        IconButton(
                          icon: Icon(Icons.control_point_duplicate,
                            color: controller.pasteMode
                                ? Colors.blue
                                : Colors.black,
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


                      const Divider(
                        color: Colors.white24,
                      ),

                      // ZOOM IN
                      IconButton(
                        icon: const Icon(
                          Icons.zoom_in,
                          color: Colors.black,
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
                        icon: const Icon(
                          Icons.zoom_out,
                          color: Colors.black,
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
                        icon: const Icon(
                          Icons.center_focus_strong,
                          color: Colors.black,
                        ),
                        tooltip: 'Reset Zoom',
                        onPressed:
                        controller.resetZoom,
                      ),

                    ],

                  ),

                ),

              ),


              // =====================================================
              // PITCH COLUMN — constantly present, shows the current
              // scale's pitch for every one of the 56 rows. Scrolls
              // vertically in sync with the grid.
              // =====================================================

              SafeArea(
                child: PitchColumnWidget(
                  controller: controller,
                  cellHeight: cellHeight,
                  scrollController: _pitchVerticalController,
                ),
              ),


              // =====================================================
              // GRID AREA
              // =====================================================

              Expanded(
                child: !hasMeasures
                    ? Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(
                      Icons.playlist_add,
                      size: 22,
                      // color: Colors.black,
                    ),
                    label: const Text(
                      'Add Measures',
                      style: TextStyle(
                        fontSize: 22,
                        // color: Colors.black,
                        // fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _openAppendMeasuresForm(context);
                    },
                  ),
                )
                    : SafeArea(
                  child: NotificationListener<ScrollNotification>(
                    // If playback is running and the person starts an
                    // actual finger drag (as opposed to the jumpTo()
                    // calls the ticker itself makes every frame), pause
                    // playback — otherwise the next frame's jumpTo()
                    // would just override their gesture, and manual
                    // scrolling (especially backward) would look like
                    // it's not working at all.
                    //
                    // The ticker itself is torn down immediately (safe
                    // — no setState involved), so there's no window
                    // where Play could create a second ticker while
                    // this one is still alive. Only the setState/icon
                    // update is deferred to a post-frame callback,
                    // since this notification fires WHILE the
                    // descendant Scrollable's drag gesture is still
                    // being dispatched, and calling setState() at that
                    // exact moment can misbehave.
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