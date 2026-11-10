import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/controllers/session_controller.dart';
import '../../features/auth/models/session_status.dart';
import '../../features/catalogs/screens/category_management_screen.dart';
import '../../features/incidents/screens/incident_dashboard_screen.dart';
import '../../features/incidents/screens/my_incidents_screen.dart';
import '../../features/incidents/screens/incident_queue_screen.dart';
import '../../features/users/models/user_profile.dart';
import '../../features/users/models/user_role.dart';
import '../../features/users/presentation/user_role_labels.dart';
import '../../features/users/screens/profile_screen.dart';
import '../../features/users/screens/user_management_screen.dart';
import '../navigation/campus_destination.dart';
import '../screens/overview_screen.dart';
import 'campus_navigation.dart';
import '../../features/notifications/widgets/notification_bell.dart';

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
  bool _createReportOnOpen = false;
  bool _sidebarExpanded = true;
  int _initialStage = 0;

  void _openStage(CampusDestination destination, int stage) {
    _select(destination);
    setState(() => _initialStage = stage);
  }

  @override
  void didUpdateWidget(covariant CampusShell oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      _createReportOnOpen = false;
      _initialStage = 0;
    });
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _createReport() {
    if (!CampusDestination.incidents.isVisibleTo(widget.profile.role)) return;
    setState(() {
      _selected = CampusDestination.incidents;
      _createReportOnOpen = true;
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
    final auth = context.watch<AuthController>();
    final session = context.watch<SessionController>();
    final destinations = CampusDestination.forRole(widget.profile.role);
    VoidCallback? signOut;
    if (!auth.isLoading) {
      signOut = _signOut;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer = constraints.maxWidth < 900;
        final showCreateReportButton =
            session.status == SessionStatus.authenticated &&
            session.profile?.id == widget.profile.id &&
            session.profile?.role == UserRole.reporter &&
            widget.profile.role == UserRole.reporter &&
            _selected == CampusDestination.overview;
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
        } else {
          leading = IconButton(
            key: const ValueKey('sidebar-toggle'),
            tooltip: _sidebarExpanded ? 'Ocultar menú' : 'Mostrar menú',
            onPressed: () =>
                setState(() => _sidebarExpanded = !_sidebarExpanded),
            icon: AnimatedRotation(
              turns: _sidebarExpanded ? 0 : 0.5,
              duration: const Duration(milliseconds: 260),
              child: const Icon(Icons.menu_open),
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            leading: leading,
            title: const Text('CampusFix'),
            actions: [
              NotificationBell(
                key: ValueKey(
                  'notifications:${widget.profile.id}:${widget.profile.role.name}',
                ),
                profile: widget.profile,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    widget.profile.role.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          floatingActionButton: showCreateReportButton
              ? FloatingActionButton.extended(
                  key: const ValueKey('home-create-incident'),
                  onPressed: _createReport,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear incidencia'),
                )
              : null,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!useDrawer)
                  ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.centerLeft,
                      widthFactor: _sidebarExpanded ? 1 : 0,
                      child: ExcludeFocus(
                        excluding: !_sidebarExpanded,
                        child: ExcludeSemantics(
                          excluding: !_sidebarExpanded,
                          child: IgnorePointer(
                            ignoring: !_sidebarExpanded,
                            child: SizedBox(
                              width: 241,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CampusNavigation(
                                      selected: _selected,
                                      destinations: destinations,
                                      onSelected: _select,
                                    ),
                                  ),
                                  const VerticalDivider(width: 1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(_selected),
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      showCreateReportButton ? 100 : 24,
                    ),
                    child: SizedBox(width: double.infinity, child: _page()),
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
    CampusDestination.overview => OverviewScreen(
      profile: widget.profile,
      onNavigate: _select,
      onOpenStage: _openStage,
      destinations: CampusDestination.forRole(widget.profile.role),
    ),
    CampusDestination.profile => ProfileScreen(profile: widget.profile),
    CampusDestination.users => UserManagementScreen(
      currentUserId: widget.profile.id,
    ),
    CampusDestination.incidents => MyIncidentsScreen(
      userId: widget.profile.id,
      initiallyCreating: _createReportOnOpen,
      initialStage: _initialStage,
    ),
    CampusDestination.management || CampusDestination.workspace =>
      IncidentQueueScreen(initialStage: _initialStage),
  };
}
