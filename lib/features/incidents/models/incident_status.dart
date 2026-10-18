/// Defines the supported incident states.
enum IncidentStatus {
  /// A new incident awaiting review.
  reported('REPORTADA'),

  /// An incident being classified by an administrator.
  underReview('EN_REVISION'),

  /// An incident assigned to a technician.
  assigned('ASIGNADA'),

  /// An incident currently being handled.
  inProgress('EN_ATENCION'),

  /// An incident with a recorded solution.
  resolved('RESUELTA'),

  /// An incident formally closed by an administrator.
  closed('CERRADA'),

  /// An incident rejected during review.
  rejected('RECHAZADA'),

  /// An incident cancelled before resolution.
  cancelled('CANCELADA'),

  /// A resolved or closed incident requiring another review.
  reopened('REABIERTA');

  /// Value stored in Firestore.
  final String value;

  /// Creates a status with its stored value.
  const IncidentStatus(this.value);

  /// Returns the status associated with a stored value.
  ///
  /// Throws a [FormatException] if the value is unsupported.
  static IncidentStatus fromValue(String value) {
    for (final status in IncidentStatus.values) {
      if (status.value == value) {
        return status;
      }
    }
    throw FormatException('Unsupported incident status: $value');
  }
}
