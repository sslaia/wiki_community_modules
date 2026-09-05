/// Model representing a single word clue in a crossword puzzle.
class CrosswordWord {
  final String word;
  final String pageTitle;
  final String clue;
  final int x;
  final int y;
  final String direction; // 'across' or 'down'

  const CrosswordWord({
    required this.word,
    required this.pageTitle,
    required this.clue,
    required this.x,
    required this.y,
    required this.direction,
  });

  factory CrosswordWord.fromJson(Map<String, dynamic> json) => CrosswordWord(
        word: (json['word'] as String?)?.toUpperCase().trim() ?? '',
        pageTitle: json['page_title'] as String? ?? json['word'] as String? ?? '',
        clue: json['clue'] as String? ?? '',
        x: json['x'] as int? ?? 0,
        y: json['y'] as int? ?? 0,
        direction: json['direction'] as String? ?? 'across',
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'page_title': pageTitle,
        'clue': clue,
        'x': x,
        'y': y,
        'direction': direction,
      };

  bool containsCell(int cx, int cy) {
    if (direction == 'across') {
      return cy == y && cx >= x && cx < x + word.length;
    } else {
      return cx == x && cy >= y && cy < y + word.length;
    }
  }

  int cellIndex(int cx, int cy) {
    if (!containsCell(cx, cy)) return -1;
    return direction == 'across' ? (cx - x) : (cy - y);
  }
}

/// Model representing a complete crossword puzzle board with its words.
class CrosswordPuzzle {
  final int puzzleId;
  final int gridSize;
  final List<CrosswordWord> words;

  const CrosswordPuzzle({
    required this.puzzleId,
    required this.gridSize,
    required this.words,
  });

  factory CrosswordPuzzle.fromJson(Map<String, dynamic> json) => CrosswordPuzzle(
        puzzleId: json['puzzle_id'] as int? ?? json['id'] as int? ?? 1,
        gridSize: json['grid_size'] as int? ?? 10,
        words: (json['words'] as List<dynamic>? ?? [])
            .map((w) => CrosswordWord.fromJson(w as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'puzzle_id': puzzleId,
        'grid_size': gridSize,
        'words': words.map((w) => w.toJson()).toList(),
      };
}
