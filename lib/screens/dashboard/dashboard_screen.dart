import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/providers/app_controller.dart';
import 'package:agreeo/screens/events/create_event_screen.dart';
import 'package:agreeo/screens/swipe/swipe_screen.dart';
import 'package:agreeo/screens/watchlist/watchlist_screen.dart';
import 'package:agreeo/widgets/consensus_banner.dart';
import 'package:agreeo/widgets/empty_state.dart';
import 'package:agreeo/widgets/gradient_scaffold.dart';
import 'package:agreeo/widgets/movie_card.dart';
import 'package:agreeo/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = state.session;
    final activeEvent = state.activeEvent;
    final activeGroup = state.activeGroup;
    final movieOfTheDay = state.movieOfTheDay;

    return GradientScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Agreeo',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser == null
                          ? 'Build movie nights with less friction.'
                          : 'Hey ${currentUser.displayName}, your group is ready.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  currentUser?.isGuest == true
                      ? Icons.person_outline
                      : Icons.groups_rounded,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // --- START CATALOG SECTION REPLACEMENT ---
          SectionHeader(
            title: 'Explore Movies',
            subtitle: 'Browse through recommended and saved titles from TMDb/Local Catalog.',
          ),
          const SizedBox(height: 12),
          // Dynamic Catalog View Placeholder (TMDb Integration)
          if (state.savedWatchlist.isNotEmpty) ...<Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: state.savedWatchlist
                .take(5) // Show top 5 saved items
                .map((movie) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MovieCard(movie: movie, compact: false),
                ))
                .toList(),
            ),
          ] else if (state.movieOfTheDay != null) ...<Widget>[
             // Display Movie of the Day again here for visibility in catalog section
             Padding(
               padding: const EdgeInsets.only(bottom: 20),
               child: MovieCard(movie: state.movieOfTheDay!, compact: false, onTap: () {}),
             ),
           ] else ...<Widget>[
             const EmptyState(
               icon: Icons.search_rounded,
               title: 'No movies available yet',
               message: 'Use Quick Actions to populate your daily queue or watchlist.',
             ),
           ],
          const SizedBox(height: 22),
          // --- END CATALOG SECTION REPLACEMENT ---


          SectionHeader(
            title: 'Quick actions',
            subtitle: 'Jump into the next decision without hunting for menus.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _ActionTile(
                icon: Icons.swipe_rounded,
                title: 'Daily queue',
                subtitle: 'Swipe through your picks.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SwipeScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.bookmark_add_rounded,
                title: 'Watchlist',
                subtitle: 'Saved for later and group picks.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WatchlistScreen(),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.event_rounded,
                title: 'Create event',
                subtitle: 'Choose a group and generate a shortlist.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateEventScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          SectionHeader(
            title: 'Group status',
            subtitle: activeGroup == null
                ? 'No active group selected yet.'
                : '${activeGroup.name} • ${activeGroup.memberIds.length} members',
          ),
          const SizedBox(height: 12),
          if (activeGroup == null)
            const EmptyState(
              icon: Icons.group_add_rounded,
              title: 'Create or join a group',
              message: 'Add friends with a code, then keep a shared watchlist alive.',
            )
          else
            _GroupSummary(group: activeGroup),
          const SizedBox(height: 22),

          SectionHeader(
            title: 'Active event',
            subtitle: activeEvent == null
                ? 'No event is in progress.'
                : '${activeEvent.groupName} • ${activeEvent.shortlist.length} shortlist picks',
          ),
          const SizedBox(height: 12),
          if (activeEvent == null)
            const EmptyState(
              icon: Icons.how_to_vote_rounded,
              title: 'No active shortlist',
              message: 'Create a movie night and Agreeo will prepare a shortlist.',
            )
          else
            ConsensusBanner(
              title: activeEvent.isResolved
                  ? 'Match found!'
                  : 'Voting in progress',
              message: activeEvent.isResolved
                  ? 'Your group already found a winner.'
                  : 'Keep voting to reach consensus faster.',
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: MediaQuery.of(context).size.width > 640
              ? 180
              : double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: colorScheme.primary),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupSummary extends StatelessWidget {
  const _GroupSummary({required this.group});

  final MovieGroup group;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.65),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            group.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Invite code: ${group.inviteCode}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.sharedWatchlist.isEmpty
                ? <Widget>[
                    Chip(label: Text('${group.memberIds.length} members')),
                  ]
                : group.sharedWatchlist
                      .take(3)
                      .map((movie) => Chip(label: Text(movie.title)))
                      .toList(growable: false),
          ),
        ],
      ),
    );
  }
}