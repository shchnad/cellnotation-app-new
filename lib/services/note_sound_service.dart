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
///
/// INSTRUMENTS: every pitch can be played in one of the [SoundTimbre]s
/// below (piano, organ, bowed strings, plucked strings, flute, brass
/// …). [playTone] and [warmUp] take an optional `timbre`; without it
/// they play the piano tone as before. Each (timbre, pitch) pair is
/// synthesized once and kept in memory.
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

  /// Loaded tone per (timbre, pitch) — see [_key]. MIDI note number:
  /// 60 = middle C.
  final Map<int, AudioSource> _sources = {};
  final Map<int, Future<AudioSource?>> _loading = {};

  /// The most recent voice started for each (timbre, pitch), so a
  /// re-strike can fade out the one still ringing.
  final Map<int, SoundHandle> _lastHandle = {};

  /// One number for a (timbre, pitch) pair.
  static int _key(SoundTimbre timbre, int midi) => timbre.index * 1000 + midi;

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

  Future<AudioSource?> _sourceFor(SoundTimbre timbre, int midi) {
    final key = _key(timbre, midi);
    final ready = _sources[key];
    if (ready != null) return Future.value(ready);
    return _loading[key] ??= _load(timbre, midi).whenComplete(() {
      _loading.remove(key);
    });
  }

  Future<AudioSource?> _load(SoundTimbre timbre, int midi) async {
    if (!await _ensureInit()) return null;
    try {
      final frequency = _frequencyForMidi(midi);
      final timbreIndex = timbre.index;
      final bytes = await Isolate.run(
            () => _synthesizeTone(frequency, _sampleRate, timbreIndex),
      );
      final source =
      await _soloud.loadMem('${timbre.name}_$midi.wav', bytes);
      _sources[_key(timbre, midi)] = source;
      return source;
    } catch (e) {
      debugPrint('NoteSoundService: could not load ${timbre.name} $midi: $e');
      return null;
    }
  }

  /// Prepares, ahead of time, every pitch in [frequenciesHz] that
  /// isn't ready yet in [timbre], one after another. Safe to call
  /// repeatedly.
  Future<void> warmUp(
      Iterable<double> frequenciesHz, {
        SoundTimbre timbre = SoundTimbre.piano,
      }) async {
    final midis = frequenciesHz
        .where((f) => f > 0)
        .map(_midiFor)
        .toSet()
        .where((m) => !_sources.containsKey(_key(timbre, m)))
        .toList();
    for (final midi in midis) {
      await _sourceFor(timbre, midi);
    }
  }

  /// Plays one note: [frequencyHz] for [durationSeconds]. Silently
  /// does nothing if sound is off or the values aren't playable.
  Future<void> playTone({
    required double frequencyHz,
    required double durationSeconds,
    SoundTimbre timbre = SoundTimbre.piano,
  }) async {
    if (!enabled || frequencyHz <= 0 || durationSeconds <= 0) return;
    final midi = _midiFor(frequencyHz);
    final key = _key(timbre, midi);

    try {
      final source = await _sourceFor(timbre, midi);
      if (source == null) return;

      // Re-strike of a pitch that's still ringing: fade the old voice.
      final previous = _lastHandle[key];
      if (previous != null) _fadeOutAndStop(previous);

      // play() is synchronous in flutter_soloud 4.x — returns the
      // voice handle immediately.
      final handle = _soloud.play(source);
      _lastHandle[key] = handle;

      final holdSeconds = math.max(durationSeconds, _minAudibleSeconds);
      Timer(
        Duration(microseconds: (holdSeconds * 1000000).round()),
            () {
          _fadeOutAndStop(handle);
          if (_lastHandle[key] == handle) _lastHandle.remove(key);
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


/// The kinds of sound an instrument can be played with. Every
/// instrument of the app is mapped to one of these (see
/// CompositionController.timbreForInstrument).
enum SoundTimbre {
  piano, // struck strings
  electricPiano, // keyboard
  organ, // steady pipes
  reed, // accordion, bayan
  guitar, // plucked nylon / steel strings
  electricGuitar,
  bassGuitar,
  bright, // banjo, balalaika, ukulele — short and bright
  harp,
  bowed, // violin
  bowedLow, // cello
  flute,
  clarinet,
  brass, // trumpet, cornet, trombone
  horn, // French horn — darker brass
  saxophone,
  xylophone,
}

/// Synthesizes one tone of [frequency] Hz in the [SoundTimbre] whose
/// index is [timbreIndex] (an index, so it can cross into
/// [Isolate.run]) and returns it as a mono 16-bit WAV.
Uint8List _synthesizeTone(double frequency, int sampleRate, int timbreIndex) {
  final timbre = SoundTimbre.values[timbreIndex];
  switch (timbre) {
    case SoundTimbre.piano:
      return _encodeWav(_pianoSamples(frequency, sampleRate), sampleRate, 0.25);
    case SoundTimbre.electricPiano:
      return _encodeWav(
          _additive(frequency, sampleRate,
              harmonics: const [[1, 1.0], [2, 0.25], [3, 0.06], [14, 0.04]],
              seconds: 3.0,
              attack: 0.003,
              decay: 0.8,
              decayPerHarmonic: 0.5),
          sampleRate,
          0.25);
    case SoundTimbre.organ:
      return _encodeWav(
          _additive(frequency, sampleRate,
              harmonics: const [[0.5, 0.5], [1, 1.0], [2, 0.6], [3, 0.35], [4, 0.25], [6, 0.12], [8, 0.1]],
              seconds: 4.0,
              attack: 0.012),
          sampleRate,
          0.2);
    case SoundTimbre.reed:
      return _encodeWav(_reedSamples(frequency, sampleRate), sampleRate, 0.2);
    case SoundTimbre.guitar:
      return _encodeWav(
          _plucked(frequency, sampleRate,
              seconds: 3.0, damping: 0.996, brightness: 0.5),
          sampleRate,
          0.27);
    case SoundTimbre.electricGuitar:
      return _encodeWav(_electricGuitarSamples(frequency, sampleRate),
          sampleRate, 0.22);
    case SoundTimbre.bassGuitar:
      return _encodeWav(
          _plucked(frequency, sampleRate,
              seconds: 3.5, damping: 0.998, brightness: 0.2),
          sampleRate,
          0.3);
    case SoundTimbre.bright:
      return _encodeWav(
          _plucked(frequency, sampleRate,
              seconds: 1.6, damping: 0.990, brightness: 0.9),
          sampleRate,
          0.27);
    case SoundTimbre.harp:
      return _encodeWav(
          _plucked(frequency, sampleRate,
              seconds: 3.5, damping: 0.998, brightness: 0.25),
          sampleRate,
          0.27);
    case SoundTimbre.bowed:
      return _encodeWav(
          _additive(frequency, sampleRate,
              harmonics: _sawHarmonics(12, 1.0),
              seconds: 4.0,
              attack: 0.08,
              vibratoDepth: 0.004),
          sampleRate,
          0.2);
    case SoundTimbre.bowedLow:
      return _encodeWav(
          _additive(frequency, sampleRate,
              harmonics: _sawHarmonics(10, 1.3),
              seconds: 4.0,
              attack: 0.12,
              vibratoDepth: 0.003),
          sampleRate,
          0.22);
    case SoundTimbre.flute:
      return _encodeWav(_fluteSamples(frequency, sampleRate), sampleRate, 0.2);
    case SoundTimbre.clarinet:
      return _encodeWav(
          _additive(frequency, sampleRate,
              harmonics: const [[1, 1.0], [3, 0.55], [5, 0.3], [7, 0.15], [9, 0.08], [11, 0.04]],
              seconds: 4.0,
              attack: 0.04),
          sampleRate,
          0.2);
    case SoundTimbre.brass:
      return _encodeWav(
          _additive(frequency, sampleRate,
              harmonics: _sawHarmonics(10, 0.7),
              seconds: 4.0,
              attack: 0.03,
              brightRise: 0.08,
              vibratoDepth: 0.002),
          sampleRate,
          0.2);
    case SoundTimbre.horn:
      return _encodeWav(
          _additive(frequency, sampleRate,
              harmonics: _sawHarmonics(6, 1.4),
              seconds: 4.0,
              attack: 0.06,
              brightRise: 0.12),
          sampleRate,
          0.22);
    case SoundTimbre.saxophone:
      return _encodeWav(
          _additive(frequency, sampleRate,
              harmonics: const [[1, 1.0], [2, 0.7], [3, 0.8], [4, 0.5], [5, 0.45], [6, 0.25], [7, 0.15], [8, 0.1]],
              seconds: 4.0,
              attack: 0.04,
              vibratoDepth: 0.005),
          sampleRate,
          0.2);
    case SoundTimbre.xylophone:
      return _encodeWav(
          _additive(frequency, sampleRate,
              harmonics: const [[1, 1.0], [3.93, 0.35], [9.2, 0.1]],
              seconds: 1.0,
              attack: 0.002,
              decay: 5.0,
              decayPerHarmonic: 1.5),
          sampleRate,
          0.28);
  }
}

/// Harmonics 1…[count] with amplitude 1/n^[slope] (a sawtooth-like,
/// string or brass tone; a bigger slope is darker).
List<List<double>> _sawHarmonics(int count, double slope) => [
  for (int n = 1; n <= count; n++)
    [n.toDouble(), 1 / math.pow(n, slope).toDouble()],
];

/// A sum of [harmonics] ([multiple of the frequency, amplitude]) with
/// an [attack], an optional exponential [decay] (faster for higher
/// harmonics by [decayPerHarmonic]), an optional vibrato (5.5 Hz,
/// starting gently after 0.25 s) and an optional [brightRise] — the
/// upper harmonics grow in over that many seconds, like a brass note
/// "speaking". Without [decay] the tone is steady (wind, bowed,
/// organ) for [seconds].
Float64List _additive(
    double frequency,
    int sampleRate, {
      required List<List<double>> harmonics,
      required double seconds,
      double attack = 0.01,
      double decay = 0,
      double decayPerHarmonic = 0,
      double vibratoDepth = 0,
      double brightRise = 0,
    }) {
  final n = (seconds * sampleRate).round();
  final out = Float64List(n);
  final nyquist = sampleRate / 2;
  for (final h in harmonics) {
    final mult = h[0];
    final amp = h[1];
    final f = frequency * mult;
    if (f >= nyquist * 0.9) continue; // would alias — skip
    final hDecay = decay * (1 + decayPerHarmonic * (mult - 1));
    double phase = 0;
    for (int i = 0; i < n; i++) {
      final t = i / sampleRate;
      double vib = 0;
      if (vibratoDepth > 0) {
        final ramp = ((t - 0.25) / 0.3).clamp(0.0, 1.0);
        vib = vibratoDepth * ramp * math.sin(2 * math.pi * 5.5 * t);
      }
      phase += 2 * math.pi * f * (1 + vib) / sampleRate;
      double a = amp;
      if (hDecay > 0) a *= math.exp(-hDecay * t);
      if (brightRise > 0 && mult > 1) {
        a *= (t / brightRise).clamp(0.0, 1.0);
      }
      out[i] += a * math.sin(phase);
    }
  }
  _envelope(out, sampleRate, attack);
  return out;
}

/// Accordion / bayan: two slightly detuned reeds (the gentle beating
/// gives the typical "musette" shimmer), rich in harmonics, steady.
Float64List _reedSamples(double frequency, int sampleRate) {
  final a = _additive(frequency * 0.9985, sampleRate,
      harmonics: _sawHarmonics(10, 0.9), seconds: 4.0, attack: 0.03);
  final b = _additive(frequency * 1.0015, sampleRate,
      harmonics: _sawHarmonics(10, 0.9), seconds: 4.0, attack: 0.03);
  for (int i = 0; i < a.length; i++) {
    a[i] += b[i];
  }
  return a;
}

/// Flute: an almost pure tone with a little breath noise and vibrato.
Float64List _fluteSamples(double frequency, int sampleRate) {
  final out = _additive(frequency, sampleRate,
      harmonics: const [[1, 1.0], [2, 0.18], [3, 0.08], [4, 0.03]],
      seconds: 4.0,
      attack: 0.06,
      vibratoDepth: 0.005);
  final rnd = math.Random(7);
  double lp = 0;
  for (int i = 0; i < out.length; i++) {
    // Soft, low-passed breath noise, strongest at the start.
    lp += 0.2 * ((rnd.nextDouble() * 2 - 1) - lp);
    final t = i / sampleRate;
    out[i] += lp * (0.05 + 0.15 * math.exp(-t * 8));
  }
  _envelope(out, sampleRate, 0.06);
  return out;
}

/// Plucked string (Karplus–Strong): a burst of noise that circulates in
/// a delay line one period long and is softened every round, which is
/// exactly how a plucked string loses its brightness. [damping] close
/// to 1 rings longer; [brightness] 0…1 shapes the pluck (low = soft
/// finger, high = metal pick).
Float64List _plucked(
    double frequency,
    int sampleRate, {
      required double seconds,
      required double damping,
      required double brightness,
    }) {
  final n = (seconds * sampleRate).round();
  final out = Float64List(n);
  final period = math.max(2, (sampleRate / frequency).round());
  final buffer = Float64List(period);
  final rnd = math.Random(frequency.round());
  double prev = 0;
  for (int i = 0; i < period; i++) {
    final noise = rnd.nextDouble() * 2 - 1;
    // Low-pass the initial noise for a softer pluck.
    prev = prev + (0.15 + 0.85 * brightness) * (noise - prev);
    buffer[i] = prev;
  }
  int idx = 0;
  for (int i = 0; i < n; i++) {
    final current = buffer[idx];
    final next = buffer[(idx + 1) % period];
    out[i] = current;
    buffer[idx] = damping * 0.5 * (current + next);
    idx = (idx + 1) % period;
  }
  _envelope(out, sampleRate, 0.002);
  return out;
}

/// Electric guitar: a plucked string that rings long, with a little
/// soft overdrive for its warm edge.
Float64List _electricGuitarSamples(double frequency, int sampleRate) {
  final out = _plucked(frequency, sampleRate,
      seconds: 4.0, damping: 0.999, brightness: 0.7);
  double peak = 0;
  for (final v in out) {
    if (v.abs() > peak) peak = v.abs();
  }
  if (peak == 0) return out;
  for (int i = 0; i < out.length; i++) {
    out[i] = _tanh(2.5 * out[i] / peak);
  }
  return out;
}

double _tanh(double x) {
  final e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

/// Fades the first [attack] seconds in and the last 40 ms out (so a
/// tone left to ring to its end stops without a click).
void _envelope(Float64List samples, int sampleRate, double attack) {
  final n = samples.length;
  final attackSamples = math.max(1, (attack * sampleRate).round());
  final fadeOut = math.min(n, (0.04 * sampleRate).round());
  for (int i = 0; i < n; i++) {
    double env = 1;
    if (i < attackSamples) env = i / attackSamples;
    if (i >= n - fadeOut) env *= (n - i) / fadeOut;
    samples[i] *= env;
  }
}

/// The piano tone (unchanged): a fundamental plus a few harmonics,
/// each with a fast attack and its own exponential decay — higher
/// harmonics decay faster, so the tone starts bright and mellows like
/// a struck string — and lower notes ring longer than higher ones.
Float64List _pianoSamples(double frequency, int sampleRate) {
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
  _envelope(samples, sampleRate, 0.004);
  return samples;
}

/// Normalizes [samples] to [targetLevel] (leaving headroom for chords —
/// several notes sounding at once are mixed by the engine) and returns
/// them as a mono 16-bit WAV.
Uint8List _encodeWav(Float64List samples, int sampleRate, double targetLevel) {
  double peak = 0;
  for (final v in samples) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  final double gain = peak > 0 ? targetLevel / peak : 0;
  final sampleCount = samples.length;

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