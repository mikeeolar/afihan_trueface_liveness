import 'package:meta/meta.dart';

/// The overall outcome of a liveness check.
enum AfihanLivenessStatus {
  /// The hosted check reported that the face passed the liveness check.
  passed,

  /// The hosted check reported that the capture could not be verified.
  failed,

  /// The user left the check before it produced a result.
  cancelled,

  /// The check could not run. See [AfihanLivenessResult.errorReason].
  error,
}

/// Why a liveness check ended with [AfihanLivenessStatus.error].
enum AfihanLivenessErrorReason {
  /// The widget link expired or was already used. Create a new session.
  invalidSession,

  /// The liveness service could not confirm a result, usually because of a
  /// network problem.
  unavailable,

  /// The user did not allow camera access.
  cameraPermissionDenied,

  /// The liveness page could not be loaded.
  loadFailed,

  /// The hosted page reported an error this package does not know about.
  unknown;

  /// Maps the `reason` string sent by the hosted page to a reason.
  static AfihanLivenessErrorReason fromWire(String? value) {
    switch (value) {
      case 'invalid_session':
        return AfihanLivenessErrorReason.invalidSession;
      case 'unavailable':
        return AfihanLivenessErrorReason.unavailable;
      default:
        return AfihanLivenessErrorReason.unknown;
    }
  }
}

/// The result returned when a liveness check finishes.
///
/// This is a client-side notification. Always confirm the final decision with
/// your backend using [widgetId] before granting access to anything.
@immutable
class AfihanLivenessResult {
  /// Creates a result.
  const AfihanLivenessResult({
    required this.status,
    this.widgetId,
    this.callbackUrl,
    this.errorReason,
    this.message,
  });

  /// A result for a check that passed.
  const AfihanLivenessResult.passed({String? widgetId, Uri? callbackUrl})
      : this(
          status: AfihanLivenessStatus.passed,
          widgetId: widgetId,
          callbackUrl: callbackUrl,
        );

  /// A result for a check that failed.
  const AfihanLivenessResult.failed({String? widgetId, Uri? callbackUrl})
      : this(
          status: AfihanLivenessStatus.failed,
          widgetId: widgetId,
          callbackUrl: callbackUrl,
        );

  /// A result for a check the user left.
  const AfihanLivenessResult.cancelled({String? widgetId})
      : this(status: AfihanLivenessStatus.cancelled, widgetId: widgetId);

  /// A result for a check that could not run.
  const AfihanLivenessResult.error(
    AfihanLivenessErrorReason reason, {
    String? widgetId,
    String? message,
  }) : this(
          status: AfihanLivenessStatus.error,
          widgetId: widgetId,
          errorReason: reason,
          message: message,
        );

  /// The overall outcome.
  final AfihanLivenessStatus status;

  /// The widget the result belongs to. Use it to confirm the outcome with
  /// your backend.
  final String? widgetId;

  /// The redirect URL the hosted page navigated to when it finished, if any.
  ///
  /// The navigation is intercepted, so the user returns to your app instead
  /// of seeing that page.
  final Uri? callbackUrl;

  /// Why the check failed to run, when [status] is
  /// [AfihanLivenessStatus.error].
  final AfihanLivenessErrorReason? errorReason;

  /// Extra detail about an error, meant for logs rather than end users.
  final String? message;

  /// Whether the check passed.
  bool get isPassed => status == AfihanLivenessStatus.passed;

  /// Whether the check failed.
  bool get isFailed => status == AfihanLivenessStatus.failed;

  /// Whether the user cancelled the check.
  bool get isCancelled => status == AfihanLivenessStatus.cancelled;

  /// Whether the check could not run.
  bool get isError => status == AfihanLivenessStatus.error;

  @override
  bool operator ==(Object other) =>
      other is AfihanLivenessResult &&
      other.status == status &&
      other.widgetId == widgetId &&
      other.callbackUrl == callbackUrl &&
      other.errorReason == errorReason &&
      other.message == message;

  @override
  int get hashCode =>
      Object.hash(status, widgetId, callbackUrl, errorReason, message);

  @override
  String toString() {
    final parts = <String>[
      'status: ${status.name}',
      if (widgetId != null) 'widgetId: $widgetId',
      if (errorReason != null) 'errorReason: ${errorReason!.name}',
      if (callbackUrl != null) 'callbackUrl: $callbackUrl',
      if (message != null) 'message: $message',
    ];
    return 'AfihanLivenessResult(${parts.join(', ')})';
  }
}
