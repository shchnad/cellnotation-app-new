import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';
import '../enums/note_duration.dart';
import '../models/note.dart';

/// Greedily decomposes [ticks] into a list of NoteDuration values
/// (largest first) summing to it — e.g. an eighth+half combination's
/// ticks decomposes back into [half, eighth]. Used both to display a
/// note's duration as a readable combination (see note_dialog.dart)
/// and to pre-seed this dialog's own combination when reopening it.
/// Returns an empty list if [ticks] <= 0. Any note whose duration was
/// set either via a single NoteDuration or via this dialog decomposes
/// exactly; a genuinely non-standard tick count (which shouldn't
/// normally reach here — grace notes use a separate display path)
/// just stops once no remaining standard duration fits the leftover
/// amount, silently dropping that remainder rather than showing an
/// inexact label.
List<NoteDuration> decomposeDurationTicks(int ticks) {
  final result = <NoteDuration>[];
  var remaining = ticks;
  final sortedDesc = NoteDuration.values.toList()
    ..sort((a, b) => b.ticks.compareTo(a.ticks));
  for (final d in sortedDesc) {
    while (d.ticks > 0 && remaining >= d.ticks) {
      result.add(d);
      remaining -= d.ticks;
    }
  }
  return result;
}

/// Lets the person build up [note]'s duration as the SUM of two or
/// more standard NoteDuration values — for a note that's really a tie
/// across a barline (or any other combined duration standard notation
/// can't express as one symbol). This app's grid is duration-based
/// rather than glyph-based, so a tie doesn't need two separate Note
/// objects — one Note with the combined duration is both simpler and
/// more accurate to what's actually sustained. Each tap on a duration
/// adds one instance of it to the running combination; the same
/// duration can be added more than once (e.g. two tied quarter
/// notes). Applying calls
/// CompositionController.setNoteDurationTicks with the sum, then
/// closes BOTH this dialog and the NoteDialog it was opened from
/// (using [context], the caller's own context — see the Apply button
/// below) — the whole point of combining is to finish editing that
/// note's duration, so there's nothing left to do in either dialog
/// once it's set.
void combinedDurationDialog({
  required BuildContext context,
  required CompositionController controller,
  required Note note,
}) {
  // Pre-seeded with the note's CURRENT duration, decomposed back into
  // whichever standard durations sum to it — reopening this dialog
  // shows what's already set, the same way every other field's
  // picker shows its currentValue, now including combinations (not
  // just a single matching value).
  final combination = decomposeDurationTicks(note.durationTicks);

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          final totalTicks =
          combination.fold<int>(0, (sum, d) => sum + d.ticks);

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,

            title: const Text(
              "Set Duration",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const SizedBox(height: 12),

                  // CURRENT COMBINATION — readable summary, updates
                  // live as durations are added/removed below.
                  Text(
                    combination.isEmpty
                        ? 'Current: none'
                        : 'Current: ${combination.map((d) => d.label).join(' + ')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // PICKER GRID — tapping a duration ADDS it (never
                  // replaces the running combination), matching the
                  // "keep tapping to build up the total" model this
                  // whole dialog is built around. A duration already
                  // part of the combination is highlighted in blue,
                  // so it's clear at a glance which ones are active.
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 2,
                    children: NoteDuration.values.map((d) {
                      final isActive = combination.contains(d);
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          minimumSize: const Size(0, 36),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () {
                          setState(() {
                            combination.add(d);
                          });
                        },
                        child: Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 22,
                            color: isActive ? Colors.blue : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // CURRENT COMBINATION — tap a chip to remove just
                  // that one instance (not every instance of that
                  // duration, if it was added more than once).
                  if (combination.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (int i = 0; i < combination.length; i++)
                          ActionChip(
                            label: Text(
                              combination[i].label,
                              style: const TextStyle(fontSize: 16),
                            ),
                            onPressed: () {
                              setState(() {
                                combination.removeAt(i);
                              });
                            },
                          ),
                      ],
                    )
                  else
                    const Text(
                      'No durations added yet.',
                      style: TextStyle(fontSize: 22, color: Colors.black),
                    ),

                  const SizedBox(height: 8),

                  // Text(
                  //   'Total: $totalTicks ticks',
                  //   style: const TextStyle(
                  //     fontSize: 16,
                  //     fontWeight: FontWeight.bold,
                  //     color: Colors.black54,
                  //   ),
                  // ),

                  // const SizedBox(height: 8),

                  if (combination.isNotEmpty)
                    const Text(
                      'tap duration in the line to delete it',
                      style: TextStyle(fontSize: 22, color: Colors.black),
                    ),
                ],
              ),
            ),

            actions: [
              const Divider(thickness: 1.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: combination.isEmpty
                        ? null
                        : () => setState(() => combination.clear()),
                    child: const Text(
                      "Clear",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (totalTicks == 0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please choose some duration',
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                        return;
                      }
                      controller.setNoteDurationTicks(note, totalTicks);
                      // Closes this dialog, then the NoteDialog it was
                      // opened from too (via the caller's own
                      // context) — per request, setting the
                      // combination finishes the whole editing flow
                      // rather than dropping back to NoteDialog.
                      Navigator.pop(dialogContext);
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Apply",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color:  combination.isNotEmpty ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}