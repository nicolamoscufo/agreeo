import 'dart:ui';
import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/providers/app_controller.dart';
import 'package:agreeo/widgets/empty_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

    if (!mounted) return;

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

    // 1. Stato Vuoto (Queue Completata)
    if (remaining.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E1E),
        body: Center(
          child: EmptyState(
            icon: Icons.celebration_rounded,
            title: 'Queue complete',
            message: 'Come back tomorrow for a fresh set of suggestions.',
          ),
        ),
      );
    }

    final currentMovie = remaining.first;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 2. Sfondo Immagine Full-Screen (Poster o Backdrop)
          if (currentMovie.posterUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: currentMovie.posterUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  Container(color: const Color(0xFF1E1E1E)),
            )
          else
            Container(color: const Color(0xFF1E1E1E)),

          // 3. Gradiente Oscuro inferiore per la leggibilità del testo
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.4, 0.7, 0.9, 1.0],
              ),
            ),
          ),

          // 4. Chip di feedback fluttuante (sostituisce l'header statico precedente)
          if (_completionMessage != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: Center(child: _StatusChip(message: _completionMessage!)),
              ),
            ),

          // 5. Informazioni Film e Bottoni di Azione (Allineati in basso)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titolo del Film
                  Text(
                    currentMovie.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Chips dei Generi (Stile contorno bianco)
                  if (currentMovie.genres.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: currentMovie.genres.take(4).map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 1.0),
                          ),
                          child: Text(
                            genre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),

                  // 6. I 5 Bottoni di Azione
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.undo_rounded, 48, () {
                        // Inserisci qui l'azione Undo in futuro
                      }),
                      _buildActionButton(Icons.close_rounded, 56, () {
                        _handleFeedback(currentMovie, FeedbackAction.dislike);
                      }),
                      _buildActionButton(Icons.remove_red_eye_outlined, 48, () {
                        _handleFeedback(currentMovie, FeedbackAction.seen);
                      }),
                      _buildActionButton(Icons.favorite_rounded, 56, () {
                        _handleFeedback(currentMovie, FeedbackAction.like);
                      }),
                      _buildActionButton(
                        Icons.bookmark_outline_rounded,
                        48,
                        () {
                          _handleFeedback(currentMovie, FeedbackAction.later);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Metodo helper per creare i bottoni circolari bianchi dello screenshot
  Widget _buildActionButton(IconData icon, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: size * 0.5),
      ),
    );
  }
}

// Reskin del messaggio di stato per farlo fluttuare sopra l'immagine in stile Glassmorphism
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
