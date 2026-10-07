import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Plays note sounds for the composition — rewritten for smoother,
/// more reliable playback. What changed compared with the old version,
/// and why:
///
/// 1. ONE SOUND PER PITCH, NOT PER (PITCH, DURATION). The old version
///    synthesized and wrote a new WAV file for every different
///    frequency + duration combination, the very first time it was
///    needed — so notes were often late (synthesis + disk write happen
///    right when the note should sound) and a tempo change created a
///    whole new batch of files. Now each pitch gets one fixed-length,
///    naturally decaying tone, and a note's own length is produced by
///    stopping that tone at the right moment (it has already decayed by
///    then, so the stop is soft).
///
/// 2. ONE PLAYER PER PITCH, PRELOADED, IN LOW-LATENCY MODE. Each pitch
///    has its own [AudioPlayer] with its sound already loaded
///    ([PlayerMode.lowLatency] — Android's SoundPool, meant for short
///    game-style sounds). Starting a note is just "play from the start"
///    — no file is opened at that moment. Different pitches never
///    compete for a shared pool any more, so chords don't drop notes;
///    re-striking the same pitch simply restarts it, like a piano key.
///
/// 3. WARM-UP BEFORE PLAYBACK. [warmUp] synthesizes and loads every
///    pitch a composition uses ahead of time, on a background isolate
///    so the UI doesn't stutter — call it when a composition opens
///    (see CompositionController's constructor). Playback then never
///    waits for synthesis.
///
/// 4. A MORE PIANO-LIKE TONE. Instead of a plain beep, each tone is a
///    sum of a few harmonics with a very fast attack and an
///    exponential decay (higher harmonics fade faster, low notes ring
///    longer than high ones), which reads much more like a struck
///    string.
///
/// The public API ([playTone], [enabled], [toggle], [dispose]) is
/// unchanged, so existing callers keep working as-is.
class NoteSoundService {
  NoteSoundService._() {
    _configureAudioContext();
  }

  static final NoteSoundService instance = NoteSoundService._();

  bool enabled = true;

  void toggle() {
    enabled = !enabled;
  }

  /// Sample rate of the synthesized tones — 22.05 kHz is plenty for
  /// these tones (their highest harmonics stay well below 11 kHz)
  /// and halves file size and synthesis time versus 44.1 kHz.
  static const int _sampleRate = 22050;

  /// Notes shorter than this are stretched to it, so very fast notes
  /// (a sixty-fourth at a quick tempo) are still audible at all.
  static const double _minAudibleSeconds = 0.07;

  /// Per-pitch players, keyed by MIDI note number (60 = middle C).
  final Map<int, AudioPlayer> _players = {};

  /// Per-pitch "preparation in progress" futures, so two requests for
  /// the same pitch at the same moment share one synthesis/load
  /// rather than racing each other.
  final Map<int, Future<AudioPlayer?>> _preparing = {};

  /// Per-pitch counter bumped on every new strike of that pitch, so a
  /// pending "stop at end of note" from an EARLIER strike can tell it
  /// has been superseded and must not cut off the newer one.
  final Map<int, int> _strikeGeneration = {};

  Directory? _toneDir;

