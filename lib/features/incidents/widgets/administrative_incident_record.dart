import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';
import '../controllers/incident_detail_controller.dart';
import '../models/incident_evidence.dart';
import '../models/incident_history_event.dart';
import 'evidence_widgets.dart';
import 'incident_detail_cards.dart';

/// Tabbed audit history, progress and photography for the administrative view.
class AdministrativeIncidentRecord extends StatefulWidget {
  final IncidentDetailController controller;
  final String Function(String) person;
  final String Function(DateTime) formatDate;
  final String Function(IncidentHistoryEvent) actionLabel;

  const AdministrativeIncidentRecord({
    super.key,
    required this.controller,
    required this.person,
    required this.formatDate,
    required this.actionLabel,
  });

  @override
  State<AdministrativeIncidentRecord> createState() =>
      _AdministrativeIncidentRecordState();
}

enum _RecordTab {
  history('Historial', 'history'),
  progress('Avances y comentarios', 'progress'),
  photos('Fotografías', 'evidence');

  final String label;
  final String section;
  const _RecordTab(this.label, this.section);
}

class _AdministrativeIncidentRecordState
    extends State<AdministrativeIncidentRecord> {
  _RecordTab _selected = _RecordTab.history;
  bool _recentFirst = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final loading = controller.loadingSections.contains(_selected.section);
    return SectionCard(
      key: const ValueKey('administrative-incident-record'),
      child: Semantics(
        container: true,
        label: 'Registro de la incidencia',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final tab in _RecordTab.values)
                      ChoiceChip(
                        key: ValueKey('incident-record-${tab.name}'),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        label: Text(_tabLabel(tab)),
                        selected: _selected == tab,
                        selectedColor: colors.primaryContainer,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _selected = tab),
                      ),
                  ],
                ),
                if (_selected == _RecordTab.history)
                  OutlinedButton.icon(
                    key: const ValueKey('incident-history-sort'),
                    onPressed: () =>
                        setState(() => _recentFirst = !_recentFirst),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.swap_vert, size: 18),
                    label: Text(
                      _recentFirst
                          ? 'Más reciente primero'
                          : 'Más antiguo primero',
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (loading)
              const LinearProgressIndicator()
            else
              switch (_selected) {
                _RecordTab.history => _history(),
                _RecordTab.progress => IncidentProgressEntries(
                  controller: controller,
                  person: widget.person,
                  formatDate: widget.formatDate,
                ),
                _RecordTab.photos => IncidentPhotoContent(
                  controller: controller,
                ),
              },
          ],
        ),
      ),
    );
  }

  String _tabLabel(_RecordTab tab) {
    final controller = widget.controller;
    if (controller.loadingSections.contains(tab.section)) return tab.label;
    final count = switch (tab) {
      _RecordTab.history => controller.history.length,
      _RecordTab.progress => controller.progress.length,
      _RecordTab.photos =>
        controller.evidenceRepository == null
            ? null
            : controller.evidence.length,
    };
    return count == null ? tab.label : '${tab.label} ($count)';
  }

  Widget _history() {
    final controller = widget.controller;
    final events = _recentFirst
        ? controller.history.reversed.toList()
        : controller.history;
    if (events.isEmpty) return const Text('No hay eventos registrados.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, event) in events.indexed)
          IncidentHistoryCard(
            key: ValueKey('history-event-${event.id}'),
            event: event,
            title: widget.actionLabel(event),
            timestamp: widget.formatDate(event.createdAt),
            person: widget.person,
            categoryName:
                event.details?['categoryId'] == controller.category?.id
                ? controller.category?.name
                : null,
            inTimeline: true,
            showTimelineConnector: index < events.length - 1,
          ),
      ],
    );
  }
}

/// Displays confirmed progress notes and their optional linked evidence.
class IncidentProgressEntries extends StatelessWidget {
  final IncidentDetailController controller;
  final String Function(String) person;
  final String Function(DateTime) formatDate;

  const IncidentProgressEntries({
    super.key,
    required this.controller,
    required this.person,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.progress.isEmpty) {
      return const Text('Todavía no hay avances registrados.');
    }
    final theme = Theme.of(context);
    final photosByProgress = <String, List<IncidentEvidence>>{};
    for (final photo in controller.evidence) {
      final progressId = photo.progressId;
      if (progressId != null) {
        photosByProgress.putIfAbsent(progressId, () => []).add(photo);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, entry) in controller.progress.indexed)
          Container(
            key: ValueKey('progress-entry-${entry.id}'),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 3),
              ),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avance ${index + 1} · Técnico: ${person(entry.authorUserId)}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  formatDate(entry.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SelectableText(entry.description),
                if (photosByProgress[entry.id] case final photos?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: EvidenceGallery(
                      uid: controller.uid,
                      evidence: photos,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Uses the current environment's photo availability and authorized gallery.
class IncidentPhotoContent extends StatelessWidget {
  final IncidentDetailController controller;

  const IncidentPhotoContent({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.evidenceRepository == null) {
      return const PhotoAvailabilityNotice();
    }
    if (controller.evidence.isEmpty) {
      return const Text('No hay fotografías asociadas.');
    }
    return EvidenceGallery(uid: controller.uid, evidence: controller.evidence);
  }
}
