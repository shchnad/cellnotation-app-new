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
        const SnackBar(content: Text(
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
        const SnackBar(content: Text(
            'Name updated',
            style: TextStyle(fontSize: 22))),
      );
      setState(() {}); // refresh displayed name
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // title: const Text(
        //     'Profile',
        //     style: TextStyle(fontSize: 22)
        // ),
        // actions: [
        // IconButton(
        //   icon: const Icon(Icons.logout, size: 30,),
        //   tooltip: 'Sign out',
        //   onPressed: () async {
        //     await _authService.signOut();
        //     if (context.mounted) {
        //       Navigator.popUntil(context, (route) => route.isFirst);
        //     }
        //   },
        // ),
        // ],
      ),
      body: user == null
          ? Column(
        children: [
          const Center(
              child: Text(
                  'Not signed in',
                  style: TextStyle(fontSize: 22))),
        ],
      )
          : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: SizedBox(
              width: 500,
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
                    decoration: InputDecoration(
                      labelText: 'Edit user name',
                      labelStyle: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      border: const OutlineInputBorder(),
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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : _saveName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        // foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Kept as a plain ElevatedButton (rather than
                      // ElevatedButton.icon) since it also needs to
                      // swap to a loading spinner while saving —
                      // building the icon+label Row manually gives
                      // the same visual result as .icon while still
                      // allowing that conditional.
                      child: _saving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text('Save',
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                              )),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Explicit Home button, same size/shape as Save but
                  // black — replaces the AppBar's automatic back
                  // arrow (suppressed via automaticallyImplyLeading:
                  // false above).
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      icon: const Icon(
                        Icons.exit_to_app,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: const Text('Home',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 60),

          StreamBuilder<List<Composition>>(
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