import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../models/composition.dart';
import '../models/measure.dart';
import '../models/timeline.dart';
import '../models/time_signature.dart';
import '../enums/note_duration.dart';
import '../enums/music_style.dart';
import '../enums/instrument.dart';
import '../models/note.dart';
import 'noteValues_dialog.dart';
import 'scale_dialog.dart';


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

  final _titleController = TextEditingController(text: 'My Composition');
  final _composerController = TextEditingController(text: 'Anonymous');
  final _measuresController = TextEditingController(text: '4');

  int _beatsPerMeasure = 4;
  NoteDuration _selectedBeatUnit = NoteDuration.quarter;
  MusicStyle _selectedStyle = MusicStyle.classical;
  Instrument _selectedInstrument = Instrument.piano;

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    _measuresController.dispose();
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
        FocusScope.of(context).unfocus(); // Drops the keyboard safely before switching dialogs
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
    final parts = widget.controller.scaleName.split(' ');
    final scaleDisplayLabel = parts.length == 2
        ? '${parts[1]} ${parts[0]}'
        : parts.length > 2
        ? '${parts.sublist(1).join(' ')} ${parts[0]}'
        : widget.controller.scaleName;

    return SafeArea(
      child: AlertDialog(
        alignment: Alignment.topCenter, // Anchors the card upwards
        insetPadding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
        title: const Text(
          'New Composition',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: SingleChildScrollView( // <-- Bulletproof fix against keyboard shrinking screen space
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= LEFT COLUMN =================
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Composition Title',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      const SizedBox(width: 16),

                      // ================= RIGHT COLUMN =================
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Time Signature', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          value: _beatsPerMeasure,
                                          isDense: true,
                                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), border: OutlineInputBorder()),
                                          items: [1, 2, 3, 4, 5, 6, 7, 9, 12].map((b) {
                                            return DropdownMenuItem(value: b, child: Text('$b', style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold)));
                                          }).toList(),
                                          onChanged: (val) => setState(() => _beatsPerMeasure = val ?? 4),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                                        child: Text('/', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            FocusScope.of(context).unfocus();
                                            noteValuesDialog<NoteDuration>(
                                              context: context,
                                              title: 'Select Duration',
                                              currentValue: _selectedBeatUnit,
                                              values: NoteDuration.values,
                                              labelBuilder: (d) => d.label,
                                              numberOfColumns: 3,
                                              onSelected: (dur) => setState(() => _selectedBeatUnit = dur),
                                            );
                                          },
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              border: OutlineInputBorder(),
                                            ),
                                            child: Text(_selectedBeatUnit.label, style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSelectionField(
                              label: 'Scale Key',
                              valueText: scaleDisplayLabel,
                              icon: Icons.music_note,
                              onTap: () {
                                showScaleDialog(context, widget.controller);
                                Future.delayed(const Duration(milliseconds: 250), () {
                                  if (mounted) setState(() {});
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _measuresController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Measures to Generate',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.playlist_add_check, size: 22),
                              ),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Required';
                                final num = int.tryParse(value);
                                if (num == null || num <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: _submitForm,
            child: const Text('Create', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final timeSignature = TimeSignature(
      beats: _beatsPerMeasure,
      beatUnit: _selectedBeatUnit,
    );

    final timeline = Timeline(measures: <Measure>[]);
    final int countOfMeasures = int.parse(_measuresController.text);
    for (int i = 0; i < countOfMeasures; i++) {
      timeline.addMeasure(timeSignature);
    }

    final newComposition = Composition(
      title: _titleController.text.trim(),
      composer: _composerController.text.trim(),
      style: _selectedStyle.label,
      instrument: _selectedInstrument.label,
      userId: 1,
      numberOfOctaves: 8,
      scaleName: widget.controller.scaleName,
      timeline: timeline,
      notes: <Note>[],
    );

    widget.onCompositionCreated(newComposition);
    Navigator.pop(context);
  }
}