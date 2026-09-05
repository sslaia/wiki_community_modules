import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crossword_models.dart';

/// Abstract data source interface for providing crossword puzzles.
abstract class CrosswordDataSource {
  Future<List<CrosswordPuzzle>> loadPuzzles();
}

/// Asset-based data source reading puzzles from local asset bundle.
class AssetCrosswordDataSource implements CrosswordDataSource {
  final String assetPath;

  const AssetCrosswordDataSource(this.assetPath);

  @override
  Future<List<CrosswordPuzzle>> loadPuzzles() async {
    final jsonStr = await rootBundle.loadString(assetPath);
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is List) {
      return decoded
          .map((e) => CrosswordPuzzle.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}

/// Network-based data source with transparent offline cache fallback.
class NetworkCrosswordDataSource implements CrosswordDataSource {
  final Uri endpoint;
  final Map<String, String>? headers;
  final String? cacheKey;

  const NetworkCrosswordDataSource(
    this.endpoint, {
    this.headers,
    this.cacheKey,
  });

  @override
  Future<List<CrosswordPuzzle>> loadPuzzles() async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveCacheKey = cacheKey ?? 'crossword_cache_${endpoint.toString()}';

    try {
      final response = await http.get(endpoint, headers: headers);
      if (response.statusCode == 200) {
        await prefs.setString(effectiveCacheKey, response.body);
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map((e) => CrosswordPuzzle.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Fallback to cache on network error
    }

    final cachedStr = prefs.getString(effectiveCacheKey);
    if (cachedStr != null) {
      final dynamic decoded = jsonDecode(cachedStr);
      if (decoded is List) {
        return decoded
            .map((e) => CrosswordPuzzle.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    return [];
  }
}

/// In-memory data source, useful for testing and quick previews.
class MemoryCrosswordDataSource implements CrosswordDataSource {
  final List<CrosswordPuzzle> puzzles;

  const MemoryCrosswordDataSource(this.puzzles);

  @override
  Future<List<CrosswordPuzzle>> loadPuzzles() async => puzzles;
}
