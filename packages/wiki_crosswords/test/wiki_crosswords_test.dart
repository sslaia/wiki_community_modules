import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiki_crosswords/wiki_crosswords.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Crossword Models Tests', () {
    test('parses CrosswordWord from JSON', () {
      final json = {
        'word': 'BÖBÖI',
        'page_title': 'böböi',
        'clue': 'Idanö soroi ba dögi-tögi sigide-ide ba guli',
        'x': 2,
        'y': 5,
        'direction': 'across',
      };

      final word = CrosswordWord.fromJson(json);

      expect(word.word, 'BÖBÖI');
      expect(word.pageTitle, 'böböi');
      expect(word.x, 2);
      expect(word.y, 5);
      expect(word.direction, 'across');
      expect(word.containsCell(2, 5), isTrue);
      expect(word.containsCell(6, 5), isTrue);
      expect(word.containsCell(7, 5), isFalse);
      expect(word.cellIndex(2, 5), 0);
      expect(word.cellIndex(4, 5), 2);
    });

    test('parses CrosswordPuzzle with words from JSON', () {
      final json = {
        'puzzle_id': 42,
        'grid_size': 10,
        'words': [
          {
            'word': 'OMOHADA',
            'page_title': 'omo hada',
            'clue': 'Traditional house',
            'x': 0,
            'y': 0,
            'direction': 'across',
          },
          {
            'word': 'ONO',
            'page_title': 'ono',
            'clue': 'Child',
            'x': 0,
            'y': 0,
            'direction': 'down',
          }
        ],
      };

      final puzzle = CrosswordPuzzle.fromJson(json);

      expect(puzzle.puzzleId, 42);
      expect(puzzle.gridSize, 10);
      expect(puzzle.words.length, 2);
      expect(puzzle.words.first.word, 'OMOHADA');
      expect(puzzle.words.last.word, 'ONO');
    });
  });

  group('CrosswordGameView Widget Tests', () {
    final samplePuzzle = CrosswordPuzzle(
      puzzleId: 1,
      gridSize: 5,
      words: const [
        CrosswordWord(
          word: 'NIAS',
          pageTitle: 'nias',
          clue: 'Island in North Sumatra',
          x: 0,
          y: 0,
          direction: 'across',
        ),
        CrosswordWord(
          word: 'NAHA',
          pageTitle: 'naha',
          clue: 'Place or container',
          x: 0,
          y: 0,
          direction: 'down',
        ),
      ],
    );

    testWidgets('renders segmented navigation tabs and daily crossword grid', (tester) async {
      final dataSource = MemoryCrosswordDataSource([samplePuzzle]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGameView(
              dataSource: dataSource,
              languageCode: 'nia',
              customLabels: const {
                'crossword_daily': 'Dahö-Dahö',
                'crossword_favorites': 'Somasido',
                'crossword_scoreboard': 'Papan Skor',
                'across': 'Misa',
                'down': 'Mitou',
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Segmented Tabs
      expect(find.text('Dahö-Dahö'), findsWidgets);
      expect(find.text('Somasido'), findsOneWidget);
      expect(find.text('Papan Skor'), findsOneWidget);

      // Clue card
      expect(find.text('Island in North Sumatra'), findsOneWidget);
    });

    testWidgets('tapping cell renders TextField and typing sets answer', (tester) async {
      final dataSource = MemoryCrosswordDataSource([samplePuzzle]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGameView(
              dataSource: dataSource,
              languageCode: 'nia',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap top-left playable cell (starts at 0,0 where word starts)
      final cellOne = find.text('1');
      expect(cellOne, findsWidgets);
      await tester.tap(cellOne.first);
      await tester.pumpAndSettle();

      // A TextField should now be focused in the selected cell
      expect(find.byType(TextField), findsOneWidget);

      // Enter character
      await tester.enterText(find.byType(TextField), 'N');
      await tester.pumpAndSettle();

      // Cell text should display 'N'
      expect(find.text('N'), findsWidgets);
    });

    testWidgets('switching to Scoreboard tab renders ScoreboardWidget', (tester) async {
      final dataSource = MemoryCrosswordDataSource([samplePuzzle]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGameView(
              dataSource: dataSource,
              languageCode: 'en',
              customLabels: const {
                'crossword_daily': 'Daily',
                'crossword_favorites': 'Favorites',
                'crossword_scoreboard': 'Scoreboard',
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Scoreboard tab
      await tester.tap(find.text('Scoreboard'));
      await tester.pumpAndSettle();

      expect(find.byType(ScoreboardWidget), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
    });
  });
}
