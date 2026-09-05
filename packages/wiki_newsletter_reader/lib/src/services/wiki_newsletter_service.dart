import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/newsletter_models.dart';

class WikiNewsletterService {
  static final NewsletterCacheDelegate _defaultCache = DefaultSharedPreferencesNewsletterCache();

  /// Fetches the newsletter edition HTML from the specified Wikimedia endpoint.
  static Future<NewsletterEdition> fetchNewsletter(
    NewsletterConfig config, {
    bool forceRefresh = false,
    NewsletterCacheDelegate? cacheDelegate,
  }) async {
    final cache = cacheDelegate ?? _defaultCache;

    if (!forceRefresh) {
      final cached = await cache.loadCached(config.cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final endpoint = Uri.parse(
      'https://${config.domain}/w/api.php?action=parse&page=${Uri.encodeComponent(config.pageTitle)}&format=json&prop=text|images&mobileformat=1&redirects=1',
    );

    try {
      final response = await http.get(
        endpoint,
        headers: {
          'User-Agent': config.userAgent,
          'Accept': 'application/json',
          if (forceRefresh) 'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final parse = decoded['parse'] as Map<String, dynamic>?;

        if (parse != null) {
          final rawText = (parse['text']?['*'] as String?) ?? '';
          final imagesList = (parse['images'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          final processedHtml = _sanitizeHtml(rawText, config.domain);

          String? heroImage = config.heroImageUrl;
          if (heroImage == null && imagesList.isNotEmpty) {
            final firstPhoto = imagesList.firstWhere(
              (img) {
                final lower = img.toLowerCase();
                return lower.endsWith('.jpg') ||
                    lower.endsWith('.jpeg') ||
                    lower.endsWith('.png') ||
                    lower.endsWith('.webp');
              },
              orElse: () => '',
            );
            if (firstPhoto.isNotEmpty) {
              heroImage =
                  'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(firstPhoto)}?width=1000';
            }
          }

          final result = NewsletterEdition(
            pageTitle: parse['title'] as String? ?? config.pageTitle,
            htmlContent: processedHtml,
            heroImageUrl: heroImage,
            images: imagesList,
            isOfflineCache: false,
            lastFetched: DateTime.now(),
          );

          await cache.saveCached(config.cacheKey, result);
          return result;
        }
      }
      throw Exception('Failed to load newsletter. HTTP ${response.statusCode}');
    } catch (e) {
      final cached = await cache.loadCached(config.cacheKey);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  static String _sanitizeHtml(String html, String domain) {
    var cleaned = html.replaceAll('src="//', 'src="https://');
    cleaned = cleaned.replaceAll('href="//', 'href="https://');
    cleaned = cleaned.replaceAll('href="/wiki/', 'href="https://$domain/wiki/');
    return cleaned;
  }
}
