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
    //
    // Uses controller.displayNotes rather than controller.notes: a
    // plain note comes through unchanged (isGhost: false) and plays
    // exactly as before, but a note carrying an ornament is expanded
    // into its short "ghost" sequence of sub-notes (see
    // CompositionController.displayNotes / Ornament.shiftMap) — so
    // instead of the ornamented note sounding as one long tone at its
    // base pitch, each ghost in the sequence triggers its own tone,
    // at its own onset tick, at its own EXACT pitch (the real note's
    // own actual pitch — accidental included — shifted by its raw
    // semitone shift; see CompositionController.getOrnamentFrequencyHz),
    // actually playing the ornament's pattern regardless of how it's
    // currently drawn. entry.interactionNote is always the real
    // underlying note for a ghost (not just when clickable), which is
    // what supplies that actual pitch.
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
              // TITLE COLUMN — tap to edit title/composer/style/
              // instrument (see _showEditDialog); this replaces the
              // toolbar's old separate "Edit Info" button.
              // =====================================================

              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showEditDialog(context),
                child: Container(
                  width: 45,
                  color: Colors.grey.shade300,
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
              ),



              // =====================================================
              // LEFT TOOLBAR — compact IconButtons via a local Theme
              // override, laid out as a single vertical Column at a
              // small FIXED width (see below) and scrolling if there
              // isn't room for every button. Earlier attempts tried a
              // multi-column Wrap sized either via IntrinsicWidth or
              // an estimated column count — both approaches guessed
              // at each button's true rendered size and consistently
              // got it wrong (too wide, or overflowing) in one
              // direction or the other. A single fixed-width column
              // has no guessing involved at all.
              // =====================================================

              Builder(
                builder: (context) {
                  final buttons = <Widget>[
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


                    // HAND
                    IconButton(
                      icon: Icon(Icons.pan_tool,
                        color:  controller.currentHand == Hand.right
                            ? Colors.black
                            : Colors.blue,
                      ),
                      tooltip: 'Hand',
                      onPressed: () {
                        controller.toggleHand();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.currentHand == Hand.right
                                  ? 'The right hand is set.'
                                  : 'The left hand is set.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
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

                    // ADD GRACE NOTE MODE — only ever turned ON
                    // from a note's own dialog (choosing a grace
                    // note type there needs a specific note to
                    // attach to — see
                    // CompositionController.startAddingGraceNotes),
                    // but can always be turned OFF from here.
                    // While on, every grid tap adds another
                    // grace note to whichever note started it
                    // (see CompositionController.
                    // addGraceNoteAtRow), up to
                    // maxGraceNotesPerNote.
                    IconButton(
                      icon: Icon(
                        Icons.grain,
                        color: controller.isAddingGraceNotes
                            ? Colors.blue
                            : Colors.black,
                      ),
                      tooltip: controller.isAddingGraceNotes
                          ? 'Add Grace Note Mode: On'
                          : 'Add Grace Note Mode: Off',
                      onPressed: () {
                        // This button can only ever turn the mode
                        // OFF (see the comment above) — if it was
                        // already off, there's nothing to toggle,
                        // so the message instead explains the
                        // only way to actually turn it ON.
                        final wasOn = controller.isAddingGraceNotes;
                        controller.stopAddingGraceNotes();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              wasOn
                                  ? 'Add Grace Note mode is off.'
                                  : 'To add grace notes, tap the '
                                  'note and choose Grace Notes.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),

                    // LEGATO MODE — while on, tapping a note toggles
                    // its own legato flag instead of opening the
                    // note-edit dialog. Independent of Articulation
                    // (a note can be legato and, say, sforzando at
                    // the same time).
                    IconButton(
                      icon: Icon(
                        Icons.airline_stops_outlined,
                        color: controller.legatoMode
                            ? Colors.red
                            : Colors.black,
                      ),
                      tooltip: controller.legatoMode
                          ? 'Legato Mode: On'
                          : 'Legato Mode: Off',
                      onPressed: () {
                        controller.toggleLegatoMode();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.legatoMode
                                  ? 'Legato mode is on. Tap notes '
                                  'to mark them as played legato.'
                                  : 'Legato mode is off.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),

                    // HIGHLIGHT ACCIDENTAL NOTES — purely a
                    // display toggle (see CompositionController.
                    // highlightAccidentalNotes): while on, every
                    // note with a non-null accidental is drawn
                    // green in the grid instead of its usual
                    // hand-based color; toggling off instantly
                    // restores their normal color, since no note
                    // data is actually changed. Icon itself turns
                    // green (rather than the usual blue used by
                    // other toggles) to preview what the toggle
                    // does. Same icon NoteDialog uses for its own
                    // Accidental field, for visual consistency.
                    IconButton(
                      icon: Icon(
                        Icons.open_in_full_sharp,
                        color: controller.highlightAccidentalNotes
                            ? Colors.green
                            : Colors.black,
                      ),
                      tooltip: controller.highlightAccidentalNotes
                          ? 'Highlight Accidental Notes: On'
                          : 'Highlight Accidental Notes: Off',
                      onPressed: () {
                        controller.toggleHighlightAccidentalNotes();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.highlightAccidentalNotes
                                  ? 'Notes which do not belong to '
                                  'the scale are highlighted in '
                                  'green.'
                                  : 'Highlight mode is off.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),


                    // HIDE FINGER NUMBERS — purely a display
                    // toggle (see CompositionController.
                    // hideFingerNumbers): while on, every note's
                    // finger number is hidden in the grid;
                    // toggling off instantly restores them, since
                    // no note data is actually changed.
                    IconButton(
                      icon: Icon(
                        Icons.touch_app,
                        color: controller.hideFingerNumbers
                            ? Colors.red
                            : Colors.black,
                      ),
                      tooltip: controller.hideFingerNumbers
                          ? 'Hide Finger Numbers: On'
                          : 'Hide Finger Numbers: Off',
                      onPressed: () {
                        controller.toggleHideFingerNumbers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.hideFingerNumbers
                                  ? 'Fingers are hidden.'
                                  : 'Fingers are visible.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),


                    // GRID FONT SIZE — toggles the shared font
                    // size used by every grid annotation label
                    // (finger number, playing technique, time
                    // signature, pedal, dynamic, tempo, scale
                    // name, measure number — see
                    // CompositionController.gridFontSize /
                    // DefaultValues.gridFontSize /
                    // gridFontSizeLarge) between 16 and 22.
                    IconButton(
                      icon: Icon(
                        Icons.format_size,
                        color: controller.gridFontSize ==
                            DefaultValues.gridFontSizeLarge
                            ? Colors.blue
                            : Colors.black,
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
                                  ? 'Grid labels are now larger.'
                                  : 'Grid labels are back to '
                                  'normal size.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
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
                      onPressed: () {
                        controller.toggleInputLocked();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.inputLocked
                                  ? 'Lock mode is on, no input is '
                                  'possible. To be able to edit, '
                                  'the button must be toggled.'
                                  : 'Lock mode is off.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
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
                      onPressed: () {
                        controller.toggleCompensatedNotation();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.showCompensatedNotation
                                  ? 'Easy Read mode is on and no '
                                  'edit is possible. To return to '
                                  'normal, the button must be '
                                  'toggled.'
                                  : 'Easy Read mode is off.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),

                    // ROTATE PITCH TEXT — rotates the pitch
                    // label drawn inside each note cell, handy
                    // when cells are narrow. Also drives Easy
                    // Read mode (Compensated Notation) and
                    // Scroll Lock to match its own new state —
                    // see CompositionController.
                    // toggleRotatePitchText.
                    IconButton(
                      icon: Icon(Icons.rotate_left,
                        color: controller.rotatePitchText
                            ? Colors.blue
                            : Colors.black,
                      ),
                      tooltip: controller.rotatePitchText
                          ? 'Rotate Pitch Text: On'
                          : 'Rotate Pitch Text: Off',
                      onPressed: () {
                        controller.toggleRotatePitchText();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.rotatePitchText
                                  ? 'The grid is rotated for '
                                  'piano reading. Easy Read '
                                  'mode and Scroll Lock are '
                                  'now on too.'
                                  : 'The grid is rotated for '
                                  'notation reading. Easy Read '
                                  'mode and Scroll Lock are '
                                  'now off too.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
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
                      onPressed: hasMeasures
                          ? () {
                        _scrollToStart();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Scrolled to the beginning.',
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      }
                          : null,
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
                      onPressed: () {
                        controller.toggleSound();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.soundEnabled
                                  ? 'The sound is on.'
                                  : 'The sound is off.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),




                    // RAISE SCALE
                    IconButton(
                      icon: const Icon(Icons.arrow_upward,
                        color: Colors.black,
                      ),
                      tooltip: 'Raise scales',
                      onPressed: () {
                        controller.raiseAllScales();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'The composition is raised a semitone.',
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),


                    // RESET SCALE
                    IconButton(
                      icon: const Icon(Icons.adjust,
                        color: Colors.black,
                      ),
                      tooltip: 'Reset scales',
                      onPressed: () {
                        controller.resetAllScales();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'The initial scale is set back.',
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),


                    // LOWER SCALE
                    IconButton(
                      icon: const Icon(Icons.arrow_downward,
                        color: Colors.black,
                      ),
                      tooltip: 'Lower scales',
                      onPressed: () {
                        controller.lowerAllScales();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'The composition is lowered a semitone.',
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
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


                    // GRID DARK MODE — inverts ONLY the grid
                    // itself (background/lines — see
                    // GridPainter.paint), the pitch column next
                    // to it, and every note's fill/text color
                    // (see NoteBlockWidget/AppColors). The rest
                    // of the app (this toolbar, every dialog)
                    // stays as-is — scoped to just the grid on
                    // request, not a full app-wide theme.
                    // Placed at the very bottom of the toolbar
                    // per request.
                    IconButton(
                      icon: Icon(
                        controller.isDarkMode
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        color: controller.isDarkMode
                            ? Colors.blue
                            : Colors.black,
                      ),
                      tooltip: controller.isDarkMode
                          ? 'Grid Dark Mode: On'
                          : 'Grid Dark Mode: Off',
                      onPressed: () {
                        controller.toggleDarkMode();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.isDarkMode
                                  ? 'Grid dark mode is on.'
                                  : 'Grid dark mode is off.',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),

                  ];

                  return Theme(
                    data: Theme.of(context).copyWith(
                      iconButtonTheme: IconButtonThemeData(
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(4),
                          minimumSize: const Size(36, 36),
                          iconSize: 22,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    // Single column, small FIXED width (exactly one
                    // button's worth + a couple pixels), scrolling
                    // vertically if there isn't room for every button
                    // on screen — deliberately NOT trying to estimate
                    // how many columns/pixels are needed (that
                    // required guessing each button's true rendered
                    // height, which never quite matched reality and
                    // kept making the toolbar either too wide or
                    // overflowing). A fixed single-column width has no
                    // guesswork at all: it's always exactly as thin as
                    // one button can be.
                    child: Container(
                      width: 40,
                      height: double.infinity,
                      color: Colors.grey.shade300,
                      // LayoutBuilder + ConstrainedBox(minHeight: full
                      // available height) + Center: if the buttons
                      // fit within the toolbar's full height, they're
                      // centered vertically rather than starting from
                      // the top; if they don't fit, the
                      // SingleChildScrollView still scrolls normally
                      // (ConstrainedBox's minHeight doesn't force the
                      // Column smaller than it naturally needs).
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: buttons,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
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
                      Icons.copy,
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