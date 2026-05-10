import 'package:agreeo/models/neo4j/neo4j_models.dart';
import 'package:agreeo/services/auth_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';

class MockAuthException implements Exception {
  const MockAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MockAuthService {
  MockAuthService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<AgreeoUserSession> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final success = await _authService.register(
      email.trim(),
      password,
      displayName: displayName,
    );

    if (!success) {
      throw MockAuthException(
        _authService.lastErrorMessage ?? 'Unable to create the account.',
      );
    }

    return _loadSessionFromBackend();
  }

  Future<AgreeoUserSession> logIn({
    required String email,
    required String password,
  }) async {
    final accessToken = await _authService.login(email.trim(), password);
    if (accessToken == null || accessToken.isEmpty) {
      throw MockAuthException(
        _authService.lastErrorMessage ?? 'Email or password did not match.',
      );
    }

    return _loadSessionFromBackend();
  }

  Future<void> logOut() async {
    await _authService.logout();
  }

  Future<AgreeoUserSession> _loadSessionFromBackend() async {
    final user = await _authService.getCurrentNeo4jUser();
    if (user == null) {
      throw const MockAuthException(
        'Authenticated, but unable to load profile.',
      );
    }

    return _toSession(user);
  }

  AgreeoUserSession _toSession(Neo4jUser user) {
    return AgreeoUserSession(
      id: user.uid,
      displayName: user.displayName,
      email: user.email,
      bio: 'Always looking for the one title everyone says yes to.',
      joinedAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }
}
