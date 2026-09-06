import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiki_media_gallery/wiki_media_gallery.dart';

void main() {
  group('GalleryItem Model Tests', () {
    test('parses from standard JSON format', () {
      final json = {
        'id': 'item-1',
        'title': 'Omo Hada Traditional House',
        'imageUrl': 'https://example.org/omohada.jpg',
        'thumbnailUrl': 'https://example.org/omohada_thumb.jpg',
        'category': 'architecture',
        'description': 'Traditional earthquake-resistant architecture',
        'author': 'Museum Pusaka Nias',
        'license': 'CC BY-SA 4.0',
      };

      final item = GalleryItem.fromJson(json);

      expect(item.id, 'item-1');
      expect(item.title, 'Omo Hada Traditional House');
      expect(item.imageUrl, 'https://example.org/omohada.jpg');
      expect(item.thumbnailUrl, 'https://example.org/omohada_thumb.jpg');
      expect(item.category, 'architecture');
      expect(item.description, 'Traditional earthquake-resistant architecture');
      expect(item.author, 'Museum Pusaka Nias');
      expect(item.license, 'CC BY-SA 4.0');
    });

    test('resolves Wikimedia Commons fileName automatically', () {
      final json = {
        'title': "Motif Ni'ohulayo",
        'fileName': "File:Motif_Ni'ohulayo.jpg",
        'category': 'arts',
        'description': 'Lewi Zega drawing',
      };

      final item = GalleryItem.fromJson(json);

      expect(item.id, "File:Motif_Ni'ohulayo.jpg");
      expect(item.title, "Motif Ni'ohulayo");
      expect(
        item.imageUrl,
        "https://commons.wikimedia.org/wiki/Special:FilePath/Motif_Ni'ohulayo.jpg",
      );
      expect(
        item.thumbnailUrl,
        "https://commons.wikimedia.org/wiki/Special:FilePath/Motif_Ni'ohulayo.jpg?width=500",
      );
      expect(item.category, 'arts');
    });

    test('toJson produces correct map structure', () {
      const item = GalleryItem(
        id: '123',
        title: 'Megalith Behu',
        imageUrl: 'https://example.org/behu.jpg',
        category: 'megalith',
        author: 'Archaeologist',
      );

      final map = item.toJson();
      expect(map['id'], '123');
      expect(map['title'], 'Megalith Behu');
      expect(map['imageUrl'], 'https://example.org/behu.jpg');
      expect(map['category'], 'megalith');
      expect(map['author'], 'Archaeologist');
    });
  });

  group('MediaGalleryCarousel Widget Tests', () {
    final sampleItems = [
      const GalleryItem(
        id: '1',
        title: 'Omo Sebua',
        imageUrl: '',
        category: 'architecture',
        description: 'Chief house',
      ),
      const GalleryItem(
        id: '2',
        title: 'Maena Dance',
        imageUrl: '',
        category: 'dance',
        description: 'Traditional round dance',
      ),
      const GalleryItem(
        id: '3',
        title: 'Ni’obiku Motif',
        imageUrl: '',
        category: 'arts',
        description: 'Traditional wood carving',
      ),
    ];

    testWidgets('renders category chips and items in carousel mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaGalleryCarousel(
              items: sampleItems,
              categoryLabels: const {
                'architecture': 'Lareŵa',
                'dance': 'Fanari',
                'arts': 'Tomosa',
              },
              allLabel: 'Fefu',
            ),
          ),
        ),
      );

      // Verify Category Chips
      expect(find.text('Fefu'), findsOneWidget);
      expect(find.text('Lareŵa'), findsOneWidget);
      expect(find.text('Fanari'), findsOneWidget);
      expect(find.text('Tomosa'), findsOneWidget);

      // Verify item title is present
      expect(find.text('Omo Sebua'), findsOneWidget);
    });

    testWidgets('filters items when category chip is selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaGalleryCarousel(
              items: sampleItems,
              categoryLabels: const {
                'architecture': 'Lareŵa',
                'dance': 'Fanari',
                'arts': 'Tomosa',
              },
            ),
          ),
        ),
      );

      // Tap 'Fanari' (dance) chip
      await tester.tap(find.text('Fanari'));
      await tester.pumpAndSettle();

      // Now the active item should be 'Maena Dance'
      expect(find.text('Maena Dance'), findsOneWidget);
      expect(find.text('Omo Sebua'), findsNothing);
    });

    testWidgets('toggles between Carousel and Grid views', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaGalleryCarousel(
              items: sampleItems,
            ),
          ),
        ),
      );

      // Mode toggle button should switch to grid
      final toggleButton = find.byIcon(Icons.grid_view_rounded);
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Now in Grid mode: icons toggle should be view_carousel_rounded
      expect(find.byIcon(Icons.view_carousel_rounded), findsOneWidget);
      // In grid mode all items are visible in grid
      expect(find.text('Omo Sebua'), findsOneWidget);
      expect(find.text('Maena Dance'), findsOneWidget);
      expect(find.text('Ni’obiku Motif'), findsOneWidget);
    });
  });
}