  Future<void> _configureAudioContext() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            // No exclusive focus — every pitch's player must be able to
            // sound together with all the others (chords).
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } catch (_) {
      // Unsupported field on some platform/version — fall back to the
      // platform default rather than losing sound entirely.
    }
  }

  /// MIDI note number closest to [frequencyHz] (A4 = 440 Hz = 69).
  /// Every pitch the app produces is in 12-tone equal temperament, so
  /// this maps each one to exactly one cached sound.
  static int _midiFor(double frequencyHz) =>
      (69 + 12 * (math.log(frequencyHz / 440) / math.ln2)).round();

  static double _frequencyForMidi(int midi) =>
      440.0 * math.pow(2, (midi - 69) / 12).toDouble();

  Future<Directory> _ensureToneDir() async {
    if (_toneDir != null) return _toneDir!;
    final tempDir = await getTemporaryDirectory();
    // "v2" so files from the old, differently-synthesized version are
    // never picked up by mistake.
    final dir = Directory('${tempDir.path}/note_tones_v2');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _toneDir = dir;
    return dir;
  }

  /// Returns a ready-to-play player for [midi], synthesizing and
  /// loading its sound first if this is the first time it's needed.
  Future<AudioPlayer?> _playerFor(int midi) {
    final existing = _players[midi];
    if (existing != null) return Future.value(existing);
    return _preparing[midi] ??= _preparePlayer(midi).whenComplete(() {
      _preparing.remove(midi);
    });
  }

  Future<AudioPlayer?> _preparePlayer(int midi) async {
    try {
      final dir = await _ensureToneDir();
      final file = File('${dir.path}/piano_$midi.wav');
      if (!await file.exists()) {
        final frequency = _frequencyForMidi(midi);
        // Synthesis is pure number-crunching — done on a background
        // isolate so the UI (and playback scrolling) never stutters.
        final bytes = await Isolate.run(
              () => _synthesizePianoTone(frequency, _sampleRate),
        );
        await file.writeAsBytes(bytes, flush: true);
      }

      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(DeviceFileSource(file.path));
      _players[midi] = player;
      return player;
    } catch (e) {
      debugPrint('NoteSoundService: could not prepare pitch $midi: $e');
      _registerFailure();
      return null;
    }
  }

  /// Failures since the last rebuild. Low-latency mode is ALWAYS kept
  /// (the regular media-player mode starts each sound far too slowly
  /// for playback to stay in sync with the scrolling); instead, after
  /// a few failures every player is simply rebuilt.
  int _failureCount = 0;
  static const int _failuresBeforeRebuild = 3;

  void _registerFailure() {
    _failureCount++;
    if (_failureCount >= _failuresBeforeRebuild) {
      debugPrint('NoteSoundService: rebuilding all players');
      _failureCount = 0;
      _resetPlayers();
    }
  }

  /// Throws away every per-pitch player (not the generated sound
  /// files — those are reused), so each pitch is reloaded fresh the
  /// next time it plays.
  void _resetPlayers() {
    for (final player in _players.values) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _players.clear();
    _sounding.clear();
  }

  /// Rebuilds all players from scratch, re-applying the audio
  /// settings. Call it when the app comes back from the background
  /// (see CompositionScreen), since the system may have released the
  /// audio resources while the app was away — a common reason sound
  /// works at first and then goes silent.
  Future<void> recover() async {
    _resetPlayers();
    await _configureAudioContext();
  }

  /// Synthesizes and loads, ahead of time, the sound for every
  /// frequency in [frequenciesHz] that isn't ready yet — so playback
  /// never has to wait for it. Safe to call repeatedly; already-ready
  /// pitches are skipped. Pitches are prepared one after another
  /// rather than all at once, to keep memory and CPU use gentle.
  Future<void> warmUp(Iterable<double> frequenciesHz) async {
    final midis = frequenciesHz
        .where((f) => f > 0)
        .map(_midiFor)
        .toSet()
        .where((m) => !_players.containsKey(m));
    for (final midi in midis) {
      await _playerFor(midi);
    }
  }

  /// Pitches whose player is currently sounding — only those need a
  /// stop() before being struck again. Skipping that extra call for
  /// every other note keeps each note start to a SINGLE call into the
  /// platform's audio system.
  final Set<int> _sounding = {};

  /// Plays one note: [frequencyHz] for [durationSeconds]. Silently
  /// does nothing if sound is off or the values aren't playable —
  /// callers don't need to guard against either.
  ///
  /// Kept deliberately lean: every call into the platform's audio
  /// system goes through one shared message queue, so extra calls per
  /// note (the old version made up to 6, including a volume fade)
  /// pile up during fast passages and make each later note start later
  /// and later — the growing delay between scrolling and sound. Now a
  /// note costs one call to start (two if the same pitch is still
  /// ringing) and one call to stop.
  Future<void> playTone({
    required double frequencyHz,
    required double durationSeconds,
  }) async {
    if (!enabled || frequencyHz <= 0 || durationSeconds <= 0) return;

    final midi = _midiFor(frequencyHz);
    final generation = (_strikeGeneration[midi] ?? 0) + 1;
    _strikeGeneration[midi] = generation;

    // Up to two attempts: if the player for this pitch has gone bad
    // (e.g. the system released it), it's thrown away and rebuilt once
    // before giving up on this note.
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final player = await _playerFor(midi);
        if (player == null) return;
        // Another strike of this same pitch may have started while this
        // one was still being prepared — that newer one wins.
        if (_strikeGeneration[midi] != generation) return;

        if (_sounding.contains(midi)) {
          await player.stop();
        }
        await player.resume();
        _sounding.add(midi);

        final holdSeconds = math.max(durationSeconds, _minAudibleSeconds);
        Timer(
          Duration(microseconds: (holdSeconds * 1000000).round()),
              () => _releaseNote(midi, player, generation),
        );
        return;
      } catch (e) {
        debugPrint('NoteSoundService: playback failed for pitch $midi: $e');
        _registerFailure();
        _sounding.remove(midi);
        final broken = _players.remove(midi);
        try {
          broken?.dispose();
        } catch (_) {}
      }
    }
  }

  /// Ends a note at the end of its written duration — a single stop
  /// call. The synthesized tone has already decayed by then, so the
  /// cut is soft. Does nothing if the same pitch has been struck again
  /// in the meantime — the newer strike now owns the player.
  Future<void> _releaseNote(int midi, AudioPlayer player, int generation) async {
    if (_strikeGeneration[midi] != generation) return;
    _sounding.remove(midi);
    try {
      await player.stop();
    } catch (_) {}
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}

