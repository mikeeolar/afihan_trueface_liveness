import 'dart:async';

import 'package:flutter/foundation.dart';

import 'liveness_config.dart';
import 'liveness_event.dart';
import 'liveness_result.dart';
import 'liveness_session.dart';
import 'navigation_policy.dart';

/// The visible phase of a liveness check.
@internal
enum LivenessPhase {
  /// Asking for camera access.
  preparingCamera,

  /// Camera access was refused.
  cameraDenied,

  /// The hosted page is loading.
  loading,

  /// The hosted page is visible.
  ready,

  /// The hosted page failed to load.
  loadFailed,

  /// A result was delivered.
  finished,
}

/// Runs the state of one liveness check, independently of any web view.
///
/// The web view feeds it page events, bridge messages and navigations, and it
/// decides what the user sees and when the check is over. [onFinish] is
/// called exactly once.
@internal
class LivenessFlow extends ChangeNotifier {
  /// Creates the flow.
  LivenessFlow({
    required this.session,
    required this.config,
    required this.onFinish,
    this.onEvent,
  }) : policy = LivenessNavigationPolicy(
          widgetUrl: session.widgetUrl,
          callbackUrl: config.callbackUrl,
          trustedHosts: config.trustedHosts,
        );

  /// The session being checked.
  final AfihanLivenessSession session;

  /// The behaviour settings.
  final AfihanLivenessConfig config;

  /// Receives the final result.
  final ValueChanged<AfihanLivenessResult> onFinish;

  /// Receives every event.
  final ValueChanged<AfihanLivenessEvent>? onEvent;

  /// Decides which navigations end the check.
  final LivenessNavigationPolicy policy;

  LivenessPhase _phase = LivenessPhase.preparingCamera;
  AfihanLivenessResult? _lastOutcome;
  AfihanLivenessResult? _result;
  String? _loadError;
  Timer? _passTimer;
  bool _disposed = false;

  /// The current phase.
  LivenessPhase get phase => _phase;

  /// The final result, once delivered.
  AfihanLivenessResult? get result => _result;

  /// The last pass, fail or error reported by the page, before the check
  /// closed.
  AfihanLivenessResult? get lastOutcome => _lastOutcome;

  /// The last load error, for the error screen.
  String? get loadError => _loadError;

  /// Whether a result was delivered.
  bool get isFinished => _result != null;

  /// Whether leaving now should ask the user first.
  ///
  /// True while the hosted check is in progress, and false once it produced
  /// an outcome or when no check is visible.
  bool get shouldConfirmExit =>
      config.confirmBeforeExit &&
      _phase == LivenessPhase.ready &&
      _lastOutcome == null;

  /// The widget id that bridge messages must carry.
  String? get widgetId => session.widgetId;

  /// Records the outcome of the native camera permission request.
  void cameraPermissionResolved({required bool granted}) {
    if (isFinished) return;
    _setPhase(granted ? LivenessPhase.loading : LivenessPhase.cameraDenied);
  }

  /// Called when the page starts loading, for example after a retry.
  void pageLoadStarted() {
    if (isFinished || _phase == LivenessPhase.loadFailed) return;
    if (_phase != LivenessPhase.ready) _setPhase(LivenessPhase.loading);
  }

  /// Called when the main frame finished loading [url].
  void pageLoaded(Uri? url) {
    if (isFinished || _phase == LivenessPhase.loadFailed) return;
    if (_phase != LivenessPhase.ready) {
      _setPhase(LivenessPhase.ready);
      _emit(AfihanLivenessPageLoaded(url));
    }
  }

  /// Called when the main frame could not load.
  void pageFailed(String description) {
    if (isFinished) return;
    _loadError = description;
    _setPhase(LivenessPhase.loadFailed);
  }

  /// Resets the flow after the user asked to try loading again.
  void retry() {
    if (isFinished) return;
    _loadError = null;
    _setPhase(LivenessPhase.loading);
  }

