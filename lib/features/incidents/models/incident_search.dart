import 'incident.dart';
import 'incident_filters.dart';

/// Immutable local search criteria for an already authorized incident list.
///
/// Numeric input, optionally prefixed by #, matches the exact sequence number.
/// Other text searches title, description and location without case or Spanish
/// accent differences. A category ID combines with the query using AND.
class IncidentSearch {
  /// User-entered sequence number or partial text; whitespace is ignored at ends.
  final String query;

  /// Exact category identifier, or null to include every authorized category.
  final String? categoryId;

  /// Optional administrative criteria, ignored only when all choices are clear.
  final IncidentFilters filters;

  /// Creates criteria without performing database reads or granting access.
  const IncidentSearch({
    this.query = '',
    this.categoryId,
    this.filters = const IncidentFilters(),
  });

  /// Whether any query or category currently restricts the list.
  bool get hasCriteria =>
      query.trim().isNotEmpty || categoryId != null || filters.hasCriteria;

  /// Copies text, category or filters without discarding the other criteria.
  IncidentSearch copyWith({
    String? query,
    String? categoryId,
    bool clearCategory = false,
    IncidentFilters? filters,
  }) => IncidentSearch(
    query: query ?? this.query,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    filters: filters ?? this.filters,
  );

  /// Returns immutable matches in their original repository ordering.
  ///
  /// Callers must authorize [incidents] before supplying them. Invalid or
  /// oversized numeric input produces no sequence match, never a partial one.
  List<Incident> applyTo(Iterable<Incident> incidents) {
    final text = query.trim();
    final numberText = text.startsWith('#') ? text.substring(1).trim() : text;
    final numeric = text.startsWith('#') || RegExp(r'^\d+$').hasMatch(text);
    final sequence = RegExp(r'^\d+$').hasMatch(numberText)
        ? int.tryParse(numberText)
        : null;
    final normalized = normalizeText(text);
    return List.unmodifiable(
      incidents.where((incident) {
        if (!filters.matches(incident)) return false;
        if (categoryId != null && categoryId != incident.categoryId) {
          return false;
        }
        if (text.isEmpty) return true;
        if (numeric) return incident.sequenceNumber == sequence;
        return [
          incident.title,
          incident.description,
          incident.location,
        ].any((field) => normalizeText(field).contains(normalized));
      }),
    );
  }

  /// Normalizes case and common Spanish accents, including combining marks.
  ///
  /// Keeps punctuation and internal spaces; performs no transliteration outside
  /// the supported Latin characters and requires no external dependency.
  static String normalizeText(String text) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .split('')
        .map((character) => accents[character] ?? character)
        .join();
  }
}
