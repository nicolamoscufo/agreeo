import 'dart:ui' as ui;
import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/utils/movie_night_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MovieNightVotingScreen extends ConsumerStatefulWidget {
  const MovieNightVotingScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<MovieNightVotingScreen> createState() =>
      _MovieNightVotingScreenState();
}

class _MovieNightVotingScreenState extends ConsumerState<MovieNightVotingScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final List<_VoteHistoryEntry> _voteHistory = <_VoteHistoryEntry>[];
  bool _navigatedToResult = false;
  late final AnimationController _swipeController;
  Animation<Offset>? _swipeAnimation;
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );
  final ValueNotifier<double> _dragProgressNotifier = ValueNotifier<double>(
    0.0,
  );
  bool _isSubmittingSwipe = false;
  int _cardVersion = 0;
  int _lastKnownRound = 1;
  bool _showTieBreakerInterstitial = false;

  @override
  void initState() {
    super.initState();
    _swipeController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          final animation = _swipeAnimation;
          if (animation == null || !mounted) {
            return;
          }
          _dragOffsetNotifier.value = animation.value;
          _updateDragProgress(animation.value);
        });
  }

  void _updateDragProgress(Offset offset) {
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    final isHorizontalDominant = offset.dx.abs() >= offset.dy.abs();
    final progress =
        (isHorizontalDominant
                ? (offset.dx.abs() / (size.width * 0.45))
                : (offset.dy.abs() / (size.height * 0.25)))
            .clamp(0.0, 1.0)
            .toDouble();
    _dragProgressNotifier.value = progress;
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _dragOffsetNotifier.dispose();
    _dragProgressNotifier.dispose();
    super.dispose();
  }

  List<ShortlistCandidate> _unvotedCandidates(
    MovieNightEvent event,
    FriendsMovieNightController controller,
  ) {
    return event.shortlist.where((candidate) {
      final vote = controller.currentUserVoteFor(event.id, candidate.movie.id);
      return vote == null;
    }).toList();
  }

  Future<bool> _submitVote(
    MovieNightEvent event,
    ShortlistCandidate candidate,
    MovieNightVoteValue voteValue,
  ) async {
    final controller = ref.read(friendsMovieNightControllerProvider.notifier);

    _voteHistory.add(_VoteHistoryEntry(candidate: candidate, vote: voteValue));

    final updated = await controller.submitVote(
      eventId: event.id,
      movieId: candidate.movie.id,
      vote: voteValue,
    );

    if (!mounted) return false;

    if (updated == null) {
      _voteHistory.removeLast();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit this vote.')),
      );
      _dragOffsetNotifier.value = Offset.zero;
      _dragProgressNotifier.value = 0.0;
      return false;
    }

    if (updated.status != MovieNightStatus.completed) {
      setState(() {
        _currentIndex = 0;
        _dragOffsetNotifier.value = Offset.zero;
        _dragProgressNotifier.value = 0.0;
        _cardVersion++;
      });
    }
    return true;
  }

  Future<void> _undoLastVote(MovieNightEvent event) async {
    if (_voteHistory.isEmpty) return;
    final lastEntry = _voteHistory.removeLast();
    final controller = ref.read(friendsMovieNightControllerProvider.notifier);

    final updated = await controller.deleteVote(
      eventId: event.id,
      movieId: lastEntry.candidate.movie.id,
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() {
        _currentIndex = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Undid vote for "${lastEntry.candidate.movie.title}".'),
        ),
      );
    } else {
      _voteHistory.add(lastEntry);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not undo vote.')));
    }
  }

  Future<void> _animateDragTo(Offset target) async {
    _swipeController.stop();
    _swipeAnimation =
        Tween<Offset>(begin: _dragOffsetNotifier.value, end: target).animate(
          CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
        );
    await _swipeController.forward(from: 0);
  }

  Future<void> _handlePanEnd(
    DragEndDetails details,
    MovieNightEvent event,
    ShortlistCandidate candidate,
  ) async {
    if (_isSubmittingSwipe) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final dragOffset = _dragOffsetNotifier.value;
    final velocityX = details.velocity.pixelsPerSecond.dx;
    final velocityY = details.velocity.pixelsPerSecond.dy;
    final isHorizontalDominant = dragOffset.dx.abs() >= dragOffset.dy.abs();

    if (isHorizontalDominant) {
      // Horizontal swipe → like / dislike
      final shouldVote =
          dragOffset.dx.abs() > size.width * 0.28 || velocityX.abs() > 650;
      if (!shouldVote) {
        await _animateDragTo(Offset.zero);
        return;
      }
      final voteLike = velocityX.abs() > dragOffset.dx.abs()
          ? velocityX > 0
          : dragOffset.dx > 0;
      final vote = voteLike
          ? MovieNightVoteValue.like
          : MovieNightVoteValue.dislike;
      final target = Offset(
        (voteLike ? 1 : -1) * (size.width + 260),
        dragOffset.dy,
      );
      HapticFeedback.mediumImpact();
      setState(() => _isSubmittingSwipe = true);
      await _animateDragTo(target);
      await _submitVote(event, candidate, vote);
      if (mounted) setState(() => _isSubmittingSwipe = false);
    } else {
      // Vertical swipe → already seen (up) / neutral (down)
      final shouldVote =
          dragOffset.dy.abs() > size.height * 0.18 || velocityY.abs() > 650;
      if (!shouldVote) {
        await _animateDragTo(Offset.zero);
        return;
      }
      final swipeUp = velocityY.abs() > dragOffset.dy.abs()
          ? velocityY < 0
          : dragOffset.dy < 0;
      final vote = swipeUp
          ? MovieNightVoteValue.alreadySeen
          : MovieNightVoteValue.neutral;
      final target = Offset(
        dragOffset.dx,
        (swipeUp ? -1 : 1) * (size.height + 260),
      );
      HapticFeedback.mediumImpact();
      setState(() => _isSubmittingSwipe = true);
      await _animateDragTo(target);
      await _submitVote(event, candidate, vote);
      if (mounted) setState(() => _isSubmittingSwipe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialState = ref.watch(friendsMovieNightControllerProvider);
    final controller = ref.read(friendsMovieNightControllerProvider.notifier);
    final event = socialState.eventById(widget.eventId);
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voting')),
        body: const Center(child: Text('Movie Night not found')),
      );
    }

    if (event.status == MovieNightStatus.completed && !_navigatedToResult) {
      _navigatedToResult = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => MovieNightResultScreen(eventId: event.id),
            ),
          );
        }
      });
    }

    final unvoted = _unvotedCandidates(event, controller);
    final votedCount = event.shortlist.length - unvoted.length;
    final totalCandidates = event.shortlist.length;
    final completedVoterIds = movieNightCompletedVoterIds(event).toSet();
    final joinedParticipants = event.joinedParticipants;
    final votedParticipantCount = joinedParticipants
        .where((participant) => completedVoterIds.contains(participant.userId))
        .length;

    if (event.shortlist.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voting')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: EmptyState(
                icon: Icons.movie_filter_rounded,
                title: 'No movies match these preferences',
                message:
                    'Relax one constraint or refresh the shortlist before asking the group to vote.',
                action: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to waiting room'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Detect tie-breaker round change — reset voting state
    if (event.round > _lastKnownRound) {
      _lastKnownRound = event.round;
      _voteHistory.clear();
      _currentIndex = 0;
      _dragOffsetNotifier.value = Offset.zero;
      _dragProgressNotifier.value = 0.0;
      _cardVersion++;
      if (votedCount == 0) {
        _showTieBreakerInterstitial = true;
      }
    } else if (event.round < _lastKnownRound) {
      _lastKnownRound = event.round;
    }

    if (unvoted.isEmpty) {
      return Scaffold(
        backgroundColor: AgreeoColors.deepBlack,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                left: 12,
                child: ClipOval(
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _PulsingIcon(
                        icon: Icons.check_circle_outline_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'All votes in!',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You\'ve voted on all $totalCandidates movies. Waiting for other participants to finish voting.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ParticipantVoteProgressCard(
                        participants: joinedParticipants,
                        votedUserIds: completedVoterIds,
                        votedCount: votedParticipantCount,
                      ),
                      const SizedBox(height: 32),
                      if (_voteHistory.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _undoLastVote(event),
                          icon: const Icon(
                            Icons.undo_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Undo last vote',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentCandidate =
        unvoted[_currentIndex.clamp(0, unvoted.length - 1)];
    final nextCandidate = unvoted.length > 1
        ? unvoted[(_currentIndex + 1).clamp(0, unvoted.length - 1)]
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Tie-breaker round banner
          if (event.round > 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(48, 8, 48, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AgreeoColors.kernelGold, Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AgreeoColors.kernelGold.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.flash_on_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tie-Breaker — Round ${event.round}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Background card (next movie visible behind)
          if (nextCandidate != null && nextCandidate != currentCandidate)
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _dragProgressNotifier,
                child: _VotingImmersiveCard(
                  candidate: nextCandidate,
                  isBackground: true,
                ),
                builder: (context, dragProgress, child) {
                  return Transform.scale(
                    scale: 0.94 + (dragProgress * 0.04),
                    child: child!,
                  );
                },
              ),
            ),

          // Current card (swipeable)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                key: ValueKey<String>(
                  '${currentCandidate.movie.id}-$_cardVersion',
                ),
                onPanUpdate: _isSubmittingSwipe
                    ? null
                    : (details) {
                        final newOffset =
                            _dragOffsetNotifier.value + details.delta;
                        _dragOffsetNotifier.value = newOffset;
                        _updateDragProgress(newOffset);
                      },
                onPanEnd: (details) =>
                    _handlePanEnd(details, event, currentCandidate),
                onPanCancel: () => _animateDragTo(Offset.zero),
                child: ValueListenableBuilder<Offset>(
                  valueListenable: _dragOffsetNotifier,
                  child: _VotingImmersiveCard(
                    candidate: currentCandidate,
                    isBackground: false,
                    progress: '${votedCount + 1}/$totalCandidates',
                    onInfoTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AgreeoMovieDetailsScreen(
                            movieId: currentCandidate.movie.id,
                          ),
                        ),
                      );
                    },
                    actions: _VotingCardActions(
                      canUndo: _voteHistory.isNotEmpty,
                      onUndo: () => _undoLastVote(event),
                      onDislike: () {
                        _submitVote(
                          event,
                          currentCandidate,
                          MovieNightVoteValue.dislike,
                        );
                      },
                      onAlreadySeen: () {
                        _submitVote(
                          event,
                          currentCandidate,
                          MovieNightVoteValue.alreadySeen,
                        );
                      },
                      onLike: () {
                        _submitVote(
                          event,
                          currentCandidate,
                          MovieNightVoteValue.like,
                        );
                      },
                      onNeutral: () {
                        _submitVote(
                          event,
                          currentCandidate,
                          MovieNightVoteValue.neutral,
                        );
                      },
                    ),
                  ),
                  builder: (context, dragOffset, child) {
                    final width = MediaQuery.sizeOf(context).width;
                    final rotation =
                        (dragOffset.dx / width).clamp(-1.0, 1.0).toDouble() *
                        0.18;
                    final hProgress = (dragOffset.dx.abs() / (width * 0.42))
                        .clamp(0.0, 1.0)
                        .toDouble();
                    final vProgress =
                        (dragOffset.dy.abs() /
                                (MediaQuery.sizeOf(context).height * 0.22))
                            .clamp(0.0, 1.0)
                            .toDouble();
                    final isHorizontalDominant =
                        dragOffset.dx.abs() >= dragOffset.dy.abs();
                    final overlayProgress = isHorizontalDominant
                        ? hProgress
                        : vProgress;
                    return Transform.translate(
                      offset: dragOffset,
                      child: Transform.rotate(
                        angle: rotation,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            child!,
                            if (overlayProgress > 0)
                              _SwipeStampOverlay(
                                progress: overlayProgress,
                                dragOffset: dragOffset,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_showTieBreakerInterstitial)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AgreeoColors.kernelGold.withValues(
                                alpha: 0.15,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AgreeoColors.kernelGold.withValues(
                                  alpha: 0.3,
                                ),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: AgreeoColors.kernelGold,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Tie detected!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Some movies have the same score. Vote again to decide the winner.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showTieBreakerInterstitial = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AgreeoColors.kernelGold,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: AgreeoColors.kernelGold.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            child: const Text(
                              'Start tie-breaker',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: ClipOval(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantVoteProgressCard extends StatelessWidget {
  const _ParticipantVoteProgressCard({
    required this.participants,
    required this.votedUserIds,
    required this.votedCount,
  });

  final List<MovieNightParticipant> participants;
  final Set<String> votedUserIds;
  final int votedCount;

  @override
  Widget build(BuildContext context) {
    final total = participants.length;
    final progress = total == 0 ? 0.0 : votedCount / total;
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$votedCount/$total participants voted',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AgreeoColors.kernelGold,
              ),
            ),
            const SizedBox(height: 12),
            ...participants.map((participant) {
              final voted = votedUserIds.contains(participant.userId);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  voted
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_top_rounded,
                  color: voted
                      ? AgreeoColors.kernelGold
                      : AgreeoColors.kernelGold,
                ),
                title: Text(
                  participant.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  voted ? 'Voted' : 'Waiting...',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SwipeStampOverlay extends StatelessWidget {
  const _SwipeStampOverlay({required this.progress, required this.dragOffset});

  final double progress;
  final Offset dragOffset;

  @override
  Widget build(BuildContext context) {
    final isHorizontalDominant = dragOffset.dx.abs() >= dragOffset.dy.abs();

    late final Color color;
    late final Alignment alignment;
    late final double angle;
    late final String label;

    if (isHorizontalDominant) {
      if (dragOffset.dx >= 0) {
        color = AgreeoColors.kernelGold;
        alignment = Alignment.topLeft;
        angle = -0.18;
        label = 'LIKE \u2665';
      } else {
        color = AgreeoColors.cinematicRed;
        alignment = Alignment.topRight;
        angle = 0.18;
        label = 'NOPE \u2715';
      }
    } else {
      if (dragOffset.dy < 0) {
        color = AgreeoColors.popcornWhite;
        alignment = Alignment.bottomCenter;
        angle = 0;
        label = 'SEEN \u{1F441}';
      } else {
        color = AgreeoColors.kernelGold;
        alignment = Alignment.topCenter;
        angle = 0;
        label = 'MAYBE \u223C';
      }
    }

    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(38, 78, 38, 0),
          child: Align(
            alignment: alignment,
            child: Opacity(
              opacity: progress,
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(
                  scale: 0.86 + progress * 0.24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color, width: 4),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoteHistoryEntry {
  const _VoteHistoryEntry({required this.candidate, required this.vote});
  final ShortlistCandidate candidate;
  final MovieNightVoteValue vote;
}

class _VotingImmersiveCard extends StatelessWidget {
  const _VotingImmersiveCard({
    required this.candidate,
    required this.isBackground,
    this.onInfoTap,
    this.actions,
    this.progress,
  });

  final ShortlistCandidate candidate;
  final bool isBackground;
  final VoidCallback? onInfoTap;
  final Widget? actions;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    final movie = candidate.movie;
    final actions = this.actions;
    final actionWidgets = actions == null ? null : <Widget>[actions];
    String imageUrl = movie.posterUrl.isNotEmpty
        ? movie.posterUrl
        : movie.backdropUrl;
    if (imageUrl.isNotEmpty) {
      if (!imageUrl.startsWith('http')) {
        imageUrl = 'https://image.tmdb.org/t/p/w780$imageUrl';
      } else {
        imageUrl = imageUrl.replaceFirst('/w500/', '/w780/');
      }
    }
    final metadata = <String>[
      if (movie.releaseYear > 0) movie.releaseYear.toString(),
      if (movie.genres.isNotEmpty) movie.genres.take(3).join(', '),
    ].join(' • ');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isBackground ? 26 : 16,
        isBackground ? 36 : 18,
        isBackground ? 26 : 16,
        isBackground ? 120 : 18,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 30,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      _buildFallbackPlaceholder(movie),
                )
              else
                _buildFallbackPlaceholder(movie),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x22121212),
                      Color(0x66121212),
                      Color(0xE6121212),
                    ],
                    stops: <double>[0, 0.45, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          if (progress != null && !isBackground)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                progress!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          if (onInfoTap != null && !isBackground)
                            ClipOval(
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.35),
                                child: InkWell(
                                  onTap: onInfoTap,
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                      if (progress != null && !isBackground) ...<Widget>[
                        const SizedBox(height: 8),
                        const _VotingRulesHint(),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (candidate
                                .explanationTags
                                .isNotEmpty) ...<Widget>[
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: candidate.explanationTags
                                    .take(3)
                                    .map(
                                      (tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          tag,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
                              movie.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: -0.6,
                              ),
                            ),
                            if (metadata.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                metadata,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (movie.overview.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 14),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Text(
                                    movie.overview,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            ...?actionWidgets,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackPlaceholder(Movie movie) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AgreeoColors.darkSurface, AgreeoColors.deepBlack],
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.12,
          child: Icon(Icons.movie_rounded, size: 160, color: Colors.white),
        ),
      ),
    );
  }
}

class _VotingRulesHint extends StatelessWidget {
  const _VotingRulesHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Text(
        'Vote every movie: like, maybe, already seen, or dislike. You can undo until the group result is ready.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }
}

class _VotingCardActions extends StatelessWidget {
  const _VotingCardActions({
    required this.canUndo,
    required this.onUndo,
    required this.onDislike,
    required this.onAlreadySeen,
    required this.onLike,
    required this.onNeutral,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onDislike;
  final VoidCallback onAlreadySeen;
  final VoidCallback onLike;
  final VoidCallback onNeutral;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 340;
        final baseSize = isSmall ? 46.0 : 52.0;
        final mainSize = isSmall ? 54.0 : 64.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _VotingActionButton(
              icon: Icons.undo_rounded,
              semanticLabel: 'Undo',
              size: baseSize,
              enabled: canUndo,
              onTap: onUndo,
            ),
            _VotingActionButton(
              icon: Icons.close_rounded,
              semanticLabel: 'Dislike',
              size: mainSize,
              onTap: onDislike,
            ),
            _VotingActionButton(
              icon: Icons.remove_red_eye_outlined,
              semanticLabel: 'Already seen',
              size: baseSize,
              onTap: onAlreadySeen,
            ),
            _VotingActionButton(
              icon: Icons.favorite_rounded,
              semanticLabel: 'Like',
              size: mainSize,
              onTap: onLike,
            ),
            _VotingActionButton(
              icon: Icons.horizontal_rule_rounded,
              semanticLabel: 'Maybe',
              size: baseSize,
              onTap: onNeutral,
            ),
          ],
        );
      },
    );
  }
}

class _VotingActionButton extends StatelessWidget {
  const _VotingActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.size,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String semanticLabel;
  final double size;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: Colors.black, size: size * 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({
    required this.icon,
    required this.size,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + _controller.value * 0.12;
        final opacity = 0.6 + _controller.value * 0.4;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Icon(widget.icon, size: widget.size, color: widget.color),
          ),
        );
      },
    );
  }
}
