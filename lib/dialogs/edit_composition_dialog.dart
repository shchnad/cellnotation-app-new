import 'package:flutter/material.dart';
import '../models/composition.dart';
import '../enums/music_style.dart';
import '../enums/instrument.dart';
import 'note_values_dialog.dart';

class EditCompositionDialog extends StatefulWidget {
  final Composition composition;
  final ValueChanged<Composition> onSaved;
  final VoidCallback? onDelete;

  const EditCompositionDialog({
    super.key,
    required this.composition,
    required this.onSaved,
    this.onDelete,
  });

  @override
  State<EditCompositionDialog> createState() => _EditCompositionDialogState();
}

class _EditCompositionDialogState extends State<EditCompositionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _composerController;

  late MusicStyle _selectedStyle;
  late Instrument _selectedInstrument;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.composition.title);
    _composerController = TextEditingController(text: widget.composition.composer);

    // The composition stores style/instrument as label strings, so we
    // resolve back to the matching enum value (falling back to "any"
    // if the stored label doesn't match anything, just in case).
    _selectedStyle = MusicStyle.values.firstWhere(
          (s) => s.label == widget.composition.style,
      orElse: () => MusicStyle.any,
    );
    _selectedInstrument = Instrument.values.firstWhere(
          (i) => i.label == widget.composition.instrument,
      orElse: () => Instrument.any,
    );
    _isPublic = widget.composition.isPublic;
  }

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
        // fontWeight: FontWeight.bold,
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Delete Composition?',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete "${widget.composition.title}". This cannot be undone.',
          style: const TextStyle(fontSize: 22),
        ),
        actions: [
          const Divider(thickness: 1.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close confirmation
                  Navigator.pop(context); // close edit dialog
                  widget.onDelete?.call();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      alignment: Alignment.topCenter,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'Edit Composition Data',
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
                              // fontWeight: FontWeight.bold,
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
                              // fontWeight: FontWeight.bold,
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
                        style: TextStyle(fontSize: 22),
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
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      actions: [
        const Divider(thickness: 1.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.onDelete != null)
              TextButton(
                onPressed: () => _confirmDelete(context),
                child: const Text(
                  'Delete Composition',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                final updated = widget.composition.copyWith(
                  title: _titleController.text.trim(),
                  composer: _composerController.text.trim(),
                  style: _selectedStyle.label,
                  instrument: _selectedInstrument.label,
                  isPublic: _isPublic,
                  editedAt: DateTime.now(),
                );
                Navigator.pop(context);
                widget.onSaved(updated);
              },
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
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
        ),
      ],
    );
  }
}