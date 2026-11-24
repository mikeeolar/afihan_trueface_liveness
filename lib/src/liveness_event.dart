import 'dart:convert';

import 'package:meta/meta.dart';

import 'liveness_result.dart';

/// Something that happened during a liveness check.
///
/// Listen to events with `AfihanLivenessView.onEvent`, for example to log
/// analytics. You do not need events to get the final result.
@immutable
sealed class AfihanLivenessEvent {
  const AfihanLivenessEvent();

  /// Parses a message posted by the hosted liveness page.
  ///
  /// [message] may be a JSON string or an already decoded map. Returns `null`
  /// for anything that is not a recognised liveness message, or that carries
  /// a `widget_id` different from [expectedWidgetId].
  static AfihanLivenessEvent? fromBridgeMessage(
    Object? message, {
    String? expectedWidgetId,
  }) {
    Object? decoded = message;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } on FormatException {
        return null;
      }
    }
    if (decoded is! Map) return null;
    final data = decoded.cast<Object?, Object?>();

    final widgetId = data['widget_id'];
    if (widgetId != null && widgetId is! String) return null;
    if (widgetId is String &&
        expectedWidgetId != null &&
        widgetId.trim() != expectedWidgetId) {
      return null;
    }
    final id = widgetId is String ? widgetId.trim() : null;

    switch (data['type']) {
      case 'liveness_complete':
        final success = data['success'];
        if (success is! bool) return null;
        return AfihanLivenessCompleted(passed: success, widgetId: id);
      case 'liveness_error':
        final reason = data['reason'];
        return AfihanLivenessFailedToRun(
          reason: AfihanLivenessErrorReason.fromWire(
            reason is String ? reason : null,
          ),
          rawReason: reason is String ? reason : null,
          widgetId: id,
        );
      case 'liveness_close':
        return const AfihanLivenessClosed();
      default:
        return null;
    }
  }
}

/// The liveness page finished loading and is visible.
final class AfihanLivenessPageLoaded extends AfihanLivenessEvent {
  /// Creates the event.
  const AfihanLivenessPageLoaded(this.url);

  /// The page that loaded.
  final Uri? url;

  @override
  bool operator ==(Object other) =>
      other is AfihanLivenessPageLoaded && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'AfihanLivenessPageLoaded($url)';
}

/// The hosted page produced a pass or fail decision.
///
/// After a failure the page offers the user another attempt, so more events
/// may follow.
final class AfihanLivenessCompleted extends AfihanLivenessEvent {
  /// Creates the event.
  const AfihanLivenessCompleted({required this.passed, this.widgetId});

  /// Whether the capture passed.
  final bool passed;

  /// The widget the decision belongs to.
  final String? widgetId;

  @override
  bool operator ==(Object other) =>
      other is AfihanLivenessCompleted &&
      other.passed == passed &&
      other.widgetId == widgetId;

  @override
  int get hashCode => Object.hash(passed, widgetId);

  @override
  String toString() =>
      'AfihanLivenessCompleted(passed: $passed, widgetId: $widgetId)';
}

/// The hosted page reported that the check cannot run.
final class AfihanLivenessFailedToRun extends AfihanLivenessEvent {
  /// Creates the event.
  const AfihanLivenessFailedToRun({
    required this.reason,
    this.rawReason,
    this.widgetId,
  });

  /// The reason, mapped to a known value.
  final AfihanLivenessErrorReason reason;

  /// The reason exactly as the page sent it.
  final String? rawReason;

  /// The widget the error belongs to.
  final String? widgetId;

  @override
  bool operator ==(Object other) =>
      other is AfihanLivenessFailedToRun &&
      other.reason == reason &&
      other.rawReason == rawReason &&
      other.widgetId == widgetId;

  @override
  int get hashCode => Object.hash(reason, rawReason, widgetId);

  @override
  String toString() =>
      'AfihanLivenessFailedToRun(reason: ${reason.name}, widgetId: $widgetId)';
}

/// The user closed the hosted page with its own back or close button.
final class AfihanLivenessClosed extends AfihanLivenessEvent {
  /// Creates the event.
  const AfihanLivenessClosed();

  @override
  bool operator ==(Object other) => other is AfihanLivenessClosed;

  @override
  int get hashCode => (AfihanLivenessClosed).hashCode;

  @override
  String toString() => 'AfihanLivenessClosed()';
}

/// The hosted page tried to leave for a redirect URL, and the navigation was
/// intercepted so the user returns to the app.
final class AfihanLivenessRedirected extends AfihanLivenessEvent {
  /// Creates the event.
  const AfihanLivenessRedirected(this.url);

  /// The URL the page tried to open.
  final Uri url;

  @override
  bool operator ==(Object other) =>
      other is AfihanLivenessRedirected && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'AfihanLivenessRedirected($url)';
}
