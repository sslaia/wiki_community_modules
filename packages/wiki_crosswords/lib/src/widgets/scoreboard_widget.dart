import 'package:flutter/material.dart';

class ScoreboardWidget extends StatelessWidget {
  final Map<String, double> scores;
  final Map<String, String>? customLabels;
  final Color? primaryColor;

  const ScoreboardWidget({
    super.key,
    required this.scores,
    this.customLabels,
    this.primaryColor,
  });

  String _label(String key, String defaultValue) {
    if (customLabels != null && customLabels!.containsKey(key)) {
      return customLabels![key]!;
    }
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = primaryColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  color: primary.withValues(alpha: 0.12),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 48,
                        color: primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _label('crossword_scoreboard', 'Scoreboard'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _label('crossword_score_earned', 'Scores earned'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24.0,
                    horizontal: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ScoreItem(
                        label: _label('crossword_weekly', 'Weekly'),
                        score: scores['weekly'] ?? 0.0,
                        icon: Icons.calendar_view_week,
                        primaryColor: primary,
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      _ScoreItem(
                        label: _label('crossword_monthly', 'Monthly'),
                        score: scores['monthly'] ?? 0.0,
                        icon: Icons.calendar_view_month,
                        primaryColor: primary,
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      _ScoreItem(
                        label: _label('crossword_yearly', 'Yearly'),
                        score: scores['yearly'] ?? 0.0,
                        icon: Icons.calendar_today,
                        primaryColor: primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreItem extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;
  final Color primaryColor;

  const _ScoreItem({
    required this.label,
    required this.score,
    required this.icon,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 8),
        Text(
          score.toStringAsFixed(1),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
