import 'dart:async';

import 'package:http/http.dart' as http;

import '../domain/agent_exception.dart';
import 'network_error_stub.dart'
    if (dart.library.io) 'network_error_io.dart'
    as platform;

bool isNetworkTransportError(Object error) {
  return error is http.ClientException ||
      platform.isPlatformNetworkError(error);
}

bool isFallbackEligibleError(Object error) {
  if (error is AgentApiException) {
    return error.isFallbackEligible;
  }
  if (error is TimeoutException) {
    return true;
  }
  return isNetworkTransportError(error);
}
