/// Defines the stored action codes used by incident history events.
enum IncidentHistoryAction {
  /// An incident was reported.
  created('created'),

  /// An incident's category or priority was classified.
  classified('classified'),

  /// A technician was assigned to an incident.
  assigned('assigned'),

  /// The assigned technician declined the work with a reason.
  assignmentDeclined('assignmentDeclined'),

  /// The assigned technician started attention.
  started('started'),

  /// The assigned technician recorded progress.
  progressAdded('progressAdded'),

  /// A resolution was recorded.
  resolved('resolved'),

  /// The original reporter accepted the current solution.
  solutionAccepted('solutionAccepted'),

  /// The reporter explained why the solution needs another review.
  reviewRequested('reviewRequested'),

  /// An administrator answered a review; fresh closure approvals are required.
  reviewDismissed('reviewDismissed'),

  /// An incident was formally closed.
  closed('closed'),

  /// An incident was rejected during review.
  rejected('rejected'),

  /// An incident was cancelled.
  cancelled('cancelled'),

  /// The author withdrew the report from their views without deleting audit.
  removedFromList('removedFromList'),

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
