import 'package:flutter_test/flutter_test.dart';
import 'package:wiki_course_reader/wiki_course_reader.dart';

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
  });
}
