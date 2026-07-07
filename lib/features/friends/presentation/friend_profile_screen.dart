import 'package:agreeo/features/friends/presentation/movie_night_wizard_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:agreeo/shared/utils/movie_night_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FriendProfileScreen extends ConsumerStatefulWidget {
  const FriendProfileScreen({super.key, required this.friendId});

  final String friendId;

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

enum _FriendTab { watched, reviews, watchlist }

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  _FriendTab _tab = _FriendTab.watched;

  @override
  void initState() {
    super.initState();
    final cached = ref
        .read(friendsMovieNightControllerProvider)
        .profileFor(widget.friendId);
    if (cached == null) {
      _isLoading = true;
      Future<void>.microtask(_loadProfile);
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ref
          .read(friendsMovieNightControllerProvider.notifier)
          .loadFriendProfile(widget.friendId)
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (res == null) {
            _errorMessage = 'Could not load this friend profile.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connection error. Try again.';
        });
      }
    }
  }

  Future<void> _showActions(Friend friend) async {
    final action = await showAgSheet<_FriendAction>(
      context: context,
      child: _FriendActionsSheet(friendName: friend.name),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _FriendAction.report:
        await _reportFriend(friend);
      case _FriendAction.remove:
        await _confirmRemove(friend);
      case _FriendAction.block:
        await _confirmBlock(friend);
    }
  }

  Future<void> _reportFriend(Friend friend) async {
    final reason = await showAgSheet<String>(
      context: context,
      child: _ReportReasonSheet(friendName: friend.name),
    );
    if (!mounted || reason == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(friendsMovieNightControllerProvider.notifier)
        .reportFriend(friend.id, reason: reason);
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Thanks — our team will review this within 24 hours.'
                : 'Could not submit the report. Try again.',
          ),
        ),
      );
    if (!ok) return;
    // Reporting is usually followed by blocking; offer it as a one-tap follow-up.
    final block = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${friend.name} too?'),
        content: const Text(
          'Blocking removes them from your friends and stops them contacting you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.tokens.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (block == true && mounted) {
      ref
          .read(friendsMovieNightControllerProvider.notifier)
          .blockFriend(friend.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRemove(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${friend.name}?'),
        content: const Text(
          'You will no longer see each other\'s profiles or create movie nights together.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(friendsMovieNightControllerProvider.notifier)
        .removeFriend(friend.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmBlock(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${friend.name}?'),
        content: const Text(
          'They will be removed from your friends and will no longer be able to find you or send you requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.tokens.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(friendsMovieNightControllerProvider.notifier)
        .blockFriend(friend.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final social = ref.watch(friendsMovieNightControllerProvider);
    final profile = social.profileFor(widget.friendId);

    if (profile == null) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(backgroundColor: t.bg, leading: const _BackIconButton()),
        body: Center(
          child: _errorMessage != null
              ? AgStateCard(
                  icon: AgIcons.wifiOff,
                  title: 'Loading error',
                  message: _errorMessage!,
                  actionLabel: 'Try again',
                  onAction: _loadProfile,
                )
              : _isLoading
              ? CircularProgressIndicator(color: t.red)
              : Text('Friend not found', style: TextStyle(color: t.sub)),
        ),
      );
    }

    final friend = profile.friend;
    final privacy = friend.privacySettings;
    final sharedNights = social.movieNights
        .where((e) => e.participants.any((p) => p.userId == friend.id))
        .length;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SquareIcon(
                    icon: AgIcons.chevronLeft,
                    label: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _SquareIcon(
                    icon: Icons.more_horiz_rounded,
                    label: 'More options',
                    onTap: () => _showActions(friend),
                  ),
                ],
              ),
            ),
            // Header card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: t.gradSoft,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: t.line2),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AgAvatar(
                          name: friend.name,
                          imageUrl: friend.avatarUrl,
                          size: 68,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.name,
                                style: AgText.h2.copyWith(
                                  letterSpacing: -0.4,
                                  color: t.text,
                                ),
                              ),
                              if (friend.bio.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  friend.bio,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AgText.caption.copyWith(
                                    height: 1.4,
                                    color: t.sub,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 7),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AgIcons.users, size: 13, color: t.faint),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Friends',
                                    style: AgText.labelSm.copyWith(
                                      color: t.faint,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatBox(
                          icon: AgIcons.eye,
                          value: friend.watchedCount,
                          label: 'Watched',
                          color: t.text,
                        ),
                        const SizedBox(width: 9),
                        _StatBox(
                          icon: AgIcons.edit,
                          value: friend.reviewsCount,
                          label: 'Reviews',
                          color: t.gold,
                        ),
                        const SizedBox(width: 9),
                        _StatBox(
                          icon: AgIcons.film,
                          value: sharedNights,
                          label: 'Nights',
                          color: t.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: AgButton(
                label: 'Start a Movie Night',
                icon: AgIcons.film,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MovieNightWizardScreen(
                      preSelectedFriendIds: [friend.id],
                    ),
                  ),
                ),
              ),
            ),
            // Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Row(
                children: [
                  _TabLabel(
                    label: 'Watched',
                    active: _tab == _FriendTab.watched,
                    onTap: () => setState(() => _tab = _FriendTab.watched),
                  ),
                  const SizedBox(width: 24),
                  _TabLabel(
                    label: 'Reviews',
                    active: _tab == _FriendTab.reviews,
                    onTap: () => setState(() => _tab = _FriendTab.reviews),
                  ),
                  const SizedBox(width: 24),
                  _TabLabel(
                    label: 'Watchlist',
                    active: _tab == _FriendTab.watchlist,
                    onTap: () => setState(() => _tab = _FriendTab.watchlist),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: t.line),
            Expanded(child: _buildTabBody(profile, privacy, friend)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(
    FriendProfile profile,
    PrivacySettings privacy,
    Friend friend,
  ) {
    switch (_tab) {
      case _FriendTab.watched:
        return privacy.canShowWatched
            ? _MovieGrid(movies: profile.watchedMovies)
            : _PrivateState(name: friend.name, what: 'watched movies');
      case _FriendTab.reviews:
        return privacy.canShowReviews
            ? _ReviewList(reviews: profile.reviews)
            : _PrivateState(name: friend.name, what: 'reviews');
      case _FriendTab.watchlist:
        return privacy.canShowWatchlist
            ? _MovieGrid(movies: profile.watchlist)
            : _PrivateState(name: friend.name, what: 'watchlist');
    }
  }
}

class _BackIconButton extends StatelessWidget {
  const _BackIconButton();
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(AgIcons.chevronLeft, color: context.tokens.text),
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  const _SquareIcon({
    required this.icon,
    required this.onTap,
    required this.label,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.line),
            ),
            child: Icon(icon, size: 20, color: t.text),
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 5),
            Text('$value', style: AgText.h3.copyWith(color: t.text)),
            Text(
              label,
              style: AgText.micro.copyWith(
                fontWeight: FontWeight.w600,
                color: t.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              label,
              style: AgText.body.copyWith(
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? t.text : t.faint,
              ),
            ),
            if (active)
              Positioned(
                left: 0,
                right: 0,
                bottom: -11,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: t.red,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MovieGrid extends StatelessWidget {
  const _MovieGrid({required this.movies});
  final List<Movie> movies;
  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: AgStateCard(
          icon: AgIcons.film,
          title: 'Nothing here yet',
          message: 'No public movie activity in this section.',
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
      ),
      itemCount: movies.length,
      itemBuilder: (context, i) {
        final m = movies[i];
        return AgPoster(
          imageUrl: m.posterUrl,
          title: m.title,
          radius: 12,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AgreeoMovieDetailsScreen(movieId: m.id),
            ),
          ),
        );
      },
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.reviews});
  final List<FriendMovieReview> reviews;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: AgStateCard(
          icon: AgIcons.edit,
          title: 'No reviews visible',
          message: 'Shared reviews will appear here.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      itemCount: reviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 11),
      itemBuilder: (context, i) {
        final r = reviews[i];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AgreeoMovieDetailsScreen(movieId: r.movie.id),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 50,
                  child: AgPoster(
                    imageUrl: r.movie.posterUrl,
                    title: r.movie.title,
                    radius: 9,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AgText.h4.copyWith(
                          fontSize: 14.5,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          for (var s = 0; s < 5; s++)
                            Icon(
                              s < r.rating ? AgIcons.star : AgIcons.starOutline,
                              size: 12,
                              color: s < r.rating ? t.gold : t.line2,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            movieNightDateLabel(r.date),
                            style: AgText.micro.copyWith(color: t.faint),
                          ),
                        ],
                      ),
                      if (r.reviewPreview.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          '"${r.reviewPreview}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AgText.caption.copyWith(
                            height: 1.45,
                            fontStyle: FontStyle.italic,
                            color: t.sub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _FriendAction { report, remove, block }

class _FriendActionsSheet extends StatelessWidget {
  const _FriendActionsSheet({required this.friendName});
  final String friendName;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          friendName,
          style: AgText.h2.copyWith(letterSpacing: -0.4, color: t.text),
        ),
        const SizedBox(height: 16),
        _ActionRow(
          icon: Icons.flag_outlined,
          title: 'Report $friendName',
          subtitle: 'Flag abuse or inappropriate content',
          color: t.text,
          onTap: () => Navigator.of(context).pop(_FriendAction.report),
        ),
        _ActionRow(
          icon: AgIcons.users,
          title: 'Remove friend',
          subtitle: 'You can send a new request later',
          color: t.text,
          onTap: () => Navigator.of(context).pop(_FriendAction.remove),
        ),
        _ActionRow(
          icon: AgIcons.shield,
          title: 'Block $friendName',
          subtitle: "They won't be able to find you or contact you",
          color: t.red,
          onTap: () => Navigator.of(context).pop(_FriendAction.block),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Reason picker shown after tapping "Report". Returns the chosen reason
/// string (or null if dismissed) so the caller can file it with the backend.
class _ReportReasonSheet extends StatelessWidget {
  const _ReportReasonSheet({required this.friendName});
  final String friendName;

  static const List<String> _reasons = <String>[
    'Spam or scam',
    'Harassment or bullying',
    'Inappropriate or offensive content',
    'Impersonation or fake profile',
    'Something else',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report ${friendName.split(' ').first}',
          style: AgText.h2.copyWith(letterSpacing: -0.4, color: t.text),
        ),
        const SizedBox(height: 4),
        Text(
          "Tell us what's wrong. Reports are confidential.",
          style: AgText.caption.copyWith(color: t.sub),
        ),
        const SizedBox(height: 16),
        for (final reason in _reasons)
          GestureDetector(
            onTap: () => Navigator.of(context).pop(reason),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      reason,
                      style: AgText.label.copyWith(
                        fontSize: 14.5,
                        color: t.text,
                      ),
                    ),
                  ),
                  Icon(AgIcons.chevron, size: 20, color: t.faint),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AgText.label.copyWith(fontSize: 14.5, color: color),
                  ),
                  const SizedBox(height: 1),
                  Text(subtitle, style: AgText.micro.copyWith(color: t.faint)),
                ],
              ),
            ),
            Icon(AgIcons.chevron, size: 20, color: t.faint),
          ],
        ),
      ),
    );
  }
}

class _PrivateState extends StatelessWidget {
  const _PrivateState({required this.name, required this.what});
  final String name;
  final String what;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: AgStateCard(
        icon: AgIcons.bookmark,
        title: 'Private section',
        message:
            "${name.split(' ').first}'s $what is private. Become closer friends to unlock it.",
        iconColor: context.tokens.faint,
      ),
    );
  }
}
