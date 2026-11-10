import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../models/incident.dart';
import '../models/incident_status.dart';
import '../presentation/incident_status_labels.dart';

/// Calendar periods use Costa Rica time, independently of the device timezone.
DateTime campusTime(DateTime date) =>
    date.toUtc().subtract(const Duration(hours: 6));

class AdministrativeSummary extends StatelessWidget {
  final List<Incident> incidents;
  final DateTime? now;
  const AdministrativeSummary({super.key, required this.incidents, this.now});

  @override
  Widget build(BuildContext context) {
    final today = campusTime(now ?? DateTime.now());
    final day = DateTime.utc(today.year, today.month, today.day);
    final week = day.subtract(Duration(days: today.weekday - 1));
    final month = DateTime.utc(today.year, today.month);
    final nextMonth = DateTime.utc(today.year, today.month + 1);
    List<Incident> between(DateTime start, DateTime end) =>
        incidents.where((row) {
          final created = campusTime(row.createdAt);
          return !created.isBefore(start) && created.isBefore(end);
        }).toList();
    final metrics = [
      (
        'Esta semana',
        Icons.date_range,
        between(week, week.add(const Duration(days: 7))),
      ),
      ('Este mes', Icons.calendar_month, between(month, nextMonth)),
      (
        'Por confirmar cierre',
        Icons.fact_check_outlined,
        incidents
            .where((row) => row.status == IncidentStatus.resolved)
            .toList(),
      ),
      (
        'Sin técnico asignado',
        Icons.person_search_outlined,
        incidents
            .where(
              (row) =>
                  row.assignedTechnicianId == null &&
                  {
                    IncidentStatus.reported,
                    IncidentStatus.underReview,
                    IncidentStatus.reopened,
                  }.contains(row.status),
            )
            .toList(),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Actividad administrativa',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Reportes recibidos por período · Semana de lunes a domingo · Hora de Costa Rica',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950
                ? 4
                : constraints.maxWidth >= 500
                ? 2
                : 1;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width:
                        (constraints.maxWidth - (columns - 1) * 12) / columns,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => showCases(context, metric.$1, metric.$3),
                        child: SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    metric.$2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${metric.$3.length}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              Text(metric.$1),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reportes de los últimos 7 días',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (var index = 6; index >= 0; index--)
                Builder(
                  builder: (context) {
                    final start = day.subtract(Duration(days: index));
                    final rows = between(
                      start,
                      start.add(const Duration(days: 1)),
                    );
                    final maxCount = incidents.isEmpty ? 1 : incidents.length;
                    return InkWell(
                      onTap: () => showCases(
                        context,
                        '${start.day}/${start.month}',
                        rows,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text('${start.day}/${start.month}'),
                            ),
                            Expanded(
                              child: Semantics(
                                label:
                                    '${start.day}/${start.month}: ${rows.length} reportes',
                                child: Container(
                                  height: 10,
                                  alignment: Alignment.centerLeft,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor: rows.length / maxCount,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${rows.length}',
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  static void showCases(
    BuildContext context,
    String title,
    List<Incident> rows,
  ) {
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 680,
          height: 380,
          child: rows.isEmpty
              ? const Center(child: Text('No hay incidencias en este grupo.'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      title: Text('#${row.sequenceNumber} · ${row.title}'),
                      subtitle: Text('${row.status.label} · ${row.location}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pop();
                        navigator.pushNamed(
                          '/incidents/${Uri.encodeComponent(row.id)}',
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }
}
