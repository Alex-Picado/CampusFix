import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error_messages.dart';
import '../../core/widgets/page_heading.dart';
import '../../core/widgets/section_card.dart';
import '../../features/auth/controllers/session_controller.dart';
import '../../features/auth/models/session_status.dart';
import '../../features/incidents/models/incident.dart';
import '../../features/incidents/models/incident_status.dart';
import '../../features/incidents/presentation/incident_status_labels.dart';
import '../../features/incidents/repositories/incident_repository.dart';
import '../../features/users/models/user_profile.dart';
import '../../features/users/models/user_role.dart';
import '../navigation/campus_destination.dart';
import '../theme/campus_theme.dart';

/// Shows a personal reporter summary or the shared landing page for other roles.
class OverviewScreen extends StatelessWidget {
  final UserProfile profile;
  final ValueChanged<CampusDestination> onNavigate;
  final List<CampusDestination> destinations;

  const OverviewScreen({
    super.key,
    required this.profile,
    required this.onNavigate,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.role == UserRole.reporter) {
      return _ReporterOverview(
        key: ValueKey(profile.id),
        profile: profile,
        onNavigate: onNavigate,
      );
    }
    return Column(
      key: const ValueKey('overview-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'Inicio',
          description: 'Gestión de incidencias del campus.',
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accesos rápidos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final destination
                      in destinations
                          .where((item) => item != CampusDestination.overview)
                          .take(3))
                    OutlinedButton.icon(
                      onPressed: () => onNavigate(destination),
                      icon: Icon(destination.icon),
                      label: Text(destination.label),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Cómo funciona?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text('1. Reportá el problema e indicá dónde ocurre.'),
              const SizedBox(height: 8),
              const Text('2. Consultá su estado y los avances registrados.'),
              const SizedBox(height: 8),
              const Text(
                '3. Da seguimiento a la solución y al cierre del reporte.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReporterOverview extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<CampusDestination> onNavigate;

  const _ReporterOverview({
    super.key,
    required this.profile,
    required this.onNavigate,
  });

  @override
  State<_ReporterOverview> createState() => _ReporterOverviewState();
}

class _ReporterOverviewState extends State<_ReporterOverview> {
  late Stream<List<Incident>> _reports;
  int _watchVersion = 0;

  @override
  void initState() {
    super.initState();
    _reports = _watchOwn();
  }

  @override
  void didUpdateWidget(covariant _ReporterOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _watchVersion++;
      _reports = _watchOwn();
    }
  }

  Stream<List<Incident>> _watchOwn() {
    try {
      return context.read<IncidentRepository>().watchOwn(
        userId: widget.profile.id,
      );
    } catch (error) {
      return Stream.error(error);
    }
  }

  void _retry() {
    setState(() {
      _watchVersion++;
      _reports = _watchOwn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.status != SessionStatus.authenticated ||
        session.profile?.id != widget.profile.id ||
        session.profile?.role != UserRole.reporter) {
      return const SizedBox.shrink();
    }

    final name = widget.profile.fullName.trim().split(' ').first;
    return Column(
      key: const ValueKey('overview-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          title: name.isEmpty ? 'Tu inicio' : 'Hola, $name',
          description: 'Revisá tus reportes y continuá donde lo dejaste.',
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mis incidencias',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Consultá el avance y los detalles de todos tus reportes.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const ValueKey('home-view-incidents'),
                onPressed: () => widget.onNavigate(CampusDestination.incidents),
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('Ver mis incidencias'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        StreamBuilder<List<Incident>>(
          key: ValueKey('${widget.profile.id}:$_watchVersion'),
          stream: _reports,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _loadError(snapshot.error!);
            if (!snapshot.hasData) {
              return const SectionCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Cargando resumen de tus incidencias...'),
                    ),
                  ],
                ),
              );
            }
            final reports = snapshot.data!;
            if (reports.any(
              (item) => item.createdByUserId != widget.profile.id,
            )) {
              return _loadError(
                const FormatException('Foreign report in own query.'),
              );
            }
            return _summary(reports);
          },
        ),
      ],
    );
  }

  Widget _loadError(Object error) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No pudimos cargar tus incidencias.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(AppErrorMessages.fromError(error)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('home-retry'),
          onPressed: _retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    ),
  );

  Widget _summary(List<Incident> reports) {
    final groups = [
      (
        'Pendientes',
        Icons.schedule_outlined,
        reports
            .where(
              (row) => {
                IncidentStatus.reported,
                IncidentStatus.underReview,
                IncidentStatus.reviewRequested,
                IncidentStatus.reopened,
              }.contains(row.status),
            )
            .length,
      ),
      (
        'Asignadas',
        Icons.assignment_ind_outlined,
        reports.where((row) => row.status == IncidentStatus.assigned).length,
      ),
      (
        'En atención',
        Icons.handyman_outlined,
        reports.where((row) => row.status == IncidentStatus.inProgress).length,
      ),
      (
        'Solucionada',
        Icons.task_alt_outlined,
        reports.where((row) => row.status == IncidentStatus.resolved).length,
      ),
      (
        'Finalizadas',
        Icons.inventory_2_outlined,
        reports
            .where(
              (row) => {
                IncidentStatus.closed,
                IncidentStatus.rejected,
                IncidentStatus.cancelled,
              }.contains(row.status),
            )
            .length,
      ),
    ];
    final recent = [...reports]
      ..sort((a, b) {
        final date = b.updatedAt.compareTo(a.updatedAt);
        return date != 0 ? date : b.sequenceNumber.compareTo(a.sequenceNumber);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen de mis reportes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text('Cantidad de incidencias en cada etapa.'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 820
                ? 5
                : constraints.maxWidth >= 460
                ? 3
                : 2;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var index = 0; index < groups.length; index++)
                  SizedBox(
                    width: width,
                    child: _CountCard(
                      key: ValueKey('home-count-$index'),
                      label: groups[index].$1,
                      icon: groups[index].$2,
                      count: groups[index].$3,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actividad reciente',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text('Tus reportes con los cambios más recientes.'),
              const SizedBox(height: 16),
              if (recent.isEmpty)
                const Text(
                  'Todavía no tenés incidencias. Creá tu primer reporte para comenzar.',
                )
              else
                for (var index = 0; index < recent.take(3).length; index++) ...[
                  if (index > 0) const Divider(height: 24),
                  _RecentReport(report: recent[index]),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;

  const _CountCard({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: CampusTheme.primary),
        const SizedBox(height: 12),
        Text('$count', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _RecentReport extends StatelessWidget {
  final Incident report;

  const _RecentReport({required this.report});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '#${report.sequenceNumber} · ${report.title}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 4),
      Text(
        report.status.label,
        style: const TextStyle(color: CampusTheme.primary),
      ),
      const SizedBox(height: 4),
      Text(
        report.status.reporterGuidance,
        style: const TextStyle(color: CampusTheme.secondaryText),
      ),
    ],
  );
}
