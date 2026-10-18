/// Defines the application's session states.
enum SessionStatus {
  /// Authentication or profile information is loading.
  loading,

  /// No account is currently signed in.
  signedOut,

  /// An account is signed in but its profile is missing.
  profileRequired,

  /// Both the authenticated account and its profile are available.
  authenticated,

  /// Authentication or profile observation failed.
  failure,
}
