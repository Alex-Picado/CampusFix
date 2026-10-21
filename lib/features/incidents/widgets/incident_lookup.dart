import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';

/// Opens an existing assigned incident without implementing assignment management.
class IncidentLookup extends StatefulWidget {
  const IncidentLookup({super.key});
  @override
  State<IncidentLookup> createState() => _IncidentLookupState();
}

class _IncidentLookupState extends State<IncidentLookup> {
  final _id = TextEditingController();
  String? _error;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seguimiento de una incidencia',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('incident-lookup-id'),
          controller: _id,
          decoration: InputDecoration(
            labelText: 'Identificador de la incidencia',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            final id = _id.text.trim();
            if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
              setState(() => _error = 'Ingresá un identificador válido.');
              return;
            }
            setState(() => _error = null);
            Navigator.of(context).pushNamed('/incidents/$id');
          },
          child: const Text('Abrir seguimiento'),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }
}
