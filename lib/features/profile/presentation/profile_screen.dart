import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoProfileScreen extends ConsumerWidget {
  const AgreeoProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agreeoAppControllerProvider);
    final controller = ref.read(agreeoAppControllerProvider.notifier);
    final session = state.session;

    if (session == null) {
      return const SizedBox.shrink();
    }

    final activity = _buildRecentActivity(state);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: <Widget>[
          Row(
            children: <Widget>[
              UserAvatar(initials: session.initials, size: 66),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.bio.isEmpty
                          ? 'Spend less time choosing. More time watching.'
                          : session.bio,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: () => _showEditProfileSheet(context, controller, session),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit profile'),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _StatCard(label: 'Watched', value: state.watchedCount.toString()),
              _StatCard(label: 'Liked', value: state.likedCount.toString()),
              _StatCard(label: 'Watchlist', value: state.watchlistCount.toString()),
              _StatCard(label: 'Reviews', value: state.reviewCount.toString()),
              const _StatCard(label: 'Movie Nights', value: '0'),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Favorite genres',
            subtitle: state.onboarding.favoriteGenres.isEmpty
                ? 'No genres selected yet.'
                : 'Your onboarding picks still shape discovery and the swipe queue.',
          ),
          const SizedBox(height: 14),
          if (state.onboarding.favoriteGenres.isEmpty)
            const EmptyState(
              icon: Icons.category_outlined,
              title: 'No favorite genres yet',
              message: 'Complete onboarding to shape the discovery feed.',
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: state.onboarding.favoriteGenres
                  .map((genre) => Chip(label: Text(genre)))
                  .toList(growable: false),
            ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Recent activity',
            subtitle: 'A quick personal feed built from the local movie state history.',
          ),
          const SizedBox(height: 14),
          if (activity.isEmpty)
            const EmptyState(
              icon: Icons.auto_awesome_motion_outlined,
              title: 'No recent activity yet',
              message: 'Start swiping, saving, or reviewing to populate your profile.',
            )
          else
            Card(
              child: Column(
                children: activity
                    .map(
                      (item) => ListTile(
                        leading: Icon(item.icon),
                        title: Text(item.title),
                        subtitle: Text(item.subtitle),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Settings',
            subtitle: 'Keep privacy and notifications explicit, even in a mock prototype.',
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Edit profile'),
                  subtitle: const Text('Update your name and bio.'),
                  onTap: () => _showEditProfileSheet(context, controller, session),
                ),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Manage favorite genres'),
                  subtitle: const Text('Currently driven by onboarding selections.'),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: state.profilePreferences.showWatchedToFriends,
                  onChanged: (value) => controller.setPrivacyPreference(
                    showWatchedToFriends: value,
                  ),
                  title: const Text('Friends can see watched movies'),
                ),
                SwitchListTile.adaptive(
                  value: state.profilePreferences.showLikedToFriends,
                  onChanged: (value) => controller.setPrivacyPreference(
                    showLikedToFriends: value,
                  ),
                  title: const Text('Friends can see liked movies'),
                ),
                SwitchListTile.adaptive(
                  value: state.profilePreferences.showWatchlistToFriends,
                  onChanged: (value) => controller.setPrivacyPreference(
                    showWatchlistToFriends: value,
                  ),
                  title: const Text('Friends can see watchlist'),
                ),
                SwitchListTile.adaptive(
                  value: state.profilePreferences.showReviewsToFriends,
                  onChanged: (value) => controller.setPrivacyPreference(
                    showReviewsToFriends: value,
                  ),
                  title: const Text('Friends can see reviews'),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: state.profilePreferences.dailySuggestionReminder,
                  onChanged: (value) => controller.setNotificationPreference(
                    dailySuggestionReminder: value,
                  ),
                  title: const Text('Daily suggestion reminder'),
                ),
                SwitchListTile.adaptive(
                  value: state.profilePreferences.movieNightInvites,
                  onChanged: (value) => controller.setNotificationPreference(
                    movieNightInvites: value,
                  ),
                  title: const Text('Movie Night invites'),
                ),
                SwitchListTile.adaptive(
                  value: state.profilePreferences.votingStarted,
                  onChanged: (value) => controller.setNotificationPreference(
                    votingStarted: value,
                  ),
                  title: const Text('Voting started'),
                ),
                SwitchListTile.adaptive(
                  value: state.profilePreferences.finalDecisionReached,
                  onChanged: (value) => controller.setNotificationPreference(
                    finalDecisionReached: value,
                  ),
                  title: const Text('Final decision reached'),
                ),
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Account settings'),
                  subtitle: Text(session.email),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: controller.logOut,
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  List<_ProfileActivity> _buildRecentActivity(AgreeoAppState state) {
    final entries = state.movieStates.entries.toList(growable: false)
      ..sort((left, right) => right.value.updatedAt.compareTo(left.value.updatedAt));

    return entries.take(5).map((entry) {
      final movie = state.movieById(entry.key);
      final title = movie?.title ?? 'Unknown title';
      final userState = entry.value;

      if (userState.hasReview) {
        return _ProfileActivity(
          icon: Icons.rate_review_outlined,
          title: 'Reviewed $title',
          subtitle: userState.review!,
        );
      }
      if (userState.preference == MoviePreference.liked) {
        return _ProfileActivity(
          icon: Icons.thumb_up_alt_outlined,
          title: 'Liked $title',
          subtitle: 'Kept as a strong positive preference signal.',
        );
      }
      if (userState.inWatchlist) {
        return _ProfileActivity(
          icon: Icons.bookmark_outline_rounded,
          title: 'Saved $title',
          subtitle: 'Added to your personal watchlist.',
        );
      }
      if (userState.watched) {
        return _ProfileActivity(
          icon: Icons.visibility_outlined,
          title: 'Watched $title',
          subtitle: userState.rating == null
              ? 'Marked as already seen.'
              : 'Rated ${userState.rating}/5 after watching.',
        );
      }
      return _ProfileActivity(
        icon: Icons.hide_source_outlined,
        title: 'Hidden $title',
        subtitle: 'Removed from future swipe momentum.',
      );
    }).toList(growable: false);
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
                style: Theme.of(sheetContext)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Bio / status'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  await controller.updateProfile(
                    displayName: nameController.text,
                    bio: bioController.text,
                  );
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: const Text('Save profile'),
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActivity {
  const _ProfileActivity({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
