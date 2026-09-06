import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/crossword_models.dart';

class CrosswordGrid extends StatefulWidget {
  final CrosswordPuzzle puzzle;
  final Map<String, String> userAnswers;
  final void Function(int x, int y, String letter) onAnswerChanged;
  final bool isFillable;
  final bool isTemporarilyRevealed;
  final Map<String, String>? customLabels;
  final Color? primaryColor;
  final Color? accentColor;
  final void Function(String word, String pageTitle)? onWordDefinitionTap;

  const CrosswordGrid({
    super.key,
    required this.puzzle,
    required this.userAnswers,
    required this.onAnswerChanged,
    this.isFillable = true,
    this.isTemporarilyRevealed = false,
    this.customLabels,
    this.primaryColor,
    this.accentColor,
    this.onWordDefinitionTap,
  });

  @override
  State<CrosswordGrid> createState() => _CrosswordGridState();
}

class _CrosswordGridState extends State<CrosswordGrid> {
  int? selectedX;
  int? selectedY;
  CrosswordWord? selectedWord;
  late final ScrollController _clueScrollController = ScrollController();

  @override
  void dispose() {
    _clueScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CrosswordGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.puzzle.puzzleId != widget.puzzle.puzzleId) {
      setState(() {
        selectedX = null;
        selectedY = null;
        selectedWord = null;
      });
    }
  }

  String _label(String key, String defaultValue) {
    if (widget.customLabels != null && widget.customLabels!.containsKey(key)) {
      return widget.customLabels![key]!;
    }
    return defaultValue;
  }

  bool _isWordWrong(CrosswordWord word, Map<String, String> userAnswers) {
    for (int i = 0; i < word.word.length; i++) {
      int cx = word.direction == 'across' ? word.x + i : word.x;
      int cy = word.direction == 'down' ? word.y + i : word.y;
      final answer = userAnswers['$cx,$cy'];
      if (answer != null && answer.isNotEmpty) {
        if (answer.toUpperCase() != word.word[i].toUpperCase()) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isCellInWrongWord(
    int x,
    int y,
    List<CrosswordWord> words,
    Map<String, String> userAnswers,
  ) {
    for (var word in words) {
      bool isPart = false;
      if (word.direction == 'across') {
        if (y == word.y && x >= word.x && x < word.x + word.word.length) {
          isPart = true;
        }
      } else {
        if (x == word.x && y >= word.y && y < word.y + word.word.length) {
          isPart = true;
        }
      }
      if (isPart && _isWordWrong(word, userAnswers)) {
        return true;
      }
    }
    return false;
  }

  bool _isWordWrongOrIncomplete(CrosswordWord word, Map<String, String> userAnswers) {
    for (int i = 0; i < word.word.length; i++) {
      int cx = word.direction == 'across' ? word.x + i : word.x;
      int cy = word.direction == 'down' ? word.y + i : word.y;
      final answer = userAnswers['$cx,$cy'];
      if (answer == null || answer.isEmpty) {
        return true;
      }
      if (answer.toUpperCase() != word.word[i].toUpperCase()) {
        return true;
      }
    }
    return false;
  }

  bool _isCellInWrongOrIncompleteWord(
    int x,
    int y,
    List<CrosswordWord> words,
    Map<String, String> userAnswers,
  ) {
    for (var word in words) {
      bool isPart = false;
      if (word.direction == 'across') {
        if (y == word.y && x >= word.x && x < word.x + word.word.length) {
          isPart = true;
        }
      } else {
        if (x == word.x && y >= word.y && y < word.y + word.word.length) {
          isPart = true;
        }
      }
      if (isPart && _isWordWrongOrIncomplete(word, userAnswers)) {
        return true;
      }
    }
    return false;
  }

  void _handleLockedCellTap(BuildContext context, int x, int y) {
    final matchingWords = widget.puzzle.words.where((word) {
      if (word.direction == 'across') {
        return y == word.y && x >= word.x && x < word.x + word.word.length;
      } else {
        return x == word.x && y >= word.y && y < word.y + word.word.length;
      }
    }).toList();

    if (matchingWords.isEmpty) return;

    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (builderContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _label('reference', 'Reference').toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _label('crossword_wiktionary_ref', 'Wiktionary Reference'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: matchingWords.length,
                  itemBuilder: (context, index) {
                    final word = matchingWords[index];
                    final wordIndex = widget.puzzle.words.indexOf(word) + 1;
                    final directionLabel = word.direction == 'across'
                        ? _label('across', 'Across')
                        : _label('down', 'Down');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  size: 20,
                                  color: primary,
                                ),
                              ),
                              title: Text(
                                '$wordIndex. ${word.pageTitle} ($directionLabel)',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  word.clue,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 12,
                              ),
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: primary,
                                  minimumSize: const Size.fromHeight(40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  if (widget.onWordDefinitionTap != null) {
                                    widget.onWordDefinitionTap!(
                                      word.word,
                                      word.pageTitle,
                                    );
                                    return;
                                  }
                                  final pageTitle = Uri.encodeComponent(word.pageTitle);
                                  final url = Uri.parse(
                                    'https://nia.wiktionary.org/wiki/$pageTitle',
                                  );
                                  try {
                                    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                                  } catch (_) {}
                                },
                                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                label: Text(_label('crossword_open_wiktionary', 'Open in Wiktionary')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleCellTap(int x, int y) {
    setState(() {
      selectedX = x;
      selectedY = y;

      List<CrosswordWord> matchingWords = [];
      for (var word in widget.puzzle.words) {
        if (word.direction == 'across') {
          if (y == word.y && x >= word.x && x < word.x + word.word.length) {
            matchingWords.add(word);
          }
        } else {
          if (x == word.x && y >= word.y && y < word.y + word.word.length) {
            matchingWords.add(word);
          }
        }
      }

      if (matchingWords.isNotEmpty) {
        if (matchingWords.length == 1) {
          selectedWord = matchingWords.first;
        } else {
          if (selectedWord != null && matchingWords.contains(selectedWord)) {
            selectedWord = matchingWords.firstWhere((w) => w != selectedWord);
          } else {
            selectedWord = matchingWords.first;
          }
        }
      } else {
        selectedWord = null;
      }
    });

    if (selectedWord != null) {
      _scrollToActiveClue();
    }
  }

  void _moveToNextCell() {
    if (selectedWord == null || selectedX == null || selectedY == null) return;

    setState(() {
      if (selectedWord!.direction == 'across') {
        if (selectedX! < selectedWord!.x + selectedWord!.word.length - 1) {
          selectedX = selectedX! + 1;
        }
      } else {
        if (selectedY! < selectedWord!.y + selectedWord!.word.length - 1) {
          selectedY = selectedY! + 1;
        }
      }
    });
  }

  void _selectWordFromClueCard(CrosswordWord word) {
    setState(() {
      selectedWord = word;

      int targetX = word.x;
      int targetY = word.y;

      for (int i = 0; i < word.word.length; i++) {
        int cx = word.direction == 'across' ? word.x + i : word.x;
        int cy = word.direction == 'down' ? word.y + i : word.y;
        final currentAnswer = widget.userAnswers['$cx,$cy'];
        if (currentAnswer == null || currentAnswer.isEmpty) {
          targetX = cx;
          targetY = cy;
          break;
        }
      }

      selectedX = targetX;
      selectedY = targetY;
    });

    _scrollToActiveClue();
  }

  void _scrollToActiveClue() {
    if (selectedWord == null) return;
    final idx = widget.puzzle.words.indexOf(selectedWord!);
    if (idx != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_clueScrollController.hasClients) {
          const cardWidth = 228.0;
          _clueScrollController.animateTo(
            idx * cardWidth,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Widget _buildPermanentClueCard(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final words = widget.puzzle.words;

    return Container(
      height: 105,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        controller: _clueScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          final wordNum = index + 1;
          final isSelected = selectedWord == word;
          final directionLabel = word.direction == 'across'
              ? _label('across', 'Across')
              : _label('down', 'Down');

          return GestureDetector(
            onTap: () => _selectWordFromClueCard(word),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 220,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: 0.15)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? primary
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: isSelected
                            ? primary
                            : theme.colorScheme.secondaryContainer,
                        child: Text(
                          '$wordNum',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primary.withValues(alpha: 0.18)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          directionLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? primary
                                : theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      word.clue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        height: 1.25,
                      ),
                      maxLines: 3,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final size = widget.puzzle.gridSize;

    List<List<String?>> grid = List.generate(
      size,
      (_) => List.generate(size, (_) => null),
    );
    Map<String, int> wordNumbers = {};
    Map<String, String> correctMap = {};

    for (var i = 0; i < widget.puzzle.words.length; i++) {
      var word = widget.puzzle.words[i];
      wordNumbers['${word.x},${word.y}'] = i + 1;

      for (int j = 0; j < word.word.length; j++) {
        int cx = word.direction == 'across' ? word.x + j : word.x;
        int cy = word.direction == 'down' ? word.y + j : word.y;

        if (cx < size && cy < size) {
          correctMap['$cx,$cy'] = word.word[j].toUpperCase();
          final isCellWrong = _isCellInWrongOrIncompleteWord(
            cx,
            cy,
            widget.puzzle.words,
            widget.userAnswers,
          );
          if (widget.isTemporarilyRevealed && isCellWrong) {
            grid[cy][cx] = word.word[j].toUpperCase();
          } else {
            grid[cy][cx] = widget.userAnswers['$cx,$cy'] ?? '';
          }
        }
      }
    }

    return TapRegion(
      onTapOutside: (event) {
        FocusScope.of(context).unfocus();
        setState(() {
          selectedX = null;
          selectedY = null;
          selectedWord = null;
        });
      },
      child: Column(
        children: [
          _buildPermanentClueCard(context),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline,
                      width: 2,
                    ),
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size,
                      childAspectRatio: 1,
                    ),
                    itemCount: size * size,
                    itemBuilder: (context, index) {
                      int x = index % size;
                      int y = index ~/ size;
                      String? cellValue = grid[y][x];

                      bool isBlack = cellValue == null;
                      bool isSelected = selectedX == x && selectedY == y;
                      bool isPartOfSelectedWord = false;

                      if (selectedWord != null) {
                        if (selectedWord!.direction == 'across') {
                          if (y == selectedWord!.y &&
                              x >= selectedWord!.x &&
                              x < selectedWord!.x + selectedWord!.word.length) {
                            isPartOfSelectedWord = true;
                          }
                        } else {
                          if (x == selectedWord!.x &&
                              y >= selectedWord!.y &&
                              y < selectedWord!.y + selectedWord!.word.length) {
                            isPartOfSelectedWord = true;
                          }
                        }
                      }

                      if (isBlack) {
                        return GestureDetector(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              selectedX = null;
                              selectedY = null;
                              selectedWord = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                                width: 0.5,
                              ),
                            ),
                          ),
                        );
                      }

                      bool isWrong = false;
                      bool isWrongOrIncomplete = false;
                      if (cellValue.isNotEmpty) {
                        isWrong = _isCellInWrongWord(
                          x,
                          y,
                          widget.puzzle.words,
                          widget.userAnswers,
                        );
                      }
                      isWrongOrIncomplete = _isCellInWrongOrIncompleteWord(
                        x,
                        y,
                        widget.puzzle.words,
                        widget.userAnswers,
                      );

                      final cellColor = isSelected
                          ? primary.withValues(alpha: 0.25)
                          : (isPartOfSelectedWord
                              ? primary.withValues(alpha: 0.10)
                              : theme.colorScheme.surface);

                      final isCellRevealed = widget.isTemporarilyRevealed && isWrongOrIncomplete;
                      final cellTextColor = isCellRevealed
                          ? primary
                          : isWrong
                              ? theme.colorScheme.error
                              : (isSelected || isPartOfSelectedWord
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface);

                      return GestureDetector(
                        onTap: () {
                          if (widget.isFillable && !widget.isTemporarilyRevealed) {
                            _handleCellTap(x, y);
                          } else if (!widget.isFillable) {
                            _handleLockedCellTap(context, x, y);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: cellColor,
                            border: Border.all(
                              color: isSelected
                                  ? primary
                                  : theme.colorScheme.outline.withValues(alpha: 0.5),
                              width: isSelected ? 1.5 : 0.5,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (wordNumbers.containsKey('$x,$y'))
                                Positioned(
                                  top: 2,
                                  left: 2,
                                  child: Text(
                                    wordNumbers['$x,$y'].toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              Center(
                                child: isSelected && !widget.isTemporarilyRevealed
                                    ? TextField(
                                        autofocus: true,
                                        textAlign: TextAlign.center,
                                        maxLength: 1,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: cellTextColor,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          counterText: '',
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (val) {
                                          widget.onAnswerChanged(x, y, val);
                                          _moveToNextCell();
                                        },
                                      )
                                    : Text(
                                        cellValue,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: cellTextColor,
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
            ),
          ),
        ],
      ),
    );
  }
}
