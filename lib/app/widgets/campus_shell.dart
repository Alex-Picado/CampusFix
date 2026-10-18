import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/users/models/user_profile.dart';
import '../../features/users/presentation/user_role_labels.dart';
import '../../features/users/screens/profile_screen.dart';
import '../navigation/campus_destination.dart';
import '../screens/module_preview_screen.dart';
import '../screens/overview_screen.dart';
import '../theme/campus_theme.dart';
import 'campus_navigation.dart';

/// Hosts the common interface for an authenticated profile.
///
/// Resets inaccessible selections when the observed role changes.
/// Pending modules do not read or simulate incident data.
class CampusShell extends StatefulWidget {
  final UserProfile profile;

  const CampusShell({super.key, required this.profile});

  @override
  State<CampusShell> createState() => _CampusShellState();
}

class _CampusShellState extends State<CampusShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  CampusDestination _selected = CampusDestination.overview;

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

  Widget _page() {
    if (_selected == CampusDestination.overview) {
      return OverviewScreen(
        onNavigate: _select,
        destinations: CampusDestination.forRole(widget.profile.role),
      );
    }

    if (_selected == CampusDestination.profile) {
      return ProfileScreen(profile: widget.profile);
    }

    return ModulePreviewScreen(
      key: ValueKey('preview-${_selected.name}'),
      destination: _selected,
      onBack: () => _select(CampusDestination.overview),
    );
  }
}
