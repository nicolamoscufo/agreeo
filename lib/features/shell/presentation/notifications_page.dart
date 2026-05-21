import 'package:flutter/material.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/providers/notifications_provider.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/friends/presentation/movie_night_waiting_room_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/nav_index_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationsProvider.notifier).refreshNotifications().then((_) {
          if (mounted) {
            ref.read(notificationsProvider.notifier).markLessImportantAsRead();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);

    // Group notifications:
    // Friends: friend_request, friend_accepted, friend_declined
    // Movie Nights: movie_night_invite, movie_night_voting, movie_night_completed, movie_night_updated
    final friendNotifications = state.notifications.where((n) {
      return n.type == 'friend_request' ||
          n.type == 'friend_accepted' ||
          n.type == 'friend_declined';
    }).toList();

    final movieNightNotifications = state.notifications.where((n) {
      return n.type == 'movie_night_invite' ||
          n.type == 'movie_night_voting' ||
          n.type == 'movie_night_completed' ||
          n.type == 'movie_night_updated';
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AgreeoColors.trueBlack, AgreeoColors.deepBlack, AgreeoColors.anthraciteBlack],
            ),
          ),
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar(
                    backgroundColor: AgreeoColors.trueBlack,
                    elevation: 0,
                    pinned: true,
                    surfaceTintColor: Colors.transparent,
                    title: const Text(
                      'Notifications',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    bottom: TabBar(
                      indicatorColor: AgreeoColors.cinematicRed,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Friends'),
                              if (friendNotifications.any((n) => !n.read)) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AgreeoColors.cinematicRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Movie Nights'),
                              if (movieNightNotifications.any(
                                (n) => !n.read,
                              )) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AgreeoColors.cinematicRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _NotificationsTabList(
                  notifications: friendNotifications,
                  onTap: (n) => _handleNotificationTap(context, n),
                  emptyMessage: 'No friend activity yet.',
                  formatTimestamp: _formatTimestamp,
                ),
                _NotificationsTabList(
                  notifications: movieNightNotifications,
                  onTap: (n) => _handleNotificationTap(context, n),
                  emptyMessage: 'No movie night invites or updates.',
                  formatTimestamp: _formatTimestamp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    InAppNotification notif,
  ) async {
    // 1. Mark as read
    if (!notif.read) {
      await ref.read(notificationsProvider.notifier).markAsRead(notif.id);
    }

    if (!context.mounted) return;

    // 2. Navigate based on type
    if (notif.type == 'friend_request' || notif.type == 'friend_accepted') {
      // Go to Friends screen (tab index 3 in shell)
      ref.read(navIndexProvider.notifier).state = 3;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (notif.type == 'movie_night_invite' ||
        notif.type == 'movie_night_voting' ||
        notif.type == 'movie_night_completed' ||
        notif.type == 'movie_night_updated') {
      final eventId = notif.entityId;
      if (eventId != null && eventId.isNotEmpty) {
        // Resolve event first to check current status
        final event = await ref
            .read(friendsMovieNightControllerProvider.notifier)
            .resolveMovieNightInvite(eventId);
        if (event != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => _routeForMovieNight(event)),
          );
        }
      }
    }
  }

  Widget _routeForMovieNight(MovieNightEvent event) {
    return switch (event.status) {
      MovieNightStatus.draft || MovieNightStatus.waiting =>
        MovieNightWaitingRoomScreen(eventId: event.id),
      MovieNightStatus.voting => MovieNightVotingScreen(eventId: event.id),
      MovieNightStatus.completed => MovieNightResultScreen(eventId: event.id),
    };
  }
}

class _NotificationsTabList extends StatelessWidget {
  const _NotificationsTabList({
    required this.notifications,
    required this.onTap,
    required this.emptyMessage,
    required this.formatTimestamp,
  });

  final List<InAppNotification> notifications;
  final ValueChanged<InAppNotification> onTap;
  final String emptyMessage;
  final String Function(DateTime) formatTimestamp;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final notif = notifications[index];
                final isUnread = !notif.read;

                IconData iconData = Icons.notifications;
                Color iconColor = AgreeoColors.cinematicRed;

                switch (notif.type) {
                  case 'friend_request':
                    iconData = Icons.person_add_outlined;
                    iconColor = AgreeoColors.cinematicRed;
                    break;
                  case 'friend_accepted':
                    iconData = Icons.people_outline;
                    iconColor = AgreeoColors.kernelGold;
                    break;
                  case 'movie_night_invite':
                    iconData = Icons.local_movies_outlined;
                    iconColor = AgreeoColors.kernelGold;
                    break;
                  case 'movie_night_voting':
                    iconData = Icons.how_to_vote_outlined;
                    iconColor = AgreeoColors.cinematicRed;
                    break;
                  case 'movie_night_completed':
                    iconData = Icons.emoji_events_outlined;
                    iconColor = AgreeoColors.kernelGold;
                    break;
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUnread
                        ? AgreeoColors.darkSurface.withValues(alpha: 0.4)
                        : AgreeoColors.darkSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUnread
                          ? AgreeoColors.cinematicRed.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => onTap(notif),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: iconColor, size: 24),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AgreeoColors.cinematicRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif.message,
                            style: TextStyle(
                              color: isUnread ? Colors.grey[200] : Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatTimestamp(notif.createdAt),
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: notifications.length,
            ),
          ),
        ),
      ],
    );
  }
}
