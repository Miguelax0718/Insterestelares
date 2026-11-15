import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

/// Configuration thresholds for energy-based PCM16 voice activity detection.
class VadConfig {
  const VadConfig({
    this.sampleRate = 16000,
    this.frameDuration = const Duration(milliseconds: 20),
    this.silenceDuration = const Duration(milliseconds: 800),
    this.minUtteranceDuration = const Duration(milliseconds: 400),
    this.maxUtteranceDuration = const Duration(seconds: 15),
    this.preRollDuration = const Duration(milliseconds: 300),
    this.tailPaddingDuration = const Duration(milliseconds: 200),
    this.initialNoiseFloorDb = -55.0,
    this.minNoiseFloorDb = -75.0,
    this.maxNoiseFloorDb = -35.0,
    this.speechMarginDb = 10.0,
    this.minSpeechThresholdDb = -45.0,
    this.onsetHangoverFrames = 2,
  }) : assert(sampleRate > 0),
       assert(onsetHangoverFrames >= 1);

  final int sampleRate;
  final Duration frameDuration;
  final Duration silenceDuration;
  final Duration minUtteranceDuration;
  final Duration maxUtteranceDuration;
  final Duration preRollDuration;
  final Duration tailPaddingDuration;
  final double initialNoiseFloorDb;
  final double minNoiseFloorDb;
  final double maxNoiseFloorDb;
  final double speechMarginDb;
  final double minSpeechThresholdDb;
  final int onsetHangoverFrames;

  int get samplesPerFrame =>
      (sampleRate * frameDuration.inMilliseconds) ~/ 1000;

  int get bytesPerFrame => samplesPerFrame * 2;

  int get silenceFrames => math.max(
    1,
    (silenceDuration.inMilliseconds / frameDuration.inMilliseconds).ceil(),
  );

  int get minUtteranceFrames => math.max(
    1,
    (minUtteranceDuration.inMilliseconds / frameDuration.inMilliseconds).ceil(),
  );

  int get maxUtteranceFrames => math.max(
    minUtteranceFrames,
    (maxUtteranceDuration.inMilliseconds / frameDuration.inMilliseconds).ceil(),
  );

  int get preRollFrames => math.max(
    0,
    (preRollDuration.inMilliseconds / frameDuration.inMilliseconds).floor(),
  );

  int get tailPaddingFrames => math.max(
    0,
    (tailPaddingDuration.inMilliseconds / frameDuration.inMilliseconds).ceil(),
  );
}

sealed class VadEvent {
  const VadEvent();
}

final class VadSpeechStart extends VadEvent {
  const VadSpeechStart({required this.energyDb, required this.noiseFloorDb});

  final double energyDb;
  final double noiseFloorDb;
}

final class VadSpeechEnd extends VadEvent {
  const VadSpeechEnd({
    required this.pcmBytes,
    required this.speechDuration,
    required this.totalDuration,
  });

  final Uint8List pcmBytes;
  final Duration speechDuration;
  final Duration totalDuration;
}

enum _VadPhase { idle, tentative, speaking }

/// Pure-Dart energy-based Voice Activity Detector operating on 16-bit signed
/// little-endian mono PCM frames with adaptive noise-floor tracking.
class VoiceActivityDetector {
  VoiceActivityDetector({this.config = const VadConfig()})
    : _noiseFloorDb = config.initialNoiseFloorDb;

  final VadConfig config;

  final List<int> _residualBytes = [];
  final Queue<Uint8List> _preRoll = Queue<Uint8List>();
  final List<Uint8List> _onsetPendingFrames = [];
  final List<Uint8List> _utteranceFrames = [];

  _VadPhase _phase = _VadPhase.idle;
  double _noiseFloorDb;
  double _lastFrameDb = -120.0;
  int _activeSpeechFrames = 0;
  int _trailingSilenceFrames = 0;
  int _framesSinceOnset = 0;
  int _lastSpeechFrameIndex = -1;

  bool get isSpeechActive => _phase == _VadPhase.speaking;

  double get noiseFloorDb => _noiseFloorDb;

  double get lastFrameDb => _lastFrameDb;

