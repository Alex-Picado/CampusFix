/// Defines the stored action codes used by incident history events.
enum IncidentHistoryAction {
  /// An incident was reported.
  created('created'),

  /// An incident's category or priority was classified.
  classified('classified'),

  /// A technician was assigned to an incident.
  assigned('assigned'),

  /// The assigned technician started attention.
  started('started'),

  /// The assigned technician recorded progress.
  progressAdded('progressAdded'),

  /// A resolution was recorded.
  resolved('resolved'),

  /// An incident was formally closed.
  closed('closed'),

  /// An incident was rejected during review.
  rejected('rejected'),

  /// An incident was cancelled.
  cancelled('cancelled'),

  /// An incident was reopened for review.
  reopened('reopened');

  /// Stable English action code stored in the history document.
  final String value;

  /// Creates a history action with its stored code.
  const IncidentHistoryAction(this.value);

  /// Returns the action associated with a stored code.
  ///
  /// Throws a [FormatException] when the code is unsupported.
  static IncidentHistoryAction fromValue(String value) {
    for (final action in IncidentHistoryAction.values) {
      if (action.value == value) {
        return action;
      }
    }

    throw FormatException('Unsupported incident history action: $value');
  }
}
