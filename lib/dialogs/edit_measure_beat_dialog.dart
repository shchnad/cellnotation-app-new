import 'package:flutter/material.dart';
import 'package:music_composer/dialogs/tempo_dialog.dart';

import '../controllers/composition_controller.dart';
import '../utils/scale_resolver.dart';
import 'dynamic_change_dialog.dart';
import 'dynamic_dialog.dart';
import 'measure_range_dialog.dart';
import 'pedal_dialog.dart';
import 'scale_dialog.dart';


/// Asks how many ordinary beats long a fermata-stretched beat should
/// last, then applies it via CompositionController.applyFermataToBeat
/// — a few common preset options (2/3/5/10 beats) plus a free-form
/// number field for anything else, per request. Public (not
/// file-private) so grid_widget.dart can open this directly when the
/// blue "fz" label on an already-stretched beat is tapped. If a
/// fermata is already applied to this beat (see
/// CompositionController.getFermataMultiplier), a "Delete Fermata"
/// option is also shown, reverting the beat back to its normal width
/// via CompositionController.deleteFermata.
void fermataDialog({
  required BuildContext context,
  required CompositionController controller,
  required int measureIndex,
  required int beatIndex,
}) {
  final customController = TextEditingController();
  final currentMultiplier =
  controller.getFermataMultiplier(measureIndex, beatIndex);

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Set Fermata',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How many beats long should this beat be held?',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 8),
              for (final n in [2, 3, 5, 10])
                ListTile(
                  title: Text(
                    '$n beats',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    controller.applyFermataToBeat(
                      measureIndex,
                      beatIndex,
                      n,
                    );
                    Navigator.pop(dialogContext);
                  },
                ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Custom',
                        labelStyle: TextStyle(fontSize: 18),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final n = int.tryParse(customController.text.trim());
                      if (n == null || n <= 1) return;
                      controller.applyFermataToBeat(
                        measureIndex,
                        beatIndex,
                        n,
                      );
                      Navigator.pop(dialogContext);
                    },
                    child: const Text(
                      'Set',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              if (currentMultiplier != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  iconColor: Colors.red,
                  title: const Text(
                    'Delete Fermata',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    controller.deleteFermata(measureIndex, beatIndex);
                    Navigator.pop(dialogContext);
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
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
}


void editMeasureBeatDialog({
  required BuildContext context,
  required CompositionController controller,
  required int measureIndex,
  required int beatIndex,
}) {
  showDialog(
    context: context,
    builder: (_) {
      // Read once at build time — the dialog is rebuilt fresh each
      // time it's opened, so this reflects the current state and the
      // "Delete Fermata" option below only needs to be correct at
      // open time (the dialog closes after any action anyway, same
      // as every other ListTile here).
      final currentFermataMultiplier =
      controller.getFermataMultiplier(measureIndex, beatIndex);

      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        // Tight explicit padding on every side — AlertDialog's own
        // DEFAULT padding (contentPadding/actionsPadding/insetPadding)
        // is fairly generous and was never overridden here before,
        // adding real height on top of the content itself even with
        // every ListTile already as compact as possible.
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),

        // FIXED size, rather than computing an exact width from the
        // longest label — that approach kept causing edge cases
        // (text wrapping when the estimate was too tight, then a
        // genuine RenderFlex overflow when the sum of both columns'
        // measured widths exceeded what AlertDialog actually had
        // available). A fixed size is simple and predictable instead.
        // Each column gets its own SingleChildScrollView as a safety
        // net in case content ever doesn't fit within 560 — normally
        // this never engages and nothing looks scrollable at all.
        content: SizedBox(
          width: 560,
          height: 560,
          child: Theme(
            data: Theme.of(context).copyWith(
              listTileTheme: const ListTileThemeData(
                dense: true,
                visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                minVerticalPadding: 0,
                minLeadingWidth: 24,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // LEFT COLUMN
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        Text(
                          "Measure ${measureIndex + 1}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        ListTile(
                          leading: const Icon(Icons.playlist_add),
                          title: const Text(
                            "Insert Measure",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            final measure = controller.measures[measureIndex];
                            controller.insertMeasureAt(
                              measureIndex,
                              measure.timeSignature,
                              measure.scaleName,
                            );
                            Navigator.pop(context);
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.copy),
                          title: const Text(
                            "Duplicate Measure",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.copyMeasure(measureIndex);
                            Navigator.pop(context);
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.library_books_outlined),
                          title: const Text(
                            "Duplicate Range",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            measureRangeDialog(
                              context: context,
                              controller: controller,
                              title: 'Duplicate Measures',
                              actionLabel: 'Duplicate',
                              actionColor: Colors.blue,
                              onConfirm: (from, to) {
                                controller.duplicateMeasureRange(from, to);
                              },
                            );
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.cleaning_services_outlined),
                          title: const Text(
                            "Clean Measure",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.clearMeasureNotes(measureIndex);
                            Navigator.pop(context);
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.cleaning_services),
                          title: const Text(
                            "Clean Range",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            measureRangeDialog(
                              context: context,
                              controller: controller,
                              title: 'Clean Measures',
                              actionLabel: 'Clean',
                              actionColor: Colors.black,
                              onConfirm: (from, to) {
                                controller.clearMeasureRangeNotes(from, to);
                              },
                            );
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          iconColor: Colors.red,
                          title: const Text(
                            "Delete Measure",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.deleteMeasure(measureIndex);
                            Navigator.pop(context);
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.delete_sweep_outlined),
                          iconColor: Colors.red,
                          title: const Text(
                            "Delete Range",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            measureRangeDialog(
                              context: context,
                              controller: controller,
                              title: 'Delete Measures',
                              actionLabel: 'Delete',
                              actionColor: Colors.red,
                              onConfirm: (from, to) {
                                controller.deleteMeasureRange(from, to);
                              },
                            );
                          },
                        ),

                        const Divider(height: 8),

                        ListTile(
                          leading: const Icon(Icons.lock_clock),
                          iconColor: Colors.blue,
                          title: const Text(
                            "Set Tempo",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            tempoDialog(
                              context,
                              controller,
                              controller.getBeatTick(
                                measureIndex,
                                beatIndex,
                              ),
                            );
                          },
                        ),

                        const Divider(),

                        ListTile(
                          leading: const Icon(Icons.music_note),
                          iconColor: Colors.black,
                          title: const Text(
                            "Set Scale",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            scaleDialog(
                              context: context,
                              controller: controller,
                              currentScale: ScaleResolver.normalizeScaleName(
                                controller.measures[measureIndex].scaleName,
                              ),
                              onSelected: (scale) {
                                controller.updateMeasureScale(
                                  measureIndex,
                                  scale,
                                );
                              },
                            );
                          },
                        ),

                      ],
                    ),
                  ),
                ),

                const VerticalDivider(thickness: 1),

                // RIGHT COLUMN
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        Text(
                          "Beat ${beatIndex + 1}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        ListTile(
                          leading: const Icon(Icons.playlist_add),
                          title: const Text(
                            "Insert Beat",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.addBeatToMeasure(measureIndex);
                            Navigator.pop(context);
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.copy),
                          title: const Text(
                            "Duplicate Beat",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.copyBeat(measureIndex, beatIndex);
                            Navigator.pop(context);
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.cleaning_services_outlined),
                          title: const Text(
                            "Clean Beat",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.clearBeatNotes(measureIndex, beatIndex);
                            Navigator.pop(context);
                          },
                        ),

                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          iconColor: Colors.red,
                          title: const Text(
                            "Delete Beat",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.removeBeatFromMeasure(
                              measureIndex,
                              beatIndex,
                            );
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(),
                        // FERMATA — moved into the beat column, per
                        // request (previously in the measure column
                        // under Set Tempo). Opens a small picker
                        // asking how many beats long to stretch this
                        // beat, then applies it via
                        // CompositionController.applyFermataToBeat.
                        ListTile(
                          leading: const Icon(Icons.pause_circle_outline),
                          iconColor: Colors.blue,
                          title: const Text(
                            "Set Fermata",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            fermataDialog(
                              context: context,
                              controller: controller,
                              measureIndex: measureIndex,
                              beatIndex: beatIndex,
                            );
                          },
                        ),


                        const Divider(height: 8),

                        ListTile(
                          leading: const Icon(Icons.campaign_outlined),
                          iconColor: Colors.green,
                          title: const Text(
                            "Set Dynamic",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            dynamicDialog(
                              context,
                              controller,
                              controller.getBeatTick(
                                measureIndex,
                                beatIndex,
                              ),
                            );
                          },
                        ),


                        ListTile(
                          leading: const Icon(Icons.bar_chart_outlined),
                          iconColor: Colors.green,
                          title: const Text(
                            "Set Dynamic Change",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            dynamicChangeDialog(
                              context,
                              controller,
                              controller.getBeatTick(
                                measureIndex,
                                beatIndex,
                              ),
                            );
                          },
                        ),

                        // PEDAL — same pattern as "Set Dynamic Change"
                        // above: opens a dedicated grid-of-options
                        // dialog (pedalDialog) with Delete/Close
                        // actions, rather than toggling in place.
                        ListTile(
                          leading: const Icon(Icons.arrow_circle_down),
                          iconColor: Colors.green,
                          title: const Text(
                            "Set Pedal",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            pedalDialog(
                              context,
                              controller,
                              controller.getBeatTick(
                                measureIndex,
                                beatIndex,
                              ),
                            );
                          },
                        ),


                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        actions: [
          const Divider(thickness: 1.0, height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      );

    },
  );

}