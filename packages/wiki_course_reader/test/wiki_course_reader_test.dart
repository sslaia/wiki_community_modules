import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiki_course_reader/wiki_course_reader.dart';

class MockCourseCacheDelegate implements CourseCacheDelegate {
  final Map<String, CoursePageContent> store = {};

  @override
  Future<CoursePageContent?> loadCached(String key) async => store[key];

  @override
  Future<void> saveCached(String key, CoursePageContent content) async {
    store[key] = content;
  }
}

void main() {
  group('CourseConfig and CoursePageContent tests', () {
    test('CourseConfig resolves default and custom domains correctly', () {
      const config = CourseConfig(
        langCode: 'nia',
        project: 'wiktionary',
        pageTitle: 'Wikikamus:Sulu',
      );

      expect(config.domain, equals('nia.wiktionary.org'));
      expect(config.pageUrl, equals('https://nia.wiktionary.org/wiki/Wikikamus:Sulu'));
      expect(config.cacheKey, contains('nia.wiktionary.org'));

      const customConfig = CourseConfig(
        langCode: 'jv',
        project: 'wikipedia',
        pageTitle: 'Sinau Basa',
        customDomain: 'custom.wiki.org',
      );
      expect(customConfig.domain, equals('custom.wiki.org'));
      expect(customConfig.pageUrl, equals('https://custom.wiki.org/wiki/Sinau_Basa'));
    });

    test('CoursePageContent serializes and deserializes JSON correctly', () {
      final now = DateTime.now();
      final content = CoursePageContent(
        pageTitle: 'Wikikamus:Sulu',
        htmlContent: '<p>Lala wamaheolu</p>',
        images: ['Image1.jpg'],
        isOfflineCache: false,
        lastFetched: now,
      );

      final json = content.toJson();
      final restored = CoursePageContent.fromJson(json, isOfflineCache: true);

      expect(restored.pageTitle, equals('Wikikamus:Sulu'));
      expect(restored.htmlContent, equals('<p>Lala wamaheolu</p>'));
      expect(restored.images, contains('Image1.jpg'));
      expect(restored.isOfflineCache, isTrue);
    });

    test('cleanWikimediaImageUrl normalizes protocol and thumbnail size', () {
      const raw = '//thumb.wikimedia.org/wikipedia/commons/thumb/7/78/Pic.jpg/250px-Pic.jpg?utm_source=test';
      final cleaned = cleanWikimediaImageUrl(raw, defaultWidth: 500);
      expect(cleaned, equals('https://thumb.wikimedia.org/wikipedia/commons/thumb/7/78/Pic.jpg/500px-Pic.jpg'));
    });

    test('extractHeroImageUrl extracts first non-icon image from HTML or images', () {
      const html = '<div><p>Text</p><img src="//upload.wikimedia.org/thumb/a/a1/Hero.jpg/300px-Hero.jpg"><p>More</p></div>';
      final hero = extractHeroImageUrl(html, []);
      expect(hero, equals('https://upload.wikimedia.org/thumb/a/a1/Hero.jpg/500px-Hero.jpg'));

      final fallback = extractHeroImageUrl('<p>No image</p>', ['CourseArt.png']);
      expect(fallback, contains('Special:FilePath/CourseArt.png'));
    });
    test('extractFirstH2Title and removeFirstH2 work accurately', () {
      const sampleHtml = '<div class="course-header">HEAD</div><div class="lesson-title"><div class="mw-heading"><h2>Wa\x27omasigu wa\x27omasimö</h2></div></div><blockquote>Text</blockquote>';
      final title = extractFirstH2Title(sampleHtml);
      expect(title, equals("Wa'omasigu wa'omasimö"));

      final cleaned = removeFirstH2(sampleHtml);
      expect(cleaned, isNot(contains('<h2>')));
      expect(cleaned, isNot(contains('lesson-title')));
      expect(cleaned, contains('<blockquote>Text</blockquote>'));
    });
  });

  group('CourseReaderScreen widget tests', () {
    testWidgets('Renders SliverAppBar, hero title, and floating action bar with Refresh and Share', (WidgetTester tester) async {
      const config = CourseConfig(
        langCode: 'nia',
        project: 'wiktionary',
        pageTitle: 'Wikikamus:Sulu',
      );

      final cache = MockCourseCacheDelegate();
      await cache.saveCached(
        config.cacheKey,
        CoursePageContent(
          pageTitle: 'Wikikamus:Sulu',
          htmlContent: '<blockquote>Abu dödögu</blockquote><p>Paragraph text</p>',
          images: [],
          isOfflineCache: false,
          lastFetched: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CourseReaderScreen(
            config: config,
            cacheDelegate: cache,
            title: "Famaha'ö Li Niha",
            subtitle: 'Wikikamus:Sulu',
            accentColor: const Color(0xFFD97706),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify SliverAppBar and title
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.text("Famaha'ö Li Niha"), findsOneWidget);

      // Verify Floating Action Bar with Refresh and Share buttons
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });
  });
}
