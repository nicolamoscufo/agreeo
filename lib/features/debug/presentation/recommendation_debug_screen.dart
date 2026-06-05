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
              Tab(text: 'How It Works', icon: Icon(Icons.psychology_rounded)),
              Tab(text: 'Score Analysis', icon: Icon(Icons.calculate_rounded)),
              Tab(text: 'Diagnostics', icon: Icon(Icons.insights_rounded)),
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
                    title: 'Debug Data Unavailable',
                    message: snapshot.error.toString(),
                    action: FilledButton(
                      onPressed: () {
                        setState(() {
                          _debugFuture = _load();
                        });
                      },
                      child: const Text('Try Again'),
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
                    title: 'No Debug Data',
                    message:
                        'The backend did not return diagnostic data. Complete onboarding or swipe on a few movies before trying again.',
                    action: FilledButton(
                      onPressed: () {
                        setState(() {
                          _debugFuture = _load();
                        });
                      },
                      child: const Text('Try Again'),
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
  // TAB 1: ALGORITHM EXPLAINER (HOW IT WORKS)
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
                          'The Recommendation Engine',
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
                    'Agreeo uses a hybrid recommendation model powered by Neo4j '
                    'and the MovieLens dataset to suggest movies that match your taste '
                    'while still helping you discover new genres.',
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
            title: 'Step 1: Hard Filters (Exclusion)',
            description:
                'Before scoring starts, the catalog excludes everything that would make '
                'a recommendation redundant or unwanted:\n\n'
                '• 🚫 **Already Swiped**: Movies you already liked, disliked, or saved to your Watchlist.\n'
                '• 👁️ **Already Seen**: Movies marked as already watched.\n'
                '• 🖼️ **Missing Metadata**: Movies without a poster or cover image.',
          ),
          const SizedBox(height: 16),
          _buildAlgoStepCard(
            context,
            stepNumber: '2',
            icon: Icons.calculate_rounded,
            iconColor: Colors.blueAccent,
            title: 'Step 2: Score Assignment',
            description:
                'Remaining candidates are evaluated with two scoring paths depending on their source:\n\n'
                '💡 **A. Personalized Score (Collaborative & Semantic)**\n'
                'Combines two hybrid recommendation engines:\n'
                '  • **Collaborative (Neo4j Graph)**: Finds other users with similar interests. Your signal weights:\n'
                '     - Favorites: **+4.0** | Likes: **+3.0** | Watchlist: **+1.25**\n'
                '     - *Genre Penalty*: Subtracts a dynamic score proportional to dislike count and ratio (for example from **-1.5** up to **-15.0+** for heavily disliked genres).\n'
                '  • **Semantic (Tag Embeddings)**: Builds a **User Taste Vector** from 384-dimensional tag vectors across your swiped movies. It searches Neo4j through the `tag_embeddings` vector index for movies with tags and vibes closest to your taste.\n\n'
                '🚀 **B. Exploratory Score**\n'
                'Looks for popular movies outside your usual circle to test new directions:\n'
                '   - Familiar genre match: **+15.0** per genre.\n'
                '   - Global popularity: **10.0 * Average + log(Votes)**.\n'
                '   - Unexplored genres (New Genres): **+40.0**.\n'
                '   - Disliked genres: **-25.0**.',
          ),
          const SizedBox(height: 16),
          _buildAlgoStepCard(
            context,
            stepNumber: '3',
            icon: Icons.shuffle_rounded,
            iconColor: Colors.purpleAccent,
            title: 'Step 3: Daily Mix and Blending',
            description:
                'Your daily swipe queue is not filled only with personal recommendations '
                'so the app avoids a filter bubble. The backend blends results with this ratio:\n\n'
                '• 🔀 **65% Personal Recommendations**: Movies with very high calculated compatibility.\n'
                '• 🔀 **35% Exploratory Recommendations**: Fresh prompts that refine your interests.',
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
  // TAB 2: CANDIDATE SCORE DETAILS (SCORE ANALYSIS)
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
                title: 'No Ranked Movies',
                message:
                    'There are no ranked candidates in the pool right now. Swipe on a few movies or refresh.',
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
          final title = entry['title'] ?? 'Unknown title';
          final reason = entry['reason'] ?? '';

          final collaborativeScore = entry['collaborativeScore'] ?? 0.0;
          final genreScore = entry['genreScore'] ?? 0.0;
          final popularityScore = entry['popularityScore'] ?? 0.0;
          final explorationBonus = entry['explorationBonus'] ?? 0.0;
          final negativePenalty = entry['negativePenalty'] ?? 0.0;
          final tagRelevanceScore = entry['tagRelevanceScore'] ?? 0.0;
          final tagScore = tagRelevanceScore is num ? tagRelevanceScore.toDouble() * 10.0 : 0.0;
          final matchedTags = _listOfMaps(entry['matchedTags']);

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
                        'SCORE COMPOSITION',
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
                        label: 'Collaborative Score (Neo4j)',
                        value: collaborativeScore,
                        icon: Icons.people_outline_rounded,
                        isPositive: true,
                      ),
                      _buildScoreDetailRow(
                        context,
                        label: 'Genre Match (Onboarding/Likes)',
                        value: genreScore,
                        icon: Icons.category_outlined,
                        isPositive: true,
                      ),
                      _buildScoreDetailRow(
                        context,
                        label: 'Popularity & Votes (MovieLens)',
                        value: popularityScore,
                        icon: Icons.star_outline_rounded,
                        isPositive: true,
                      ),
                      _buildScoreDetailRow(
                        context,
                        label: 'Exploration Bonus (New Genres)',
                        value: explorationBonus,
                        icon: Icons.explore_outlined,
                        isPositive: true,
                      ),
                      _buildScoreDetailRow(
                        context,
                        label: 'Disliked Genre Penalty',
                        value: negativePenalty,
                        icon: Icons.warning_amber_rounded,
                        isPositive: false,
                      ),
                      _buildScoreDetailRow(
                        context,
                        label: 'Semantic Tag Affinity (Embeddings)',
                        value: tagScore,
                        icon: Icons.local_offer_outlined,
                        isPositive: true,
                      ),
                      if (matchedTags.isNotEmpty) ...[
                        const Divider(height: 16),
                        const Text(
                          'MATCHING SEMANTIC TAGS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: matchedTags.map((mt) {
                            final tagName = mt['tag'] ?? '';
                            final frequency = mt['frequency'] ?? 1;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '#$tagName (x$frequency)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Calculated Final Score',
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
            title: 'User Profile Signals',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyValueRow(
                  label: 'User ID',
                  value: '${userSignals['uid'] ?? '-'}',
                ),
                _KeyValueRow(
                  label: 'Total Feedback Actions',
                  value: '${userSignals['totalFeedbackActions'] ?? 0}',
                  tooltip: 'The total number of interactions (Like, Dislike, etc.) feeding the Neo4j algorithm.',
                ),
                const SizedBox(height: 8),
                _TokenWrap(
                  label: 'Favorite Genres (Onboarding)',
                  entries: _listOfStrings(userSignals['onboardingGenres']),
                ),
                const Divider(height: 24),
                const Text(
                  'INTERACTION COUNTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                _KeyValueRow(
                  label: 'Favorite Movies',
                  value: '${userSignals['favoriteMoviesCount'] ?? 0}',
                  tooltip: 'Movies selected during onboarding. They carry a strong +4.0 weight for finding similar movies in the graph.',
                ),
                _KeyValueRow(
                  label: 'Liked Movies',
                  value: '${userSignals['likedMoviesCount'] ?? 0}',
                  tooltip: 'Movies you liked. They add a positive +3.0 weight to collaborative scoring.',
                ),
                _KeyValueRow(
                  label: 'Disliked Movies',
                  value: '${userSignals['dislikedMoviesCount'] ?? 0}',
                  tooltip: 'Rejected movies. If you accumulate 2+ dislikes in one genre, that genre gets a strong penalty.',
                ),
                _KeyValueRow(
                  label: 'Already Seen Movies',
                  value: '${userSignals['alreadySeenCount'] ?? 0}',
                  tooltip: 'Movies you already watched. They are removed from candidates to avoid repeats.',
                ),
                _KeyValueRow(
                  label: 'Saved to Watchlist',
                  value: '${userSignals['watchlistCount'] ?? 0}',
                  tooltip: 'Movies saved in your library. They add a positive +1.25 impact to recommendations.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DebugCard(
            title: 'Genre Interests',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TokenWrap(
                  label: 'Top Positive Genres (and score)',
                  entries: _listOfMaps(recommendationSignals['topPositiveGenres'])
                      .map((entry) => '${entry['name']} (${entry['score']})')
                      .toList(),
                ),
                const SizedBox(height: 16),
                _TokenWrap(
                  label: 'Top Negative Genres (and dislikes)',
                  entries: _listOfMaps(recommendationSignals['topNegativeGenres'])
                      .map((entry) => '${entry['name']} (${entry['score']})')
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DebugCard(
            title: 'Semantic Tags (Embeddings)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TokenWrap(
                  label: 'Top Positive Tags (and weight)',
                  entries: _listOfMaps(recommendationSignals['topPositiveTags'])
                      .map((entry) {
                        final score = entry['score'];
                        final displayScore = score is num ? score.toStringAsFixed(1) : '0.0';
                        return '${entry['name']} ($displayScore)';
                      })
                      .toList(),
                ),
                const SizedBox(height: 16),
                _TokenWrap(
                  label: 'Top Negative Tags (and weight)',
                  entries: _listOfMaps(recommendationSignals['topNegativeTags'])
                      .map((entry) {
                        final score = entry['score'];
                        final displayScore = score is num ? score.toStringAsFixed(1) : '0.0';
                        return '${entry['name']} ($displayScore)';
                      })
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DebugCard(
            title: 'Key Titles in the Graph',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TokenWrap(
                  label: 'Influential Positive Movies',
                  entries: _listOfMaps(
                          recommendationSignals['influentialPositiveMovies'])
                      .map((entry) =>
                          '${entry['title']} (${entry['signalType']})')
                      .toList(),
                ),
                const SizedBox(height: 16),
                _TokenWrap(
                  label: 'Penalizing Negative Movies',
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
            title: 'Daily Queue Mix',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatBox(
                      label: 'Personalized',
                      value: '${dailyStats['personalizedCandidateCount'] ?? 0}',
                      color: Colors.purpleAccent,
                    ),
                    _StatBox(
                      label: 'Exploratory',
                      value: '${dailyStats['exploratoryCandidateCount'] ?? 0}',
                      color: Colors.tealAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _KeyValueRow(
                  label: 'Current Queue Ratio',
                  value:
                      '${dailyStats['personalizedPercentage'] ?? 0}% Personal / ${dailyStats['exploratoryPercentage'] ?? 0}% Explore',
                  tooltip: 'The algorithm balances the swipe queue: about 65% based on your direct taste signals and about 35% based on new exploratory genres.',
                ),
                const Divider(height: 24),
                const Text(
                  'SWIPE QUEUE SAMPLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                if (_listOfMaps(dailyStats['sampleQueue']).isEmpty)
                  const Text('No queue sample available.')
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
                      title: Text(entry['title'] ?? 'Unknown movie'),
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
                          isExplore ? 'Explore' : 'Personal',
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
            title: 'Fallback State',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyValueRow(
                  label: 'Fallback Strategy Active',
                  value: fallbackStats['used'] == true ? 'Yes' : 'No',
                  tooltip: 'If active, the backend used generic popular movies because the graph did not have enough data.',
                ),
                _KeyValueRow(
                  label: 'Fallback Reason',
                  value: '${fallbackStats['reason'] ?? '-'}',
                  tooltip: 'The specific cause that prevented the personalized algorithm from generating enough recommendations.',
                ),
                _KeyValueRow(
                  label: 'Recovery Strategy',
                  value: '${fallbackStats['strategy'] ?? '-'}',
                  tooltip: 'The alternative method used to load movies, such as popular movies from onboarding genres.',
                ),
                _KeyValueRow(
                  label: 'Loaded Fallback Candidates',
                  value: '${fallbackStats['candidateCount'] ?? 0}',
                  tooltip: 'The number of movies loaded by the fallback plan.',
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
              'Candidate Funnel (Pipeline)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFunnelStep(context, 'Initially Considered', total,
                isHeader: true),
            _buildFunnelArrow(),
            _buildFunnelStep(context, 'Filtered Already Seen', -seen,
                isNegative: true),
            _buildFunnelArrow(),
            _buildFunnelStep(context, 'Filtered Disliked', -disliked,
                isNegative: true),
            _buildFunnelArrow(),
            _buildFunnelStep(context, 'Filtered Already Swiped', -swiped,
                isNegative: true),
            _buildFunnelArrow(),
            _buildFunnelStep(
                context, 'Filtered Missing Metadata', -missing,
                isNegative: true),
            _buildFunnelArrow(),
            _buildFunnelStep(
                context, 'Remaining Candidates (Ranking Stage)', remaining,
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
