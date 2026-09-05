import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/crossword_data_source.dart';
import '../models/crossword_models.dart';

/// Decoupled, embeddable Crossword game view body widget.
class CrosswordGameView extends StatefulWidget {
  final CrosswordDataSource dataSource;
  final String languageCode;
  final int? initialPuzzleId;
  final void Function(String word, String pageTitle)? onWordDefinitionTap;
  final void Function(double score, String puzzleTitle)? onShareScore;
  final Map<String, String>? customLabels;
  final Color? primaryColor;
  final Color? accentColor;
  final bool showArchiveButton;
  final List<String>? extraKeypadLetters;

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
    this.showArchiveButton = true,
    this.extraKeypadLetters,
  });

  @override
  State<CrosswordGameView> createState() => _CrosswordGameViewState();
}

class _CrosswordGameViewState extends State<CrosswordGameView> {
  List<CrosswordPuzzle> _puzzles = [];
  CrosswordPuzzle? _currentPuzzle;
  bool _isLoading = true;
  String? _errorMessage;

  // Game interaction state
  int? _selectedX;
  int? _selectedY;
  CrosswordWord? _selectedWord;
  Map<String, String> _userAnswers = {}; // "x,y": "LETTER"
  bool _isChecking = false;
  bool _isRevealed = false;

