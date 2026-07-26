import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'tone_synthesizer.dart';

/// Plays short synthesized tones for notes. Toggleable via [enabled];
/// uses a small round-robin pool of [AudioPlayer]s so overlapping notes
/// — several triggered in the same frame during scroll playback, or a
/// chord tapped in quickly — can actually sound at once instead of
/// cutting each other off.
///
/// Each unique tone is synthesized once, written to a small file in
/// the app's temp directory, and played from there via
/// [DeviceFileSource] — chosen over playing raw bytes directly since
/// that API (BytesSource) isn't available/consistent across every
/// audioplayers version, while DeviceFileSource has been stable for a
/// long time.
class NoteSoundService {
  NoteSoundService._();
  static final NoteSoundService instance = NoteSoundService._();

  static const int _poolSize = 8;
  final List<AudioPlayer> _pool = List.generate(
    _poolSize,
        (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
  );
  int _nextPlayerIndex = 0;

  // Cache generated tone file paths so repeated/identical notes don't
  // get resynthesized or rewritten to disk every time — frequency/
  // duration are rounded a bit when building the key so near-identical
  // tones share a cache entry.
  final Map<String, String> _toneFileCache = {};
  Directory? _toneDir;

  bool enabled = true;

  void toggle() {
    enabled = !enabled;
  }

  Future<String> _toneFilePathFor(
      double frequencyHz, double durationSeconds) async {
    final key =
        '${frequencyHz.toStringAsFixed(1)}_${durationSeconds.toStringAsFixed(2)}';

    final cached = _toneFileCache[key];
    if (cached != null) {
      return cached;
    }

    _toneDir ??= await _prepareToneDirectory();

    final bytes = ToneSynthesizer.synthesizeTone(
      frequencyHz: frequencyHz,
      durationSeconds: durationSeconds,
    );

    final file = File('${_toneDir!.path}/tone_$key.wav');
    await file.writeAsBytes(bytes, flush: true);

    _toneFileCache[key] = file.path;
    return file.path;
  }

  Future<Directory> _prepareToneDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final toneDir = Directory('${tempDir.path}/note_tones');
    if (!await toneDir.exists()) {
      await toneDir.create(recursive: true);
    }
    return toneDir;
  }

  /// Plays one tone. Silently does nothing if sound is [enabled] ==
  /// false, or the frequency isn't playable — callers don't need to
  /// guard against either case themselves.
  Future<void> playTone({
    required double frequencyHz,
    required double durationSeconds,
  }) async {
    if (!enabled || frequencyHz <= 0 || durationSeconds <= 0) {
      return;
    }

    try {
      final path = await _toneFilePathFor(frequencyHz, durationSeconds);
      final player = _pool[_nextPlayerIndex];
      _nextPlayerIndex = (_nextPlayerIndex + 1) % _poolSize;

      await player.stop();
      await player.play(DeviceFileSource(path));
    } catch (_) {
      // A playback hiccup (e.g. platform audio session briefly busy, or
      // a file-write failure) shouldn't crash the app — just skip this
      // one tone.
    }
  }

  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
  }
}