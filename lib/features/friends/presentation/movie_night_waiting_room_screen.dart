import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/services/real_time_service.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MovieNightWaitingRoomScreen extends ConsumerStatefulWidget {
  const MovieNightWaitingRoomScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<MovieNightWaitingRoomScreen> createState() => _MovieNightWaitingRoomScreenState();
}

class _MovieNightWaitingRoomScreenState extends ConsumerState<MovieNightWaitingRoomScreen> {
  bool _navigated = false;
  bool _starting = false;

  MovieNightParticipant? _participantFor(MovieNightEvent event, String userId) {
    for (final p in event.participants) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  Future<void> _startVoting(MovieNightEvent event) async {
    setState(() => _starting = true);
    final messenger = ScaffoldMessenger.of(context);
    final updated = await ref.read(friendsMovieNightControllerProvider.notifier).startVoting(event.id);
    if (!mounted) return;
    setState(() => _starting = false);
    if (updated == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not start voting.')));
    }
  }

  Future<void> _join(MovieNightEvent event) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await ref.read(friendsMovieNightControllerProvider.notifier).joinMovieNight(event.id);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(updated == null ? 'Could not join.' : 'You joined this Movie Night.')));
  }

  Future<void> _leave(MovieNightEvent event) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final left = await ref.read(friendsMovieNightControllerProvider.notifier).leaveMovieNight(event.id);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(left ? 'You left this Movie Night.' : 'Could not leave.')));
    if (left) navigator.pop();
  }

  Future<void> _shareLink(MovieNightEvent event) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await ref.read(friendsMovieNightControllerProvider.notifier).createInviteLink(event.id);
    final link = updated?.inviteLink ?? event.inviteLink;
    if (!mounted) return;
    if (link.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Invite link copied to clipboard!')));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Could not create invite link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final social = ref.watch(friendsMovieNightControllerProvider);
    final appState = ref.watch(agreeoAppControllerProvider);
    final isLive = ref.watch(realTimeConnectionProvider);
    final event = social.eventById(widget.eventId);

    if (event == null) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(child: Text('Movie Night not found', style: TextStyle(color: t.sub))),
      );
    }

    // Auto-navigate on status changes.
    if (!_navigated && (event.status == MovieNightStatus.voting || event.status == MovieNightStatus.completed)) {
      _navigated = true;
      final next = event.status == MovieNightStatus.voting
          ? MovieNightVotingScreen(eventId: event.id)
          : MovieNightResultScreen(eventId: event.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => next));
        }
      });
    }

    final currentUserId = appState.session?.id ?? 'local-host';
    final me = _participantFor(event, currentUserId);
    final isHost = me?.isHost == true || event.hostUserId == currentUserId;
    final canJoin = event.status == MovieNightStatus.waiting && me?.status == MovieNightParticipantStatus.pending;
    final joinedCount = event.participants.where((p) => p.status == MovieNightParticipantStatus.joined).length;
    final inviteCode = event.inviteLink.isNotEmpty
        ? event.inviteLink.split('/').last.toUpperCase()
        : event.id.substring(0, event.id.length.clamp(0, 6)).toUpperCase();

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _NightStepHeader(
              step: 1,
              title: 'Waiting room',
              trailing: _LiveBadge(isLive: isLive),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(friendsMovieNightControllerProvider.notifier).refreshMovieNight(event.id).then((_) {}),
                color: t.red,
                backgroundColor: t.surface,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // Event card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(gradient: t.gradSoft, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.line2)),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(gradient: t.grad, borderRadius: BorderRadius.circular(14)),
                            child: const Icon(AgIcons.film, size: 24, color: Colors.white),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event.name, style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 16, color: t.text)),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(fontFamily: 'Manrope', fontSize: 12.5, color: t.sub),
                                    children: [
                                      const TextSpan(text: 'Invite code '),
                                      TextSpan(text: inviteCode, style: TextStyle(color: t.text, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$joinedCount of ${event.participants.length} joined',
                      style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.3, color: t.faint),
                    ),
                    const SizedBox(height: 12),
                    for (final p in event.participants)
                      _ParticipantRow(participant: p, isMe: p.userId == currentUserId),
                  ],
                ),
              ),
            ),
            // Bottom actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  if (isHost) ...[
                    Row(
                      children: [
                        Expanded(
                          child: AgButton.secondary(label: 'Share link', icon: AgIcons.share, height: 50, onPressed: () => _shareLink(event)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AgButton(
                            label: _starting ? 'Starting…' : 'Start voting now',
                            icon: AgIcons.play,
                            height: 50,
                            onPressed: _starting ? null : () => _startVoting(event),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("You can start before everyone's in", style: TextStyle(fontFamily: 'Manrope', fontSize: 12.5, color: t.faint)),
                  ] else if (canJoin)
                    AgButton(label: 'Join this Movie Night', icon: AgIcons.check, onPressed: () => _join(event))
                  else
                    AgButton.secondary(label: 'Leave event', icon: AgIcons.logout, onPressed: () => _leave(event)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isLive});
  final bool isLive;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = isLive ? t.green : t.faint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(isLive ? 'Live' : 'Offline', style: TextStyle(fontFamily: 'Manrope', color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant, required this.isMe});
  final MovieNightParticipant participant;
  final bool isMe;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final joined = participant.status == MovieNightParticipantStatus.joined;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
      child: Row(
        children: [
          AgAvatar(name: participant.name, imageUrl: participant.avatarUrl, size: 46),
          const SizedBox(width: 13),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    isMe ? 'You' : participant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 15, color: t.text),
                  ),
                ),
                if (participant.isHost) ...[
                  const SizedBox(width: 6),
                  Text('· Host', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 11, color: t.gold)),
                ],
              ],
            ),
          ),
          if (joined)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: t.green.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AgIcons.check, size: 14, color: t.green),
                  const SizedBox(width: 5),
                  Text('Ready', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12, color: t.green)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.line)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: t.gold, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Text('Joining…', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 12, color: t.faint)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared movie-night step header (back + 4 progress dots + eyebrow + title).
class _NightStepHeader extends StatelessWidget {
  const _NightStepHeader({required this.step, required this.title, this.trailing});
  final int step;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                  child: Icon(AgIcons.chevronLeft, size: 20, color: t.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: i <= step ? t.grad : null,
                            color: i <= step ? null : t.surface,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      if (i < 3) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MOVIE NIGHT · STEP ${step + 1}', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.4, color: t.red)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 25, letterSpacing: -0.6, color: t.text)),
            ],
          ),
        ),
      ],
    );
  }
}
