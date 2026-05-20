String? movieNightInviteEventIdFromUri(Uri? uri) {
  if (uri == null || uri.scheme.toLowerCase() != 'agreeo') {
    return null;
  }

  if (uri.host.toLowerCase() == 'invite' && uri.pathSegments.isNotEmpty) {
    return _cleanEventId(uri.pathSegments.first);
  }

  if (uri.pathSegments.length >= 2 &&
      uri.pathSegments.first.toLowerCase() == 'invite') {
    return _cleanEventId(uri.pathSegments[1]);
  }

  return null;
}

String? _cleanEventId(String value) {
  final eventId = Uri.decodeComponent(value).trim();
  return eventId.isEmpty ? null : eventId;
}
