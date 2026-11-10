import 'package:flutter/material.dart';

import '../navigation/campus_destination.dart';

/// Displays the same navigation options in a sidebar or drawer.
class CampusNavigation extends StatelessWidget {
  final CampusDestination selected;
  final List<CampusDestination> destinations;
  final ValueChanged<CampusDestination> onSelected;
  final bool collapsed;

  const CampusNavigation({
    super.key,
    required this.selected,
    required this.destinations,
    required this.onSelected,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = collapsed || constraints.maxWidth < 220;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              if (!compact)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    'UCR · CampusFix',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              for (final destination in destinations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: compact
                      ? Tooltip(
                          message: destination.label,
                          child: IconButton.filledTonal(
                            key: ValueKey('nav-${destination.name}'),
                            isSelected: selected == destination,
                            onPressed: () => onSelected(destination),
                            icon: Icon(destination.icon),
                          ),
                        )
                      : ListTile(
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
      },
    );
  }
}
