import 'dart:async';

import 'package:agreeo/config/backend_config.dart';
import 'package:agreeo/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Wake-up channel for the Neo4j Live tab. The backend emits `neo4j_live_action`
/// after recording a traced request; the payload is a summary only, so the tab
/// always re-reads the authoritative history from `/debug/neo4j/live`.
class Neo4jLivePush {
  Neo4jLivePush({AuthService? authService, BackendConfig? config})
    : _authService = authService ?? AuthService(),
      _config = config ?? BackendConfig.fromEnv();

  final AuthService _authService;
  final BackendConfig _config;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  io.Socket? _socket;

  Stream<Map<String, dynamic>> get events => _events.stream;

  bool get connected => _socket?.connected == true;

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _authService.readToken();
    if (token == null || token.isEmpty) {
      debugPrint('[Neo4jLivePush] No access token, skipping connection');
      return;
    }
    final socket = io.io(
      _config.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    socket.on('neo4j_live_action', (data) {
      if (data is Map) {
        _events.add(Map<String, dynamic>.from(data));
      } else {
        _events.add(const {});
      }
    });
    socket.onConnectError((error) {
      debugPrint('[Neo4jLivePush] Connection error: $error');
    });
    _socket = socket;
    socket.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _events.close();
  }
}
