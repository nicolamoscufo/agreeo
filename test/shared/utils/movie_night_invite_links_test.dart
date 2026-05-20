import 'package:agreeo/shared/utils/movie_night_invite_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses agreeo movie-night invite links', () {
    expect(
      movieNightInviteEventIdFromUri(Uri.parse('agreeo://invite/event-123')),
      'event-123',
    );
    expect(
      movieNightInviteEventIdFromUri(Uri.parse('agreeo:/invite/event-456')),
      'event-456',
    );
    expect(
      movieNightInviteEventIdFromUri(Uri.parse('https://agreeo.app/invite/x')),
      isNull,
    );
  });
}
