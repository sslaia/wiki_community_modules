import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration describing how to fetch the newsletter page.
class NewsletterConfig {
  /// The language code (e.g. 'nia', 'jv', 'id', 'en', 'zh', 'ja', 'tl').
  final String langCode;

  /// The Wikimedia project name (e.g. 'wikipedia', 'wiktionary', 'wikibooks').
  final String project;

  /// The exact page title (e.g. 'Wikipedia:Turia', 'Wikipedia:Warta').
  final String pageTitle;

  /// Optional custom domain override (e.g. 'custom-wiki.org').
  final String? customDomain;

  /// Optional custom cover/hero image URL.
  final String? heroImageUrl;

  /// User-Agent header in compliance with Wikimedia policy.
  final String userAgent;

  const NewsletterConfig({
    required this.langCode,
    this.project = 'wikipedia',
    required this.pageTitle,
    this.customDomain,
    this.heroImageUrl,
    this.userAgent = 'WikiCommunityModules/1.0 (https://github.com/sslaia/wiki_community_modules)',
  });

  String get domain => customDomain ?? '$langCode.$project.org';

  String get pageUrl => 'https://$domain/wiki/${pageTitle.replaceAll(' ', '_')}';

  String get cacheKey => 'newsletter_cache_${domain}_${pageTitle.replaceAll(' ', '_')}';
}

/// Represents a parsed heading/section in the newsletter article.
class NewsletterSectionItem {
  final String id;
  final String title;
  final int level;

  const NewsletterSectionItem({
    required this.id,
    required this.title,
    this.level = 2,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'level': level,
      };

  factory NewsletterSectionItem.fromJson(Map<String, dynamic> json) {
    final rawLevel = json['level'] ?? json['toclevel'];
    final level = rawLevel is int
        ? rawLevel
        : int.tryParse(rawLevel?.toString() ?? '2') ?? 2;
    return NewsletterSectionItem(
      id: json['id'] as String? ?? json['anchor'] as String? ?? '',
      title: json['title'] as String? ?? json['line'] as String? ?? '',
      level: level,
    );
  }
}

/// Content loaded for a newsletter edition.
class NewsletterEdition {
  final String pageTitle;
  final String htmlContent;
  final String? heroImageUrl;
  final List<String> images;
  final List<NewsletterSectionItem> sections;
  final bool isOfflineCache;
  final DateTime lastFetched;

  const NewsletterEdition({
    required this.pageTitle,
    required this.htmlContent,
    this.heroImageUrl,
    this.images = const [],
    this.sections = const [],
    this.isOfflineCache = false,
    required this.lastFetched,
  });

  NewsletterEdition copyWith({
    String? pageTitle,
    String? htmlContent,
    String? heroImageUrl,
    List<String>? images,
    List<NewsletterSectionItem>? sections,
    bool? isOfflineCache,
    DateTime? lastFetched,
  }) {
    return NewsletterEdition(
      pageTitle: pageTitle ?? this.pageTitle,
      htmlContent: htmlContent ?? this.htmlContent,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      images: images ?? this.images,
      sections: sections ?? this.sections,
      isOfflineCache: isOfflineCache ?? this.isOfflineCache,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }

  Map<String, dynamic> toJson() => {
        'pageTitle': pageTitle,
        'htmlContent': htmlContent,
        'heroImageUrl': heroImageUrl,
        'images': images,
        'sections': sections.map((s) => s.toJson()).toList(),
        'lastFetched': lastFetched.toIso8601String(),
      };

  factory NewsletterEdition.fromJson(Map<String, dynamic> json, {bool isOfflineCache = true}) {
    return NewsletterEdition(
      pageTitle: json['pageTitle'] as String? ?? '',
      htmlContent: json['htmlContent'] as String? ?? '',
      heroImageUrl: json['heroImageUrl'] as String?,
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => NewsletterSectionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isOfflineCache: isOfflineCache,
      lastFetched: json['lastFetched'] != null
          ? DateTime.tryParse(json['lastFetched'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Abstract delegate for reading/writing newsletter cache.
abstract class NewsletterCacheDelegate {
  Future<NewsletterEdition?> loadCached(String key);
  Future<void> saveCached(String key, NewsletterEdition edition);
}

/// Default built-in cache using SharedPreferences.
class DefaultSharedPreferencesNewsletterCache implements NewsletterCacheDelegate {
  @override
  Future<NewsletterEdition?> loadCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        final data = jsonDecode(str) as Map<String, dynamic>;
        return NewsletterEdition.fromJson(data, isOfflineCache: true);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveCached(String key, NewsletterEdition edition) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(edition.toJson()));
    } catch (_) {}
  }
}

/// Abstract content delegate conforming to Modular Modules Specification Section 4.3.
abstract class NewsletterContentDelegate {
  Future<NewsletterEdition> fetchEdition(String editionId);
  Future<NewsletterEdition?> loadOfflineEdition(String editionId);
  Future<void> saveOfflineEdition(NewsletterEdition edition);
}
