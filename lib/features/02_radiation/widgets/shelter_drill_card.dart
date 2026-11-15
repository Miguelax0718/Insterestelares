import 'dart:async';

import 'package:flutter/material.dart';

/// Manual demo timer. It is not an operational exposure or safety deadline.
class ShelterDrillCard extends StatefulWidget {
  const ShelterDrillCard({
    super.key,
    this.duration = const Duration(hours: 2),
    this.now = DateTime.now,
  });

  final Duration duration;
  final DateTime Function() now;

  @override
  State<ShelterDrillCard> createState() => _ShelterDrillCardState();
}

class _ShelterDrillCardState extends State<ShelterDrillCard>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<ShelterDrillCard> {
  Timer? _timer;
  DateTime? _deadline;
  late Duration _remaining;
  bool _shelterReached = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    WidgetsBinding.instance.addObserver(this);
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null) return;
    final remaining = deadline.difference(widget.now());
    setState(
      () => _remaining = remaining.isNegative ? Duration.zero : remaining,
    );
    if (_remaining == Duration.zero) {
      _timer?.cancel();
      _deadline = null;
    }
  }

  void _start() {
    _deadline = widget.now().add(_remaining);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() {});
  }

  void _stop({bool reached = false}) {
    _tick();
    _timer?.cancel();
    setState(() {
      _deadline = null;
      _shelterReached = reached;
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _deadline = null;
      _remaining = widget.duration;
      _shelterReached = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final seconds = (_remaining.inMilliseconds / 1000).ceil();
    String two(int value) => value.toString().padLeft(2, '0');
    final clock =
        '${two(seconds ~/ 3600)}:'
        '${two((seconds % 3600) ~/ 60)}:${two(seconds % 60)}';
    final running = _deadline != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SPE shelter drill',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Simulated response: move to the storm shelter.\n'
              'Demo countdown: 2 hours. This is not a safe exposure window.',
            ),
            const SizedBox(height: 8),
            Text(clock, style: Theme.of(context).textTheme.headlineMedium),
            Text(
              _shelterReached
                  ? 'Shelter arrival recorded for this drill.'
                  : seconds == 0
                  ? 'Drill time elapsed. Shelter arrival is unconfirmed.'
                  : running
                  ? 'Drill running'
                  : 'Drill ready or paused',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _shelterReached || seconds == 0
                      ? null
                      : running
                      ? () => _stop()
                      : _start,
                  child: Text(running ? 'Pause drill' : 'Start / resume drill'),
                ),
                OutlinedButton(
                  onPressed: _shelterReached
                      ? null
                      : () => _stop(reached: true),
                  child: const Text('Mark shelter reached'),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset drill')),
              ],
            ),
            const Text(
              'Changing day or crew, or leaving this screen, resets the drill.',
            ),
          ],
        ),
      ),
    );
  }
}
