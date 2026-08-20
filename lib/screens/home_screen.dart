import 'package:flutter/material.dart';
import 'package:music_composer/screens/profile_screen.dart';
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
    // Every button on this page shares one style — a plain blue/white
    // ElevatedButton.icon at fontSize 22 bold, matching what "Create
    // Composition" always used — stacked in a single centered column
    // rather than split between an AppBar row and the body, per
    // request. Sign out (previously an AppBar action) is now just
    // "Exit", the last button in that same column.
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(
                  builder: (buttonContext) {
                    return _HomeMenuButton(
                      icon: Icons.library_add,
                      label: 'Create Composition',
                      color: Colors.blue,
                      textColor: Colors.white,
                      onPressed: () => _handleCreateComposition(buttonContext),
                    );
                  },
                ),
                const SizedBox(height: 40),
                _HomeMenuButton(
                  icon: Icons.music_video_rounded,
                  label: 'My Compositions',
                  color: Colors.blue,
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CompositionsListScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                _HomeMenuButton(
                  icon: Icons.cloud,
                  label: 'Cloud Library',
                  color: Colors.black,
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CloudLibraryScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                _HomeMenuButton(
                  icon: Icons.person,
                  label: 'Profile',
                  color: Colors.black,
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // EXIT — top-left corner, clickable text + icon (not a
          // full note-block button like the rest of this page), both
          // red. SafeArea keeps it clear of any notch/status bar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () async {
                  await AuthService().signOut();
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 6),
                    Text(
                      'Exit',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One button in the home page's centered column — same fixed width
/// and text style (fontSize 22 bold) for every entry, so "Create
/// Composition" and the four actions below it all read as one
/// consistent set of choices. [color] varies per button (blue for
/// the two composition-related actions, black for the two profile/
/// library navigation actions, red for the destructive Exit) while
/// everything else about the button stays identical.
class _HomeMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _HomeMenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // A fixed-width SizedBox, rather than relying on minimumSize
    // alone — minimumSize only sets a FLOOR, so a longer label (e.g.
    // "My Compositions") would still make its own button wider than
    // a shorter one (e.g. "Profile") unless every button is
    // explicitly constrained to the SAME width like this.
    return SizedBox(
      width: 500,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          // Rectangular with just a touch of rounding — matches
          // NoteBlockWidget's own note container exactly
          // (BorderRadius.circular(4)), so this button reads as a
          // "note" rather than Material's default pill-shaped button.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}