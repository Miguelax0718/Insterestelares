enum AgentErrorCode {
  unauthorized('unauthorized'),
  rateLimited('rate_limited'),
  invalidRequest('invalid_request'),
  payloadTooLarge('payload_too_large'),
  upstreamUnavailable('upstream_unavailable'),
  internal('internal'),
  networkError('network_error'),
  timeout('timeout'),
  agentUnavailable('agent_unavailable'),
  unknown('unknown');

  const AgentErrorCode(this.wireName);

  final String wireName;

  static AgentErrorCode fromWire(String? code, {int? statusCode}) {
    for (final value in AgentErrorCode.values) {
      if (value.wireName == code) {
        return value;
      }
    }
    return fromStatusCode(statusCode);
  }

  static AgentErrorCode fromStatusCode(int? statusCode) {
    return switch (statusCode) {
      401 => AgentErrorCode.unauthorized,
      429 => AgentErrorCode.rateLimited,
      400 || 422 => AgentErrorCode.invalidRequest,
      413 => AgentErrorCode.payloadTooLarge,
      502 || 503 || 504 => AgentErrorCode.upstreamUnavailable,
      final int s when s >= 500 => AgentErrorCode.internal,
      _ => AgentErrorCode.unknown,
    };
  }
}

class AgentApiException implements Exception {
  const AgentApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.rawCode,
    this.cause,
  });

  factory AgentApiException.fromErrorEnvelope(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final errorObj = json['error'];
    if (errorObj is Map<String, dynamic>) {
      final rawCode = errorObj['code'] as String?;
      final message =
          errorObj['message'] as String? ??
          'Gateway request failed${statusCode != null ? ' ($statusCode)' : ''}.';
      return AgentApiException(
        code: AgentErrorCode.fromWire(rawCode, statusCode: statusCode),
        message: message,
        statusCode: statusCode,
        rawCode: rawCode,
      );
    }
    return AgentApiException(
      code: AgentErrorCode.fromStatusCode(statusCode),
      message:
          'Gateway request failed${statusCode != null ? ' ($statusCode)' : ''}.',
      statusCode: statusCode,
    );
  }

  factory AgentApiException.unavailable([
    String message = 'Clinical agent is unavailable.',
    Object? cause,
    int? statusCode,
  ]) {
    return AgentUnavailableException(
      message: message,
      cause: cause,
      statusCode: statusCode,
    );
  }

  final AgentErrorCode code;
  final String message;
  final int? statusCode;
  final String? rawCode;
  final Object? cause;

  bool get isFallbackEligible {
    if (code == AgentErrorCode.networkError ||
        code == AgentErrorCode.timeout ||
        code == AgentErrorCode.upstreamUnavailable ||
        code == AgentErrorCode.internal ||
        code == AgentErrorCode.agentUnavailable) {
      return true;
    }
    return statusCode != null && statusCode! >= 500;
  }

  @override
  String toString() {
    final status = statusCode != null ? ' status=$statusCode' : '';
    return 'AgentApiException(code=${code.wireName}$status, message=$message)';
  }
}

class AgentUnavailableException extends AgentApiException {
  const AgentUnavailableException({
    super.message = 'Clinical agent is unavailable.',
    super.statusCode,
    super.cause,
  }) : super(
         code: AgentErrorCode.agentUnavailable,
         rawCode: 'agent_unavailable',
       );
}
