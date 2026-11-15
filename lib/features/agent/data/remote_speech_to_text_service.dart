import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../domain/agent_exception.dart';
import '../domain/agent_ports.dart';
import 'agent_api_client.dart';
import 'wav_encoder.dart';

abstract interface class AudioCapturePort {
  Future<bool> hasPermission();
  Future<void> start();
  Future<Uint8List> stop();
  Future<void> cancel();
  Future<void> dispose();

  /// Starts a raw PCM16 mono 16 kHz audio stream for continuous VAD processing.
  Future<Stream<Uint8List>> startPcmStream();

  /// Stops an active continuous PCM stream.
  Future<void> stopPcmStream();
}

class RecordAudioCapture implements AudioCapturePort {
  RecordAudioCapture({this._recorder});

  AudioRecorder? _recorder;
  final List<int> _pcmBuffer = [];
  StreamSubscription<Uint8List>? _subscription;

  static const int _sampleRate = 16000;
  static const int _channels = 1;

  static const RecordConfig _pcmRecordConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: _sampleRate,
    numChannels: _channels,
    echoCancel: true,
    noiseSuppress: true,
  );

  AudioRecorder get _instance => _recorder ??= AudioRecorder();

  @override
  Future<bool> hasPermission() => _instance.hasPermission();

  @override
  Future<void> start() async {
    final recorder = _instance;
    final permitted = await recorder.hasPermission();
    if (!permitted) {
      throw const AgentApiException(
        code: AgentErrorCode.unknown,
        message: 'Microphone permission denied.',
      );
    }
    await _subscription?.cancel();
    _pcmBuffer.clear();

    final stream = await recorder.startStream(_pcmRecordConfig);
    _subscription = stream.listen(_pcmBuffer.addAll);
  }

  @override
  Future<Stream<Uint8List>> startPcmStream() async {
    final recorder = _instance;
    final permitted = await recorder.hasPermission();
    if (!permitted) {
      throw const AgentApiException(
        code: AgentErrorCode.unknown,
        message: 'Microphone permission denied.',
      );
    }
    await _subscription?.cancel();
    _subscription = null;
    _pcmBuffer.clear();

    return recorder.startStream(_pcmRecordConfig);
  }

  @override
  Future<void> stopPcmStream() async {
    final recorder = _recorder;
    if (recorder != null) {
      await recorder.stop();
    }
  }

  @override
  Future<Uint8List> stop() async {
    final recorder = _recorder;
    if (recorder != null) {
      await recorder.stop();
    }
    await _subscription?.cancel();
    _subscription = null;
    final pcm = Uint8List.fromList(_pcmBuffer);
    _pcmBuffer.clear();
    return buildWavBytes(
      pcm,
      sampleRate: _sampleRate,
      channels: _channels,
      bitsPerSample: 16,
    );
  }

  @override
  Future<void> cancel() async {
    final recorder = _recorder;
    if (recorder != null) {
      await recorder.cancel();
    }
    await _subscription?.cancel();
    _subscription = null;
    _pcmBuffer.clear();
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      await recorder.dispose();
    }
  }
}

class RemoteSpeechToTextService implements SpeechToTextService {
  RemoteSpeechToTextService({required this._client, AudioCapturePort? capture})
    : _capture = capture ?? RecordAudioCapture();

  final AgentApiClient _client;
  final AudioCapturePort _capture;
  String _activeLanguage = 'en';
  Completer<void>? _listenCompleter;

  AudioCapturePort get capture => _capture;

  @override
  Future<bool> isAvailable() async {
    if (!_client.config.isConfigured) {
      return false;
    }
    return _capture.hasPermission();
  }

  Future<String> transcribeWav(
    Uint8List wavBytes, {
    String language = 'en',
  }) async {
    if (wavBytes.lengthInBytes <= 44) {
      return '';
    }
    final result = await _client.transcribe(
      wavBytes,
      filename: 'recording.wav',
      mimeType: 'audio/wav',
      language: language,
    );
    return result.text;
  }

  @override
  Future<void> startListening({String language = 'en'}) async {
    _activeLanguage = language;
    await _capture.start();
  }

  @override
  Future<String> stopListening() async {
    if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
      _listenCompleter!.complete();
    }
    final wavBytes = await _capture.stop();
    return transcribeWav(wavBytes, language: _activeLanguage);
  }

  @override
  Future<String> listen({
    String language = 'en',
    Duration maxDuration = const Duration(seconds: 15),
  }) async {
    await startListening(language: language);
    final completer = Completer<void>();
    _listenCompleter = completer;
    try {
      await completer.future.timeout(maxDuration, onTimeout: () {});
    } finally {
      _listenCompleter = null;
    }
    return stopListening();
  }

  @override
  Future<void> cancel() async {
    if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
      _listenCompleter!.complete();
    }
    await _capture.cancel();
  }

  @override
  Future<void> dispose() => _capture.dispose();
}
