import 'package:flutter/material.dart';

import '../models/composition.dart';

import '../controllers/composition_controller.dart';
import 'composition_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Composition _createEmptyComposition() {
    return Composition(
      title: "New Composition",
      numberOfMeasures: 4,
      beatsPerMeasure: 4,
      numberOfOctaves: 8,
      notes: [],
    );
  }

  void _openComposition(BuildContext context) {
    final composition = _createEmptyComposition();

    final controller = CompositionController(composition);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompositionScreen(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Music Composer"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _openComposition(context),
          child: const Text("Create Composition"),
        ),
      ),
    );
  }
}