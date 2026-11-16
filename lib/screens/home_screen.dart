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
    // Every button on this page has the look of the app's dialog
    // buttons: grey, rounded, black text at size 22. Exit is the round
    // ✕ button in the top-right corner.
    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND IMAGE — the piano photo, full-bleed behind
          // everything else on this screen, per request. Positioned
          // first in the Stack so it paints BEHIND the button column
          // and the Exit link. Positioned.fill + BoxFit.cover fills
          // the whole screen regardless of aspect ratio, cropping
          // rather than stretching/leaving gaps. A semi-transparent
          // dark scrim sits on top of the image (below the buttons)
          // so the white button text/icons stay legible against
          // whatever part of the photo shows through.
          Positioned.fill(
            child: Image.asset(
              'assets/cellnotation_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(
                  builder: (buttonContext) {
                    return _HomeMenuButton(
                      icon: Icons.library_add,
                      label: 'Create Composition',
                      color: Colors.grey.shade300,
                      textColor: Colors.black,
                      onPressed: () => _handleCreateComposition(buttonContext),
                    );
                  },
                ),
                const SizedBox(height: 40),
                _HomeMenuButton(
                  icon: Icons.music_video_rounded,
                  label: 'My Compositions',
                  color: Colors.grey.shade300,
                  textColor: Colors.black,
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
                  color: Colors.grey.shade300,
                  textColor: Colors.black,
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
                  color: Colors.grey.shade300,
                  textColor: Colors.black,
                  // Profile is a pop-up window over the Home screen.
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ProfileScreen(),
                    );
                  },
                ),
              ],
            ),
          ),

          // EXIT — a round button with a cross in the top-right
          // corner (signs out).
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Tooltip(
                  message: 'Exit',
                  child: Material(
                    color: Colors.grey.shade300,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        await AuthService().signOut();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.close, color: Colors.black, size: 32),
                      ),
                    ),
                  ),
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
      width: 350,
      height: 80,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          minimumSize: const Size(double.infinity, 55),
          // The same rounded shape as the buttons of the app's
          // dialogs (noteValuesDialog) — Flutter's default.
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
        label: Text(
          label,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}