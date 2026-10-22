import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rows = [
    _incident(
      'light',
      12,
      title: 'Iluminación del aula',
      category: 'lighting',
      description: 'Luminaria intermitente',
      location: 'Edificio A',
    ),
    _incident(
      'network',
      112,
      title: 'Conexión inestable',
      category: 'network',
      description: 'Revisar conexión del router',
      location: 'Biblioteca',
    ),
    _incident(
      'bathroom',
      2,
      title: 'Baños',
      category: 'plumbing',
      description: 'Tubería con fuga',
      location: 'Edificio B',
    ),
  ];

  test(
    'Empty criteria preserve repository ordering and return immutable results',
    () {
      final result = const IncidentSearch(query: '  ').applyTo(rows);
      expect(result, orderedEquals(rows));
      expect(identical(result.first, rows.first), true);
      expect(() => result.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Sequences match exactly with an optional hash and never as substrings',
    () {
      for (final query in ['12', '#12', '  # 0012  ']) {
        expect(
          IncidentSearch(query: query).applyTo(rows).map((row) => row.id),
          ['light'],
        );
      }
      expect(const IncidentSearch(query: '1').applyTo(rows), isEmpty);
      expect(
        const IncidentSearch(query: '112').applyTo(rows).single.id,
        'network',
      );
    },
  );

  test('Invalid and oversized sequence inputs produce no matches', () {
    for (final query in [
      '#',
      '#abc',
      '#-1',
      '#12x',
      '999999999999999999999999999999',
    ]) {
      expect(IncidentSearch(query: query).applyTo(rows), isEmpty);
    }
  });

  test(
    'Text searches titles descriptions and locations without case or accents',
    () {
      for (final query in [
        'ILUMINACION',
        'iluminacio\u0301n',
        'intermitente',
        'edificio a',
      ]) {
        expect(IncidentSearch(query: query).applyTo(rows).single.id, 'light');
      }
      expect(
        const IncidentSearch(query: 'biblioteca').applyTo(rows).single.id,
        'network',
      );
      expect(
        const IncidentSearch(query: 'CONEXION DEL').applyTo(rows).single.id,
        'network',
      );
      expect(
        const IncidentSearch(query: 'banos').applyTo(rows).single.id,
        'bathroom',
      );
    },
  );

  test('Category IDs match exactly and combine with text using AND', () {
    expect(const IncidentSearch(categoryId: 'light').applyTo(rows), isEmpty);
    expect(
      const IncidentSearch(categoryId: 'lighting').applyTo(rows).single.id,
      'light',
    );
    expect(
      const IncidentSearch(
        query: 'edificio',
        categoryId: 'plumbing',
      ).applyTo(rows).single.id,
      'bathroom',
    );
    expect(
      const IncidentSearch(query: '#12', categoryId: 'network').applyTo(rows),
      isEmpty,
    );
    expect(
      const IncidentSearch(
        query: 'router',
        categoryId: 'network',
      ).applyTo(rows).single.id,
      'network',
    );
  });

  test(
    'Unknown text and empty source return empty lists without modifying input',
    () {
      expect(const IncidentSearch(query: 'missing').applyTo(rows), isEmpty);
      expect(const IncidentSearch(query: '#12').applyTo(const []), isEmpty);
      expect(rows.length, 3);
      expect(const IncidentSearch().hasCriteria, false);
      expect(const IncidentSearch(query: '  ').hasCriteria, false);
      expect(const IncidentSearch(categoryId: 'lighting').hasCriteria, true);
    },
  );
}

Incident _incident(
  String id,
  int sequence, {
  required String title,
  required String category,
  required String description,
  required String location,
}) => Incident(
  id: id,
  sequenceNumber: sequence,
  title: title,
  description: description,
  categoryId: category,
  location: location,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  createdByUserId: 'reporter',
);
