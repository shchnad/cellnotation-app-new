import 'package:flutter/material.dart';
import '../dialogs/note_dialog.dart';
import '../models/composition.dart';
import '../controllers/composition_controller.dart';
import '../dialogs/new_composition_dialog.dart';
import 'composition_screen.dart';
import '../features/auth/auth_service.dart';
import 'compositions_list_screen.dart';
import 'cloud_library_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _handleCreateComposition(BuildContext routingContext) {
    showDialog(
      context: routingContext,
      builder: (_) => NewCompositionDialog(
        onCompositionCreated: (newComposition) {
          final controller = CompositionController(composition: newComposition);

          Navigator.push(
            routingContext,
            MaterialPageRoute(
              builder: (_) {
                return CompositionScreen(
                  controller: controller,
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Cellnotation",
          style: TextStyle(fontSize: 22),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MenuItem(
                  label: 'My Compositions',
                  icon: Icons.library_music,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder:
                          (_) => const CompositionsListScreen()),
                    );
                  },
                ),
                _MenuItem(
                  label: 'Cloud Library',
                  icon: Icons.cloud,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CloudLibraryScreen()),
                    );
                  },
                ),
                _MenuItem(
                  label: 'Profile',
                  icon: Icons.person,
                  onTap: () {
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    // );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_video_rounded,
              size: 80,
              color: Colors.blue.shade400,
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (buttonContext) {
                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(220, 50),
                    elevation: 0,
                  ),
                  onPressed: () => _handleCreateComposition(buttonContext),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text(
                    "New Composition",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _MenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}