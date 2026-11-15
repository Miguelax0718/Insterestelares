import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../domain/agent_ports.dart';
import 'agent_api_client.dart';

abstract interface class AudioPlaybackPort {
  Future<void> playWav(Uint8List wavBytes);
  Future<void> stop();
  Future<void> dispose();
}

class AudioplayersPlayback implements AudioPlaybackPort {
  AudioplayersPlayback({this._player});

  AudioPlayer? _player;

  AudioPlayer get _instance => _player ??= AudioPlayer();

  @override
  Future<void> playWav(Uint8List wavBytes) async {
    await _instance.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
  }

  @override
  Future<void> stop() async {
    final player = _player;
    if (player != null) {
      await player.stop();
    }
  }

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    if (player != null) {
      await player.dispose();
    }
  }
}

class RemoteTextToSpeechService implements TextToSpeechService {
  RemoteTextToSpeechService({
    required this._client,
    AudioPlaybackPort? playback,
  }) : _playback = playback ?? AudioplayersPlayback();

  final AgentApiClient _client;
  final AudioPlaybackPort _playback;

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'es-ES',
  }) async {
    final wavBytes = await _client.synthesize(text, voice: voice);
    await _playback.playWav(wavBytes);
  }

  @override
  Future<void> stop() => _playback.stop();

  @override
  Future<void> dispose() => _playback.dispose();
}
