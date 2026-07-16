import 'package:flutter/material.dart';
import '../models/composition.dart';
import '../models/timeline.dart';
import '../models/measure.dart';
import '../models/note.dart';
import '../enums/music_style.dart';
import '../enums/instrument.dart';
import 'note_values_dialog.dart';

class CreateCompositionDialog extends StatefulWidget {
  final Function(Composition) onCompositionCreated;

  const CreateCompositionDialog({super.key, required this.onCompositionCreated});

  @override
  State<CreateCompositionDialog> createState() => _CreateCompositionDialogState();
}

class _CreateCompositionDialogState extends State<CreateCompositionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'My Composition');
  final _composerController = TextEditingController(text: 'Anonymous');

  MusicStyle _selectedStyle = MusicStyle.classical;
  Instrument _selectedInstrument = Instrument.piano;

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  Widget _buildSelectionField({
    required String label,
    required String valueText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon, size: 22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                valueText,
                style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'New Composition Metadata',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.45,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Composition Title',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title, size: 22),
                  ),
                  style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _composerController,
                  decoration: const InputDecoration(
                    labelText: 'Composer Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, size: 22),
                  ),
                  style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _buildSelectionField(
                  label: 'Musical Style',
                  valueText: _selectedStyle.label,
                  icon: Icons.palette,
                  onTap: () {
                    noteValuesDialog<MusicStyle>(
                      context: context,
                      title: 'Select Style',
                      currentValue: _selectedStyle,
                      values: MusicStyle.values,
                      labelBuilder: (s) => s.label,
                      numberOfColumns: 3,
                      onSelected: (style) => setState(() => _selectedStyle = style),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildSelectionField(
                  label: 'Target Instrument',
                  valueText: _selectedInstrument.label,
                  icon: Icons.piano,
                  onTap: () {
                    noteValuesDialog<Instrument>(
                      context: context,
                      title: 'Select Instrument',
                      currentValue: _selectedInstrument,
                      values: Instrument.values,
                      labelBuilder: (i) => i.label,
                      numberOfColumns: 3,
                      onSelected: (inst) => setState(() => _selectedInstrument = inst),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
          ),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            final baseComposition = Composition(
              title: _titleController.text.trim(),
              composer: _composerController.text.trim(),
              style: _selectedStyle.label,
              instrument: _selectedInstrument.label,
              userId: 1,
              numberOfOctaves: 8,
              scaleName: 'major C',
              timeline: Timeline(measures: <Measure>[]),
              notes: <Note>[],
            );
            // Close the dialog first so it is cleared off the stack
            Navigator.pop(context);
            // ow pass the data and push the new screen forward safely
            widget.onCompositionCreated(baseComposition);
          },
          child: const Text(
            'Next',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}