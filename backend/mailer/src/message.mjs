const labels = Object.freeze({
  REPORTADA: 'Reportada',
  EN_REVISION: 'En revisión',
  ASIGNADA: 'Asignada',
  EN_ATENCION: 'En atención',
  RESUELTA: 'Resuelta',
  REVISION_SOLICITADA: 'Revisión solicitada',
  CERRADA: 'Cerrada',
  RECHAZADA: 'Rechazada',
  CANCELADA: 'Cancelada',
  REABIERTA: 'Reabierta',
});

export function recipientIds(incident, event, administrators) {
  const ids = [
    incident.createdByUserId,
    event.fromTechnicianId,
    event.toTechnicianId,
    ...(Array.isArray(incident.technicianQueue) ? incident.technicianQueue : []),
    event.actorUserId,
    ...administrators,
  ];
  return [...new Set(ids.filter((id) => typeof id === 'string' && id.trim()))];
}

export function messageFor(incidentId, incident, event, recipientName, appBaseUrl) {
  const label = labels[event.toStatus] ?? event.toStatus;
  const number = Number.isSafeInteger(incident.sequenceNumber)
    ? `#${incident.sequenceNumber}` : incidentId;
  const link = `${appBaseUrl.replace(/\/$/, '')}/#/incidents/${encodeURIComponent(incidentId)}`;
  return {
    subject: `CampusFix: reporte ${number} — ${label}`,
    text: [
      `Hola ${recipientName || 'usuario'},`,
      '',
      `El reporte ${number} cambió de ${labels[event.fromStatus] ?? event.fromStatus} a ${label}.`,
      '',
      `Consultar reporte: ${link}`,
      '',
      'CampusFix',
    ].join('\n'),
  };
}
