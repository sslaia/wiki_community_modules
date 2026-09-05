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

    test('NewsletterEdition serializes and restores JSON correctly', () {
      final now = DateTime.now();
      final edition = NewsletterEdition(
        pageTitle: 'Wikipedia:Turia',
        htmlContent: '<div>Warta Sura</div>',
        heroImageUrl: 'https://example.com/cover.jpg',
        images: ['cover.jpg', 'pic.png'],
        isOfflineCache: false,
        lastFetched: now,
      );

      final json = edition.toJson();
      final restored = NewsletterEdition.fromJson(json, isOfflineCache: true);

      expect(restored.pageTitle, equals('Wikipedia:Turia'));
      expect(restored.htmlContent, equals('<div>Warta Sura</div>'));
      expect(restored.heroImageUrl, equals('https://example.com/cover.jpg'));
      expect(restored.images, contains('cover.jpg'));
      expect(restored.isOfflineCache, isTrue);
    });
  });
}
