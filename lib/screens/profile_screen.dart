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
        // title: const Text(
        //     'Profile',
        //     style: TextStyle(fontSize: 22)
        // ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 30,),
            tooltip: 'Sign out',
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text(
          'Not signed in',
          style: TextStyle(fontSize: 22)))
          : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? const Icon(Icons.person, size: 48, color: Colors.black)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              user.email ?? '',
              style: const TextStyle(
                  fontSize: 22,
                  color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            child: const Text(
              'Edit user name',
              style: TextStyle(
                  fontSize: 22,
                  color: Colors.black,
              ),
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _saving
                    ? null
                    : _saveName,
                child: _saving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save',
                    style: TextStyle(
                        fontSize: 22,
                        color: Colors.black,
                    )),
              ),
            ],
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