import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/providers/app_controller.dart';
import 'package:agreeo/screens/dashboard/dashboard_screen.dart';
import 'package:agreeo/widgets/empty_state.dart';
import 'package:agreeo/widgets/gradient_scaffold.dart';
import 'package:agreeo/widgets/movie_card.dart';
import 'package:agreeo/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  String? _completionMessage;

  Future<void> _handleFeedback(Movie movie, FeedbackAction action) async {
    await ref
        .read(appControllerProvider.notifier)
        .recordFeedback(movie, action);
    if (!mounted) {
      return;
    }
    setState(() {
      _completionMessage = action == FeedbackAction.like
          ? 'Added to your likes.'
          : action == FeedbackAction.dislike
          ? 'Marked as not for you.'
          : action == FeedbackAction.seen
          ? 'Tagged as already seen.'
          : 'Saved for later.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final session = state.session;
    final remaining = state.remainingQueueForUser(session?.uid);

    return GradientScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          SectionHeader(
            title: 'Daily swipe',
            subtitle: remaining.isEmpty
                ? 'You are done for today.'
                : '${remaining.length} picks left in the queue.',
          ),
          const SizedBox(height: 12),
          if (_completionMessage != null) ...<Widget>[
            _StatusChip(message: _completionMessage!),
            const SizedBox(height: 14),
          ],
          if (remaining.isEmpty)
            const EmptyState(
              icon: Icons.celebration_rounded,
              title: 'Queue complete',
              message: 'Come back tomorrow for a fresh set of suggestions.',
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: MovieCard(
                key: ValueKey<String>(remaining.first.id),
                movie: remaining.first,
                onLike: () =>
                    _handleFeedback(remaining.first, FeedbackAction.like),
                onDislike: () =>
                    _handleFeedback(remaining.first, FeedbackAction.dislike),
                onSeen: () =>
                    _handleFeedback(remaining.first, FeedbackAction.seen),
                onLater: () =>
                    _handleFeedback(remaining.first, FeedbackAction.later),
              ),
            ),
          const SizedBox(height: 18),
          if (state.movieOfTheDay != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_fire_department_rounded),
                title: const Text('Movie of the day'),
                subtitle: Text(state.movieOfTheDay!.title),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const DashboardScreen(),
                      ),
                    );
                  },
                  child: const Text('Back home'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
