import 'package:agreeo/services/real_time_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/state/connectivity_provider.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connection-error / Offline takeover. Reference: `ag-states.jsx` OfflineScreen.
/// Driven by [connectivityProvider]; "Try again" re-probes connectivity and, if
/// back online + authenticated, reconnects the realtime socket.
class OfflineScreen extends ConsumerStatefulWidget {
  const OfflineScreen({super.key});

  @override
  ConsumerState<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends ConsumerState<OfflineScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    final online = await ref.read(connectivityProvider.notifier).retry();
    if (online) {
      final session = ref.read(agreeoAppControllerProvider).session;
      if (session != null) {
        ref.read(realTimeServiceProvider).connect(session.id);
      }
    }
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AgStateCard(
                icon: AgIcons.wifiOff,
                title: "You're offline",
                message:
                    "We can't reach Agreeo right now. Your library is saved on this device — reconnect to sync your watchlist and Movie Nights.",
                actionLabel: _retrying ? 'Reconnecting…' : 'Try again',
                onAction: _retrying ? null : _retry,
              ),
              const SizedBox(height: 18),
              Text(
                'Saved on this device',
                style: AgText.micro.copyWith(color: t.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