  /// Handles a message posted by the hosted page through the bridge.
  ///
  /// Returns the parsed event, or `null` when the message was ignored.
  AfihanLivenessEvent? handleBridgeMessage(Object? message) {
    if (isFinished) return null;
    final event = AfihanLivenessEvent.fromBridgeMessage(
      message,
      expectedWidgetId: widgetId,
    );
    if (event == null) return null;
    _emit(event);
    switch (event) {
      case AfihanLivenessCompleted(:final passed):
        _passTimer?.cancel();
        if (passed) {
          _lastOutcome = AfihanLivenessResult.passed(widgetId: widgetId);
          if (config.closeOnPass) {
            _passTimer = Timer(config.passRedirectTimeout, () {
              _finish(_lastOutcome ??
                  AfihanLivenessResult.passed(widgetId: widgetId));
            });
          }
        } else {
          _lastOutcome = AfihanLivenessResult.failed(widgetId: widgetId);
          if (config.closeOnFailure) _finish(_lastOutcome!);
        }
        notifyListeners();
      case AfihanLivenessFailedToRun(:final reason, :final rawReason):
        _passTimer?.cancel();
        _lastOutcome = AfihanLivenessResult.error(
          reason,
          widgetId: widgetId,
          message: rawReason,
        );
        if (config.closeOnError) _finish(_lastOutcome!);
        notifyListeners();
      case AfihanLivenessClosed():
        close();
      case AfihanLivenessPageLoaded() || AfihanLivenessRedirected():
        break;
    }
    return event;
  }

  /// Decides whether the web view may load [url].
  ///
  /// When the page is returning to the app, the result is delivered and
  /// [LivenessNavigation.callback] is returned so the caller cancels the
  /// navigation.
  LivenessNavigation handleNavigation(Uri url, {required bool isMainFrame}) {
    if (isFinished) return LivenessNavigation.block;
    final decision = policy.classify(url, isMainFrame: isMainFrame);
    if (decision == LivenessNavigation.callback) {
      _emit(AfihanLivenessRedirected(url));
      final stated = outcomeFromCallback(url);
      final previous = _lastOutcome;
      final passed = stated ??
          (previous == null || previous.status == AfihanLivenessStatus.passed);
      if (!passed && previous?.status == AfihanLivenessStatus.error) {
        _finish(previous!);
      } else {
        _finish(
          passed
              ? AfihanLivenessResult.passed(
                  widgetId: widgetId, callbackUrl: url)
              : AfihanLivenessResult.failed(
                  widgetId: widgetId, callbackUrl: url),
        );
      }
    }
    return decision;
  }

  /// Ends the check because the user left it.
  ///
  /// When the page already reported an outcome, that outcome is returned;
  /// otherwise the check is cancelled.
  void close() {
    if (_phase == LivenessPhase.cameraDenied && _lastOutcome == null) {
      _finish(
        AfihanLivenessResult.error(
          AfihanLivenessErrorReason.cameraPermissionDenied,
          widgetId: widgetId,
        ),
      );
      return;
    }
    if (_phase == LivenessPhase.loadFailed && _lastOutcome == null) {
      _finish(
        AfihanLivenessResult.error(
          AfihanLivenessErrorReason.loadFailed,
          widgetId: widgetId,
          message: _loadError,
        ),
      );
      return;
    }
    _finish(_lastOutcome ?? AfihanLivenessResult.cancelled(widgetId: widgetId));
  }

  void _finish(AfihanLivenessResult result) {
    if (isFinished || _disposed) return;
    _passTimer?.cancel();
    _result = result;
    _phase = LivenessPhase.finished;
    notifyListeners();
    onFinish(result);
  }

  void _emit(AfihanLivenessEvent event) => onEvent?.call(event);

  void _setPhase(LivenessPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _passTimer?.cancel();
    super.dispose();
  }
}
