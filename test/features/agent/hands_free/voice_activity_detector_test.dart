import 'dart:math' as math;
import 'dart:typed_data';

import 'package:astramed/features/agent/data/voice_activity_detector.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _silencePcm({required int durationMs, int sampleRate = 16000}) {
  final sampleCount = (sampleRate * durationMs) ~/ 1000;
  return Uint8List(sampleCount * 2);
}

Uint8List _tonePcm({
  required int durationMs,
  int amplitude = 6000,
  double frequencyHz = 440,
  int sampleRate = 16000,
}) {
  final sampleCount = (sampleRate * durationMs) ~/ 1000;
  final data = ByteData(sampleCount * 2);
  for (var i = 0; i < sampleCount; i++) {
    final sample =
        (amplitude * math.sin(2 * math.pi * frequencyHz * i / sampleRate))
            .round()
            .clamp(-32768, 32767);
    data.setInt16(i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

Uint8List _constantSamplePcm({
  required int durationMs,
  required int sampleValue,
  int sampleRate = 16000,
}) {
  final sampleCount = (sampleRate * durationMs) ~/ 1000;
  final data = ByteData(sampleCount * 2);
  for (var i = 0; i < sampleCount; i++) {
    data.setInt16(i * 2, sampleValue.clamp(-32768, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('VoiceActivityDetector', () {
    test('emits no events on pure silence', () {
      final vad = VoiceActivityDetector();
      final events = vad.process(_silencePcm(durationMs: 3000));
      expect(events, isEmpty);
      expect(vad.isSpeechActive, isFalse);
    });

    test('emits speechStart then speechEnd after ~800ms trailing silence', () {
      final vad = VoiceActivityDetector(
        config: const VadConfig(
          silenceDuration: Duration(milliseconds: 800),
          minUtteranceDuration: Duration(milliseconds: 400),
          preRollDuration: Duration(milliseconds: 300),
        ),
      );

      final events = <VadEvent>[];
      events.addAll(vad.process(_silencePcm(durationMs: 500)));
      expect(events, isEmpty);

      events.addAll(vad.process(_tonePcm(durationMs: 700, amplitude: 6000)));
      expect(events.whereType<VadSpeechStart>(), hasLength(1));
      expect(events.whereType<VadSpeechEnd>(), isEmpty);

      // 600 ms silence is not enough yet (< 800 ms).
      events.addAll(vad.process(_silencePcm(durationMs: 600)));
      expect(events.whereType<VadSpeechEnd>(), isEmpty);

      // Additional 240 ms crosses the 800 ms threshold.
      events.addAll(vad.process(_silencePcm(durationMs: 240)));
      final ends = events.whereType<VadSpeechEnd>().toList();
      expect(ends, hasLength(1));
      expect(ends.first.pcmBytes.lengthInBytes, greaterThan(0));
      expect(vad.isSpeechActive, isFalse);
    });

    test('ignores too-short burst below minUtteranceDuration (~400ms)', () {
      final vad = VoiceActivityDetector(
        config: const VadConfig(
          minUtteranceDuration: Duration(milliseconds: 400),
          silenceDuration: Duration(milliseconds: 800),
        ),
      );

      final events = <VadEvent>[];
      events.addAll(vad.process(_silencePcm(durationMs: 400)));
      events.addAll(vad.process(_tonePcm(durationMs: 220, amplitude: 7000)));
      events.addAll(vad.process(_silencePcm(durationMs: 1000)));

      expect(events, isEmpty);
      expect(vad.isSpeechActive, isFalse);
    });

    test('cuts utterance at maxUtteranceDuration (~15s) without silence', () {
      final vad = VoiceActivityDetector(
        config: const VadConfig(
          maxUtteranceDuration: Duration(seconds: 15),
          minUtteranceDuration: Duration(milliseconds: 400),
          preRollDuration: Duration(milliseconds: 300),
        ),
      );

      final events = <VadEvent>[];
      events.addAll(vad.process(_silencePcm(durationMs: 400)));
      events.addAll(vad.process(_tonePcm(durationMs: 15200, amplitude: 6000)));

      expect(events.whereType<VadSpeechStart>(), isNotEmpty);
      final ends = events.whereType<VadSpeechEnd>().toList();
      expect(ends, hasLength(1));
      // Should be roughly <= 15s + 300ms pre-roll (32000 bytes/sec).
      expect(ends.first.pcmBytes.lengthInBytes, lessThanOrEqualTo(15400 * 32));
    });

    test('includes ~300ms pre-roll audio before speech onset', () {
      final vad = VoiceActivityDetector(
        config: const VadConfig(
          preRollDuration: Duration(milliseconds: 300),
          minUtteranceDuration: Duration(milliseconds: 400),
          silenceDuration: Duration(milliseconds: 800),
        ),
      );

      // 500 ms of quiet tagged signal (amplitude 40 -> ~-58 dBFS, below threshold)
      // followed by 500 ms of speech tone -> total emitted must contain the
      // 300 ms pre-roll samples (value == 40).
      final events = <VadEvent>[];
      events.addAll(
        vad.process(_constantSamplePcm(durationMs: 500, sampleValue: 40)),
      );
      events.addAll(vad.process(_tonePcm(durationMs: 500, amplitude: 6000)));
      events.addAll(vad.process(_silencePcm(durationMs: 900)));

      final end = events.whereType<VadSpeechEnd>().single;
      final byteData = ByteData.sublistView(end.pcmBytes);
      final firstSample = byteData.getInt16(0, Endian.little);
      expect(firstSample, 40);
      // 300ms pre-roll (9600 bytes) + 500ms speech (16000 bytes) = >= 25600 bytes.
      expect(end.pcmBytes.lengthInBytes, greaterThanOrEqualTo(25600));
    });

    test('adapts noise floor and handles unaligned chunk sizes', () {
      final vad = VoiceActivityDetector();
      final bgNoise = _tonePcm(durationMs: 1000, amplitude: 120); // ~-49 dBFS
      final speech = _tonePcm(durationMs: 600, amplitude: 6500);
      final trailing = _silencePcm(durationMs: 900);

      final combined = Uint8List.fromList([...bgNoise, ...speech, ...trailing]);
      final events = <VadEvent>[];
      // Feed irregular 333-byte chunks (odd byte boundary!).
      for (var i = 0; i < combined.length; i += 333) {
        final end = math.min(i + 333, combined.length);
        events.addAll(vad.process(combined.sublist(i, end)));
      }

      expect(events.whereType<VadSpeechStart>(), hasLength(1));
      expect(events.whereType<VadSpeechEnd>(), hasLength(1));
    });
  });
}
