import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiki_newsletter_reader/wiki_newsletter_reader.dart';

void main() {
  group('NewsletterConfig and NewsletterEdition tests', () {
    test('NewsletterConfig constructs valid URLs and cache keys', () {
      const config = NewsletterConfig(
        langCode: 'nia',
        project: 'wikipedia',
        pageTitle: 'Wikipedia:Turia',
      );

      expect(config.domain, equals('nia.wikipedia.org'));
      expect(config.pageUrl, equals('https://nia.wikipedia.org/wiki/Wikipedia:Turia'));
      expect(config.cacheKey, contains('nia.wikipedia.org'));

      const customConfig = NewsletterConfig(
        langCode: 'jv',
        project: 'wikipedia',
        pageTitle: 'Warta Pawarta',
        customDomain: 'jv.custom.org',
      );
      expect(customConfig.domain, equals('jv.custom.org'));
      expect(customConfig.pageUrl, equals('https://jv.custom.org/wiki/Warta_Pawarta'));
    });

    test('NewsletterEdition serializes and restores JSON with sections correctly', () {
      final now = DateTime.now();
      final edition = NewsletterEdition(
        pageTitle: 'Wikipedia:Turia',
        htmlContent: '<div>Warta Sura</div>',
        heroImageUrl: 'https://example.com/cover.jpg',
        images: ['cover.jpg', 'pic.png'],
        sections: const [
          NewsletterSectionItem(id: 'Li_Famasao', title: 'Li Famasao', level: 2),
          NewsletterSectionItem(id: 'Halowo', title: 'Halöŵö Komunitas', level: 2),
          NewsletterSectionItem(id: 'Sub', title: 'Sub section', level: 3),
        ],
        isOfflineCache: false,
        lastFetched: now,
      );

      final json = edition.toJson();
      final restored = NewsletterEdition.fromJson(json, isOfflineCache: true);

      expect(restored.pageTitle, equals('Wikipedia:Turia'));
      expect(restored.htmlContent, equals('<div>Warta Sura</div>'));
      expect(restored.heroImageUrl, equals('https://example.com/cover.jpg'));
      expect(restored.images, contains('cover.jpg'));
      expect(restored.sections.length, equals(3));
      expect(restored.sections[0].title, equals('Li Famasao'));
      expect(restored.sections[2].level, equals(3));
      expect(restored.isOfflineCache, isTrue);
    });

    test('cleanWikimediaImageUrl normalizes protocol and thumbnail size to 500px', () {
      const raw = '//thumb.wikimedia.org/wikipedia/commons/thumb/c/c5/Pic.jpg/120px-Pic.jpg?utm_source=nia.wikipedia.org&utm_campaign=parser';
      final cleaned = cleanWikimediaImageUrl(raw, defaultWidth: 500);
      expect(cleaned, equals('https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c5/Pic.jpg/500px-Pic.jpg'));
    });

    test('extractHeroImageUrl extracts first non-icon image from HTML or images', () {
      const html = '<div><p>Intro</p><img src="//thumb.wikimedia.org/wikipedia/commons/thumb/c/c5/Sculpture.jpg/120px-Sculpture.jpg"><p>More</p></div>';
      final hero = extractHeroImageUrl(html, []);
      expect(hero, equals('https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c5/Sculpture.jpg/500px-Sculpture.jpg'));

      const htmlWithIcon = '<div><img src="//commons/thumb/gnome-icon.png/50px-gnome.png"><p>No photo</p></div>';
      final fallback = extractHeroImageUrl(htmlWithIcon, ['CommunityPhoto.jpg']);
      expect(fallback, contains('Special:FilePath/CommunityPhoto.jpg'));
      expect(fallback, contains('width=500'));
    });
  });

  group('NewsletterFloatingToc widget tests', () {
    testWidgets('renders TOC pill and expands upon tap', (tester) async {
      final keys = {
        'sec1': GlobalKey(),
        'sec2': GlobalKey(),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(key: keys['sec1'], height: 200, child: const Text('Section 1')),
                        SizedBox(key: keys['sec2'], height: 200, child: const Text('Section 2')),
                      ],
                    ),
                  ),
                  NewsletterFloatingToc(
                    sections: const [
                      NewsletterSectionItem(id: 'sec1', title: 'First Section', level: 2),
                      NewsletterSectionItem(id: 'sec2', title: 'Second Section', level: 3),
                    ],
                    accentColor: const Color(0xFF0891B2),
                    sectionKeys: keys,
                    tocLabel: 'Angolifa Zura',
                    closeLabel: 'Tutup',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify collapsed pill displays label and count badge
      expect(find.text('Angolifa Zura'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Angolifa Zura'));
      await tester.pumpAndSettle();

      // Verify sections are visible in expanded popover
      expect(find.text('First Section'), findsOneWidget);
      expect(find.text('Second Section'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      // Tap on section to scroll and collapse
      await tester.tap(find.text('First Section'));
      await tester.pumpAndSettle();

      // Verify popover collapsed back to pill
      expect(find.text('Angolifa Zura'), findsOneWidget);
    });
  });
}
