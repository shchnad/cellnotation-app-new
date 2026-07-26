import 'dart:math' as math;
import 'dart:typed_data';

/// Generates short, simple "piano-ish" tones entirely in code — a
/// fundamental sine wave plus two quiet harmonics, shaped by a fast
/// linear attack and an exponential decay (a "plucked" envelope rather
/// than a flat, sustained beep) — and packages the result as a
/// complete mono 16-bit PCM WAV file so it can be handed straight to
/// an audio player that accepts raw bytes.
class ToneSynthesizer {
  static const int sampleRate = 44100;

  /// Synthesizes one tone at [frequencyHz] lasting [durationSeconds].
  /// Duration is clamped to a sane playable range — extremely short or
  /// extremely long notes are still audible/bounded.
  static Uint8List synthesizeTone({
    required double frequencyHz,
    required double durationSeconds,
    double amplitude = 0.5,
  }) {
    if (frequencyHz <= 0) {
      frequencyHz = 1; // avoid nonsense math; effectively silent anyway
    }

    final clampedDuration = durationSeconds.clamp(0.05, 8.0);
    final sampleCount = (sampleRate * clampedDuration).round();
    final samples = Int16List(sampleCount);

    const attackSeconds = 0.01;
    final attackSamples = (sampleRate * attackSeconds).round();
    const decayRate = 3.0; // higher = faster decay ("plucked" feel)

    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;

      final double envelope;
      if (i < attackSamples && attackSamples > 0) {
        envelope = i / attackSamples;
      } else {
        envelope = math.exp(-decayRate * (t - attackSeconds));
      }

      // Fundamental + two quiet harmonics for a slightly richer,
      // less "beepy" timbre than a pure sine.
      final wave = math.sin(2 * math.pi * frequencyHz * t) +
          0.35 * math.sin(2 * math.pi * frequencyHz * 2 * t) +
          0.15 * math.sin(2 * math.pi * frequencyHz * 3 * t);

      final value = (wave / 1.5) * amplitude * envelope;
      samples[i] = (value.clamp(-1.0, 1.0) * 32767).round();
    }

    return _wrapAsWav(samples, sampleRate);
  }

  static Uint8List _wrapAsWav(Int16List samples, int sampleRate) {
    final dataLength = samples.length * 2;
    final buffer = ByteData(44 + dataLength);

    void writeString(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    buffer.setUint32(4, 36 + dataLength, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // PCM chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, 1, Endian.little); // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little); // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample
    writeString(36, 'data');
    buffer.setUint32(40, dataLength, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      buffer.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}