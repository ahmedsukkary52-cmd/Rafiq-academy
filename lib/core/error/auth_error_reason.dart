/// Why an authentication step failed. Drives which Auth state is shown
/// (retryable network state vs. a terminal account state).
enum AuthErrorReason {
  generic,
  invalidCredentials,
  invalidEmail,
  notProvisioned,
  disabled,
  network,
  tooManyRequests,
  sessionEnded,
}
