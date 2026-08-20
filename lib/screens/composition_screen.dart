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
  bool _pauseScheduled = false;

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

    _playbackTicker?.stop();
    _playbackTicker?.dispose();
    _playbackTicker = null;

    _playbackTick = _gridHorizontalController.hasClients
        ? _gridHorizontalController.offset / controller.pixelsPerTick
        : 0;

    if (_playbackTick >= controller.maxTicks) {
      _playbackTick = 0;
    }

    _lastTickerElapsed = Duration.zero;
    setState(() => _isPlaying = true);
    _playbackTicker = createTicker(_onPlaybackTick)..start();
  }

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

    if (_playbackTick >= controller.maxTicks) {
      _playbackTick = controller.maxTicks.toDouble();
      _scrollTo(_playbackTick);
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

          return Row(
            children: [

              Container(
                width: 45,
                color: Colors.grey.shade300,
                child: Column(
                  children: [

                    Theme(
                      data: Theme.of(context).copyWith(
                        iconButtonTheme: IconButtonThemeData(
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [

                          SizedBox(
                            height: 30,
                          ),

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

                          // GRID DARK MODE
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

                          // GRID FONT SIZE
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

                        ],
                      ),
                    ),

                    Expanded(
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
                  ],
                ),
              ),



              Builder(
                builder: (context) {
                  final buttons = <Widget>[

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

                    SizedBox(
                      height: 20,
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

                    SizedBox(
                      height: 20,
                    ),

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
                        _setOrientationLocked(
                          context,
                          controller.rotatePitchText,
                        );
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


                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: _isPlaying ? Colors.blue : Colors.black,
                      ),
                      tooltip: _isPlaying ? 'Pause' : 'Play',
                      onPressed: hasMeasures ? _togglePlayback : null,
                    ),

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

                    SizedBox(
                      height: 20,
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


                    SizedBox(
                      height: 20,
                    ),

                    IconButton(
                      icon: const Icon(
                        Icons.file_upload,
                        color: Colors.black,
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


                    IconButton(
                      icon: const Icon(
                        Icons.file_download,
                        color: Colors.black,
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
                                                        '"${batch.label}" can be imported again.',
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
                    child: Container(
                      width: 40,
                      height: double.infinity,
                      color: Colors.grey.shade300,
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


              SafeArea(
                child: PitchColumnWidget(
                  controller: controller,
                  cellHeight: cellHeight,
                  scrollController: _pitchVerticalController,
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
                    icon: const Icon(
                      Icons.copy,
                      size: 22,
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