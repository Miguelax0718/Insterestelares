import '../domain/agent_contracts.dart';

class ComponentSpec<T extends AgentViewModel> {
  const ComponentSpec({
    required this.id,
    required this.fromProps,
  });

  final String id;
  final T Function(Map<String, dynamic> props) fromProps;
}

class GenericComponentViewModel extends AgentViewModel {
  GenericComponentViewModel({
    required super.componentId,
    required super.title,
    Map<String, dynamic> props = const {},
  }) : props = Map<String, dynamic>.unmodifiable(props);

  final Map<String, dynamic> props;

  @override
  Map<String, dynamic> toProps() => props;
}

class ComponentRegistry {
  ComponentRegistry({
    Map<String, ComponentSpec<AgentViewModel>>? overrides,
  }) {
    _registerDefaults();
    if (overrides != null) {
      for (final spec in overrides.values) {
        register(spec);
      }
    }
  }

  final Map<String, ComponentSpec<AgentViewModel>> _specs = {};

  Iterable<String> get registeredIds => _specs.keys;

  bool has(String id) => _specs.containsKey(id);

  ComponentSpec<AgentViewModel>? specFor(String id) => _specs[id];

  void register<T extends AgentViewModel>(ComponentSpec<T> spec) {
    if (spec.id.trim().isEmpty) {
      throw const FormatException('Component id must not be empty');
    }
    _specs[spec.id] = ComponentSpec<AgentViewModel>(
      id: spec.id,
      fromProps: (props) => spec.fromProps(props),
    );
  }

  AgentViewModel resolve(String id, Map<String, dynamic> props) {
    final spec = _specs[id];
    if (spec == null) {
      throw FormatException('Unknown component id: $id');
    }
    return spec.fromProps(Map<String, dynamic>.from(props));
  }

  void _registerDefaults() {
    register(_vitalsCardSpec());
    register(_crewStatusSpec());
    register(_telemetryChartSpec());
    register(_alertBannerSpec());
    register(_confirmActionSpec());

    for (final id in ComponentIds.all) {
      if (_specs.containsKey(id)) {
        continue;
      }
      register(_defaultGenericSpec(id));
    }
  }

  ComponentSpec<GenericComponentViewModel> _vitalsCardSpec() {
    return ComponentSpec<GenericComponentViewModel>(
      id: ComponentIds.vitalsCard,
      fromProps: (props) {
        final astronautId = _requireNonEmptyString(
          props['astronaut_id'] ?? props['astronautId'],
          field: 'astronaut_id',
          componentId: ComponentIds.vitalsCard,
        );
        final hasVitalsMap = props['vitals'] is Map;
        final hasHeartRate = props['heart_rate'] is num || props['heartRate'] is num;
        if (!hasVitalsMap && !hasHeartRate) {
          throw const FormatException(
            'vitals_card requires "vitals" map or numeric "heart_rate"',
          );
        }
        return GenericComponentViewModel(
          componentId: ComponentIds.vitalsCard,
          title: _optionalTitle(props, fallback: 'Vitals ($astronautId)'),
          props: props,
        );
      },
    );
  }

  ComponentSpec<GenericComponentViewModel> _crewStatusSpec() {
    return ComponentSpec<GenericComponentViewModel>(
      id: ComponentIds.crewStatus,
      fromProps: (props) {
        if (props['crew'] is! List) {
          throw const FormatException('crew_status requires a "crew" list');
        }
        return GenericComponentViewModel(
          componentId: ComponentIds.crewStatus,
          title: _optionalTitle(props, fallback: 'Crew Status'),
          props: props,
        );
      },
    );
  }

  ComponentSpec<GenericComponentViewModel> _telemetryChartSpec() {
    return ComponentSpec<GenericComponentViewModel>(
      id: ComponentIds.telemetryChart,
      fromProps: (props) {
        final hasMachines = props['machines'] is List;
        final hasLogs = props['recent_logs'] is List || props['logs'] is List;
        final hasSeries = props['series'] is List;
        final hasMetrics = props['metrics'] is Map;
        if (!hasMachines && !hasLogs && !hasSeries && !hasMetrics) {
          throw const FormatException(
            'telemetry_chart requires "machines", "series", "logs", or "metrics"',
          );
        }
        return GenericComponentViewModel(
          componentId: ComponentIds.telemetryChart,
          title: _optionalTitle(props, fallback: 'Telemetry'),
          props: props,
        );
      },
    );
  }

  ComponentSpec<GenericComponentViewModel> _alertBannerSpec() {
    return ComponentSpec<GenericComponentViewModel>(
      id: ComponentIds.alertBanner,
      fromProps: (props) {
        final msg = props['message'] ?? props['title'] ?? props['text'];
        if (msg is! String || msg.trim().isEmpty) {
          throw const FormatException(
            'alert_banner requires non-empty "message" or "title"',
          );
        }
        return GenericComponentViewModel(
          componentId: ComponentIds.alertBanner,
          title: _optionalTitle(props, fallback: msg.trim()),
          props: props,
        );
      },
    );
  }

  ComponentSpec<GenericComponentViewModel> _confirmActionSpec() {
    return ComponentSpec<GenericComponentViewModel>(
      id: ComponentIds.confirmAction,
      fromProps: (props) {
        _requireNonEmptyString(
          props['id'] ?? props['action_id'],
          field: 'id',
          componentId: ComponentIds.confirmAction,
        );
        final description = _requireNonEmptyString(
          props['description'],
          field: 'description',
          componentId: ComponentIds.confirmAction,
        );
        return GenericComponentViewModel(
          componentId: ComponentIds.confirmAction,
          title: _optionalTitle(props, fallback: description),
          props: props,
        );
      },
    );
  }

  ComponentSpec<GenericComponentViewModel> _defaultGenericSpec(String id) {
    return ComponentSpec<GenericComponentViewModel>(
      id: id,
      fromProps: (props) {
        if (props.containsKey('title') && props['title'] is! String) {
          throw FormatException('$id "title" prop must be a String');
        }
        return GenericComponentViewModel(
          componentId: id,
          title: _optionalTitle(props, fallback: _defaultTitle(id)),
          props: props,
        );
      },
    );
  }

  static String _requireNonEmptyString(
    Object? value, {
    required String field,
    required String componentId,
  }) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$componentId requires non-empty "$field"');
    }
    return value.trim();
  }

  static String _optionalTitle(
    Map<String, dynamic> props, {
    required String fallback,
  }) {
    final raw = props['title'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return fallback;
  }

  static String _defaultTitle(String id) {
    return id
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
