import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../users/models/user_profile.dart';
import '../../users/models/user_role.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../incidents/repositories/incident_repository.dart';
import '../../incidents/presentation/incident_action_labels.dart';
import '../../incidents/widgets/administrative_summary.dart';
import '../controllers/notification_controller.dart';

class NotificationBell extends StatefulWidget {
  final UserProfile profile;
  const NotificationBell({super.key, required this.profile});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final NotificationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = NotificationController(
      repository: context.read<IncidentRepository>(),
      profile: widget.profile,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => IconButton(
      key: const ValueKey('notification-bell'),
      tooltip:
          'Notificaciones${_controller.unread > 0 ? ' (${_controller.unread} nuevas)' : ''}',
      onPressed: _open,
      icon: Badge(
        key: const ValueKey('notification-unread-dot'),
        isLabelVisible: _controller.unread > 0,
        backgroundColor: const Color(0xFFD32F2F),
        child: const Icon(Icons.notifications_outlined),
      ),
    ),
  );

  void _open() {
    final navigator = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 650),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Consumer<SessionController>(
            builder: (context, session, _) {
              if (session.status != SessionStatus.authenticated ||
                  session.profile?.id != widget.profile.id ||
                  session.profile?.role != widget.profile.role) {
                return const Center(
                  child: Text(
                    'La sesión cambió. Cerrá este panel para continuar.',
                  ),
                );
              }
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final entries = _controller.entries;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Notificaciones',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            TextButton(
                              onPressed: _controller.unread == 0
                                  ? null
                                  : () => _controller.markRead(entries),
                              child: const Text('Marcar todas como leídas'),
                            ),
                          ],
                        ),
                      ),
                      if (_controller.loading) const LinearProgressIndicator(),
                      if (_controller.error != null)
                        ListTile(
                          title: Text(_controller.error!),
                          trailing: TextButton(
                            onPressed: _controller.retry,
                            child: const Text('Reintentar'),
                          ),
                        ),
                      Expanded(
                        child: entries.isEmpty
                            ? Center(
                                child: Text(
                                  _controller.loading
                                      ? 'Cargando notificaciones…'
                                      : 'Estás al día. No hay novedades.',
                                ),
                              )
                            : ListView.separated(
                                itemCount: entries.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final entry = entries[index];
                                  final date = campusTime(
                                    entry.event.createdAt,
                                  );
                                  return ListTile(
                                    leading: Icon(
                                      _controller.isUnread(entry)
                                          ? Icons.notifications_active
                                          : Icons.notifications_none,
                                      color: _controller.isUnread(entry)
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                          : null,
                                    ),
                                    title: Text(
                                      '#${entry.incident.sequenceNumber} · ${entry.incident.title}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${widget.profile.role == UserRole.reporter ? 'Tu incidencia tiene una solución para revisar.' : entry.event.action.label}\n${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                    ),
                                    isThreeLine: true,
                                    trailing: _controller.isUnread(entry)
                                        ? const Badge(
                                            backgroundColor: Color(0xFFD32F2F),
                                          )
                                        : null,
                                    onTap: () {
                                      _controller.markRead(
                                        entries.where(
                                          (row) =>
                                              row.incident.id ==
                                              entry.incident.id,
                                        ),
                                      );
                                      Navigator.of(context).pop();
                                      navigator.pushNamed(
                                        '/incidents/${Uri.encodeComponent(entry.incident.id)}',
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
