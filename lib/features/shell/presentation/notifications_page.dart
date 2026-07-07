import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_waiting_room_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/providers/notifications_provider.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/nav_index_provider.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationsProvider.notifier).refreshNotifications();
      }
    });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  Future<void> _markAllRead() async {
    final notifier = ref.read(notificationsProvider.notifier);
    final unread = ref
        .read(notificationsProvider)
        .notifications
        .where((n) => !n.read)
        .map((n) => n.id)
        .toList();
    for (final id in unread) {
      await notifier.markAsRead(id);
    }
  }

  Future<void> _openNotification(InAppNotification n) async {
    if (!n.read) {
      await ref.read(notificationsProvider.notifier).markAsRead(n.id);
    }
    if (!mounted) return;
    if (n.type == 'friend_request' || n.type == 'friend_accepted') {
      ref.read(navIndexProvider.notifier).state = AgNavTab.friends;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (n.entityId != null && n.entityId!.isNotEmpty) {
      final event = await ref
          .read(friendsMovieNightControllerProvider.notifier)
          .resolveMovieNightInvite(n.entityId!);
      if (event != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _routeForMovieNight(event)),
        );
      }
    }
  }

  Widget _routeForMovieNight(MovieNightEvent event) {
    return switch (event.status) {
      MovieNightStatus.draft ||
      MovieNightStatus.waiting =>
        MovieNightWaitingRoomScreen(eventId: event.id),
      MovieNightStatus.voting => MovieNightVotingScreen(eventId: event.id),
      MovieNightStatus.completed => MovieNightResultScreen(eventId: event.id),
    };
  }

  Future<void> _acceptRequest(InAppNotification n) async {
    final id = n.entityId;
    if (id == null || id.isEmpty) return;
    await ref.read(notificationsProvider.notifier).markAsRead(n.id);
    ref
        .read(friendsMovieNightControllerProvider.notifier)
        .acceptFriendRequest(id);
  }

  Future<void> _declineRequest(InAppNotification n) async {
    final id = n.entityId;
    if (id == null || id.isEmpty) return;
    await ref.read(notificationsProvider.notifier).markAsRead(n.id);
    ref
        .read(friendsMovieNightControllerProvider.notifier)
        .declineFriendRequest(id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(notificationsProvider);
    final notifications = state.notifications;
    final hasUnread = state.unreadCount > 0;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    excludeSemantics: true,
                    child: Tooltip(
                      message: 'Back',
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.line),
                          ),
                          child: Icon(
                            AgIcons.chevronLeft,
                            size: 20,
                            color: t.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Activity',
                    style: AgText.h1.copyWith(
                      letterSpacing: -0.6,
                      color: t.text,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: hasUnread ? _markAllRead : null,
                    child: Text(
                      'Mark all read',
                      style: AgText.label.copyWith(
                        color: hasUnread ? t.red : t.faint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (state.isLoading && notifications.isEmpty)
              Expanded(
                child: Center(child: CircularProgressIndicator(color: t.red)),
              )
            else if (notifications.isEmpty)
              const Expanded(
                child: Center(
                  child: AgStateCard(
                    icon: AgIcons.bell,
                    title: 'No activity yet',
                    message:
                        'Friend requests, invites and results will appear here.',
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  itemCount: notifications.length,
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    return _NotificationTile(
                      notification: n,
                      timeAgo: _timeAgo(n.createdAt),
                      onTap: () => _openNotification(n),
                      onAccept: () => _acceptRequest(n),
                      onDecline: () => _declineRequest(n),
                      onJoin: () => _openNotification(n),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.timeAgo,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
    required this.onJoin,
  });

  final InAppNotification notification;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unread = !notification.read;
    final (icon, color) = _iconFor(t, notification.type);
    final isRequest = notification.type == 'friend_request';
    final isInvite = notification.type == 'movie_night_invite';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: unread ? t.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: unread ? t.line : Colors.transparent),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AgAvatar(name: notification.title, color: color, size: 46),
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.bg, width: 2.5),
                    ),
                    child: Icon(icon, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: AgText.label.copyWith(height: 1.45, color: t.text),
                  ),
                  if (notification.message.isNotEmpty)
                    Text(
                      notification.message,
                      style: AgText.caption.copyWith(height: 1.4, color: t.sub),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    '$timeAgo ago',
                    style: AgText.micro.copyWith(color: t.faint),
                  ),
                  if (isRequest)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          _MiniAction(
                            label: 'Accept',
                            gradient: true,
                            onTap: onAccept,
                          ),
                          const SizedBox(width: 8),
                          _MiniAction(label: 'Decline', onTap: onDecline),
                        ],
                      ),
                    ),
                  if (isInvite)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          _MiniAction(
                            label: 'Join',
                            gradient: true,
                            onTap: onJoin,
                          ),
                          const SizedBox(width: 8),
                          _MiniAction(label: 'Later', onTap: onTap),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 5, left: 6),
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: t.red, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(AgreeoTokens t, String type) {
    switch (type) {
      case 'friend_request':
        return (AgIcons.plus, t.red);
      case 'friend_accepted':
        return (AgIcons.users, t.green);
      case 'movie_night_invite':
        return (AgIcons.film, t.purple);
      case 'movie_night_voting':
        return (AgIcons.vote, t.purple);
      case 'movie_night_completed':
        return (AgIcons.trophy, t.gold);
      case 'review_liked':
        return (AgIcons.heartFilled, t.green);
      default:
        return (AgIcons.sparkle, t.gold);
    }
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.onTap,
    this.gradient = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient ? t.grad : null,
          color: gradient ? null : t.surface2,
          borderRadius: BorderRadius.circular(10),
          border: gradient ? null : Border.all(color: t.line2),
        ),
        child: Text(
          label,
          style: AgText.label.copyWith(color: gradient ? Colors.white : t.sub),
        ),
      ),
    );
  }
}
