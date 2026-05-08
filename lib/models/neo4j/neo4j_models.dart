import 'package:agreeo/models/app_models.dart';

class Neo4jUser {
  Neo4jUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.passwordHash,
  });

  final String uid;
  final String displayName;
  final String email;

  final String createdAt;
  final String? passwordHash;

  Map<String, dynamic> toProperties() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'createdAt': createdAt,
    if (passwordHash != null) 'passwordHash': passwordHash,
  };

  static Neo4jUser fromAppSession(AppSession session) {
    return Neo4jUser(
      uid: session.uid,
      displayName: session.displayName,
      email: session.email,
      createdAt: session.createdAt.toIso8601String(),
    );
  }
}
