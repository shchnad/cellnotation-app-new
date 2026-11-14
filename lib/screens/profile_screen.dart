import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/composition.dart';
import '../services/composition_service.dart';
import '../features/auth/auth_service.dart';

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

    // No AppBar — HomeScreen (whose Exit text this Home text is meant
    // to line up with) has none either, and an AppBar here — even
    // with nothing visible in it (title/actions commented out below)
    // — still reserves its own height, which was pushing the body
    // (and the Home text inside it) down from that same position.
    return Scaffold(
      // BACKGROUND — same cellnotation_background.jpg + dark scrim
      // treatment as home_screen.dart/login_screen.dart/
      // register_screen.dart, per request, so the profile screen
      // shares the same consistent look. Text that used to be plain
      // black is now white below — black text would be unreadable
      // against this dark background.
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/cellnotation_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

          // The main content is now genuinely centered VERTICALLY as
          // well as horizontally, per request — not just horizontally
          // (via the existing Center+width-clamped SizedBox below).
          // LayoutBuilder + a min-height ConstrainedBox is the
          // standard way to center content that's SHORTER than the
          // viewport while still allowing it to scroll normally if it
          // ever overflows a short screen — a plain ListView/Column
          // alone only ever top-aligns content, leaving blank space
          // below it on a tall screen instead of centering.
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: user == null
                        ? Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      // White panel, like the app's dialogs.
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                              'Not signed in',
                              style: TextStyle(fontSize: 22, color: Colors.black)),
                          const SizedBox(height: 12),
                          const Divider(thickness: 1.0),
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
                    )
                        : Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      // White panel, like the app's dialogs.
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: (MediaQuery.of(context).size.width - 48).clamp(0, 500),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: user.photoURL != null
                                      ? NetworkImage(user.photoURL!)
                                      : null,
                                  child: user.photoURL == null
                                      ? const Icon(Icons.person, size: 48, color: Colors.black)
                                      : null,
                                ),

                                const SizedBox(height: 20),

                                Text(
                                  user.email ?? '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.black,
                                  ),
                                ),

                                const SizedBox(height: 30),

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

                          const SizedBox(height: 60),

                          SizedBox(
                            width: (MediaQuery.of(context).size.width - 48).clamp(0, 500),
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
                          // CLOSE — like the dialogs: a divider, then
                          // Close in the middle (back to Home).
                          const SizedBox(height: 20),
                          const Divider(thickness: 1.0),
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
                    ),
                  ),
                ),
              );
            },
          ),

        ],
      ),
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
              fontSize: 30,
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