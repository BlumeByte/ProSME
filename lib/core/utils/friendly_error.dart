/// Turns a raw exception into a short message the user can act on.
///
/// Network-layer failures (DNS lookup, socket, timeout) look identical to a
/// user no matter which request triggered them — uploading a photo, sending
/// a 2FA code, whatever — so they all collapse to one plain-language
/// message instead of leaking Dart/package exception class names like
/// "ClientException with SocketException: Failed host lookup: ...".
///
/// Matches on the exception's text rather than its type so this works the
/// same on every platform (importing `dart:io` for `SocketException` would
/// break web builds).
String friendlyErrorMessage(Object error) {
  final text = error.toString();
  const networkMarkers = [
    'SocketException',
    'Failed host lookup',
    'Connection refused',
    'Connection reset',
    'Connection closed',
    'Network is unreachable',
    'HandshakeException',
    'TimeoutException',
    'ClientException',
  ];
  if (networkMarkers.any(text.contains)) {
    return 'No internet connection. Check your network and try again.';
  }
  return text
      .replaceFirst(
        RegExp(r'^(StateError|Exception|Bad state):\s*'),
        '',
      )
      .trim();
}
