import 'dart:io';

bool isPlatformNetworkError(Object error) {
  return error is SocketException ||
      error is HttpException ||
      error is HandshakeException;
}
