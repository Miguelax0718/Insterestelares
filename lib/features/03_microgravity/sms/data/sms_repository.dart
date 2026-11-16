import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/storage/hive_bootstrap.dart';
import '../domain/sms_models_and_analyzers.dart';

/// Repositorio Offline-First para evaluaciones de Mareo Espacial (SMS) y función sensoriomotora.
///
/// Persiste en `HiveBoxNames.smsAssessments` cuando la caja está abierta (y mantiene respaldo
/// en memoria para pruebas unitarias/widgets sin inicialización de plataforma) y encola
/// automáticamente cada dictamen en `HiveBoxNames.syncQueue` para sincronización con Tierra.
class SmsRepository {
  final List<SmsComprehensiveAssessment> _memoryStore = [];

  List<SmsComprehensiveAssessment> loadAll() {
    if (Hive.isBoxOpen(HiveBoxNames.smsAssessments)) {
      final box = HiveBootstrap.box(HiveBoxNames.smsAssessments);
      final list = box.values
          .map((raw) => SmsComprehensiveAssessment.fromMap(raw))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    }
    final copy = List<SmsComprehensiveAssessment>.from(_memoryStore)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return copy;
  }

  Future<void> saveAssessment(SmsComprehensiveAssessment assessment) async {
    _memoryStore.removeWhere((item) => item.id == assessment.id);
    _memoryStore.insert(0, assessment);

    final serialized = assessment.toMap();
    if (Hive.isBoxOpen(HiveBoxNames.smsAssessments)) {
      final box = HiveBootstrap.box(HiveBoxNames.smsAssessments);
      await box.put(assessment.id, serialized);
    }

    await HiveBootstrap.enqueueForEarthSync(
      category: 'sms_assessment',
      recordId: assessment.id,
      payload: serialized,
    );
  }
}

class SmsAssessmentNotifier
    extends StateNotifier<List<SmsComprehensiveAssessment>> {
  final SmsRepository repository;
  final Ref ref;

  SmsAssessmentNotifier({
    required this.repository,
    required this.ref,
  }) : super(repository.loadAll());

  Future<void> recordAssessment(SmsComprehensiveAssessment assessment) async {
    await repository.saveAssessment(assessment);
    state = repository.loadAll();
    ref.read(pendingSyncCountProvider.notifier).state =
        HiveBootstrap.pendingSyncCount();
  }

  void refresh() {
    state = repository.loadAll();
  }
}

final smsRepositoryProvider = Provider<SmsRepository>((ref) {
  return SmsRepository();
});

final smsAssessmentsProvider = StateNotifierProvider<SmsAssessmentNotifier,
    List<SmsComprehensiveAssessment>>((ref) {
  final repo = ref.watch(smsRepositoryProvider);
  return SmsAssessmentNotifier(repository: repo, ref: ref);
});
