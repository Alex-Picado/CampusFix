import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error_messages.dart';
import '../../core/widgets/page_heading.dart';
import '../../core/widgets/section_card.dart';
import '../../features/auth/controllers/session_controller.dart';
import '../../features/auth/models/session_status.dart';
import '../../features/incidents/models/incident.dart';
import '../../features/incidents/models/incident_status.dart';
import '../../features/incidents/presentation/administrative_incident_stages.dart';
import '../../features/incidents/presentation/incident_status_labels.dart';
import '../../features/incidents/repositories/incident_repository.dart';
import '../../features/users/models/user_profile.dart';
import '../../features/users/models/user_role.dart';
import '../navigation/campus_destination.dart';
import '../../features/incidents/widgets/administrative_summary.dart';
import '../../core/widgets/campus_banner.dart';

/// Shows a live summary and shortcuts for the authenticated role.
class OverviewScreen extends StatelessWidget {
  final UserProfile profile;
  final ValueChanged<CampusDestination> onNavigate;
  final List<CampusDestination> destinations;
  final void Function(CampusDestination, int)? onOpenStage;

  const OverviewScreen({
    super.key,
    required this.profile,
    required this.onNavigate,
    required this.destinations,
    this.onOpenStage,
  });

  @override
  Widget build(BuildContext context) {
    return _PersonalOverview(
      key: ValueKey('${profile.role.name}:${profile.id}'),
      profile: profile,
      onNavigate: onNavigate,
      destinations: destinations,
      onOpenStage: onOpenStage,
    );
  }
}

class _PersonalOverview extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<CampusDestination> onNavigate;
  final List<CampusDestination> destinations;
  final void Function(CampusDestination, int)? onOpenStage;

  const _PersonalOverview({
    super.key,
    required this.profile,
    required this.onNavigate,
    required this.destinations,
    this.onOpenStage,
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
      return switch (widget.profile.role) {
        UserRole.reporter => repository.watchOwn(userId: widget.profile.id),
        UserRole.technician => repository.watchAssigned(
          userId: widget.profile.id,
        ),
        UserRole.administrator => repository.watchAll(),
      };
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
    final isAdministrator = widget.profile.role == UserRole.administrator;
    final name = widget.profile.fullName.trim().split(' ').first;
    return Column(
      key: const ValueKey('overview-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          title: name.isEmpty ? 'Tu inicio' : 'Hola, $name',
          description: isReporter
              ? 'Revisá tus reportes y continuá donde lo dejaste.'
              : isAdministrator
              ? 'Revisá el estado de las incidencias y las tareas del campus.'
              : 'Revisá tus asignaciones y continuá con la atención.',
        ),
        const SizedBox(height: 24),
        const CampusBanner(),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isReporter
                    ? 'Mis incidencias'
                    : isAdministrator
                    ? 'Gestión del campus'
                    : 'Mi trabajo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isReporter
                    ? 'Consultá el avance y los detalles de todos tus reportes.'
                    : isAdministrator
                    ? 'Accedé a los casos y las herramientas de administración.'
                    : 'Consultá y atendé las incidencias que tenés asignadas.',
              ),
              const SizedBox(height: 16),
              if (isAdministrator)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final destination in widget.destinations.where(
                      (item) => [
                        CampusDestination.management,
                        CampusDestination.dashboard,
                        CampusDestination.categories,
                        CampusDestination.users,
                      ].contains(item),
                    ))
                      OutlinedButton.icon(
                        key: ValueKey('admin-home-${destination.name}'),
                        onPressed: () => widget.onNavigate(destination),
                        icon: Icon(destination.icon),
                        label: Text(destination.label),
                      ),
                  ],
                )
              else
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
                            : isAdministrator
                            ? 'Cargando resumen del campus...'
                            : 'Cargando resumen de tus asignaciones...',
                      ),
                    ),
                  ],
                ),
              );
            }
            final reports = snapshot.data!;
            if (!isAdministrator &&
                reports.any(
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
              : widget.profile.role == UserRole.administrator
              ? 'No pudimos cargar las incidencias del campus.'
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
                : widget.profile.role == UserRole.administrator
                ? 'admin-home-retry'
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
    final isAdministrator = widget.profile.role == UserRole.administrator;
    final administratorIcons = [
      Icons.schedule_outlined,
      Icons.assignment_ind_outlined,
      Icons.handyman_outlined,
      Icons.task_alt_outlined,
      Icons.rate_review_outlined,
      Icons.inventory_2_outlined,
    ];
    final administratorGroups = [
      for (final (index, stage) in administrativeIncidentStages(
        reports,
      ).indexed)
        (stage.$1, administratorIcons[index], stage.$3.length),
    ];
    final groups = isAdministrator
        ? administratorGroups
        : isReporter
        ? reporterGroups
        : technicianGroups;
    final recent = [...reports]
      ..sort((a, b) {
        final date = b.updatedAt.compareTo(a.updatedAt);
        return date != 0 ? date : b.sequenceNumber.compareTo(a.sequenceNumber);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAdministrator) ...[
          AdministrativeSummary(incidents: reports),
          const SizedBox(height: 24),
        ],
        Text(
          isReporter
              ? 'Resumen de mis reportes'
              : isAdministrator
              ? 'Resumen del campus'
              : 'Resumen de mi trabajo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          isReporter
              ? 'Cantidad de incidencias en cada etapa.'
              : isAdministrator
              ? '${reports.length} incidencias en total, organizadas por etapa.'
              : 'Tus asignaciones según su estado actual.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 820
                ? isAdministrator
                      ? 3
                      : 5
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
                            : isAdministrator
                            ? 'admin-home-count-$index'
                            : 'technician-home-count-$index',
                      ),
                      label: groups[index].$1,
                      icon: groups[index].$2,
                      count: groups[index].$3,
                      onTap: () {
                        final destination = isAdministrator
                            ? CampusDestination.management
                            : isReporter
                            ? CampusDestination.incidents
                            : CampusDestination.workspace;
                        if (widget.onOpenStage != null) {
                          widget.onOpenStage!(
                            destination,
                            isAdministrator ? index + 1 : index,
                          );
                        } else {
                          widget.onNavigate(destination);
                        }
                      },
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
                    : isAdministrator
                    ? 'Las incidencias del campus con los cambios más recientes.'
                    : 'Tus asignaciones con los cambios más recientes.',
              ),
              const SizedBox(height: 16),
              if (recent.isEmpty)
                Text(
                  isReporter
                      ? 'Todavía no tenés incidencias. Creá tu primer reporte para comenzar.'
                      : isAdministrator
                      ? 'Todavía no hay incidencias registradas.'
                      : 'Todavía no tenés incidencias asignadas.',
                )
              else
                for (var index = 0; index < recent.take(3).length; index++) ...[
                  if (index > 0) const Divider(height: 24),
                  _RecentReport(
                    report: recent[index],
                    role: widget.profile.role,
                  ),
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
  final VoidCallback onTap;

  const _CountCard({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text('$count', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ),
  );
}

class _RecentReport extends StatelessWidget {
  final Incident report;
  final UserRole role;

  const _RecentReport({required this.report, required this.role});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () =>
        Navigator.of(context)
            .pushNamed('/incidents/${Uri.encodeComponent(report.id)}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#${report.sequenceNumber} · ${report.title}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          report.status.label,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(
          role == UserRole.reporter
              ? report.status.reporterGuidance
              : role == UserRole.administrator
              ? report.status.administratorGuidance
              : 'Ubicación: ${report.location}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
