import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One sense of a word under a given part-of-speech.
class WordSense {
  final String definition;
  final List<String> examples;

  const WordSense({required this.definition, required this.examples});
}

/// A part-of-speech block containing one or more senses.
class WordEntry {
  final String partOfSpeech;
  final List<WordSense> senses;

  const WordEntry({required this.partOfSpeech, required this.senses});
}

/// Thin wrapper around the free Wiktionary REST API.
///
/// Endpoint: GET https://en.wiktionary.org/api/rest_v1/page/definition/{word}
/// No API key required. Zero rate-limit concerns at human lookup speed.
///
/// A dedicated [Dio] instance is used — intentionally separate from the app's
/// API client so auth interceptors and the app baseUrl never fire on an
/// external request.
class DictionaryService {
  static const _base =
      'https://en.wiktionary.org/api/rest_v1/page/definition';

  // Shared, lazily-created Dio instance with sane timeouts.
  static final Dio _client = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 8),
    // Accept 404 so we can distinguish "word not found" from a real error.
    validateStatus: (status) => status != null && status < 500,
  ));

  /// Returns English entries for [word], or an empty list when the word is
  /// unknown. Throws [DioException] on network failure so the caller can
  /// distinguish "not found" (empty list) from "offline" (exception).
  Future<List<WordEntry>> lookup(String word) async {
    final normalised = word.trim().toLowerCase();
    if (normalised.isEmpty) return [];

    final response = await _client.get('$_base/$normalised');

    if (response.statusCode == 404) return [];

    // Response is a map keyed by language code. Show English only.
    final data = response.data as Map<String, dynamic>;
    final enBlock = data['en'] as List?;
    if (enBlock == null || enBlock.isEmpty) return [];

    return enBlock
        .cast<Map<String, dynamic>>()
        .map(_parseEntry)
        .where((e) => e.senses.isNotEmpty)
        .toList();
  }

  static WordEntry _parseEntry(Map<String, dynamic> block) {
    final pos = block['partOfSpeech'] as String? ?? '';
    final rawDefs = block['definitions'] as List? ?? [];

    final senses = rawDefs.cast<Map<String, dynamic>>().map((d) {
      final def = _stripHtml(d['definition'] as String? ?? '');

      // Prefer rich parsed examples; fall back to plain string list.
      final examples =
          (d['parsedExamples'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map((e) => _stripHtml(e['example'] as String? ?? ''))
              .where((e) => e.isNotEmpty)
              .take(2)
              .toList() ??
          (d['examples'] as List?)
              ?.cast<String>()
              .map(_stripHtml)
              .where((e) => e.isNotEmpty)
              .take(2)
              .toList() ??
          <String>[];

      return WordSense(definition: def, examples: examples);
    }).where((s) => s.definition.isNotEmpty).toList();

    return WordEntry(partOfSpeech: pos, senses: senses);
  }

  /// Strips HTML tags and decodes the most common HTML entities.
  /// Wiktionary wraps wikilinks in <a> tags and uses entities heavily.
  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .trim();
}

/// Singleton provider — one DictionaryService for the entire app lifetime.
final dictionaryServiceProvider = Provider<DictionaryService>(
  (_) => DictionaryService(),
);
