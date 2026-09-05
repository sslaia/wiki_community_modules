import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/course_models.dart';

class WikiCourseService {
  static final CourseCacheDelegate _defaultCache = DefaultSharedPreferencesCourseCache();

  /// Fetches the course page HTML from the specified Wikimedia or custom endpoint.
  static Future<CoursePageContent> fetchCourse(
    CourseConfig config, {
    bool forceRefresh = false,
    CourseCacheDelegate? cacheDelegate,
  }) async {
    final cache = cacheDelegate ?? _defaultCache;

    // Check cache first if not force-refreshing
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

          final result = CoursePageContent(
            pageTitle: parse['title'] as String? ?? config.pageTitle,
            htmlContent: processedHtml,
            images: imagesList,
            isOfflineCache: false,
            lastFetched: DateTime.now(),
          );

          await cache.saveCached(config.cacheKey, result);
          return result;
        }
      }
      throw Exception('Failed to load wiki page. HTTP ${response.statusCode}');
    } catch (e) {
      // Fallback to cache on network failure
      final cached = await cache.loadCached(config.cacheKey);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  static String _sanitizeHtml(String html, String domain) {
    // Replace relative protocol links (//upload.wikimedia.org) with https://
    var cleaned = html.replaceAll('src="//', 'src="https://');
    cleaned = cleaned.replaceAll('href="//', 'href="https://');

    // Make relative internal wiki links absolute
    cleaned = cleaned.replaceAll('href="/wiki/', 'href="https://$domain/wiki/');

    return cleaned;
  }
}
