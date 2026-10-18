import 'package:flutter/material.dart';

import '../navigation/campus_destination.dart';
import '../screens/module_preview_screen.dart';
import '../screens/overview_screen.dart';
import '../theme/campus_theme.dart';
import 'campus_navigation.dart';

/// Hosts the simple common interface and navigable module previews.
///
/// No private data is read here. Authentication and role-specific navigation
/// will be integrated with the existing controllers in a later block.
class CampusShell extends StatefulWidget {
  const CampusShell({super.key});

  @override
  State<CampusShell> createState() => _CampusShellState();
}

class _CampusShellState extends State<CampusShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  CampusDestination _selected = CampusDestination.overview;

  void _select(CampusDestination destination) {
    setState(() {
      _selected = destination;
    });
    _scaffoldKey.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer = constraints.maxWidth < 900;
        Widget? drawer;
        Widget? leading;

        if (useDrawer) {
          drawer = Drawer(
            width: 260,
            child: SafeArea(
              child: CampusNavigation(selected: _selected, onSelected: _select),
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
            actions: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: Text(
                    'Vista previa',
                    style: TextStyle(
                      fontSize: 13,
                      color: CampusTheme.secondaryText,
                    ),
                  ),
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
      return OverviewScreen(onNavigate: _select);
    }

    return ModulePreviewScreen(
      key: ValueKey('preview-${_selected.name}'),
      destination: _selected,
      onBack: () => _select(CampusDestination.overview),
    );
  }
}
