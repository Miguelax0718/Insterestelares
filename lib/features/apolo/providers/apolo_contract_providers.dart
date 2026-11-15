import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/apolo_models.dart';

/// Overridable provider for the APOLO state of the active astronaut.
/// Bound in `apolo_providers.dart` to the real `ApoloStateNotifier`.
final apoloActiveStateProvider = Provider<ApoloAstronautState>((ref) {
  throw UnimplementedError('apoloActiveStateProvider must be overridden or wired.');
});

/// Overridable provider for APOLO state actions (`showOrbs`, `addWater`, etc.).
final apoloActionsProvider = Provider<ApoloStateActions>((ref) {
  throw UnimplementedError('apoloActionsProvider must be overridden or wired.');
});
