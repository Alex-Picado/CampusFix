import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/controllers/session_controller.dart';
import '../../features/catalogs/repositories/category_repository.dart';
import '../../features/catalogs/screens/category_management_screen.dart';
import '../../features/incidents/controllers/incident_queue_controller.dart';
import '../../features/incidents/models/incident.dart';
import '../../features/incidents/repositories/incident_repository.dart';
import '../../features/incidents/screens/incident_dashboard_screen.dart';
import '../../features/incidents/screens/my_incidents_screen.dart';
import '../../features/incidents/screens/incident_queue_screen.dart';
import '../../features/incidents/screens/incident_report_screen.dart';
import '../../features/incidents/screens/personal_incident_dashboard.dart';
import '../../features/users/models/user_profile.dart';
import '../../features/users/models/user_role.dart';
import '../../features/users/presentation/user_role_labels.dart';
import '../../features/users/repositories/user_repository.dart';
import '../../features/users/screens/profile_screen.dart';
import '../../features/users/screens/user_management_screen.dart';
import '../navigation/campus_destination.dart';
import '../screens/overview_screen.dart';
import '../theme/campus_theme.dart';
import 'campus_navigation.dart';

/// Hosts the common interface for an authenticated profile.
///
/// Resets inaccessible selections when the observed role changes.
/// Every destination delegates to its implemented module.
class CampusShell extends StatefulWidget {
  final UserProfile profile;

  const CampusShell({super.key, required this.profile});

  @override
  State<CampusShell> createState() => _CampusShellState();
}

class _CampusShellState extends State<CampusShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  CampusDestination _selected = CampusDestination.overview;
  bool _reportingFromHome = false;
  ScaffoldMessengerState? _assignmentMessenger;

  @override
  void didUpdateWidget(covariant CampusShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.role != widget.profile.role) {
      _reportingFromHome = false;
      _clearAssignmentNotices();
    }
    if (!_selected.isVisibleTo(widget.profile.role)) {
      _selected = CampusDestination.overview;
    }
  }

  void _select(CampusDestination destination) {
    if (!destination.isVisibleTo(widget.profile.role)) {
      return;
    }
    setState(() {
      _selected = destination;
      _reportingFromHome = false;
    });
    _scaffoldKey.currentState?.closeDrawer();
  }

  /// Delegates sign-out and reports failures while this shell is still mounted.
  Future<void> _signOut() async {
    final auth = context.read<AuthController>();
    final success = await auth.signOut();
    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.errorMessage ?? 'No pudimos cerrar la sesión.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.role != UserRole.technician) {
      return _buildScaffold(context);
    }
    return ChangeNotifierProvider(
      key: ValueKey('technician-queue:${widget.profile.id}'),
      create: (context) => IncidentQueueController(
        repository: context.read<IncidentRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        userRepository: context.read<UserRepository>(),
        session: context.read<SessionController>(),
        uid: widget.profile.id,
        role: UserRole.technician,
        onNewAssignments: _notifyAssignments,
      ),
      child: Builder(builder: _buildScaffold),
    );
  }

  void _notifyAssignments(List<Incident> added) {
    final uid = widget.profile.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.profile.role != UserRole.technician) return;
      final profile = context.read<SessionController>().profile;
      if (profile?.id != uid || profile?.role != UserRole.technician) return;
      final messenger = ScaffoldMessenger.of(context);
      _assignmentMessenger = messenger;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added.length == 1
                ? 'Nueva asignación: incidencia #${added.single.sequenceNumber}.'
                : 'Tenés ${added.length} nuevas asignaciones.',
          ),
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _clearAssignmentNotices() {
    final messenger = _assignmentMessenger;
    _assignmentMessenger = null;
    if (messenger == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!messenger.mounted) return;
      messenger.clearSnackBars();
      messenger.removeCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _clearAssignmentNotices();
    super.dispose();
  }

  Widget _buildScaffold(BuildContext context) {
    final auth = context.watch<AuthController>();
    final destinations = CampusDestination.forRole(widget.profile.role);
    VoidCallback? signOut;
    if (!auth.isLoading) {
      signOut = _signOut;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer = constraints.maxWidth < 900;
        Widget? drawer;
        Widget? leading;

        if (useDrawer) {
          drawer = Drawer(
            width: 260,
            child: SafeArea(
              child: CampusNavigation(
                selected: _selected,
                destinations: destinations,
                onSelected: _select,
              ),
            ),
          );
          leading = IconButton(
            tooltip: 'Abrir menú',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            leading: leading,
            title: const Text('CampusFix'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    widget.profile.role.label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CampusTheme.secondaryText,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  key: const ValueKey('session-sign-out'),
                  onPressed: signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Salir'),
                ),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          drawer: drawer,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!useDrawer) ...[
                  SizedBox(
                    width: 230,
                    child: CampusNavigation(
                      selected: _selected,
                      destinations: destinations,
                      onSelected: _select,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(_selected),
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: _page(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _page() => switch (_selected) {
    CampusDestination.dashboard => const IncidentDashboardScreen(),
    CampusDestination.categories => const CategoryManagementScreen(),
    CampusDestination.overview => _overview(),
    CampusDestination.profile => ProfileScreen(profile: widget.profile),
    CampusDestination.users => UserManagementScreen(
      currentUserId: widget.profile.id,
    ),
    CampusDestination.incidents => MyIncidentsScreen(userId: widget.profile.id),
    CampusDestination.management ||
    CampusDestination.workspace => const IncidentQueueScreen(),
  };

  Widget _overview() => switch (widget.profile.role) {
    UserRole.reporter =>
      _reportingFromHome
          ? IncidentReportScreen(
              userId: widget.profile.id,
              onBack: () => setState(() => _reportingFromHome = false),
            )
          : ReporterIncidentDashboard(
              userId: widget.profile.id,
              onReport: () => setState(() => _reportingFromHome = true),
              onViewReports: () => _select(CampusDestination.incidents),
            ),
    UserRole.technician => TechnicianIncidentDashboard(
      onViewWork: () => _select(CampusDestination.workspace),
    ),
    UserRole.administrator => OverviewScreen(
      onNavigate: _select,
      destinations: CampusDestination.forRole(widget.profile.role),
    ),
  };
}
