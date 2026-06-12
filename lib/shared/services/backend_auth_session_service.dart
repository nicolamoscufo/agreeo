import 'package:agreeo/models/api_models.dart';
import 'package:agreeo/services/auth_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';

class BackendAuthException implements Exception {
  const BackendAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendAuthSessionService {
  BackendAuthSessionService({AuthService? authService})
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
      throw BackendAuthException(
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
      throw BackendAuthException(
        _authService.lastErrorMessage ?? 'Email or password did not match.',
      );
    }

    return _loadSessionFromBackend();
  }

  Future<void> logOut() async {
    await _authService.logout();
  }

  Future<AgreeoUserSession?> restoreSession() async {
    final user = await _authService.getCurrentNeo4jUser();
    if (user == null) return null;

    return _toSession(user);
  }

  Future<bool> isOnboardingCompleted() async {
    return _authService.isOnboardingCompleted();
  }

  Future<void> markOnboardingCompleted({
    List<int> selectedFavoriteTmdbIds = const <int>[],
    List<String> favoriteGenres = const <String>[],
  }) async {
    await _authService.markOnboardingCompleted(
      selectedFavoriteTmdbIds: selectedFavoriteTmdbIds,
      favoriteGenres: favoriteGenres,
    );
  }

  Future<AgreeoUserSession> _loadSessionFromBackend() async {
    final user = await _authService.getCurrentNeo4jUser();
    if (user == null) {
      throw const BackendAuthException(
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
