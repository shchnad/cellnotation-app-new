import 'package:flutter/material.dart';
import '../dialogs/note_dialog.dart';
import '../models/composition.dart';
import '../controllers/composition_controller.dart';
import '../dialogs/new_composition_dialog.dart';
import 'composition_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _handleCreateComposition(BuildContext routingContext) {
    showDialog(
      context: routingContext,
      builder: (_) => NewCompositionDialog(
        onCompositionCreated: (newComposition) {
          // The controller takes ownership of the composition model state
          final controller = CompositionController(composition: newComposition);

          Navigator.push(
            routingContext,
            MaterialPageRoute(
              builder: (_) {
                //  Removed the redundant 'composition:' argument matching the updated constructor
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
        title: const Text("Cellnotation editor"),
        centerTitle: true,
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
                      // shape: RoundedRectangleBorder(
                      //   borderRadius: BorderRadius.circular(8),
                      // ),
                      elevation: 0,
                    ),
                    onPressed: () => _handleCreateComposition(buttonContext),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      "New Composition",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  );
                }
            ),
          ],
        ),
      ),
    );
  }
}