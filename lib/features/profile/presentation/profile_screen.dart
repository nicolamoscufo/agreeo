import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/features/profile/presentation/edit_genres_sheet.dart';
import 'package:agreeo/features/profile/presentation/edit_profile_sheet.dart';
import 'package:agreeo/features/profile/presentation/settings_screen.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoProfileScreen extends ConsumerWidget {
  const AgreeoProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(agreeoAppControllerProvider);
    final session = state.session;
    final name = session?.displayName ?? 'You';
    final bio = (session?.bio.isNotEmpty ?? false)
        ? session!.bio
        : 'Tap edit to add a bio and tell friends your taste.';
    final genres = state.onboarding.favoriteGenres;
    final activity = _recentActivity(state);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 40),
          children: [
            Row(
              children: [
                if (Navigator.of(context).canPop())
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: t.line),
                      ),
                      child: Icon(AgIcons.chevronLeft, size: 22, color: t.text),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AgreeoSettingsScreen()),
                  ),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: t.line),
                    ),
                    child: Icon(AgIcons.settings, size: 21, color: t.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Identity
            Column(
              children: [
                GestureDetector(
                  onTap: session == null
                      ? null
                      : () => showEditProfileSheet(context, session),
                  child: AgAvatar(
                    name: name,
                    color: t.red,
                    imageUrl: session?.avatarUrl,
                    size: 88,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Bricolage Grotesque',
                    fontWeight: FontWeight.w800,
                    fontSize: 23,
                    letterSpacing: -0.4,
                    color: t.text,
                  ),
                ),
                if (session != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AgIcons.calendar, size: 12, color: t.faint),
                      const SizedBox(width: 5),
                      Text(
                        'Member since ${_memberSince(session.joinedAt)}',
                        style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 11.5, color: t.faint),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, height: 1.5, color: t.sub),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Stats
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  _Stat(value: state.watchedCount, label: 'Watched'),
                  _StatDivider(),
                  _Stat(value: state.likedCount, label: 'Liked'),
                  _StatDivider(),
                  _Stat(value: state.watchlistCount, label: 'Saved'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Favorite genres',
                  style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 15, color: t.text),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => showEditGenresSheet(context),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(AgIcons.edit, size: 14, color: t.red),
                      const SizedBox(width: 5),
                      Text(
                        'Edit',
                        style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12.5, color: t.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            if (genres.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'No genres picked yet — tap Edit to shape your recommendations.',
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, color: t.faint),
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < genres.length; i++) AgChip(label: genres[i], active: i == 0),
                ],
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'Recent activity',
              style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 15, color: t.text),
            ),
            const SizedBox(height: 12),
            if (activity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No activity yet — like, save, and rate movies to fill this up.',
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, color: t.faint),
                ),
              )
            else
              for (final a in activity)
                _ActivityRow(
                  entry: a,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AgreeoMovieDetailsScreen(movieId: a.movieId),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _memberSince(DateTime joinedAt) {
    return '${_months[joinedAt.month - 1]} ${joinedAt.year}';
  }

  List<_Activity> _recentActivity(AgreeoAppState state) {
    final entries = state.movieStates.values.where((s) => !s.isUntouched).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final result = <_Activity>[];
    for (final s in entries.take(6)) {
      final movie = state.movieById(s.movieId);
      if (movie == null) continue;
      result.add(_Activity(movieId: s.movieId, title: movie.title, state: s));
    }
    return result;
  }
}

class _Activity {
  _Activity({required this.movieId, required this.title, required this.state});
  final String movieId;
  final String title;
  final UserMovieState state;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 22, color: t.text),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 11.5, color: t.faint),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: context.tokens.line);
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.onTap});
  final _Activity entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (icon, color, verb) = _describe(t, entry.state);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 14, color: t.sub),
                  children: [
                    TextSpan(text: '$verb '),
                    TextSpan(
                      text: entry.title,
                      style: TextStyle(fontWeight: FontWeight.w700, color: t.text),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _timeAgo(entry.state.updatedAt),
              style: TextStyle(fontFamily: 'Manrope', fontSize: 11.5, color: t.faint),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _describe(AgreeoTokens t, UserMovieState s) {
    if (s.hasReview) return (AgIcons.edit, t.red, 'Reviewed');
    if (s.preference == MoviePreference.liked) return (AgIcons.heartFilled, t.green, 'Liked');
    if (s.watched) return (AgIcons.eye, t.gold, 'Watched');
    if (s.inWatchlist) return (AgIcons.bookmark, t.purple, 'Saved');
    return (AgIcons.dislike, t.faint, 'Hid');
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }
}
