import 'package:flutter/material.dart';
import '../controllers/composition_controller.dart';
import '../models/composition.dart';
import '../models/time_signature.dart';
import '../enums/note_duration.dart';
import 'note_values_dialog.dart';
import 'scale_dialog.dart';

class AppendMeasuresDialog extends StatefulWidget {
  final Composition targetComposition;
  final CompositionController controller;
  final VoidCallback onMeasuresAppended;

  const AppendMeasuresDialog({
    super.key,
    required this.targetComposition,
    required this.controller,
    required this.onMeasuresAppended,
  });

  @override
  State<AppendMeasuresDialog> createState() => _AppendMeasuresDialogState();
}

class _AppendMeasuresDialogState extends State<AppendMeasuresDialog> {
  final _formKey = GlobalKey<FormState>();
  final _measuresController = TextEditingController(text: '4');

  int _beatsPerMeasure = 4;
  NoteDuration _selectedBeatUnit = NoteDuration.quarter;

  @override
  void dispose() {
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
    final parts = widget.controller.scaleName.split(' ');
    final scaleDisplayLabel = parts.length == 2
        ? '${parts[1]} ${parts[0]}'
        : parts.length > 2
        ? '${parts.sublist(1).join(' ')} ${parts[0]}'
        : widget.controller.scaleName;

    return SafeArea(
      child: AlertDialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
        title: const Text(
          'Configure Generation Step',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Step Time Signature', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
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
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
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
                TextFormField(
                  controller: _measuresController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Measures to Add',
                    isDense: true,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, elevation: 0),
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;

              final stepTimeSignature = TimeSignature(
                beats: _beatsPerMeasure,
                beatUnit: _selectedBeatUnit,
              );

              // Apply updated configuration choices to the active composition instance
              widget.targetComposition.scaleName = widget.controller.scaleName;

              final int countOfMeasures = int.parse(_measuresController.text);
              for (int i = 0; i < countOfMeasures; i++) {
                widget.targetComposition.timeline.addMeasure(stepTimeSignature);
              }

              widget.onMeasuresAppended();
              Navigator.pop(context);
            },
            child: const Text('Generate', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}