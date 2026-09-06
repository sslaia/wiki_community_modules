import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration describing where and how to fetch the course page.
class CourseConfig {
  /// The language code (e.g. 'nia', 'jv', 'id', 'en', 'tl', 'ja').
  final String langCode;

  /// The Wikimedia project name (e.g. 'wiktionary', 'wikipedia', 'wikibooks').
  final String project;

  /// The exact wiki page title (e.g. 'Wikikamus:Sulu' or 'Course:Grammar').
  final String pageTitle;

  /// Optional custom domain override (e.g. 'custom-wiki.org').
  final String? customDomain;

  /// User-Agent header in compliance with Wikimedia policy.
  final String userAgent;

  const CourseConfig({
    required this.langCode,
    this.project = 'wiktionary',
    required this.pageTitle,
    this.customDomain,
    this.userAgent = 'WikiCommunityModules/1.0 (https://github.com/sslaia/wiki_community_modules)',
  });

  String get domain => customDomain ?? '$langCode.$project.org';

  String get pageUrl =>
      'https://$domain/wiki/${pageTitle.replaceAll(' ', '_')}';

  String get cacheKey => 'course_cache_${domain}_${pageTitle.replaceAll(' ', '_')}';
}

/// Content loaded for a course page.
class CoursePageContent {
  final String pageTitle;
  final String? courseTitle;
  final String htmlContent;
  final List<String> images;
  final bool isOfflineCache;
  final DateTime lastFetched;

  const CoursePageContent({
    required this.pageTitle,
    this.courseTitle,
    required this.htmlContent,
    this.images = const [],
    this.isOfflineCache = false,
    required this.lastFetched,
  });

  Map<String, dynamic> toJson() => {
        'pageTitle': pageTitle,
        'courseTitle': courseTitle,
        'htmlContent': htmlContent,
        'images': images,
        'lastFetched': lastFetched.toIso8601String(),
      };

  factory CoursePageContent.fromJson(
    Map<String, dynamic> json, {
    bool isOfflineCache = false,
  }) {
    return CoursePageContent(
      pageTitle: json['pageTitle'] as String? ?? '',
      courseTitle: json['courseTitle'] as String?,
      htmlContent: json['htmlContent'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isOfflineCache: isOfflineCache,
      lastFetched: json['lastFetched'] != null
          ? DateTime.tryParse(json['lastFetched'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CoursePageContent copyWith({
    String? pageTitle,
    String? courseTitle,
    String? htmlContent,
    List<String>? images,
    bool? isOfflineCache,
    DateTime? lastFetched,
  }) {
    return CoursePageContent(
      pageTitle: pageTitle ?? this.pageTitle,
      courseTitle: courseTitle ?? this.courseTitle,
      htmlContent: htmlContent ?? this.htmlContent,
      images: images ?? this.images,
      isOfflineCache: isOfflineCache ?? this.isOfflineCache,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }
}

/// Abstract delegate for reading/writing course cache.
abstract class CourseCacheDelegate {
  Future<CoursePageContent?> loadCached(String key);
  Future<void> saveCached(String key, CoursePageContent content);
}

/// Default built-in cache using SharedPreferences.
class DefaultSharedPreferencesCourseCache implements CourseCacheDelegate {
  @override
  Future<CoursePageContent?> loadCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        final data = jsonDecode(str) as Map<String, dynamic>;
        return CoursePageContent.fromJson(data, isOfflineCache: false);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveCached(String key, CoursePageContent content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(content.toJson()));
    } catch (_) {}
  }
}

/// Abstract repository conforming to Modular Modules Specification Section 2.3.
abstract class CourseRepository {
  /// Fetches structured lesson HTML or markdown
  Future<String> fetchLessonContent(String lessonId);

  /// Checks if lesson is bookmarked
  Future<bool> isBookmarked(String lessonId);

  /// Toggles bookmark state
  Future<void> toggleBookmark(String lessonId);
}
