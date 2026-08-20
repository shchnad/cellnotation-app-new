// Registry of every available transcription batch, in the order
// they should be imported (earlier entries first — batches often
// depend on earlier ones existing already, e.g. a sustained note
// carrying over a barline). To add a new batch of measures: create
// its own example_import_measures_X_to_Y.dart file (matching the
// pattern of the existing ones), then just add one more ImportBatch
// entry to this list — nothing else needs to change, since the
// import UI (see composition_screen.dart) reads this list directly.

import 'example_import_measures_1_to_6.dart';
import 'example_import_measures_7_to_8.dart';
import 'note_import.dart';

final List<ImportBatch> availableImportBatches = [
  ImportBatch(label: 'Measures 1–6', measures: exampleMeasures1to6),
  ImportBatch(label: 'Measures 7–8', measures: exampleMeasures7to8),
];