  double get speechThresholdDb => math.max(
    config.minSpeechThresholdDb,
    _noiseFloorDb + config.speechMarginDb,
  );

  /// Computes frame RMS energy in dBFS for 16-bit signed little-endian PCM.
  static double computeFrameDb(Uint8List frameBytes) {
    final sampleCount = frameBytes.lengthInBytes ~/ 2;
    if (sampleCount == 0) {
      return -120.0;
    }
    final data = ByteData.sublistView(frameBytes);
    var sumSquares = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final normalized = data.getInt16(i * 2, Endian.little) / 32768.0;
      sumSquares += normalized * normalized;
    }
    final rms = math.sqrt(sumSquares / sampleCount);
    if (rms <= 1e-6) {
      return -120.0;
    }
    return (20.0 * (math.log(rms) / math.ln10)).clamp(-120.0, 0.0);
  }

  /// Processes an arbitrary-length PCM16 LE mono byte chunk and returns any
  /// [VadEvent] transitions detected on frame boundaries.
  List<VadEvent> process(Uint8List pcmBytes) {
    if (pcmBytes.isEmpty) {
      return const [];
    }

    final frameBytes = config.bytesPerFrame;
    if (frameBytes <= 0) {
      return const [];
    }

    final events = <VadEvent>[];
    var offset = 0;

    if (_residualBytes.isNotEmpty) {
      final needed = frameBytes - _residualBytes.length;
      if (pcmBytes.length < needed) {
        _residualBytes.addAll(pcmBytes);
        return const [];
      }
      _residualBytes.addAll(pcmBytes.sublist(0, needed));
      final frame = Uint8List.fromList(_residualBytes);
      _residualBytes.clear();
      offset = needed;
      final event = _processFrame(frame);
      if (event != null) events.add(event);
    }

    while (offset + frameBytes <= pcmBytes.length) {
      final frame = Uint8List.sublistView(
        pcmBytes,
        offset,
        offset + frameBytes,
      );
      final event = _processFrame(Uint8List.fromList(frame));
      if (event != null) events.add(event);
      offset += frameBytes;
    }

    if (offset < pcmBytes.length) {
      _residualBytes.addAll(pcmBytes.sublist(offset));
    }

    return events;
  }

  void reset() {
    _residualBytes.clear();
    _preRoll.clear();
    _onsetPendingFrames.clear();
    _utteranceFrames.clear();
    _phase = _VadPhase.idle;
    _activeSpeechFrames = 0;
    _trailingSilenceFrames = 0;
    _framesSinceOnset = 0;
    _lastSpeechFrameIndex = -1;
  }

  VadEvent? _processFrame(Uint8List frame) {
    final frameDb = computeFrameDb(frame);
    _lastFrameDb = frameDb;
    final threshold = speechThresholdDb;
    final isSpeech = frameDb >= threshold;

    if (_phase == _VadPhase.idle) {
      if (isSpeech) {
        _onsetPendingFrames.add(frame);
        if (_onsetPendingFrames.length >= config.onsetHangoverFrames) {
          _phase = _VadPhase.tentative;
          _utteranceFrames
            ..clear()
            ..addAll(_preRoll)
            ..addAll(_onsetPendingFrames);
          _activeSpeechFrames = _onsetPendingFrames.length;
          _framesSinceOnset = _onsetPendingFrames.length;
          _trailingSilenceFrames = 0;
          _lastSpeechFrameIndex = _utteranceFrames.length - 1;
          _onsetPendingFrames.clear();
          _preRoll.clear();

          if (_activeSpeechFrames >= config.minUtteranceFrames) {
            _phase = _VadPhase.speaking;
            return VadSpeechStart(
              energyDb: frameDb,
              noiseFloorDb: _noiseFloorDb,
            );
          }
        }
        return null;
      }

      if (_onsetPendingFrames.isNotEmpty) {
        for (final pending in _onsetPendingFrames) {
          _pushPreRoll(pending);
        }
        _onsetPendingFrames.clear();
      }
      _pushPreRoll(frame);
      _updateNoiseFloor(frameDb);
      return null;
    }

    _utteranceFrames.add(frame);
    _framesSinceOnset++;

    if (isSpeech) {
      _activeSpeechFrames++;
      _trailingSilenceFrames = 0;
      _lastSpeechFrameIndex = _utteranceFrames.length - 1;

      if (_phase == _VadPhase.tentative &&
          _activeSpeechFrames >= config.minUtteranceFrames) {
        _phase = _VadPhase.speaking;
        return VadSpeechStart(energyDb: frameDb, noiseFloorDb: _noiseFloorDb);
      }
    } else {
      _trailingSilenceFrames++;
    }

    if (_trailingSilenceFrames >= config.silenceFrames) {
      if (_phase == _VadPhase.speaking) {
        return _finishUtterance(trimTrailingSilence: true);
      }
      _discardTentative(seedWithTrailing: true);
      return null;
    }

    if (_framesSinceOnset >= config.maxUtteranceFrames) {
      if (_phase == _VadPhase.speaking) {
        return _finishUtterance(trimTrailingSilence: false);
      }
      _discardTentative(seedWithTrailing: false);
      return null;
    }

    return null;
  }

  VadSpeechEnd _finishUtterance({required bool trimTrailingSilence}) {
    final endIndex = trimTrailingSilence && _lastSpeechFrameIndex >= 0
        ? math.min(
            _utteranceFrames.length,
            _lastSpeechFrameIndex + 1 + config.tailPaddingFrames,
          )
        : _utteranceFrames.length;

    final selectedFrames = _utteranceFrames.sublist(0, endIndex);
    var totalBytes = 0;
    for (final f in selectedFrames) {
      totalBytes += f.lengthInBytes;
    }
    final pcmBytes = Uint8List(totalBytes);
    var writeOffset = 0;
    for (final f in selectedFrames) {
      pcmBytes.setRange(writeOffset, writeOffset + f.lengthInBytes, f);
      writeOffset += f.lengthInBytes;
    }

    final frameMs = config.frameDuration.inMilliseconds;
    final speechDuration = Duration(
      milliseconds: _activeSpeechFrames * frameMs,
    );
    final totalDuration = Duration(
      milliseconds: (pcmBytes.lengthInBytes ~/ 2) * 1000 ~/ config.sampleRate,
    );

    _seedPreRollFromUtteranceTail();
    _clearUtteranceState();

    return VadSpeechEnd(
      pcmBytes: pcmBytes,
      speechDuration: speechDuration,
      totalDuration: totalDuration,
    );
  }

  void _discardTentative({required bool seedWithTrailing}) {
    if (seedWithTrailing) {
      _seedPreRollFromUtteranceTail();
    } else {
      _preRoll.clear();
    }
    _clearUtteranceState();
  }

  void _seedPreRollFromUtteranceTail() {
    _preRoll.clear();
    if (config.preRollFrames <= 0 || _utteranceFrames.isEmpty) {
      return;
    }
    final start = math.max(0, _utteranceFrames.length - config.preRollFrames);
    for (var i = start; i < _utteranceFrames.length; i++) {
      _preRoll.addLast(_utteranceFrames[i]);
    }
  }

  void _clearUtteranceState() {
    _utteranceFrames.clear();
    _onsetPendingFrames.clear();
    _phase = _VadPhase.idle;
    _activeSpeechFrames = 0;
    _trailingSilenceFrames = 0;
    _framesSinceOnset = 0;
    _lastSpeechFrameIndex = -1;
  }

  void _pushPreRoll(Uint8List frame) {
    if (config.preRollFrames <= 0) {
      return;
    }
    _preRoll.addLast(frame);
    while (_preRoll.length > config.preRollFrames) {
      _preRoll.removeFirst();
    }
  }

  void _updateNoiseFloor(double frameDb) {
    final alpha = frameDb < _noiseFloorDb ? 0.10 : 0.03;
    _noiseFloorDb = (_noiseFloorDb * (1 - alpha) + frameDb * alpha).clamp(
      config.minNoiseFloorDb,
      config.maxNoiseFloorDb,
    );
  }
}
