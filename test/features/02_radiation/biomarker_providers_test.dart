import 'package:astramed/features/02_radiation/data/biomarker_repository.dart';
import 'package:astramed/features/02_radiation/data/biomarker_simulator.dart';
import 'package:astramed/features/02_radiation/providers/biomarker_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('por defecto usa el repositorio mock realista', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(biomarkerRepositoryProvider), isA<MockBiomarkerRepository>());
    expect(c.read(selectedAstronautProvider), 'AST-01');
    expect(c.read(selectedBioSummaryProvider).astronautId, 'AST-01');
  });

  test('cambiar al escenario extremo sube el puntaje tras el SPE', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final realistic = c.read(selectedBioSummaryProvider).score;
    c.read(biomarkerScenarioProvider.notifier).state =
        SimulationScenario.extremeHypothetical;
    final extreme = c.read(selectedBioSummaryProvider).score;
    expect(extreme, greaterThan(realistic + 0.15));
  });

  test('se puede reemplazar el repositorio (para datos reales a futuro)', () {
    final fake = MockBiomarkerRepository(simulator: BiomarkerSimulator(seed: 1));
    final c = ProviderContainer(overrides: [
      biomarkerRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);
    expect(c.read(biomarkerRepositoryProvider), same(fake));
  });
}
