import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Plays note sounds — now built on flutter_soloud instead of
/// audioplayers.
///
/// WHY THE CHANGE: audioplayers sends every start/stop of every note
/// as a separate message to Android's main thread. During a dense
/// piece (chords + fast runs, like the Polonaise) those messages
/// arrived faster than Android could handle them, so they piled up:
/// the app froze, and queued notes kept sounding for minutes after.
/// flutter_soloud is a native audio engine called directly (FFI, no
/// message queue), and it mixes all notes itself on its own audio
/// thread — starting a note is a cheap, immediate call, so nothing
/// can pile up.
///
/// How it works:
/// - Each pitch's tone is synthesized once (on a background isolate)
///   and loaded into memory — no files.
/// - [warmUp] prepares every pitch a composition uses before playback
///   (called from CompositionController).
/// - [playTone] starts the pitch's tone; at the end of the note's
///   duration it fades out over 40 ms (no click) and stops. Striking
///   a pitch that's still ringing fades the old one out first, like a
///   piano key being struck again.
///
/// The public API ([playTone], [warmUp], [recover], [enabled],
/// [toggle], [dispose]) is unchanged, so callers keep working.
class NoteSoundService {
  NoteSoundService._();

  static final NoteSoundService instance = NoteSoundService._();

  bool enabled = true;

  void toggle() {
    enabled = !enabled;
  }

  static const int _sampleRate = 22050;
  static const double _minAudibleSeconds = 0.07;
  static const Duration _releaseFade = Duration(milliseconds: 40);

  final SoLoud _soloud = SoLoud.instance;
  Future<bool>? _initFuture;

  /// Loaded tone per pitch (MIDI note number, 60 = middle C).
  final Map<int, AudioSource> _sources = {};
  final Map<int, Future<AudioSource?>> _loading = {};

  /// The most recent voice started for each pitch, so a re-strike can
  /// fade out the one still ringing.
  final Map<int, SoundHandle> _lastHandle = {};

  Future<bool> _ensureInit() {
    return _initFuture ??= () async {
      try {
        if (!_soloud.isInitialized) {
          await _soloud.init();
        }
        // Enough voices for full chords plus notes still ringing out
        // (the default is 16).
        _soloud.setMaxActiveVoiceCount(64);
        return true;
      } catch (e) {
        debugPrint('NoteSoundService: audio engine failed to start: $e');
        _initFuture = null; // allow a later retry
        return false;
      }
    }();
  }

  static int _midiFor(double frequencyHz) =>
      (69 + 12 * (math.log(frequencyHz / 440) / math.ln2)).round();

  static double _frequencyForMidi(int midi) =>
      440.0 * math.pow(2, (midi - 69) / 12).toDouble();

  Future<AudioSource?> _sourceFor(int midi) {
    final ready = _sources[midi];
    if (ready != null) return Future.value(ready);
    return _loading[midi] ??= _load(midi).whenComplete(() {
      _loading.remove(midi);
    });
  }

  Future<AudioSource?> _load(int midi) async {
    if (!await _ensureInit()) return null;
    try {
      final frequency = _frequencyForMidi(midi);
      final bytes = await Isolate.run(
            () => _synthesizePianoTone(frequency, _sampleRate),
      );
      final source = await _soloud.loadMem('piano_$midi.wav', bytes);
      _sources[midi] = source;
      return source;
    } catch (e) {
      debugPrint('NoteSoundService: could not load pitch $midi: $e');
      return null;
    }
  }

  /// Prepares, ahead of time, every pitch in [frequenciesHz] that
  /// isn't ready yet, one after another. Safe to call repeatedly.
  Future<void> warmUp(Iterable<double> frequenciesHz) async {
    final midis = frequenciesHz
        .where((f) => f > 0)
        .map(_midiFor)
        .toSet()
        .where((m) => !_sources.containsKey(m))
        .toList();
    for (final midi in midis) {
      await _sourceFor(midi);
    }
  }

  /// Plays one note: [frequencyHz] for [durationSeconds]. Silently
  /// does nothing if sound is off or the values aren't playable.
  Future<void> playTone({
    required double frequencyHz,
    required double durationSeconds,
  }) async {
    if (!enabled || frequencyHz <= 0 || durationSeconds <= 0) return;
    final midi = _midiFor(frequencyHz);

    try {
      final source = await _sourceFor(midi);
      if (source == null) return;

      // Re-strike of a pitch that's still ringing: fade the old voice.
      final previous = _lastHandle[midi];
      if (previous != null) _fadeOutAndStop(previous);

      // play() is synchronous in flutter_soloud 4.x — returns the
      // voice handle immediately.
      final handle = _soloud.play(source);
      _lastHandle[midi] = handle;

      final holdSeconds = math.max(durationSeconds, _minAudibleSeconds);
      Timer(
        Duration(microseconds: (holdSeconds * 1000000).round()),
            () {
          _fadeOutAndStop(handle);
          if (_lastHandle[midi] == handle) _lastHandle.remove(midi);
        },
      );
    } catch (e) {
      debugPrint('NoteSoundService: could not play pitch $midi: $e');
    }
  }

  void _fadeOutAndStop(SoundHandle handle) {
    try {
      // Both run inside the audio engine itself — no waiting here.
      _soloud.fadeVolume(handle, 0, _releaseFade);
      _soloud.scheduleStop(handle, _releaseFade);
    } catch (_) {
      // The voice already ended on its own — nothing to do.
    }
  }

  /// Called when the app returns from the background. The engine
  /// normally keeps running; this only restarts it if it was shut
  /// down, then the caller re-runs warm-up.
  Future<void> recover() async {
    if (_soloud.isInitialized) return;
    _initFuture = null;
    _sources.clear();
    _lastHandle.clear();
    await _ensureInit();
  }

  void dispose() {
    _sources.clear();
    _lastHandle.clear();
    _initFuture = null;
    try {
      _soloud.deinit();
    } catch (_) {}
  }
}

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
  const double targetLevel = 0.25;
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