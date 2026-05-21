import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecommendationDebugScreen extends ConsumerStatefulWidget {
  const RecommendationDebugScreen({super.key});

  @override
  ConsumerState<RecommendationDebugScreen> createState() =>
      _RecommendationDebugScreenState();
}

class _RecommendationDebugScreenState
    extends ConsumerState<RecommendationDebugScreen> {
  late Future<Map<String, dynamic>> _debugFuture;

  @override
  void initState() {
    super.initState();
    _debugFuture = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return ref.read(movieServiceProvider).getRecommendationDebugStats();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _debugFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recommendation Debug'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Come Funziona', icon: Icon(Icons.psychology_rounded)),
              Tab(text: 'Analisi Punteggi', icon: Icon(Icons.calculate_rounded)),
              Tab(text: 'Diagnostica', icon: Icon(Icons.insights_rounded)),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _debugFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.bug_report_outlined,
                    title: 'Dati di debug non disponibili',
                    message: snapshot.error.toString(),
                    action: FilledButton(
                      onPressed: () {
                        setState(() {
                          _debugFuture = _load();
                        });
                      },
                      child: const Text('Riprova'),
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data ?? <String, dynamic>{};
            if (data.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.analytics_outlined,
                    title: 'Nessun dato di debug',
                    message:
                        'Il backend non ha restituito dati diagnostici. Completa l\'onboarding o effettua qualche swipe prima di riprovare.',
                    action: FilledButton(
                      onPressed: () {
                        setState(() {
                          _debugFuture = _load();
                        });
                      },
                      child: const Text('Riprova'),
                    ),
                  ),
                ),
              );
            }

            final userSignals = _map(data['userProfileSignals']);
            final recommendationSignals = _map(data['recommendationSignals']);
            final forYouFeedStats = _map(data['forYouFeedStats']);
            final candidatePoolStats = _map(data['candidatePoolStats']);
            final scoringStats = _map(data['scoringStats']);
            final dailyStats = _map(data['dailySuggestionsStats']);
            final fallbackStats = _map(data['fallbackStats']);

            return TabBarView(
              children: [
                _buildAlgorithmTab(context),
                _buildScoresTab(context, scoringStats),
                _buildDiagnosticsTab(
                  context,
                  userSignals,
                  recommendationSignals,
                  candidatePoolStats,
                  forYouFeedStats,
                  dailyStats,
                  fallbackStats,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: ALGORITHM EXPLAINER (COME FUNZIONA)
  // ---------------------------------------------------------------------------
  Widget _buildAlgorithmTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Card(
            color: AgreeoColors.darkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded,
                          color: AgreeoColors.kernelGold, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Il Motore di Raccomandazione',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agreeo utilizza un modello di raccomandazione ibrido basato su Neo4j '
                    'e il dataset MovieLens per proporti film affini ai tuoi gusti '
                    'senza rinunciare alla scoperta di nuovi generi.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildAlgoStepCard(
            context,
            stepNumber: '1',
            icon: Icons.filter_alt_rounded,
            iconColor: AgreeoColors.cinematicRed,
            title: 'Fase 1: Filtri Rigidi (Esclusione)',
            description:
                'Prima di iniziare a calcolare i punteggi, escludiamo dal catalogo '
                'tutto ciò che renderebbe la raccomandazione ridondante o sgradita:\n\n'
                '• 🚫 **Già Swippati**: Film a cui hai già dato Like, Dislike o salvato nella Watchlist.\n'
                '• 👁️ **Già Visti**: Film contrassegnati come già visti.\n'
                '• 🖼️ **Metadati Mancanti**: Film che non contengono un poster o un\'immagine di copertina.',
          ),
          const SizedBox(height: 16),
          _buildAlgoStepCard(
            context,
            stepNumber: '2',
            icon: Icons.calculate_rounded,
            iconColor: Colors.blueAccent,
            title: 'Fase 2: Assegnazione dei Punteggi',
            description:
                'I candidati rimanenti vengono valutati attraverso due logiche a seconda della sorgente:\n\n'
                '💡 **A. Punteggio Personalizzato (Collaborativo)**\n'
                'Trova nel grafo altri utenti con gusti sovrapponibili ai tuoi. Più film avete in comune, più la loro valutazione positiva influenza il film consigliato. I tuoi segnali hanno pesi diversi:\n'
                '   - Preferiti selezionati: **+4.0**\n'
                '   - Film piaciuti (Like): **+3.0**\n'
                '   - Film in Watchlist: **+1.25**\n'
                '   - *Penalità Generi*: **-1.5** per ciascun genere in cui hai accumulato 2 o più Dislike.\n\n'
                '🚀 **B. Punteggio Esplorativo**\n'
                'Cerca film popolari al di fuori della tua cerchia solita per testare nuove direzioni:\n'
                '   - Corrispondenza generi familiari: **+15.0** per genere.\n'
                '   - Popolarità globale: **10.0 * Media + log(Voti)**.\n'
                '   - Generi non esplorati (Novità): **+40.0**.\n'
                '   - Generi sgraditi: **-25.0**.',
          ),
          const SizedBox(height: 16),
          _buildAlgoStepCard(
            context,
            stepNumber: '3',
            icon: Icons.shuffle_rounded,
            iconColor: Colors.purpleAccent,
            title: 'Fase 3: Mix e Blending Giornaliero',
            description:
                'La tua coda di swipe quotidiana non viene riempita di soli consigli personali '
                'per evitare la "bolla dei filtri". Il backend unisce i risultati in questo rapporto:\n\n'
                '• 🔀 **65% Raccomandazioni Personali**: Film ad altissima compatibilità calcolata.\n'
                '• 🔀 **35% Raccomandazioni Esplorative**: Spunti freschi per affinare i tuoi interessi.',
          ),
        ],
      ),
    );
  }

  Widget _buildAlgoStepCard(
    BuildContext context, {
    required String stepNumber,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stepNumber,
                    style: TextStyle(
                        color: iconColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: DETTAGLIO PUNTEGGI CANDIDATI (ANALISI PUNTEGGI)
  // ---------------------------------------------------------------------------
  Widget _buildScoresTab(
      BuildContext context, Map<String, dynamic> scoringStats) {
    final recommendations = _listOfMaps(scoringStats['sampleRecommendations']);
    if (recommendations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: EmptyState(
                icon: Icons.movie_filter_rounded,
                title: 'Nessun film classificato',
                message:
                    'Al momento non ci sono candidati classificati nel pool. Effettua qualche swipe o aggiorna.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final entry = recommendations[index];
          final finalScore = entry['finalScore'] ?? 0;
          final title = entry['title'] ?? 'Titolo sconosciuto';
          final reason = entry['reason'] ?? '';

          final collaborativeScore = entry['collaborativeScore'] ?? 0.0;
          final genreScore = entry['genreScore'] ?? 0.0;
          final popularityScore = entry['popularityScore'] ?? 0.0;
          final explorationBonus = entry['explorationBonus'] ?? 0.0;
          final negativePenalty = entry['negativePenalty'] ?? 0.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor:
                    AgreeoColors.cinematicRed.withValues(alpha: 0.15),
                foregroundColor: AgreeoColors.cinematicRed,
                child: Text('${index + 1}'),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                reason,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AgreeoColors.goldTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AgreeoColors.kernelGold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  finalScore is double
                      ? finalScore.toStringAsFixed(1)
                      : finalScore.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AgreeoColors.kernelGold,
                  ),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 16),
                      const Text(
                        'COMPOSIZIONE DEL PUNTEGGIO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildScoreDetailRow(
                        context,
                        label: 'Punteggio Collaborativo (Neo4j)',
                        value: collaborativeScore,
                        icon: Icons.people_outline_rounded,
                        isPositive: true,
                      ),
                      _buildScoreDetailRow(
                        context,
                        label: 'Corrispondenza Generi (Onboarding/Likes)',
                        value: genreScore,
                        icon: Icons.category_outlined,
                        isPositive: true,
                      ),
                      _buildScoreDetailRow(
                        context,
                        label: 'Popolarità & Voti (MovieLens)',
                        value: popularityScore,
                        icon: Icons.star_outline_rounded,
                        isPositive: true,
                      ),
                      _buildScoreDetailRow(
                        context,
                        label: 'Bonus Esplorazione (Nuovi Generi)',
                        value: explorationBonus,
                        icon: Icons.explore_outlined,
                        isPositive: true,
                      ),
                      _buildScoreDetailRow(
                        context,
                        label: 'Penalità Generi Sgraditi (Disliked)',
                        value: negativePenalty,
                        icon: Icons.warning_amber_rounded,
                        isPositive: false,
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Punteggio Finale Calcolato',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            finalScore is double
                                ? finalScore.toStringAsFixed(2)
                                : finalScore.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AgreeoColors.kernelGold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreDetailRow(
    BuildContext context, {
    required String label,
    required dynamic value,
    required IconData icon,
    required bool isPositive,
  }) {
    final double numValue = value is num ? value.toDouble() : 0.0;
    if (numValue == 0.0) return const SizedBox.shrink();

    final isActuallyPositive = isPositive ? numValue >= 0 : numValue <= 0;
    final color = isActuallyPositive
        ? Colors.greenAccent.shade700
        : AgreeoColors.cinematicRed;
    final prefix = numValue > 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '$prefix${numValue.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: DIAGNOSTICA & PROFILO
  // ---------------------------------------------------------------------------
  Widget _buildDiagnosticsTab(
    BuildContext context,
    Map<String, dynamic> userSignals,
    Map<String, dynamic> recommendationSignals,
    Map<String, dynamic> candidatePoolStats,
    Map<String, dynamic> forYouFeedStats,
    Map<String, dynamic> dailyStats,
    Map<String, dynamic> fallbackStats,
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildFunnel(context, candidatePoolStats),
          const SizedBox(height: 16),
          _DebugCard(
            title: 'Segnali del Profilo Utente',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyValueRow(
                  label: 'ID Utente',
                  value: '${userSignals['uid'] ?? '-'}',
                ),
                _KeyValueRow(
                  label: 'Totale Azioni di Feedback',
                  value: '${userSignals['totalFeedbackActions'] ?? 0}',
                  tooltip: 'Il numero totale di interazioni (Like, Dislike, ecc.) che alimentano l\'algoritmo su Neo4j.',
                ),
                const SizedBox(height: 8),
                _TokenWrap(
                  label: 'Generi Preferiti (Onboarding)',
                  entries: _listOfStrings(userSignals['onboardingGenres']),
                ),
                const Divider(height: 24),
                const Text(
                  'CONTEGGI INTERAZIONI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                _KeyValueRow(
                  label: 'Film Preferiti',
                  value: '${userSignals['favoriteMoviesCount'] ?? 0}',
                  tooltip: 'Film scelti nell\'onboarding. Hanno un peso enorme di +4.0 per trovare film simili nel grafo.',
                ),
                _KeyValueRow(
                  label: 'Film Piaciuti (Like)',
                  value: '${userSignals['likedMoviesCount'] ?? 0}',
                  tooltip: 'Film a cui hai messo Like. Aggiungono un peso positivo di +3.0 nel calcolo collaborativo.',
                ),
                _KeyValueRow(
                  label: 'Film Sgraditi (Dislike)',
                  value: '${userSignals['dislikedMoviesCount'] ?? 0}',
                  tooltip: 'Film rifiutati. Se accumuli 2+ dislike in un genere, questo subirà una forte penalizzazione.',
                ),
                _KeyValueRow(
                  label: 'Film Già Visti',
                  value: '${userSignals['alreadySeenCount'] ?? 0}',
                  tooltip: 'Film che hai già visto. Vengono completamente rimossi dai candidati per evitare ripetizioni.',
                ),
                _KeyValueRow(
                  label: 'Salvati in Watchlist',
                  value: '${userSignals['watchlistCount'] ?? 0}',
                  tooltip: 'Film salvati in libreria. Hanno un impatto positivo di +1.25 sulle raccomandazioni.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DebugCard(
            title: 'Interessi dei Generi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TokenWrap(
                  label: 'Generi Positivi Principali (e punteggio)',
                  entries: _listOfMaps(recommendationSignals['topPositiveGenres'])
                      .map((entry) => '${entry['name']} (${entry['score']})')
                      .toList(),
                ),
                const SizedBox(height: 16),
                _TokenWrap(
                  label: 'Generi Negativi Principali (e dislike)',
                  entries: _listOfMaps(recommendationSignals['topNegativeGenres'])
                      .map((entry) => '${entry['name']} (${entry['score']})')
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DebugCard(
            title: 'Titoli Chiave nel Grafo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TokenWrap(
                  label: 'Film Positivi Influenti',
                  entries: _listOfMaps(
                          recommendationSignals['influentialPositiveMovies'])
                      .map((entry) =>
                          '${entry['title']} (${entry['signalType']})')
                      .toList(),
                ),
                const SizedBox(height: 16),
                _TokenWrap(
                  label: 'Film Negativi Penalizzanti',
                  entries: _listOfMaps(
                          recommendationSignals['penalizedNegativeMovies'])
                      .map((entry) => '${entry['title']}')
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DebugCard(
            title: 'Mix della Coda Giornaliera',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatBox(
                      label: 'Personalizzati',
                      value: '${dailyStats['personalizedCandidateCount'] ?? 0}',
                      color: Colors.purpleAccent,
                    ),
                    _StatBox(
                      label: 'Esplorativi',
                      value: '${dailyStats['exploratoryCandidateCount'] ?? 0}',
                      color: Colors.tealAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _KeyValueRow(
                  label: 'Rapporto Coda Attuale',
                  value:
                      '${dailyStats['personalizedPercentage'] ?? 0}% Personali / ${dailyStats['exploratoryPercentage'] ?? 0}% Esplora',
                  tooltip: 'L\'algoritmo bilancia la coda di swipe: ~65% basato sui tuoi gusti diretti e ~35% su generi nuovi (Esplorativi).',
                ),
                const Divider(height: 24),
                const Text(
                  'CAMPIONE DELLA CODA DI SWIPE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                if (_listOfMaps(dailyStats['sampleQueue']).isEmpty)
                  const Text('Nessun campione di coda disponibile.')
                else
                  ..._listOfMaps(dailyStats['sampleQueue']).map((entry) {
                    final source = entry['source'] ?? '';
                    final isExplore = source == 'exploratory';
                    final badgeColor = isExplore 
                        ? Colors.teal.withValues(alpha: 0.2)
                        : Colors.purple.withValues(alpha: 0.2);
                    final badgeTextColor = isExplore ? Colors.tealAccent : Colors.purpleAccent;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry['title'] ?? 'Film sconosciuto'),
                      subtitle: Text(
                        entry['reason'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isExplore ? 'Esplora' : 'Personal',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DebugCard(
            title: 'Stato di Emergenza (Fallback)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyValueRow(
                  label: 'Strategia di Fallback Attiva',
                  value: fallbackStats['used'] == true ? 'Sì' : 'No',
                  tooltip: 'Se attivo, significa che il backend ha usato film popolari generici a causa di dati insufficienti nel grafo.',
                ),
                _KeyValueRow(
                  label: 'Motivo Fallback',
                  value: '${fallbackStats['reason'] ?? '-'}',
                  tooltip: 'La causa specifica che ha impedito all\'algoritmo personalizzato di generare abbastanza raccomandazioni.',
                ),
                _KeyValueRow(
                  label: 'Strategia di Recupero',
                  value: '${fallbackStats['strategy'] ?? '-'}',
                  tooltip: 'Il metodo alternativo utilizzato per caricare i film (es. film popolari con generi dell\'onboarding).',
                ),
                _KeyValueRow(
                  label: 'Candidati di Fallback Caricati',
                  value: '${fallbackStats['candidateCount'] ?? 0}',
                  tooltip: 'Il numero di film caricati dal piano di riserva.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnel(BuildContext context, Map<String, dynamic> pool) {
    final total = pool['totalCandidatesConsidered'] ?? 0;
    final seen = pool['filteredAlreadySeen'] ?? 0;
    final disliked = pool['filteredDisliked'] ?? 0;
    final swiped = pool['filteredAlreadySwiped'] ?? 0;
    final missing = pool['filteredMissingMetadata'] ?? 0;
    final remaining = pool['remainingAfterFiltering'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Imbuto dei Candidati (Pipeline)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFunnelStep(context, 'Considerati Iniziali', total,
                isHeader: true),
            _buildFunnelArrow(),
            _buildFunnelStep(context, 'Filtrati Già Visti', -seen,
                isNegative: true),
            _buildFunnelArrow(),
            _buildFunnelStep(context, 'Filtrati Sgraditi (Disliked)', -disliked,
                isNegative: true),
            _buildFunnelArrow(),
            _buildFunnelStep(context, 'Filtrati Già Swippati', -swiped,
                isNegative: true),
            _buildFunnelArrow(),
            _buildFunnelStep(
                context, 'Filtrati Metadati Mancanti', -missing,
                isNegative: true),
            _buildFunnelArrow(),
            _buildFunnelStep(
                context, 'Candidati Rimanenti (Fase Ranking)', remaining,
                isResult: true),
          ],
        ),
      ),
    );
  }

  Widget _buildFunnelStep(
    BuildContext context,
    String label,
    dynamic value, {
    bool isHeader = false,
    bool isNegative = false,
    bool isResult = false,
  }) {
    Color valColor = Theme.of(context).colorScheme.onSurface;
    FontWeight valWeight = FontWeight.normal;
    double valSize = 14;

    if (isHeader) {
      valColor = AgreeoColors.popcornWhite;
      valWeight = FontWeight.bold;
    } else if (isNegative) {
      if (value != 0) {
        valColor = AgreeoColors.cinematicRed;
        valWeight = FontWeight.w600;
      } else {
        valColor = Theme.of(context).colorScheme.onSurfaceVariant;
      }
    } else if (isResult) {
      valColor = Colors.greenAccent.shade700;
      valWeight = FontWeight.bold;
      valSize = 16;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isResult ? 14 : 13,
            fontWeight:
                (isHeader || isResult) ? FontWeight.bold : FontWeight.normal,
            color: (isHeader || isResult)
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: valSize,
            fontWeight: valWeight,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFunnelArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Icon(
          Icons.arrow_downward_rounded,
          size: 14,
          color: Colors.grey,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS DI PARSING E STRUTTURE DATI
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listOfMaps(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList();
  }

  List<String> _listOfStrings(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.map((e) => e.toString()).toList();
  }
}

class _DebugCard extends StatelessWidget {
  const _DebugCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value, this.tooltip});

  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                if (tooltip != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: tooltip!,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    showDuration: const Duration(seconds: 4),
                    child: Icon(
                      Icons.help_outline,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _TokenWrap extends StatelessWidget {
  const _TokenWrap({required this.label, required this.entries});

  final String label;
  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries.isEmpty
              ? <Widget>[const Text('-')]
              : entries
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      child: Text(entry),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

