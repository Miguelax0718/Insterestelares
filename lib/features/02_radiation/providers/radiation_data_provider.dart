import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/radiation_sample_repository.dart';

/// Loads the bundled radiation sample data for the offline feature.
final radiationMissionDataProvider =
    FutureProvider<RadiationMissionData>((ref) {
  return RadiationSampleRepository().load();
});
