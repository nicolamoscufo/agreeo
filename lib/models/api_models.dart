import 'package:agreeo/models/app_models.dart';

class Neo4jUser {
  Neo4jUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.bio = '',
    this.avatarUrl = '',
    this.passwordHash,
    this.onboardingCompleted = false,
  });

  final String uid;
  final String displayName;
  final String email;
  final String createdAt;
  final String bio;
  final String avatarUrl;
  final String? passwordHash;
  final bool onboardingCompleted;

  Map<String, dynamic> toProperties() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'emailNormalized': email.toLowerCase().trim(),
    'createdAt': createdAt,
    'bio': bio,
    'avatarUrl': avatarUrl,
    'onboardingCompleted': onboardingCompleted,
    if (passwordHash != null) 'passwordHash': passwordHash,
  };

  static Neo4jUser fromAppSession(AppSession session) {
    return Neo4jUser(
      uid: session.uid,
      displayName: session.displayName,
      email: session.email,
      createdAt: session.createdAt.toIso8601String(),
      onboardingCompleted: false,
    );
  }
}