  final ScrollController _clueScrollController = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _clueScrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  String _label(String key, String defaultValue) {
    if (widget.customLabels != null && widget.customLabels!.containsKey(key)) {
      return widget.customLabels![key]!;
    }
    return defaultValue;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final puzzles = await widget.dataSource.loadPuzzles();
      if (puzzles.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = _label('no_puzzles', 'No crossword puzzles found.');
        });
        return;
      }

      _puzzles = puzzles;

      // Select initial or daily puzzle
      final targetId = widget.initialPuzzleId ?? _calculateDailyPuzzleId(puzzles.length);
      _currentPuzzle = puzzles.firstWhere(
        (p) => p.puzzleId == targetId,
        orElse: () => puzzles.first,
      );

      await _loadSavedAnswers();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  int _calculateDailyPuzzleId(int total) {
    if (total <= 0) return 1;
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(startOfYear).inDays + 1;
    return (dayOfYear % total == 0) ? total : (dayOfYear % total);
  }

  String get _prefsKey =>
      'crossword_answers_${widget.languageCode}_${_currentPuzzle?.puzzleId}';

  Future<void> _loadSavedAnswers() async {
    if (_currentPuzzle == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        final Map<String, dynamic> decoded = jsonDecode(saved);
        _userAnswers = decoded.map((k, v) => MapEntry(k, v.toString()));
      } else {
        _userAnswers = {};
      }
    } catch (_) {
      _userAnswers = {};
    }
  }

  Future<void> _saveAnswer(int x, int y, String letter) async {
    if (_currentPuzzle == null) return;
    setState(() {
      if (letter.isEmpty) {
        _userAnswers.remove('$x,$y');
      } else {
        _userAnswers['$x,$y'] = letter.toUpperCase();
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_userAnswers));
    } catch (_) {}

    _advanceToNextCell();
  }

  void _advanceToNextCell() {
    if (_selectedWord == null || _selectedX == null || _selectedY == null) return;

    final word = _selectedWord!;
    int nextX = _selectedX!;
    int nextY = _selectedY!;

    if (word.direction == 'across') {
      if (nextX < word.x + word.word.length - 1) {
        nextX++;
      }
    } else {
      if (nextY < word.y + word.word.length - 1) {
        nextY++;
      }
    }

    setState(() {
      _selectedX = nextX;
      _selectedY = nextY;
    });
  }

  void _backspace() {
    if (_selectedX == null || _selectedY == null || _selectedWord == null) return;

    final key = '$_selectedX,$_selectedY';
    if (_userAnswers.containsKey(key) && _userAnswers[key]!.isNotEmpty) {
      _saveAnswer(_selectedX!, _selectedY!, '');
      return;
    }

    // Move backward if current cell is already empty
    final word = _selectedWord!;
    int prevX = _selectedX!;
    int prevY = _selectedY!;

    if (word.direction == 'across') {
      if (prevX > word.x) prevX--;
    } else {
      if (prevY > word.y) prevY--;
    }

    setState(() {
      _selectedX = prevX;
      _selectedY = prevY;
    });
    _saveAnswer(prevX, prevY, '');
  }

  void _handleCellTap(int x, int y) {
    if (_currentPuzzle == null) return;

    final matchingWords = _currentPuzzle!.words.where((w) => w.containsCell(x, y)).toList();
    if (matchingWords.isEmpty) return;

    setState(() {
      _isChecking = false;

      // If tapped on currently selected cell, toggle direction between across & down
      if (_selectedX == x && _selectedY == y && matchingWords.length > 1) {
        if (_selectedWord == matchingWords.first) {
          _selectedWord = matchingWords.last;
        } else {
          _selectedWord = matchingWords.first;
        }
      } else {
        _selectedX = x;
        _selectedY = y;
        // Keep same direction if possible, otherwise pick first
        if (_selectedWord != null && matchingWords.any((w) => w.direction == _selectedWord!.direction)) {
          _selectedWord = matchingWords.firstWhere((w) => w.direction == _selectedWord!.direction);
        } else {
          _selectedWord = matchingWords.first;
        }
      }
    });

    _scrollToActiveClue();
  }

  void _selectWord(CrosswordWord word) {
    setState(() {
      _selectedWord = word;
      _selectedX = word.x;
      _selectedY = word.y;
      _isChecking = false;
    });
    _scrollToActiveClue();
  }

  void _scrollToActiveClue() {
    if (_selectedWord == null || _currentPuzzle == null) return;
    final idx = _currentPuzzle!.words.indexOf(_selectedWord!);
    if (idx != -1 && _clueScrollController.hasClients) {
      _clueScrollController.animateTo(
        idx * 210.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  double _calculateScore() {
    if (_currentPuzzle == null || _currentPuzzle!.words.isEmpty) return 0.0;

    int correct = 0;
    int total = 0;

    final correctMap = <String, String>{};
    for (final w in _currentPuzzle!.words) {
      for (int i = 0; i < w.word.length; i++) {
        final cx = w.direction == 'across' ? w.x + i : w.x;
        final cy = w.direction == 'down' ? w.y + i : w.y;
        correctMap['$cx,$cy'] = w.word[i].toUpperCase();
      }
    }

    total = correctMap.length;
    correctMap.forEach((key, expectedLetter) {
      if (_userAnswers[key]?.toUpperCase() == expectedLetter) {
        correct++;
      }
    });

    return total == 0 ? 0.0 : (correct / total) * 10.0;
  }

  void _showArchiveSheet(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _label('archive_title', 'All Crossword Puzzles'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_puzzles.length} ${_label('puzzles', 'Puzzles')}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _puzzles.length,
                    itemBuilder: (context, index) {
                      final p = _puzzles[index];
                      final isSelected = p.puzzleId == _currentPuzzle?.puzzleId;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? primary
                              : theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          child: Text('#${p.puzzleId}'),
                        ),
                        title: Text(
                          '${_label('puzzle', 'Puzzle')} #${p.puzzleId}',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('${p.words.length} ${_label('words', 'words')} (${p.gridSize}x${p.gridSize})'),
                        trailing: isSelected ? Icon(Icons.check_circle_rounded, color: primary) : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          setState(() {
                            _currentPuzzle = p;
                            _selectedX = null;
                            _selectedY = null;
                            _selectedWord = null;
                            _isChecking = false;
                            _isRevealed = false;
                          });
                          await _loadSavedAnswers();
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final accent = widget.accentColor ?? theme.colorScheme.secondary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primary));
    }

    if (_errorMessage != null || _currentPuzzle == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Puzzle unavailable',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadData,
              child: Text(_label('retry', 'Retry')),
            ),
          ],
        ),
      );
    }

    final puzzle = _currentPuzzle!;

    return Column(
      children: [
        // Puzzle Top Bar with title, archive button, and definition action
        _buildTopBar(context, puzzle, primary, accent),

        // Permanent Clue Ribbon
        _buildClueRibbon(context, puzzle, primary, accent),

        // Crossword Grid
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildGrid(context, puzzle, primary, accent),
            ),
          ),
        ),

        // Action Toolbar (Check, Reveal, Clear, Share)
        _buildActionToolbar(context, puzzle, primary),

        // Custom On-Screen Keypad with special characters
        _buildSoftKeypad(context, primary),
      ],
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    CrosswordPuzzle puzzle,
    Color primary,
    Color accent,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${puzzle.puzzleId}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_label('crossword_title', 'Crossword')} #${puzzle.puzzleId}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_selectedWord != null && widget.onWordDefinitionTap != null)
                IconButton(
                  icon: const Icon(Icons.menu_book_rounded),
                  color: primary,
                  tooltip: _label('view_definition', 'View Word Definition'),
                  onPressed: () {
                    widget.onWordDefinitionTap!(
                      _selectedWord!.word,
                      _selectedWord!.pageTitle,
                    );
                  },
                ),
              if (widget.showArchiveButton)
                IconButton(
                  icon: const Icon(Icons.collections_bookmark_rounded),
                  tooltip: _label('archive', 'Puzzle Archive'),
                  onPressed: () => _showArchiveSheet(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClueRibbon(
    BuildContext context,
    CrosswordPuzzle puzzle,
    Color primary,
    Color accent,
  ) {
    final theme = Theme.of(context);

    return Container(
      height: 72,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        controller: _clueScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: puzzle.words.length,
        itemBuilder: (context, index) {
          final word = puzzle.words[index];
          final isSelected = _selectedWord == word;
          final directionLabel = word.direction == 'across'
              ? _label('across', 'Across')
              : _label('down', 'Down');

          return GestureDetector(
            onTap: () => _selectWord(word),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 200,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? primary : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: isSelected ? 1.8 : 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? primary : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        directionLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primary : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      word.clue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.2,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    CrosswordPuzzle puzzle,
    Color primary,
    Color accent,
  ) {
    final theme = Theme.of(context);
    final size = puzzle.gridSize;

    // Precalculate word start numbers and active coordinates
    final wordNumbers = <String, int>{};
    for (int i = 0; i < puzzle.words.length; i++) {
      final w = puzzle.words[i];
      wordNumbers['${w.x},${w.y}'] = i + 1;
    }

    final activeCells = <String, String>{}; // "x,y": "LETTER"
    for (final w in puzzle.words) {
      for (int i = 0; i < w.word.length; i++) {
        final cx = w.direction == 'across' ? w.x + i : w.x;
        final cy = w.direction == 'down' ? w.y + i : w.y;
        activeCells['$cx,$cy'] = w.word[i].toUpperCase();
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outline,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: size,
              childAspectRatio: 1,
            ),
            itemCount: size * size,
            itemBuilder: (context, index) {
              final x = index % size;
              final y = index ~/ size;
              final key = '$x,$y';
              final isPlayable = activeCells.containsKey(key);

              if (!isPlayable) {
                // Black cell
                return Container(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                );
              }

              final isSelectedCell = _selectedX == x && _selectedY == y;
              final isPartOfSelectedWord = _selectedWord != null && _selectedWord!.containsCell(x, y);

              final userChar = _isRevealed
                  ? activeCells[key] ?? ''
                  : (_userAnswers[key] ?? '');
              final isCorrect = _isChecking && userChar.isNotEmpty && userChar == activeCells[key];
              final isWrong = _isChecking && userChar.isNotEmpty && userChar != activeCells[key];

              Color cellBackground = theme.colorScheme.surface;
              if (isSelectedCell) {
                cellBackground = primary.withValues(alpha: 0.35);
              } else if (isPartOfSelectedWord) {
                cellBackground = primary.withValues(alpha: 0.15);
              }

              Color textColor = theme.colorScheme.onSurface;
              if (isCorrect) {
                textColor = Colors.green;
              } else if (isWrong) {
                textColor = theme.colorScheme.error;
              } else if (isSelectedCell) {
                textColor = primary;
              }

              return GestureDetector(
                onTap: () => _handleCellTap(x, y),
                child: Container(
                  decoration: BoxDecoration(
                    color: cellBackground,
                    border: Border.all(
                      color: isSelectedCell
                          ? primary
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      width: isSelectedCell ? 1.5 : 0.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Cell Number in top left
                      if (wordNumbers.containsKey(key))
                        Positioned(
                          top: 1,
                          left: 2,
                          child: Text(
                            '${wordNumbers[key]}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      // Character
                      Center(
                        child: Text(
                          userChar,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionToolbar(
    BuildContext context,
    CrosswordPuzzle puzzle,
    Color primary,
  ) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Check Answers
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isChecking = !_isChecking;
              });
            },
            icon: Icon(
              _isChecking ? Icons.check_circle : Icons.check_circle_outline,
              size: 18,
              color: _isChecking ? Colors.green : primary,
            ),
            label: Text(_label('check', 'Check')),
          ),

          // Reveal Solution
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isRevealed = !_isRevealed;
              });
            },
            icon: Icon(
              _isRevealed ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: primary,
            ),
            label: Text(_label('reveal', 'Reveal')),
          ),

          // Clear Answers
          TextButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(_label('clear_title', 'Clear Puzzle?')),
                  content: Text(_label('clear_confirm', 'Are you sure you want to clear all entered answers?')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_label('cancel', 'Cancel'))),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_label('clear', 'Clear'))),
                  ],
                ),
              );
              if (confirmed == true) {
                setState(() {
                  _userAnswers.clear();
                  _isChecking = false;
                  _isRevealed = false;
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(_prefsKey);
              }
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_label('clear', 'Clear')),
          ),

          // Share Score
          if (widget.onShareScore != null)
            TextButton.icon(
              onPressed: () {
                final score = _calculateScore();
                widget.onShareScore!(score, '${_label('crossword_title', 'Crossword')} #${puzzle.puzzleId}');
              },
              icon: Icon(Icons.share_rounded, size: 18, color: primary),
              label: Text(_label('share', 'Share')),
            ),
        ],
      ),
    );
  }

  Widget _buildSoftKeypad(BuildContext context, Color primary) {
    final theme = Theme.of(context);

    // QWERTY layout rows
    const row1 = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
    const row2 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
    const row3 = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];

    final extraLetters = widget.extraKeypadLetters ?? ['Ö', 'Ŵ'];

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Extra special characters bar (e.g. Nias Ö, Ŵ)
          if (extraLetters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: extraLetters.map((char) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: SizedBox(
                      width: 52,
                      height: 36,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          if (_selectedX != null && _selectedY != null) {
                            _saveAnswer(_selectedX!, _selectedY!, char);
                          }
                        },
                        child: Text(
                          char,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Row 1
          _buildKeypadRow(row1),
          const SizedBox(height: 4),

          // Row 2
          _buildKeypadRow(row2),
          const SizedBox(height: 4),

          // Row 3 with Backspace
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...row3.map((letter) => _buildKey(letter)),
              // Backspace key
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: SizedBox(
                  width: 44,
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: theme.colorScheme.onSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      elevation: 1,
                    ),
                    onPressed: _backspace,
                    child: const Icon(Icons.backspace_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: letters.map((l) => _buildKey(l)).toList(),
    );
  }

  Widget _buildKey(String letter) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: SizedBox(
        width: 32,
        height: 38,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 1,
          ),
          onPressed: () {
            if (_selectedX != null && _selectedY != null) {
              _saveAnswer(_selectedX!, _selectedY!, letter);
            }
          },
          child: Text(
            letter,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
