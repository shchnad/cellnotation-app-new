import 'package:flutter/material.dart';
import '../models/composition.dart';
import '../models/timeline.dart';
import '../models/measure.dart';
import '../models/note.dart';
import '../enums/music_style.dart';
import '../enums/instrument.dart';
import '../utils/default_values.dart';
import 'note_values_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';



class NewCompositionDialog extends StatefulWidget {
  final Function(Composition) onCompositionCreated;

  const NewCompositionDialog({super.key, required this.onCompositionCreated});

  @override
  State<NewCompositionDialog> createState() => _NewCompositionDialogState();
}

class _NewCompositionDialogState extends State<NewCompositionDialog> {

  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: DefaultValues.title);
  final _composerController = TextEditingController(text: DefaultValues.composer);

  MusicStyle _selectedStyle = DefaultValues.style;
  Instrument _selectedInstrument = DefaultValues.instrument;
  bool _isPublic = false;

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
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: valueText),
      style: const TextStyle(
        fontSize: 22,
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, size: 22),
        suffixIcon: const Icon(
          Icons.arrow_drop_down,
          color: Colors.blue,
        ),
      ),
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      alignment: Alignment.topCenter,//keep the dialog on top of screen
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'New Composition',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.70,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
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
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                            validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _composerController,
                            decoration: const InputDecoration(
                              labelText: 'Composer',
                              isDense: true,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person, size: 22),
                            ),
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                            validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSelectionField(
                            label: 'Musical Style',
                            valueText: _selectedStyle.label,
                            icon: Icons.palette,
                            onTap: () {
                              noteValuesDialog<MusicStyle>(
                                allowToCloseNextWindow: false,
                                context: context,
                                title: 'Select Style',
                                currentValue: _selectedStyle,
                                values: MusicStyle.values,
                                labelBuilder: (s) => s.label,
                                numberOfColumns: 3,
                                onSelected: (style) =>
                                    setState(() => _selectedStyle = style),
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildSelectionField(
                            label: 'Target Instrument',
                            valueText: _selectedInstrument.label,
                            icon: Icons.piano,
                            onTap: () {
                              noteValuesDialog<Instrument>(
                                context: context,
                                allowToCloseNextWindow: false,
                                title: 'Select Instrument',
                                currentValue: _selectedInstrument,
                                values: Instrument.values,
                                labelBuilder: (i) => i.label,
                                numberOfColumns: 3,
                                onSelected: (inst) =>
                                    setState(() => _selectedInstrument = inst),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(Icons.public, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Visible to all users in Cloud Library',
                        style: TextStyle(
                            fontSize: 22,
                            color: Colors.black
                        ),
                      ),
                    ),
                    Switch(
                      value: _isPublic,
                      onChanged: (value) => setState(() => _isPublic = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      actionsPadding: const EdgeInsets.fromLTRB(
        DefaultValues.dialogPaddingRightLeft,
        DefaultValues.dialogPaddingBottomTop,
        DefaultValues.dialogPaddingRightLeft,
        DefaultValues.dialogPaddingBottomTop,
      ),
      actions: [
        const Divider(thickness: 1.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            // const Spacer(),

            TextButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                final baseComposition = Composition(
                  title: _titleController.text.trim(),
                  composer: _composerController.text.trim(),
                  style: _selectedStyle.label,
                  instrument: _selectedInstrument.label,
                  userId: currentUserId,
                  numberOfOctaves: 8,
                  scaleName: DefaultValues.scale,
                  isPublic: _isPublic,
                  timeline: Timeline(measures: <Measure>[]),
                  notes: <Note>[],
                );
                Navigator.pop(context);
                widget.onCompositionCreated(baseComposition);
              },
              child: const Text(
                'Create',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),

      ],
    );
  }
}