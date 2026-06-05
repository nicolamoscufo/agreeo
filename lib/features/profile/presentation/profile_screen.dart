import 'package:agreeo/features/debug/presentation/recommendation_debug_screen.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoProfileScreen extends ConsumerWidget {
  const AgreeoProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agreeoAppControllerProvider);
    final controller = ref.read(agreeoAppControllerProvider.notifier);
    final socialState = ref.watch(friendsMovieNightControllerProvider);
    final session = state.session;

    if (session == null) {
      return const SizedBox.shrink();
    }

    final activity = _buildRecentActivity(state);
    final movieNightCount = socialState.movieNights.length;
    final friendCount = socialState.friends.length;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final memberSince = _formatMemberSince(session.joinedAt);

    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // ── Profile Header ──
                      _ProfileHeader(
                        session: session,
                        memberSince: memberSince,
                        onEdit: () =>
                            _showEditProfileSheet(context, controller, session),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: cs.outlineVariant.withValues(alpha: 0.3),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    tabs: const <Widget>[
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.dashboard_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Activity'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.settings_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Settings'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: <Widget>[
                // Tab 1: Activity
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    // Stats Grid
                    _StatsGrid(
                      watched: state.watchedCount,
                      liked: state.likedCount,
                      watchlist: state.watchlistCount,
                      reviews: state.reviewCount,
                      friends: friendCount,
                      movieNights: movieNightCount,
                    ),
                    const SizedBox(height: 28),

                    // Favorite genres
                    _SectionTitle(
                      icon: Icons.category_rounded,
                      title: 'Favorite genres',
                      color: AgreeoColors.kernelGold,
                    ),
                    const SizedBox(height: 12),
                    if (state.onboarding.favoriteGenres.isEmpty)
                      _EmptyChip(label: 'No genres selected yet')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: state.onboarding.favoriteGenres
                            .map(
                              (genre) => _GradientChip(label: genre),
                            )
                            .toList(growable: false),
                      ),
                    const SizedBox(height: 28),

                    // Recent Activity
                    _SectionTitle(
                      icon: Icons.history_rounded,
                      title: 'Recent activity',
                      color: AgreeoColors.popcornWhite,
                    ),
                    const SizedBox(height: 12),
                    if (activity.isEmpty)
                      _EmptyChip(label: 'Start swiping to see activity here')
                    else
                      ...activity.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ActivityTile(item: item),
                        ),
                      ),
                  ],
                ),

                // Tab 2: Settings
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    // Privacy Card
                    _SectionTitle(
                      icon: Icons.shield_outlined,
                      title: 'Privacy',
                      color: AgreeoColors.kernelGold,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: <Widget>[
                          _PrivacySwitch(
                            icon: Icons.visibility_outlined,
                            title: 'Show watched to friends',
                            value: state.profilePreferences.showWatchedToFriends,
                            onChanged: (v) => controller.setPrivacyPreference(
                                showWatchedToFriends: v),
                          ),
                          _PrivacySwitch(
                            icon: Icons.favorite_outline_rounded,
                            title: 'Show liked to friends',
                            value: state.profilePreferences.showLikedToFriends,
                            onChanged: (v) => controller.setPrivacyPreference(
                                showLikedToFriends: v),
                          ),
                          _PrivacySwitch(
                            icon: Icons.bookmark_outline_rounded,
                            title: 'Show watchlist to friends',
                            value: state.profilePreferences.showWatchlistToFriends,
                            onChanged: (v) => controller.setPrivacyPreference(
                                showWatchlistToFriends: v),
                          ),
                          _PrivacySwitch(
                            icon: Icons.rate_review_outlined,
                            title: 'Show reviews to friends',
                            value: state.profilePreferences.showReviewsToFriends,
                            onChanged: (v) => controller.setPrivacyPreference(
                                showReviewsToFriends: v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Notifications Card
                    _SectionTitle(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      color: AgreeoColors.kernelGold,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: <Widget>[
                          _PrivacySwitch(
                            icon: Icons.lightbulb_outline_rounded,
                            title: 'Daily suggestion reminder',
                            value:
                                state.profilePreferences.dailySuggestionReminder,
                            onChanged: (v) => controller.setNotificationPreference(
                                dailySuggestionReminder: v),
                          ),
                          _PrivacySwitch(
                            icon: Icons.local_movies_outlined,
                            title: 'Movie Night invites',
                            value: state.profilePreferences.movieNightInvites,
                            onChanged: (v) => controller.setNotificationPreference(
                                movieNightInvites: v),
                          ),
                          _PrivacySwitch(
                            icon: Icons.how_to_vote_outlined,
                            title: 'Voting started',
                            value: state.profilePreferences.votingStarted,
                            onChanged: (v) => controller
                                .setNotificationPreference(votingStarted: v),
                          ),
                          _PrivacySwitch(
                            icon: Icons.emoji_events_outlined,
                            title: 'Final decision reached',
                            value: state.profilePreferences.finalDecisionReached,
                            onChanged: (v) => controller.setNotificationPreference(
                                finalDecisionReached: v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Account Card
                    _SectionTitle(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Account',
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            leading: const Icon(Icons.email_outlined),
                            title: Text(session.email),
                            subtitle: Text('Member since $memberSince'),
                          ),
                          if (kDebugMode)
                            ListTile(
                              leading: const Icon(Icons.bug_report_outlined),
                              title: const Text('Recommendation debug'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const RecommendationDebugScreen(),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: controller.logOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Logout'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AgreeoColors.cinematicRed,
                          side: BorderSide(color: AgreeoColors.cinematicRed),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMemberSince(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  List<_ProfileActivity> _buildRecentActivity(AgreeoAppState state) {
    final entries = state.movieStates.entries.toList(growable: false)
      ..sort(
        (left, right) => right.value.updatedAt.compareTo(left.value.updatedAt),
      );

    return entries
        .take(6)
        .map((entry) {
          final movie = state.movieById(entry.key);
          final title = movie?.title ?? 'Unknown title';
          final userState = entry.value;

          if (userState.hasReview) {
            return _ProfileActivity(
              icon: Icons.rate_review_outlined,
              color: AgreeoColors.kernelGold,
              title: 'Reviewed $title',
              subtitle: userState.review!,
            );
          }
          if (userState.preference == MoviePreference.liked) {
            return _ProfileActivity(
              icon: Icons.favorite_rounded,
              color: AgreeoColors.cinematicRed,
              title: 'Liked $title',
              subtitle: 'Strong positive preference signal.',
            );
          }
          if (userState.inWatchlist) {
            return _ProfileActivity(
              icon: Icons.bookmark_rounded,
              color: AgreeoColors.kernelGold,
              title: 'Saved $title',
              subtitle: 'Added to watchlist.',
            );
          }
          if (userState.watched) {
            return _ProfileActivity(
              icon: Icons.visibility_rounded,
              color: AgreeoColors.popcornWhite,
              title: 'Watched $title',
              subtitle: userState.rating == null
                  ? 'Marked as seen.'
                  : 'Rated ${userState.rating}/5.',
            );
          }
          return _ProfileActivity(
            icon: Icons.hide_source_rounded,
            color: const Color(0xFF6B7280),
            title: 'Hidden $title',
            subtitle: 'Removed from discovery.',
          );
        })
        .toList(growable: false);
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    AgreeoAppController controller,
    AgreeoUserSession session,
  ) async {
    final nameController = TextEditingController(text: session.displayName);
    final bioController = TextEditingController(text: session.bio);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Edit profile',
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                minLines: 3,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Bio / status',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 42),
                    child: Icon(Icons.edit_note_rounded),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await controller.updateProfile(
                      displayName: nameController.text,
                      bio: bioController.text,
                    );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Save profile'),
                ),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    bioController.dispose();
  }
}

// ── Profile Header ──
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.session,
    required this.memberSince,
    required this.onEdit,
  });

  final AgreeoUserSession session;
  final String memberSince;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.12),
            cs.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: <Widget>[
              Stack(
                children: [
                  UserAvatar(initials: session.initials, size: 78),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary,
                          border: Border.all(
                            color: cs.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (session.bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        session.bio,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Joined $memberSince',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stats Grid ──
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.watched,
    required this.liked,
    required this.watchlist,
    required this.reviews,
    required this.friends,
    required this.movieNights,
  });

  final int watched;
  final int liked;
  final int watchlist;
  final int reviews;
  final int friends;
  final int movieNights;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: watched.toString(),
            label: 'Watched',
            icon: Icons.visibility_rounded,
            color: AgreeoColors.popcornWhite,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: liked.toString(),
            label: 'Liked',
            icon: Icons.favorite_rounded,
            color: AgreeoColors.cinematicRed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: watchlist.toString(),
            label: 'Watchlist',
            icon: Icons.bookmark_rounded,
            color: AgreeoColors.kernelGold,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ──
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ── Gradient Chip ──
class _GradientChip extends StatelessWidget {
  const _GradientChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.12),
            cs.secondary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ── Empty Chip ──
class _EmptyChip extends StatelessWidget {
  const _EmptyChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ── Activity Tile ──
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});
  final _ProfileActivity item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: item.color.withValues(alpha: 0.06),
        border: Border.all(color: item.color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withValues(alpha: 0.14),
            ),
            child: Icon(item.icon, size: 18, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Privacy Switch Row ──
class _PrivacySwitch extends StatelessWidget {
  const _PrivacySwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ProfileActivity {
  const _ProfileActivity({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
