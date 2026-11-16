import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/medical_thresholds.dart';
import '../../../../core/storage/hive_bootstrap.dart';
import '../domain/sans_models_and_analyzers.dart';

/// Repositorio Offline-First para evaluaciones SANS y sesiones LBNP (-20 mmHg).
/// Guarda en memoria y en cajas locales Hive (`sans_assessments` y `lbnp_sessions`)
/// cuando están abiertas, y encola la telemetría para sincronización diferida con Tierra.
class SansRepository {
  final List<SansComprehensiveAssessment> _memoryAssessments = [];
  final List<LbnpSessionState> _memoryLbnpSessions = [];

  List<SansComprehensiveAssessment> loadAssessments() {
    if (Hive.isBoxOpen(HiveBoxNames.sansAssessments)) {
      final box = HiveBootstrap.box(HiveBoxNames.sansAssessments);
      final items = box.values
          .map((raw) => SansComprehensiveAssessment.fromMap(raw))
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return items;
    }
    final copy = List<SansComprehensiveAssessment>.from(_memoryAssessments)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return copy;
  }

  Future<void> saveAssessment(SansComprehensiveAssessment assessment) async {
    _memoryAssessments.removeWhere((item) => item.id == assessment.id);
    _memoryAssessments.insert(0, assessment);

    final payload = assessment.toMap();
    if (Hive.isBoxOpen(HiveBoxNames.sansAssessments)) {
      final box = HiveBootstrap.box(HiveBoxNames.sansAssessments);
      await box.put(assessment.id, payload);
    }
    await HiveBootstrap.enqueueForEarthSync(
      category: 'sans_assessment',
      recordId: assessment.id,
      payload: payload,
    );
  }

  List<LbnpSessionState> loadLbnpSessions() {
    if (Hive.isBoxOpen(HiveBoxNames.lbnpSessions)) {
      final box = HiveBootstrap.box(HiveBoxNames.lbnpSessions);
      return box.values
          .map((raw) => LbnpSessionState.fromMap(raw))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    }
    final copy = List<LbnpSessionState>.from(_memoryLbnpSessions)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return copy;
  }

  Future<void> saveLbnpSession(LbnpSessionState session) async {
    _memoryLbnpSessions.removeWhere((item) => item.sessionId == session.sessionId);
    _memoryLbnpSessions.insert(0, session);

    final payload = session.toMap();
    if (Hive.isBoxOpen(HiveBoxNames.lbnpSessions)) {
      final box = HiveBootstrap.box(HiveBoxNames.lbnpSessions);
      await box.put(session.sessionId, payload);
    }
    await HiveBootstrap.enqueueForEarthSync(
      category: 'lbnp_countermeasure_session',
      recordId: session.sessionId,
      payload: payload,
    );
  }
}

class SansAssessmentsNotifier
    extends StateNotifier<List<SansComprehensiveAssessment>> {
  final SansRepository _repository;
  final Ref _ref;

  SansAssessmentsNotifier(this._repository, this._ref)
      : super(_repository.loadAssessments());

  Future<void> recordAssessment({
    required NearPointEstimate nearPoint,
    required StarfieldAssessmentResult starfield,
  }) async {
    final now = DateTime.now().toUtc();
    final record = SansComprehensiveAssessment(
      id: 'sans_${now.millisecondsSinceEpoch}',
      recordedAt: now,
      nearPoint: nearPoint,
      starfield: starfield,
    );
    await _repository.saveAssessment(record);
    state = _repository.loadAssessments();
    _ref.read(pendingSyncCountProvider.notifier).state =
        HiveBootstrap.pendingSyncCount();
  }
}

class LbnpProtocolNotifier extends StateNotifier<LbnpSessionState> {
  final SansRepository _repository;
  final Ref _ref;
  final LbnpProtocolMachine _machine;
  Timer? _timer;

  LbnpProtocolNotifier(this._repository, this._ref)
      : _machine = LbnpProtocolMachine(),
        super(LbnpSessionState.initial());

  void startProtocol({
    int targetHoldDurationSeconds = 60,
    int requiredDecompressionSeconds =
        MedicalThresholds.lbnpMinDecompressionSeconds,
  }) {
    _timer?.cancel();
    state = _machine.startSession(
      targetHoldDurationSeconds: targetHoldDurationSeconds,
      requiredDecompressionSeconds: requiredDecompressionSeconds,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      stepOneSecond();
    });
  }

  Future<void> stepOneSecond({int deltaSeconds = 1}) async {
    final updated = _machine.tick(deltaSeconds: deltaSeconds);
    state = updated;
    if (updated.phase == LbnpPhase.completed ||
        updated.phase == LbnpPhase.aborted) {
      _timer?.cancel();
      await _repository.saveLbnpSession(updated);
      _ref.read(pendingSyncCountProvider.notifier).state =
          HiveBootstrap.pendingSyncCount();
    }
  }

  void requestStopOrRelease() {
    state = _machine.requestStopOrRelease();
  }

  void resetIfSafe() {
    final updated = _machine.resetIfSafe();
    state = updated;
    if (updated.phase == LbnpPhase.idle) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sansRepositoryProvider = Provider<SansRepository>((ref) {
  return SansRepository();
});

final sansAssessmentsProvider = StateNotifierProvider<SansAssessmentsNotifier,
    List<SansComprehensiveAssessment>>((ref) {
  final repo = ref.watch(sansRepositoryProvider);
  return SansAssessmentsNotifier(repo, ref);
});

final lbnpProtocolProvider =
    StateNotifierProvider<LbnpProtocolNotifier, LbnpSessionState>((ref) {
  final repo = ref.watch(sansRepositoryProvider);
  return LbnpProtocolNotifier(repo, ref);
});
