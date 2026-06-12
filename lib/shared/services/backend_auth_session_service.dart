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

  /// Persists profile fields on the backend and returns the updated session.
  /// Only non-null fields are sent.
  Future<AgreeoUserSession> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final user = await _authService.updateProfile(
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    if (user == null) {
      throw BackendAuthException(
        _authService.lastErrorMessage ?? 'Unable to update the profile.',
      );
    }
    return _toSession(user);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final success = await _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    if (!success) {
      throw BackendAuthException(
        _authService.lastErrorMessage ?? 'Unable to change the password.',
      );
    }
  }

  Future<void> deleteAccount({required String password}) async {
    final success = await _authService.deleteAccount(password: password);
    if (!success) {
      throw BackendAuthException(
        _authService.lastErrorMessage ?? 'Unable to delete the account.',
      );
    }
  }

  Future<void> updateFavoriteGenres(List<String> favoriteGenres) async {
    await _authService.markOnboardingCompleted(favoriteGenres: favoriteGenres);
  }

  /// Pushes privacy flags to the backend so friend profiles respect them.
  Future<void> updatePrivacy({
    bool? canShowWatched,
    bool? canShowReviews,
    bool? canShowWatchlist,
  }) async {
    final success = await _authService.updatePrivacy(
      canShowWatched: canShowWatched,
      canShowReviews: canShowReviews,
      canShowWatchlist: canShowWatchlist,
    );
    if (!success) {
      throw BackendAuthException(
        _authService.lastErrorMessage ?? 'Unable to update privacy settings.',
      );
    }
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
      bio: user.bio,
      joinedAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      avatarUrl: user.avatarUrl,
    );
  }
}
