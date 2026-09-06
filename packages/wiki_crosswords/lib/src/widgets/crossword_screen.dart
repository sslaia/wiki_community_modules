import 'package:flutter/material.dart';
import '../data/crossword_data_source.dart';
import 'crossword_game_view.dart';

/// Fullscreen Scaffold wrapper providing the full WikiNusa Crossword experience:
/// - AppBar with title icon, Today button, Favorite toggle, and Screenshot Share button.
/// - Segmented Navigation (Daily, Favorites, Scoreboard).
/// - Reveal system, clue ribbon, and native text input.
class CrosswordScreen extends StatefulWidget {
  final String title;
  final CrosswordDataSource dataSource;
  final String languageCode;
  final int? initialPuzzleId;
  final void Function(String word, String pageTitle)? onWordDefinitionTap;
  final void Function(double score, String puzzleTitle)? onShareScore;
  final Map<String, String>? customLabels;
  final Color? primaryColor;
  final Color? accentColor;
  final Widget? leading;
  final List<Widget>? extraActions;
  final Widget? drawer;

  const CrosswordScreen({
    super.key,
    required this.title,
    required this.dataSource,
    this.languageCode = 'en',
    this.initialPuzzleId,
    this.onWordDefinitionTap,
    this.onShareScore,
    this.customLabels,
    this.primaryColor,
    this.accentColor,
    this.leading,
    this.extraActions,
    this.drawer,
  });

  @override
  State<CrosswordScreen> createState() => _CrosswordScreenState();
}

class _CrosswordScreenState extends State<CrosswordScreen> {
  final CrosswordGameController _controller = CrosswordGameController();

  String _label(String key, String defaultValue) {
    if (widget.customLabels != null && widget.customLabels!.containsKey(key)) {
      return widget.customLabels![key]!;
    }
    return defaultValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;

    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        leading: widget.leading,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_on_rounded, color: primary),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final isMainTab = _controller.selectedTab == 0;
              final hasPuzzle = _controller.currentPuzzle != null;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play Today's Puzzle if not already on it
                  if (hasPuzzle && !_controller.isCurrentDaily && isMainTab)
                    IconButton(
                      icon: const Icon(Icons.today),
                      tooltip: _label('crossword_play', 'Play Today\'s Puzzle'),
                      onPressed: () => _controller.playDailyPuzzle(),
                    ),

                  // Favorite toggle button
                  if (hasPuzzle && isMainTab)
                    IconButton(
                      icon: Icon(
                        _controller.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _controller.isFavorite ? Colors.red : null,
                      ),
                      tooltip: _label('crossword_favorites', 'Favorite'),
                      onPressed: () => _controller.toggleFavorite(),
                    ),

                  // Share button
                  if (hasPuzzle && isMainTab)
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      tooltip: _label('crossword_share', 'Share'),
                      onPressed: () => _controller.shareScore(),
                    ),

                  if (widget.extraActions != null) ...widget.extraActions!,
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CrosswordGameView(
          controller: _controller,
          dataSource: widget.dataSource,
          languageCode: widget.languageCode,
          initialPuzzleId: widget.initialPuzzleId,
          onWordDefinitionTap: widget.onWordDefinitionTap,
          onShareScore: widget.onShareScore,
          customLabels: widget.customLabels,
          primaryColor: widget.primaryColor,
          accentColor: widget.accentColor,
        ),
      ),
    );
  }
}
