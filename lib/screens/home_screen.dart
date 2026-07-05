import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:music_composer/enums/duration.dart';

import '../models/composition.dart';

import '../controllers/composition_controller.dart';
import '../models/measure.dart';
import '../models/timeline.dart';
import '../models/time_signature.dart';
import 'composition_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Composition _createEmptyComposition() {
    return Composition(
      title: "New Composition",
      composer: "unknown",
      style: "unknown",
      instrument: "unknown",
      userId: 0, // or real logged-in user id
      createdAt: DateTime.now(),
      editedAt: DateTime.now(),
      numberOfOctaves: 8,
      scaleName: "major C",
      timeline: Timeline(measures: [
        Measure(
          id: 0,
          startTick: 0,
          signature: TimeSignature(beats: 4, beatUnit: NoteDuration.quarter),
        ),
      ]),
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