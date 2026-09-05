import 'package:flutter/material.dart';
import '../data/crossword_data_source.dart';
import 'crossword_game_view.dart';

/// Fullscreen Scaffold wrapper for host apps wanting an out-of-the-box Crossword screen.
class CrosswordScreen extends StatelessWidget {
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
  final List<Widget>? actions;
  final Widget? drawer;
  final List<String>? extraKeypadLetters;

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
    this.actions,
    this.drawer,
    this.extraKeypadLetters,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer,
      appBar: AppBar(
        leading: leading,
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        child: CrosswordGameView(
          dataSource: dataSource,
          languageCode: languageCode,
          initialPuzzleId: initialPuzzleId,
          onWordDefinitionTap: onWordDefinitionTap,
          onShareScore: onShareScore,
          customLabels: customLabels,
          primaryColor: primaryColor,
          accentColor: accentColor,
          extraKeypadLetters: extraKeypadLetters,
        ),
      ),
    );
  }
}