/// Builds a mono 16-bit WAV of a piano-like tone at [frequency] Hz —
/// a top-level function (not a method) so it can run inside
/// [Isolate.run].
///
/// The tone is a fundamental plus a few harmonics. Each harmonic has
/// a fast (~4 ms) attack and its own exponential decay — higher
/// harmonics decay faster, so the tone starts bright and mellows, the
/// way a struck string does — and lower notes decay more slowly
/// overall than higher ones. A very slight inharmonic stretch on the
/// upper harmonics adds a little realism. Length depends on pitch
/// (long for bass, shorter for treble) and the last 40 ms fade to
/// silence so a note left to ring out ends without a click.
Uint8List _synthesizePianoTone(double frequency, int sampleRate) {
  // How long a key keeps ringing if held: ~3 s in the bass down to
  // ~1 s in the high treble.
  final double ringSeconds =
  (3.2 - 0.45 * (math.log(frequency / 55) / math.ln2)).clamp(1.0, 3.2);
  final int sampleCount = (ringSeconds * sampleRate).round();

  // (harmonic number, relative amplitude)
  const harmonics = <List<double>>[
    [1, 1.00],
    [2, 0.45],
    [3, 0.25],
    [4, 0.12],
    [5, 0.08],
    [6, 0.04],
  ];
  const double inharmonicity = 0.0004;
  final double nyquist = sampleRate / 2;

  // Base decay rate: higher notes fade faster.
  final double baseDecay = 1.2 + frequency / 600;

  final samples = Float64List(sampleCount);
  double peak = 0;
  const attackSeconds = 0.004;
  const fadeOutSeconds = 0.04;
  final int fadeOutStart = sampleCount - (fadeOutSeconds * sampleRate).round();

  for (final h in harmonics) {
    final n = h[0];
    final amp = h[1];
    final f = frequency * n * math.sqrt(1 + inharmonicity * n * n);
    if (f >= nyquist * 0.9) continue; // would alias — skip
    final decay = baseDecay * (1 + 0.6 * (n - 1));
    final w = 2 * math.pi * f / sampleRate;
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      samples[i] += amp * math.exp(-decay * t) * math.sin(w * i);
    }
  }

  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    double env = 1;
    if (t < attackSeconds) env = t / attackSeconds;
    if (i >= fadeOutStart) {
      env *= (sampleCount - i) / (sampleCount - fadeOutStart);
    }
    samples[i] *= env;
    final a = samples[i].abs();
    if (a > peak) peak = a;
  }

  // Normalize to a moderate level, leaving headroom for chords
  // (several pitches sounding at once are mixed by the system).
  const double targetLevel = 0.35;
  final double gain = peak > 0 ? targetLevel / peak : 0;

  final dataBytes = sampleCount * 2;
  final bytes = ByteData(44 + dataBytes);
  void writeString(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // PCM chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM format
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  writeString(36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);

  for (int i = 0; i < sampleCount; i++) {
    final v = (samples[i] * gain * 32767).round().clamp(-32768, 32767);
    bytes.setInt16(44 + i * 2, v, Endian.little);
  }
  return bytes.buffer.asUint8List();
}