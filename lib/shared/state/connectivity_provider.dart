import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Presentation-layer device-connectivity signal that the Offline screen maps to.
///
/// This is NOT a backend service — it answers "does the device have a working
/// internet connection?" (a lightweight reachability probe), independent of
/// whether the Agreeo backend itself is up. That distinction matters because the
/// app ships local fallbacks/demo data, so the full Offline takeover should only
/// appear when the device is genuinely offline — not when the dev backend is down.
///
/// (Added during the Daylight migration to map the prototype's Connection-error
/// screen, which the backend contract flagged as having no trigger — gap §4.4.)
class ConnectivityController extends StateNotifier<bool> {
  ConnectivityController() : super(true) {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _check());
  }

  Timer? _timer;
  bool _inFlight = false;

  /// A tiny, fast, always-on "no content" endpoint used as a captive-portal /
  /// reachability probe. Any non-throwing response means the device is online.
  static final Uri _probe = Uri.parse('https://www.gstatic.com/generate_204');

  Future<void> _check() async {
    if (kIsWeb) {
      // Cross-origin probes are unreliable on web; assume online there.
      state = true;
      return;
    }
    if (_inFlight) return;
    _inFlight = true;
    try {
      final response = await http.get(_probe).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      state = response.statusCode < 500;
    } catch (_) {
      if (!mounted) return;
      state = false;
    } finally {
      _inFlight = false;
    }
  }

  /// Re-probe now (e.g. the Offline screen's "Try again"); returns the result.
  Future<bool> retry() async {
    await _check();
    return state;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// `true` when the device appears to be online.
final connectivityProvider = StateNotifierProvider<ConnectivityController, bool>(
  (ref) => ConnectivityController(),
);
