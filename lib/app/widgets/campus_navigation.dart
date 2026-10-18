import 'package:flutter/material.dart';

import '../navigation/campus_destination.dart';

/// Displays the same navigation options in a sidebar or drawer.
class CampusNavigation extends StatelessWidget {
  final CampusDestination selected;
  final ValueChanged<CampusDestination> onSelected;

  const CampusNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text('Menú', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final destination in CampusDestination.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                key: ValueKey('nav-${destination.name}'),
                selected: selected == destination,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Icon(destination.icon),
                title: Text(destination.label),
                onTap: () => onSelected(destination),
              ),
            ),
        ],
      ),
    );
  }
}
