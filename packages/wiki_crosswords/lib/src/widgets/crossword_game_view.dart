import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/crossword_data_source.dart';
import '../models/crossword_models.dart';
import 'crossword_grid.dart';
import 'scoreboard_widget.dart';

/// Controller to allow parent widgets (like AppBar in CrosswordScreen)
/// to control and observe the CrosswordGameView state.
class CrosswordGameController extends ChangeNotifier {
  _CrosswordGameViewState? _state;

  void _attach(_CrosswordGameViewState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  CrosswordPuzzle? get currentPuzzle => _state?._currentPuzzle;
  int get dailyPuzzleId => _state?._dailyPuzzleId ?? -1;
  bool get isCurrentDaily => currentPuzzle?.puzzleId == dailyPuzzleId;
  bool get isFavorite =>
      currentPuzzle != null &&
      (_state?._favoritePuzzles.contains(currentPuzzle!.puzzleId) ?? false);
  int get selectedTab => _state?._currentIndex ?? 0;

  void playDailyPuzzle() => _state?._playDailyPuzzle();
  void playPuzzle(int puzzleId) => _state?._playPuzzle(puzzleId);
  void toggleFavorite() => _state?._toggleFavorite();
  Future<void> shareScore() => _state?._captureAndShare() ?? Future.value();
}

class CrosswordGameView extends StatefulWidget {
  final CrosswordDataSource dataSource;
  final String languageCode;
  final int? initialPuzzleId;
  final void Function(String word, String pageTitle)? onWordDefinitionTap;
  final void Function(double score, String puzzleTitle)? onShareScore;
  final Map<String, String>? customLabels;
  final Color? primaryColor;
  final Color? accentColor;
  final CrosswordGameController? controller;

  const CrosswordGameView({
    super.key,
    required this.dataSource,
    this.languageCode = 'en',
    this.initialPuzzleId,
    this.onWordDefinitionTap,
    this.onShareScore,
    this.customLabels,
    this.primaryColor,
    this.accentColor,
    this.controller,
  });

