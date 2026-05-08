import 'dart:convert';

import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MockAuthException implements Exception {
  const MockAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MockAuthService {
  MockAuthService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const String _accountsKey = 'agreeo.mock.accounts.v1';
  final Uuid _uuid;

  Future<AgreeoUserSession> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final accounts = await _readAccounts();
    final normalizedEmail = email.trim().toLowerCase();

    final exists = accounts.any(
      (account) => account.email.toLowerCase() == normalizedEmail,
    );
    if (exists) {
      throw const MockAuthException('That email is already registered.');
    }

    final account = _StoredAccount(
      id: _uuid.v4(),
      displayName: displayName.trim().isEmpty ? 'Agreeo User' : displayName.trim(),
      email: normalizedEmail,
      password: password,
      bio: 'Always looking for the one title everyone says yes to.',
      joinedAt: DateTime.now(),
    );

    accounts.add(account);
    await _writeAccounts(accounts);
    return account.toSession();
  }

  Future<AgreeoUserSession> logIn({
    required String email,
    required String password,
  }) async {
    final accounts = await _readAccounts();
    final normalizedEmail = email.trim().toLowerCase();

    for (final account in accounts) {
      if (account.email.toLowerCase() == normalizedEmail &&
          account.password == password) {
        return account.toSession();
      }
    }

    throw const MockAuthException('Email or password did not match.');
  }

  Future<List<_StoredAccount>> _readAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_accountsKey);
    if (stored == null || stored.isEmpty) {
      final seeded = <_StoredAccount>[
        _StoredAccount(
          id: 'demo-user',
          displayName: 'Nicola Demo',
          email: 'demo@agreeo.app',
          password: 'demo123',
          bio: 'Testing micro-swipes before movie night starts.',
          joinedAt: DateTime(2026, 5, 1),
        ),
      ];
      await _writeAccounts(seeded);
      return seeded;
    }

    final decoded = jsonDecode(stored);
    if (decoded is! List) {
      return <_StoredAccount>[];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => _StoredAccount.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: true);
  }

  Future<void> _writeAccounts(List<_StoredAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }
}

class _StoredAccount {
  const _StoredAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.password,
    required this.bio,
    required this.joinedAt,
  });

  final String id;
  final String displayName;
  final String email;
  final String password;
  final String bio;
  final DateTime joinedAt;

  AgreeoUserSession toSession() {
    return AgreeoUserSession(
      id: id,
      displayName: displayName,
      email: email,
      bio: bio,
      joinedAt: joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'displayName': displayName,
      'email': email,
      'password': password,
      'bio': bio,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory _StoredAccount.fromJson(Map<String, dynamic> json) {
    return _StoredAccount(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Agreeo User',
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
