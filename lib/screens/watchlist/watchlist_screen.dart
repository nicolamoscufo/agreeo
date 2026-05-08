import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/providers/app_controller.dart';
import 'package:agreeo/widgets/empty_state.dart';
import 'package:agreeo/widgets/gradient_scaffold.dart';
import 'package:agreeo/widgets/movie_card.dart';
import 'package:agreeo/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final activeGroup = state.activeGroup;

    return GradientScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          SectionHeader(
            title: 'Watchlist',
            subtitle: 'Saved for later and shared group picks.',
            action: IconButton(
              icon: const Icon(Icons.group_add_rounded),
              onPressed: () => _showGroupSheet(context, ref),
            ),
          ),
          const SizedBox(height: 14),
          if (state.savedWatchlist.isEmpty)
            const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Nothing saved yet',
              message:
                  'Swipe a title to save it for later, then add it to a group list.',
            )
          else
            ...state.savedWatchlist
                .map(
                  (movie) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MovieCard(
                      movie: movie,
                      compact: true,
                      onLater: () => ref
                          .read(appControllerProvider.notifier)
                          .toggleSavedWatchlist(movie, add: false),
                    ),
                  ),
                ),
          const SizedBox(height: 18),
          SectionHeader(
            title: 'Shared groups',
            subtitle: activeGroup == null
                ? 'Create a group and invite friends with a code.'
                : 'Selected group: ${activeGroup.name}',
          ),
          const SizedBox(height: 12),
          if (state.groups.isEmpty)
            const EmptyState(
              icon: Icons.groups_rounded,
              title: 'No groups yet',
              message:
                  'Start a shared watchlist by creating a group from the plus menu.',
            )
          else
            ...state.groups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GroupCard(
                  group: group,
                  active: group.id == activeGroup?.id,
                  onSelect: () => ref
                      .read(appControllerProvider.notifier)
                      .setActiveGroup(group.id),
                  onCopyCode: () async {
                    await Clipboard.setData(
                      ClipboardData(text: group.inviteCode),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied')),
                      );
                    }
                  },
                  onAddSaved: state.savedWatchlist.isEmpty
                      ? null
                      : () => _showAddSavedSheet(context, ref, group),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showGroupSheet(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appControllerProvider.notifier);
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Create a group',
                  prefixIcon: Icon(Icons.group_add_rounded),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await controller.createGroup(nameController.text);
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: const Text('Create group'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Join with invite code',
                  prefixIcon: Icon(Icons.key_rounded),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final joined = await controller.joinGroupByCode(
                    codeController.text,
                  );
                  if (joined != null && sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: const Text('Join group'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddSavedSheet(
    BuildContext context,
    WidgetRef ref,
    MovieGroup group,
  ) async {
    final savedWatchlist = ref.read(appControllerProvider).savedWatchlist;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Text(
                'Add to ${group.name}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...savedWatchlist.map(
                (movie) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(movie.posterUrl),
                  ),
                  title: Text(movie.title),
                  subtitle: Text(movie.typeLabel),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: () async {
                      await ref
                          .read(appControllerProvider.notifier)
                          .addMovieToGroupWatchlist(group.id, movie);
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.active,
    required this.onSelect,
    required this.onCopyCode,
    required this.onAddSaved,
  });

  final MovieGroup group;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onCopyCode;
  final VoidCallback? onAddSaved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active
              ? colorScheme.primaryContainer.withValues(alpha: 0.55)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? colorScheme.primary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onCopyCode,
                  child: const Text('Copy code'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${group.memberIds.length} members • ${group.sharedWatchlist.length} titles',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.sharedWatchlist
                  .take(4)
                  .map((movie) => Chip(label: Text(movie.title)))
                  .toList(growable: false),
            ),
            if (onAddSaved != null) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onAddSaved,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Add saved movie'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