  @override
  State<CrosswordGameView> createState() => _CrosswordGameViewState();
}

class _CrosswordGameViewState extends State<CrosswordGameView> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  List<CrosswordPuzzle> _puzzles = [];
  CrosswordPuzzle? _currentPuzzle;
  Map<String, String> _userAnswers = {};
  Set<int> _favoritePuzzles = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _isTemporarilyRevealed = false;
  bool _isSharing = false;
  int _currentIndex = 0; // 0 = Daily/Puzzle, 1 = Favorites, 2 = Scoreboard

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _initData();
  }

  @override
  void didUpdateWidget(CrosswordGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  String _label(String key, String defaultValue) {
    if (widget.customLabels != null && widget.customLabels!.containsKey(key)) {
      return widget.customLabels![key]!;
    }
    return defaultValue;
  }

  int get _dailyPuzzleId {
    if (_puzzles.isEmpty) return -1;
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(startOfYear).inDays + 1;
    return (dayOfYear % _puzzles.length == 0)
        ? _puzzles.length
        : dayOfYear % _puzzles.length;
  }

  bool canRevealWords() {
    return DateTime.now().hour >= 20;
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadFavorites();
      final puzzles = await widget.dataSource.loadPuzzles();
      if (puzzles.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = _label('crossword_no', 'No crossword puzzles found.');
        });
        widget.controller?.notifyListeners();
        return;
      }

      _puzzles = puzzles;

      if (widget.initialPuzzleId != null) {
        _currentPuzzle = puzzles.firstWhere(
          (p) => p.puzzleId == widget.initialPuzzleId,
          orElse: () => puzzles.first,
        );
      } else {
        _selectDailyPuzzle();
      }

      await _checkAndResetDailyPuzzleIfNeeded();
      await _loadUserAnswers();

      setState(() {
        _isLoading = false;
      });
      widget.controller?.notifyListeners();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      widget.controller?.notifyListeners();
    }
  }

  void _selectDailyPuzzle() {
    if (_puzzles.isEmpty) return;
    final id = _dailyPuzzleId;
    _currentPuzzle = _puzzles.firstWhere(
      (p) => p.puzzleId == id,
      orElse: () => _puzzles.first,
    );
  }

  Future<void> _checkAndResetDailyPuzzleIfNeeded() async {
    final puzzleId = _dailyPuzzleId;
    if (puzzleId == -1) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final resetKey = 'crossword_reset_date_$puzzleId';
    final lastReset = prefs.getString(resetKey);

    if (lastReset != todayStr) {
      await prefs.remove('crossword_answers_$puzzleId');
      await prefs.setString(resetKey, todayStr);
      await prefs.remove('crossword_score_$todayStr');
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('crossword_favorites') ?? [];
    _favoritePuzzles = favList.map(int.parse).toSet();
  }

  Future<void> _toggleFavorite() async {
    if (_currentPuzzle == null) return;
    final currentId = _currentPuzzle!.puzzleId;
    final favs = Set<int>.from(_favoritePuzzles);

    if (favs.contains(currentId)) {
      favs.remove(currentId);
    } else {
      favs.add(currentId);
    }

    setState(() {
      _favoritePuzzles = favs;
    });
    widget.controller?.notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'crossword_favorites',
      favs.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _loadUserAnswers() async {
    if (_currentPuzzle == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(
      'crossword_answers_${_currentPuzzle!.puzzleId}',
    );
    if (saved != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(saved);
        setState(() {
          _userAnswers = decoded.map((k, v) => MapEntry(k, v.toString()));
        });
      } catch (_) {
        setState(() {
          _userAnswers = {};
        });
      }
    } else {
      setState(() {
        _userAnswers = {};
      });
    }
  }

  Future<void> _setAnswer(int x, int y, String letter) async {
    if (_currentPuzzle == null) return;
    final newAnswers = Map<String, String>.from(_userAnswers);
    final key = '$x,$y';

    if (letter.isEmpty) {
      newAnswers.remove(key);
    } else {
      newAnswers[key] = letter.toUpperCase();
    }

    setState(() {
      _userAnswers = newAnswers;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'crossword_answers_${_currentPuzzle!.puzzleId}',
      jsonEncode(newAnswers),
    );

    _updateDailyScore();
  }

  void _updateDailyScore() async {
    if (_currentPuzzle == null) return;

    int correctLetters = 0;
    int totalLetters = 0;

    final correctMap = <String, String>{};
    for (var word in _currentPuzzle!.words) {
      for (int i = 0; i < word.word.length; i++) {
        int cx = word.direction == 'across' ? word.x + i : word.x;
        int cy = word.direction == 'down' ? word.y + i : word.y;
        correctMap['$cx,$cy'] = word.word[i].toUpperCase();
      }
    }

    totalLetters = correctMap.length;
    correctMap.forEach((key, val) {
      if (_userAnswers[key] == val) {
        correctLetters++;
      }
    });

    double score = totalLetters == 0 ? 0 : (correctLetters / totalLetters) * 10;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await prefs.setDouble('crossword_score_$dateStr', score);
  }

  Future<Map<String, double>> getScores() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    double sumWeek = 0;
    int daysWeek = 0;
    int weekday = now.weekday; // 1 = Mon, 7 = Sun
    for (int i = 0; i < weekday; i++) {
      final d = now.subtract(Duration(days: i));
      final ds =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (prefs.containsKey('crossword_score_$ds')) {
        sumWeek += prefs.getDouble('crossword_score_$ds')!;
        daysWeek++;
      }
    }

    double sumMonth = 0;
    int daysMonth = 0;
    for (int i = 0; i < now.day; i++) {
      final d = now.subtract(Duration(days: i));
      final ds =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (prefs.containsKey('crossword_score_$ds')) {
        sumMonth += prefs.getDouble('crossword_score_$ds')!;
        daysMonth++;
      }
    }

    double sumYear = 0;
    int daysYear = 0;
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    for (int i = 0; i < dayOfYear; i++) {
      final d = now.subtract(Duration(days: i));
      final ds =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (prefs.containsKey('crossword_score_$ds')) {
        sumYear += prefs.getDouble('crossword_score_$ds')!;
        daysYear++;
      }
    }

    return {
      'weekly': daysWeek == 0 ? 0 : sumWeek / daysWeek,
      'monthly': daysMonth == 0 ? 0 : sumMonth / daysMonth,
      'yearly': daysYear == 0 ? 0 : sumYear / daysYear,
    };
  }

  Future<void> _playDailyPuzzle() async {
    setState(() {
      _currentIndex = 0;
      _isTemporarilyRevealed = false;
    });
    _selectDailyPuzzle();
    await _checkAndResetDailyPuzzleIfNeeded();
    await _loadUserAnswers();
    widget.controller?.notifyListeners();
  }

  Future<void> _playPuzzle(int puzzleId) async {
    final puzzle = _puzzles.firstWhere(
      (p) => p.puzzleId == puzzleId,
      orElse: () => _puzzles.first,
    );
    setState(() {
      _currentPuzzle = puzzle;
      _currentIndex = 0;
      _isTemporarilyRevealed = false;
    });
    await _loadUserAnswers();
    widget.controller?.notifyListeners();
  }

  Future<void> _captureAndShare() async {
    if (_isSharing) return;
    setState(() {
      _isSharing = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      final scores = await getScores();
      final weeklyScore = scores['weekly'] ?? 0.0;

      if (pngBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/crossword_score.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(pngBytes);

        if (widget.onShareScore != null) {
          widget.onShareScore!(weeklyScore, 'Crossword #${_currentPuzzle?.puzzleId}');
        } else {
          final text =
              "${_label('crossword_share_1', 'I completed the crossword for today! My score this week:')} ${weeklyScore.toStringAsFixed(1)}/10. ${_label('crossword_share_2', '')}";
          await SharePlus.instance.share(
            ShareParams(files: [XFile(imagePath)], text: text),
          );
        }
      }
    } catch (e) {
      debugPrint('Error capturing and sharing crossword: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primary));
    }

    if (_errorMessage != null || _puzzles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? _label('crossword_no', 'No puzzles available'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _initData,
              child: Text(_label('retry', 'Retry')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Navigation Segmented Button
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SegmentedButton<int>(
                emptySelectionAllowed: false,
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(
                      _label('crossword_daily', 'Daily'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.grid_on, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(
                      _label('crossword_favorites', 'Favorites'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.favorite, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text(
                      _label('crossword_scoreboard', 'Scoreboard'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.leaderboard, size: 18),
                  ),
                ],
                selected: {_currentIndex},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _currentIndex = newSelection.first;
                  });
                  widget.controller?.notifyListeners();
                },
              ),
            ),
          ),
        ),

        // Main Tab Views
        Expanded(
          child: _currentIndex == 1
              ? _buildFavoritesList(context)
              : _currentIndex == 2
                  ? _buildScoreboardView(context)
                  : _buildDailyCrosswordView(context),
        ),
      ],
    );
  }

  Widget _buildFavoritesList(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final favList = _favoritePuzzles.toList()..sort();

    if (favList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 56,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              _label('crossword_no_favorite', 'No favorite crosswords yet'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: favList.length,
      itemBuilder: (context, index) {
        final puzzleId = favList[index];
        final puzzle = _puzzles.firstWhere(
          (p) => p.puzzleId == puzzleId,
          orElse: () => _puzzles.first,
        );

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: Text(
              '${_label('crosswords', 'Crosswords')} #$puzzleId',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${puzzle.words.length} ${_label('words', 'words')} (${puzzle.gridSize}x${puzzle.gridSize})',
            ),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(_label('crossword_open', 'Open')),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary.withValues(alpha: 0.12),
                foregroundColor: primary,
                elevation: 0,
              ),
              onPressed: () => _playPuzzle(puzzleId),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreboardView(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: getScores(),
      builder: (context, snapshot) {
        final scores = snapshot.data ?? {'weekly': 0.0, 'monthly': 0.0, 'yearly': 0.0};
        return SingleChildScrollView(
          child: ScoreboardWidget(
            scores: scores,
            customLabels: widget.customLabels,
            primaryColor: widget.primaryColor,
          ),
        );
      },
    );
  }

  Widget _buildDailyCrosswordView(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;

    if (_currentPuzzle == null) {
      return Center(
        child: Text(_label('crossword_no', 'No crossword available')),
      );
    }

    final canReveal = canRevealWords();

    bool isFullySolved = false;
    CrosswordWord? bonusWord;

    int correctLetters = 0;
    final correctMap = <String, String>{};
    for (var word in _currentPuzzle!.words) {
      for (int i = 0; i < word.word.length; i++) {
        int cx = word.direction == 'across' ? word.x + i : word.x;
        int cy = word.direction == 'down' ? word.y + i : word.y;
        correctMap['$cx,$cy'] = word.word[i].toUpperCase();
      }
    }

    int totalLetters = correctMap.length;
    correctMap.forEach((key, val) {
      if (_userAnswers[key] == val) {
        correctLetters++;
      }
    });

    isFullySolved = (totalLetters > 0 && correctLetters == totalLetters);
    if (isFullySolved && _currentPuzzle!.words.isNotEmpty) {
      bonusWord = _currentPuzzle!.words.reduce(
        (a, b) => a.word.length > b.word.length ? a : b,
      );
    }

    final isDaily = _currentPuzzle!.puzzleId == _dailyPuzzleId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: RepaintBoundary(
            key: _repaintBoundaryKey,
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          color: primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDaily
                              ? _label('crossword_daily', 'Daily Crossword')
                              : '${_label('crosswords', 'Crossword')} #${_currentPuzzle!.puzzleId}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // The Crossword Grid with Clue Ribbon & in-cell input
                    CrosswordGrid(
                      puzzle: _currentPuzzle!,
                      userAnswers: _userAnswers,
                      onAnswerChanged: _setAnswer,
                      isFillable: !canReveal && isDaily,
                      isTemporarilyRevealed: _isTemporarilyRevealed,
                      customLabels: widget.customLabels,
                      primaryColor: widget.primaryColor,
                      accentColor: widget.accentColor,
                      onWordDefinitionTap: widget.onWordDefinitionTap,
                    ),

                    const SizedBox(height: 24),

                    // Reveal mechanism & Notes section
                    if (canReveal)
                      if (isFullySolved && bonusWord != null)
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primary,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _label('crossword_bonus', 'Bonus'),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  if (widget.onWordDefinitionTap != null) {
                                    widget.onWordDefinitionTap!(
                                      bonusWord!.word,
                                      bonusWord.pageTitle,
                                    );
                                    return;
                                  }
                                  final pageTitle = Uri.encodeComponent(bonusWord!.pageTitle);
                                  final url = Uri.parse('https://nia.wiktionary.org/wiki/$pageTitle');
                                  try {
                                    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                                  } catch (_) {}
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                    horizontal: 8.0,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${bonusWord.word.toUpperCase()} - ${bonusWord.clue}',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: primary,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.open_in_new,
                                        size: 16,
                                        color: primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        FilledButton.icon(
                          icon: Icon(
                            _isTemporarilyRevealed
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          label: Text(
                            _isTemporarilyRevealed
                                ? _label('crossword_hide_words', 'Hide Words')
                                : _label('crossword_check_words', 'Check Words'),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _isTemporarilyRevealed = !_isTemporarilyRevealed;
                            });
                          },
                        )
                    else
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _label('crossword_notes', 'Note'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _label(
                                'crossword_notes_1',
                                '1. Only letters. Don\'t include hyphen (-) or apostrophe (\')',
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _label(
                                'crossword_notes_2',
                                '2. Come back this evening. The correct answers will be revealed at 8pm!',
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
