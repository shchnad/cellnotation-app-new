import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/composition.dart';
import '../services/composition_service.dart';
import '../features/auth/auth_service.dart';
import '../dialogs/new_composition_dialog.dart' show kDialogContentHeight;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final CompositionService _compositionService = CompositionService();
  final AuthService _authService = AuthService();

  late final TextEditingController _nameController;
  bool _saving = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    // Dismiss the on-screen keyboard whenever a save is triggered —
    // covers both the Save button (called directly below) and
    // pressing Enter/Done on the keyboard (TextField's onSubmitted
    // also calls this same method, see below).
    //
    // FocusManager.instance.primaryFocus?.unfocus() rather than
    // FocusScope.of(context).unfocus() — the latter didn't reliably
    // dismiss the keyboard when triggered from the Save button
    // (unlike onSubmitted, which gets an automatic dismiss from the
    // IME's own "done" action regardless of what this method does).
    // Operating on the global primary focus directly sidesteps
    // whatever FocusScope this widget's own context resolves to.
    FocusManager.instance.primaryFocus?.unfocus();

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 2),
            content: Text(
                'Name cannot be empty',
                style: TextStyle(fontSize: 22))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _user?.updateDisplayName(newName);
      await _user?.reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 2),
            content: Text(
                'user name updated',
                style: TextStyle(fontSize: 22))),
      );
      setState(() {}); // refresh displayed name
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 2),
            content: Text(
                'Failed to update name: $e',
                style: const TextStyle(fontSize: 22))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    // The panel is an AlertDialog with the same content width as the
    // New Composition dialog — so both are exactly the same width.
    final width = (MediaQuery.of(context).size.width - 48).clamp(0.0, 500.0);

    // A pop-up window (opened with showDialog from the Home screen),
    // not a separate page.
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      content: SingleChildScrollView(
        child: Container(
          width: width,
          // At least as high as the New Composition dialog's
          // content (the same size).
          constraints: const BoxConstraints(minHeight: kDialogContentHeight),
          alignment: Alignment.topCenter,
          child: user == null
              ? const Text(
            'Not signed in',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: Colors.black),
          )
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                // The same width as the New Composition dialog's content.
                width: width,
                child: Column(
                  children: [
                    // Picture and e-mail on one row (keeps the panel as
                    // low as the New Composition dialog).
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: user.photoURL != null
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: user.photoURL == null
                              ? const Icon(Icons.person, size: 32, color: Colors.black)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            user.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveName(),
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                      // Framed like the fields of the dialogs.
                      decoration: InputDecoration(
                        labelText: 'User name',
                        labelStyle: const TextStyle(fontSize: 22),
                        isDense: true,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person, size: 22),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _nameController.clear();
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Same button as the dialogs (noteValuesDialog):
                    // grey with black text.
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _saveName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        minimumSize: const Size(220, 55),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: _saving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                          : const Icon(Icons.save,
                          color: Colors.black, size: 24),
                      label: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.black,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                // The same width as the New Composition dialog's content.
                width: width,
                child: StreamBuilder<List<Composition>>(
                  stream: _compositionService.getUserCompositions(),
                  builder: (context, snapshot) {
                    final compositions = snapshot.data ?? [];
                    final publicCount = compositions.where((c) => c.isPublic).length;
                    final totalLikes = compositions.fold<int>(
                      0,
                          (sum, c) => sum + c.likeCount,
                    );

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatTile(label: 'Compositions', value: '${compositions.length}'),
                        _StatTile(label: 'Public', value: '$publicCount'),
                        _StatTile(label: 'Likes received', value: '$totalLikes'),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
          ],
        ),
      ],
    );
  }
}




class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 22, color: Colors.black),
        ),
      ],
    );
  }
}