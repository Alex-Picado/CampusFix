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

/// Shows a personal summary or the shared administrative landing page.
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
    if (profile.role != UserRole.administrator) {
      return _PersonalOverview(
        key: ValueKey('${profile.role.name}:${profile.id}'),
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

class _PersonalOverview extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<CampusDestination> onNavigate;

  const _PersonalOverview({
    super.key,
    required this.profile,
    required this.onNavigate,
  });

  @override
  State<_PersonalOverview> createState() => _PersonalOverviewState();
}

class _PersonalOverviewState extends State<_PersonalOverview> {
  late Stream<List<Incident>> _reports;
  int _watchVersion = 0;

  @override
  void initState() {
    super.initState();
    _reports = _watchReports();
  }

  @override
  void didUpdateWidget(covariant _PersonalOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.role != widget.profile.role) {
      _watchVersion++;
      _reports = _watchReports();
    }
  }

  Stream<List<Incident>> _watchReports() {
    try {
      final repository = context.read<IncidentRepository>();
      return widget.profile.role == UserRole.reporter
          ? repository.watchOwn(userId: widget.profile.id)
          : repository.watchAssigned(userId: widget.profile.id);
    } catch (error) {
      return Stream.error(error);
    }
  }

  void _retry() {
    setState(() {
      _watchVersion++;
      _reports = _watchReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.status != SessionStatus.authenticated ||
        session.profile?.id != widget.profile.id ||
        session.profile?.role != widget.profile.role) {
      return const SizedBox.shrink();
    }

    final isReporter = widget.profile.role == UserRole.reporter;
    final name = widget.profile.fullName.trim().split(' ').first;
    return Column(
      key: const ValueKey('overview-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          title: name.isEmpty ? 'Tu inicio' : 'Hola, $name',
          description: isReporter
              ? 'Revisá tus reportes y continuá donde lo dejaste.'
              : 'Revisá tus asignaciones y continuá con la atención.',
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isReporter ? 'Mis incidencias' : 'Mi trabajo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isReporter
                    ? 'Consultá el avance y los detalles de todos tus reportes.'
                    : 'Consultá y atendé las incidencias que tenés asignadas.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: ValueKey(
                  isReporter
                      ? 'home-view-incidents'
                      : 'technician-home-view-workspace',
                ),
                onPressed: () => widget.onNavigate(
                  isReporter
                      ? CampusDestination.incidents
                      : CampusDestination.workspace,
                ),
                icon: Icon(
                  isReporter
                      ? Icons.list_alt_outlined
                      : Icons.handyman_outlined,
                ),
                label: Text(
                  isReporter ? 'Ver mis incidencias' : 'Ver mi trabajo',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        StreamBuilder<List<Incident>>(
          key: ValueKey(
            '${widget.profile.role.name}:${widget.profile.id}:$_watchVersion',
          ),
          stream: _reports,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _loadError(snapshot.error!);
            if (!snapshot.hasData) {
              return SectionCard(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isReporter
                            ? 'Cargando resumen de tus incidencias...'
                            : 'Cargando resumen de tus asignaciones...',
                      ),
                    ),
                  ],
                ),
              );
            }
            final reports = snapshot.data!;
            if (reports.any(
              (item) => isReporter
                  ? item.createdByUserId != widget.profile.id
                  : item.assignedTechnicianId != widget.profile.id,
            )) {
              return _loadError(
                const FormatException('Foreign case in personal query.'),
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
          widget.profile.role == UserRole.reporter
              ? 'No pudimos cargar tus incidencias.'
              : 'No pudimos cargar tus asignaciones.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(AppErrorMessages.fromError(error)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: ValueKey(
            widget.profile.role == UserRole.reporter
                ? 'home-retry'
                : 'technician-home-retry',
          ),
          onPressed: _retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    ),
  );

  Widget _summary(List<Incident> reports) {
    final isReporter = widget.profile.role == UserRole.reporter;
    final reporterGroups = [
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
    final technicianGroups = [
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
        'Solucionadas',
        Icons.task_alt_outlined,
        reports.where((row) => row.status == IncidentStatus.resolved).length,
      ),
      (
        'En revisión',
        Icons.rate_review_outlined,
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
    final groups = isReporter ? reporterGroups : technicianGroups;
    final recent = [...reports]
      ..sort((a, b) {
        final date = b.updatedAt.compareTo(a.updatedAt);
        return date != 0 ? date : b.sequenceNumber.compareTo(a.sequenceNumber);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isReporter ? 'Resumen de mis reportes' : 'Resumen de mi trabajo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          isReporter
              ? 'Cantidad de incidencias en cada etapa.'
              : 'Tus asignaciones según su estado actual.',
        ),
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
                      key: ValueKey(
                        isReporter
                            ? 'home-count-$index'
                            : 'technician-home-count-$index',
                      ),
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
              Text(
                isReporter
                    ? 'Tus reportes con los cambios más recientes.'
                    : 'Tus asignaciones con los cambios más recientes.',
              ),
              const SizedBox(height: 16),
              if (recent.isEmpty)
                Text(
                  isReporter
                      ? 'Todavía no tenés incidencias. Creá tu primer reporte para comenzar.'
                      : 'Todavía no tenés incidencias asignadas.',
                )
              else
                for (var index = 0; index < recent.take(3).length; index++) ...[
                  if (index > 0) const Divider(height: 24),
                  _RecentReport(report: recent[index], isReporter: isReporter),
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
  final bool isReporter;

  const _RecentReport({required this.report, required this.isReporter});

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
        isReporter
            ? report.status.reporterGuidance
            : 'Ubicación: ${report.location}',
        style: const TextStyle(color: CampusTheme.secondaryText),
      ),
    ],
  );
}
