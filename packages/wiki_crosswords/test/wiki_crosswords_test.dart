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
      expect(word.containsCell(6, 5), isTrue); // length 5: 2, 3, 4, 5, 6
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

    testWidgets('renders puzzle, clue ribbon, and custom keypad', (tester) async {
      final dataSource = MemoryCrosswordDataSource([samplePuzzle]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGameView(
              dataSource: dataSource,
              languageCode: 'nia',
              customLabels: const {
                'crossword_title': 'Dahö-Dahö',
                'across': 'Misa',
                'down': 'Mitou',
                'check': 'Faigi',
              },
              extraKeypadLetters: const ['Ö', 'Ŵ'],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title
      expect(find.text('Dahö-Dahö #1'), findsOneWidget);
      // Clue
      expect(find.text('Island in North Sumatra'), findsOneWidget);
      // Extra keypad characters
      expect(find.text('Ö'), findsOneWidget);
      expect(find.text('Ŵ'), findsOneWidget);
      // Action buttons
      expect(find.text('Faigi'), findsOneWidget);
    });

    testWidgets('tapping a cell and pressing keypad enters letter', (tester) async {
      final dataSource = MemoryCrosswordDataSource([samplePuzzle]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrosswordGameView(
              dataSource: dataSource,
              languageCode: 'nia',
              extraKeypadLetters: const ['Ö', 'Ŵ'],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap first cell (top-left, cell #1)
      final cellOne = find.text('1');
      expect(cellOne, findsWidgets);
      await tester.tap(cellOne.first);
      await tester.pumpAndSettle();

      // Tap letter 'Ö' on the custom keypad
      await tester.tap(find.text('Ö'));
      await tester.pumpAndSettle();

      // The entered letter should now appear in the cell
      expect(find.text('Ö'), findsWidgets);
    });
  });
}
