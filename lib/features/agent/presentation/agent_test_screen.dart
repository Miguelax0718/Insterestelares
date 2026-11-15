import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/agent_models.dart';
import '../providers/agent_providers.dart';

/// Developer console to exercise the agent gateway end to end
/// (STT -> chat -> TTS). Not the final agent canvas UI.
class AgentTestScreen extends ConsumerStatefulWidget {
  const AgentTestScreen({super.key});

  @override
  ConsumerState<AgentTestScreen> createState() => _AgentTestScreenState();
}

class _AgentTestScreenState extends ConsumerState<AgentTestScreen> {
  final _input = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _listening = false;
  bool _busy = false;
  bool _speakReplies = true;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    final stt = ref.read(speechToTextServiceProvider);
    setState(() => _error = null);
    try {
      if (!_listening) {
        await ref.read(textToSpeechServiceProvider).stop();
        await stt.startListening(language: 'es');
        setState(() => _listening = true);
        return;
      }
      setState(() {
        _listening = false;
        _busy = true;
      });
      final text = await stt.stopListening();
      setState(() => _busy = false);
      if (text.trim().isEmpty) {
        setState(() => _error = 'No speech detected.');
        return;
      }
      _input.text = text;
      await _send();
    } catch (e) {
      setState(() {
        _listening = false;
        _busy = false;
        _error = 'Speech-to-text failed: $e';
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _messages.add(const ChatMessage(role: ChatRole.assistant, content: ''));
      _input.clear();
      _busy = true;
      _error = null;
    });
    final history = _messages.sublist(0, _messages.length - 1);
    final buffer = StringBuffer();
    try {
      await for (final event
          in ref.read(agentChatServiceProvider).stream(history)) {
        if (event is AgentStreamDelta) {
          buffer.write(event.delta);
          setState(() {
            _messages[_messages.length - 1] = ChatMessage(
              role: ChatRole.assistant,
              content: buffer.toString(),
            );
          });
        }
      }
      if (_speakReplies && buffer.isNotEmpty) {
        await ref.read(textToSpeechServiceProvider).speak(buffer.toString());
      }
    } catch (e) {
      setState(() {
        if (buffer.isEmpty) _messages.removeLast();
        _error = 'Agent request failed: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(agentConfigProvider);
    final health = ref.watch(agentHealthProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent console (dev)'),
        actions: [
          IconButton(
            tooltip: 'Speak replies',
            icon: Icon(_speakReplies ? Icons.volume_up : Icons.volume_off),
            onPressed: () => setState(() => _speakReplies = !_speakReplies),
          ),
          IconButton(
            tooltip: 'Recheck gateway',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(agentHealthProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ListTile(
              dense: true,
              leading: Icon(
                health.hasValue ? Icons.cloud_done : Icons.cloud_off,
                color: health.hasValue ? Colors.greenAccent : Colors.orange,
              ),
              title: Text(
                config.isConfigured
                    ? config.baseUrl
                    : 'ASTRAMED_API_URL not set',
              ),
              subtitle: Text(
                health.when(
                  data: (h) =>
                      'llm=${h.providers['llm']} stt=${h.providers['stt']} tts=${h.providers['tts']}',
                  loading: () => 'Checking gateway...',
                  error: (e, _) =>
                      'Gateway unreachable (local fallback for voice)',
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final isUser = m.role == ChatRole.user;
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(maxWidth: 560),
                      decoration: BoxDecoration(
                        color: isUser
                            ? scheme.primary.withValues(alpha: 0.25)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.content.isEmpty ? '...' : m.content),
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton.filled(
                    tooltip: _listening ? 'Stop and send' : 'Talk',
                    style: IconButton.styleFrom(
                      backgroundColor: _listening
                          ? Colors.redAccent
                          : scheme.primary,
                    ),
                    icon: Icon(_listening ? Icons.stop : Icons.mic),
                    onPressed: _busy ? null : _toggleMic,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_listening,
                      decoration: InputDecoration(
                        hintText: _listening
                            ? 'Listening...'
                            : 'Type a message',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _busy ? null : _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
