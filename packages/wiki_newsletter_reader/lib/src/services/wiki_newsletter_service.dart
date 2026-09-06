import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/newsletter_models.dart';

/// Normalizes Wikimedia image URLs:
/// 1. Prepends https: to protocol-relative URLs (//upload...)
/// 2. Strips query parameters (e.g. ?utm_source=...)
/// 3. Normalizes thumbnail widths to high-res standard width (e.g. 500px)
String cleanWikimediaImageUrl(String rawSrc, {int defaultWidth = 500}) {
  var src = rawSrc.trim();
  if (src.isEmpty) return '';

  if (src.startsWith('//')) {
    src = 'https:$src';
  }

  // Strip query parameters
  if (src.contains('?')) {
    src = src.split('?').first;
  }

  // Replace &amp; with &
  src = src.replaceAll('&amp;', '&');

  // If thumbnail, scale to requested width
  if (src.contains('/thumb/')) {
    final parts = src.split('/');
    final last = parts.last;
    final match = RegExp(r'^\d+px-(.+)').firstMatch(last);
    if (match != null) {
      final originalName = match.group(1)!;
      parts.removeLast();
      parts.add('${defaultWidth}px-$originalName');
      src = parts.join('/');
    }
  }

  return src;
}

/// Extracts the first article image URL suitable for hero display.
String? extractHeroImageUrl(String htmlContent, List<String> images, {String? domain}) {
  // 1. Check for <img> tags in HTML
  final imgRegex = RegExp(r"""<img[^>]+src=["']([^"'>]+)["']""", caseSensitive: false);
  final matches = imgRegex.allMatches(htmlContent);
  for (final m in matches) {
    final rawSrc = m.group(1)!;
    final lower = rawSrc.toLowerCase();
    if (lower.contains('gnome') ||
        lower.contains('ambox') ||
        lower.contains('question_book') ||
        lower.contains('padlock') ||
        lower.contains('wikimedia-button') ||
        lower.contains('disambig') ||
        lower.contains('icon')) {
      continue;
    }
    final cleaned = cleanWikimediaImageUrl(rawSrc, defaultWidth: 500);
    if (cleaned.isNotEmpty) return cleaned;
  }

  // 2. Check images list if any
  for (final imgName in images) {
    final lower = imgName.toLowerCase();
    if (lower.contains('gnome') ||
        lower.contains('ambox') ||
        lower.contains('padlock') ||
        lower.contains('button') ||
        lower.contains('icon')) {
      continue;
    }
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp')) {
      return 'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(imgName)}?width=500';
    }
  }

  return null;
}

class WikiNewsletterService {
  static final NewsletterCacheDelegate _defaultCache = DefaultSharedPreferencesNewsletterCache();

  /// Fetches the newsletter edition using an online-first strategy:
  /// 1. Tries to fetch fresh content from the wiki network API (8-second timeout).
  /// 2. If network request succeeds, saves to cache and returns with isOfflineCache = false.
  /// 3. If network fails (timeout, socket error, offline), falls back to local cache if available and marks isOfflineCache = true.
  /// 4. If forceRefresh is requested, throws on network error without falling back silently.
  static Future<NewsletterEdition> fetchNewsletter(
    NewsletterConfig config, {
    bool forceRefresh = false,
    NewsletterCacheDelegate? cacheDelegate,
  }) async {
    final cache = cacheDelegate ?? _defaultCache;

    final endpoint = Uri.parse(
      'https://${config.domain}/w/api.php?action=parse&page=${Uri.encodeComponent(config.pageTitle)}&format=json&prop=text|images|sections&mobileformat=1&redirects=1',
    );

    try {
      final response = await http.get(
        endpoint,
        headers: {
          'User-Agent': config.userAgent,
          'Accept': 'application/json',
          if (forceRefresh) 'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final parse = decoded['parse'] as Map<String, dynamic>?;

        if (parse != null) {
          final rawText = (parse['text']?['*'] as String?) ?? '';
          final imagesList = (parse['images'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          // Extract sections from parse.sections if available
          var sectionsList = <NewsletterSectionItem>[];
          if (parse['sections'] != null) {
            final rawSections = parse['sections'] as List<dynamic>;
            sectionsList = rawSections
                .map((s) => NewsletterSectionItem.fromJson(s as Map<String, dynamic>))
                .where((s) => s.title.trim().isNotEmpty)
                .toList();
          }

          // Fallback regex section extraction from HTML if no sections in JSON
          if (sectionsList.isEmpty) {
            sectionsList = _extractSectionsFromHtml(rawText);
          }

          final processedHtml = _sanitizeHtml(rawText, config.domain);
          final heroImage = config.heroImageUrl ??
              extractHeroImageUrl(processedHtml, imagesList, domain: config.domain);

          final result = NewsletterEdition(
            pageTitle: parse['title'] as String? ?? config.pageTitle,
            htmlContent: processedHtml,
            heroImageUrl: heroImage,
            images: imagesList,
            sections: sectionsList,
            isOfflineCache: false, // Fresh online content
            lastFetched: DateTime.now(),
          );

          await cache.saveCached(config.cacheKey, result);
          return result;
        }
      }
      throw Exception('Failed to load newsletter. HTTP ${response.statusCode}');
    } catch (e) {
      // Network failed or timed out: Fallback to cache if available
      final cached = await cache.loadCached(config.cacheKey);
      if (cached != null) {
        return cached.copyWith(isOfflineCache: true);
      }
      rethrow;
    }
  }

  static List<NewsletterSectionItem> _extractSectionsFromHtml(String html) {
    final sections = <NewsletterSectionItem>[];
    final regex = RegExp(
      r"""<h([2-4])[^>]*id=['"]([^'"]+)['"][^>]*>(.*?)</h[2-4]>""",
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in regex.allMatches(html)) {
      final level = int.tryParse(match.group(1) ?? '2') ?? 2;
      final id = match.group(2) ?? '';
      // Strip any inner html tags
      final rawTitle = match.group(3) ?? '';
      final title = rawTitle.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (title.isNotEmpty) {
        sections.add(NewsletterSectionItem(id: id, title: title, level: level));
      }
    }
    return sections;
  }

  static String _sanitizeHtml(String html, String domain) {
    var cleaned = html.replaceAll('src="//', 'src="https://');
    cleaned = cleaned.replaceAll('href="//', 'href="https://');
    cleaned = cleaned.replaceAll('href="/wiki/', 'href="https://$domain/wiki/');
    return cleaned;
  }
}
