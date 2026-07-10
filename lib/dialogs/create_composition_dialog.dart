import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../models/composition.dart';
import '../models/measure.dart';
import '../models/timeline.dart';
import '../models/time_signature.dart';
import '../enums/note_duration.dart';
import '../models/note.dart';

class CreateCompositionDialog extends StatefulWidget {
  final Function(Composition) onCompositionCreated;
  final CompositionController controller;

  const CreateCompositionDialog({
    super.key,
    required this.onCompositionCreated,
    required this.controller,
  });

  @override
  State<CreateCompositionDialog> createState() => _CreateCompositionDialogState();
}

class _CreateCompositionDialogState extends State<CreateCompositionDialog> {
  final _formKey = GlobalKey<FormState>();

  // Text Form Fields Configuration Controllers
  final _titleController = TextEditingController(text: 'My Composition');
  final _composerController = TextEditingController(text: 'Anonymous');
  final _measuresController = TextEditingController(text: '4');

  // Exact Model Param Trackers
  int _beatsPerMeasure = 4;
  NoteDuration _selectedBeatUnit = NoteDuration.quarter;

  late String _selectedScale;

  @override
  void initState() {
    super.initState();
    _selectedScale = widget.controller.availableScales.isNotEmpty
        ? widget.controller.availableScales.first
        : 'major C';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    _measuresController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double fontSize = 20.0;

    return AlertDialog(
      title: const Text(
        'New Composition',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Composition Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  style: const TextStyle(fontSize: fontSize),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _composerController,
                  decoration: const InputDecoration(
                    labelText: 'Composer Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  style: const TextStyle(fontSize: fontSize),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const Divider(height: 32, thickness: 1),

                const Text(
                  'Time Signature',
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _beatsPerMeasure,
                        decoration: const InputDecoration(labelText: 'Beats', border: OutlineInputBorder()),
                        items: [1, 2, 3, 4, 5, 6, 7, 9, 12].map((b) {
                          return DropdownMenuItem(value: b, child: Text('$b', style: const TextStyle(fontSize: fontSize)));
                        }).toList(),
                        onChanged: (val) => setState(() => _beatsPerMeasure = val ?? 4),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text('/', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<NoteDuration>(
                        value: _selectedBeatUnit,
                        decoration: const InputDecoration(labelText: 'Beat Unit', border: OutlineInputBorder()),
                        items: NoteDuration.values.map((duration) {
                          return DropdownMenuItem(
                            value: duration,
                            child: Text(
                              duration.label,
                              style: const TextStyle(fontSize: fontSize),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedBeatUnit = val ?? NoteDuration.quarter),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32, thickness: 1),

                const Text(
                  'Initial Scale Key',
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedScale,
                  decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.music_note)),
                  isExpanded: true,
                  items: widget.controller.availableScales.map((scale) {
                    return DropdownMenuItem(
                      value: scale,
                      child: Text(scale, style: const TextStyle(fontSize: fontSize)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedScale = val ?? _selectedScale),
                ),
                const Divider(height: 32, thickness: 1),

                TextFormField(
                  controller: _measuresController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of Measures to Generate',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.playlist_add_check),
                  ),
                  style: const TextStyle(fontSize: fontSize),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final num = int.tryParse(value);
                    if (num == null || num <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(fontSize: 20, color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _submitForm,
          child: const Text('Create', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final timeSignature = TimeSignature(
      beats: _beatsPerMeasure,
      beatUnit: _selectedBeatUnit,
    );

    // FIXED TYPE INFUSION: Explicitly casts the array type to solve compiler inference failures
    final timeline = Timeline(measures: <Measure>[]);

    final int countOfMeasures = int.parse(_measuresController.text);
    for (int i = 0; i < countOfMeasures; i++) {
      timeline.addMeasure(timeSignature);
    }

    // Matches every single required parameter found within your exact model specification
    final newComposition = Composition(
      title: _titleController.text.trim(),
      composer: _composerController.text.trim(),
      style: 'Classical',
      instrument: 'Piano',
      userId: 1,
      numberOfOctaves: 8,
      scaleName: _selectedScale,
      timeline: timeline,
      notes: <Note>[],
    );

    final targetIndex = widget.controller.availableScales.indexOf(_selectedScale);
    if (targetIndex != -1) {
      widget.controller.setScale(targetIndex);
    }

    widget.onCompositionCreated(newComposition);
    Navigator.pop(context);
  }
}