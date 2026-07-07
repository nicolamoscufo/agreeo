import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings › Privacy › Blocked users. Lists the AppUsers this account has
/// blocked (BLOCKED relationships) and lets the user undo a block — until now
/// blocking someone was irreversible from the app.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  List<Friend>? _blocked;
  bool _loading = true;
  String? _error;
  final Set<String> _unblockingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final blocked =
          await ref.read(backendSocialServiceProvider).getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blocked = blocked;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load blocked users.';
      });
    }
  }

  Future<void> _unblock(Friend user) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _unblockingIds.add(user.id));
    try {
      final blocked =
          await ref.read(backendSocialServiceProvider).unblockFriend(user.id);
      if (!mounted) return;
      setState(() {
        _blocked = blocked;
        _unblockingIds.remove(user.id);
      });
      messenger.showSnackBar(SnackBar(content: Text('${user.name} unblocked')));
      // They can show up in search/requests again.
      ref
          .read(friendsMovieNightControllerProvider.notifier)
          .refreshSocialLayer();
    } catch (_) {
      if (!mounted) return;
      setState(() => _unblockingIds.remove(user.id));
      messenger.showSnackBar(
        SnackBar(content: Text('Could not unblock ${user.name}. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.line),
                      ),
                      child: Icon(AgIcons.chevronLeft, size: 20, color: t.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Blocked users',
                    style: AgText.h2.copyWith(
                      letterSpacing: -0.5,
                      color: t.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AgreeoTokens t) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: t.red));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AgStateCard(
          icon: AgIcons.wifiOff,
          title: 'Loading error',
          message: _error!,
          actionLabel: 'Try again',
          onAction: _load,
        ),
      );
    }
    final blocked = _blocked ?? const <Friend>[];
    if (blocked.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AgStateCard(
          icon: AgIcons.shield,
          title: 'No blocked users',
          message: 'People you block from their profile will appear here.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      itemCount: blocked.length,
      itemBuilder: (context, index) {
        final user = blocked[index];
        final unblocking = _unblockingIds.contains(user.id);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.line)),
          ),
          child: Row(
            children: [
              AgAvatar(name: user.name, imageUrl: user.avatarUrl, size: 46),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  user.name,
                  style: AgText.label.copyWith(fontSize: 15, color: t.text),
                ),
              ),
              GestureDetector(
                onTap: unblocking ? null : () => _unblock(user),
                child: Opacity(
                  opacity: unblocking ? 0.5 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: t.red.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      unblocking ? 'Unblocking…' : 'Unblock',
                      style: AgText.label.copyWith(color: t.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
