import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/section_card.dart';
import '../../auth/controllers/session_controller.dart';
import '../controllers/evidence_upload_controller.dart';
import '../models/incident_evidence.dart';
import '../repositories/evidence_repository.dart';

/// Owns one account-bound report-photo upload and recoverable association.
class ReportPhotoUpload extends StatelessWidget {
  final String incidentId;
  const ReportPhotoUpload({super.key, required this.incidentId});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<EvidenceRepository?>();
    final session = context.read<SessionController>();
    if (repository == null || session.profile == null) {
      return const SizedBox.shrink();
    }
    return ChangeNotifierProvider(
      key: ValueKey('${session.profile!.id}:$incidentId'),
      create: (_) => EvidenceUploadController(
        repository: repository,
        session: session,
        uid: session.profile!.id,
        incidentId: incidentId,
      ),
      child: const _UploadView(),
    );
  }
}

class _UploadView extends StatelessWidget {
  const _UploadView();
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EvidenceUploadController>();
    if (!controller.active) return const SizedBox.shrink();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adjuntar fotografía',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('JPEG, PNG o WebP · Hasta 3 MB por fotografía.'),
          if (controller.fileName != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(controller.fileName!),
            ),
          if (controller.success != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(controller.success!),
              ),
            ),
          if (controller.photo != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Image.memory(
                controller.photo!.bytes,
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (controller.attempted &&
              controller.photo == null &&
              controller.reference == null)
            const Text(
              'Seleccioná nuevamente la fotografía original para recuperar la carga.',
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('photo-select'),
                onPressed: controller.canSelect ? controller.select : null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Seleccionar foto'),
              ),
              if (controller.id != null)
                FilledButton(
                  key: const ValueKey('photo-upload'),
                  onPressed:
                      controller.busy ||
                          (controller.photo == null &&
                              controller.reference == null)
                      ? null
                      : controller.upload,
                  child: Text(
                    controller.busy
                        ? 'Guardando foto...'
                        : controller.attempted
                        ? 'Reintentar foto'
                        : 'Guardar foto',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Downloads protected bytes rather than passing token-bearing URLs to image widgets.
class EvidenceGallery extends StatelessWidget {
  final String uid;
  final List<IncidentEvidence> evidence;
  const EvidenceGallery({super.key, required this.uid, required this.evidence});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final photo in evidence)
        _ProtectedPhoto(
          key: ValueKey('$uid:${photo.id}'),
          uid: uid,
          evidence: photo,
        ),
    ],
  );
}

class _ProtectedPhoto extends StatefulWidget {
  final String uid;
  final IncidentEvidence evidence;
  const _ProtectedPhoto({super.key, required this.uid, required this.evidence});
  @override
  State<_ProtectedPhoto> createState() => _ProtectedPhotoState();
}

class _ProtectedPhotoState extends State<_ProtectedPhoto> {
  late Future<Uint8List> _bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bytes = context.read<EvidenceRepository?>()!.download(
      widget.uid,
      widget.evidence,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.hasData)
            Image.memory(
              snapshot.data!,
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Text('No se pudo mostrar esta fotografía.'),
            )
          else if (snapshot.hasError)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No se pudo cargar la foto. Revisá el servicio local.',
                ),
                TextButton(
                  onPressed: () => setState(_load),
                  child: const Text('Reintentar foto'),
                ),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          const SizedBox(height: 8),
          Text(widget.evidence.fileName),
          if (widget.evidence.progressId != null)
            const Text('Evidencia de avance'),
        ],
      ),
    ),
  );
}
