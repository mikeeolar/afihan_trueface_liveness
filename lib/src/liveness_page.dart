import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'camera_permission.dart';
import 'liveness_config.dart';
import 'liveness_event.dart';
import 'liveness_result.dart';
import 'liveness_session.dart';
import 'liveness_theme.dart';
import 'liveness_view.dart';
import 'ui.dart';

/// Entry point for running an Afihan TrueFace liveness check.
///
/// ```dart
/// final session = AfihanLivenessSession.fromJson(initiateResponse);
/// final result = await AfihanTrueFaceLiveness.start(
///   context,
///   session: session,
/// );
/// if (result.isPassed) {
///   // Confirm with your backend using result.widgetId.
/// }
/// ```
abstract final class AfihanTrueFaceLiveness {
  /// Shows the liveness check full screen and completes with its result.
  ///
  /// The returned future always completes with a result. If the route is
  /// removed without one, for example by your own navigation code, the result
  /// is [AfihanLivenessStatus.cancelled].
  static Future<AfihanLivenessResult> start(
    BuildContext context, {
    required AfihanLivenessSession session,
    AfihanLivenessConfig config = const AfihanLivenessConfig(),
    AfihanLivenessTheme theme = const AfihanLivenessTheme(),
    ValueChanged<AfihanLivenessEvent>? onEvent,
    AfihanCameraPermission? cameraPermission,
    bool useRootNavigator = true,
  }) async {
    final result = await Navigator.of(
      context,
      rootNavigator: useRootNavigator,
    ).push(
      route(
        session: session,
        config: config,
        theme: theme,
        onEvent: onEvent,
        cameraPermission: cameraPermission,
      ),
    );
    return result ?? AfihanLivenessResult.cancelled(widgetId: session.widgetId);
  }

  /// Builds the full screen route used by [start], for apps that manage
  /// navigation themselves.
  static Route<AfihanLivenessResult> route({
    required AfihanLivenessSession session,
    AfihanLivenessConfig config = const AfihanLivenessConfig(),
    AfihanLivenessTheme theme = const AfihanLivenessTheme(),
    ValueChanged<AfihanLivenessEvent>? onEvent,
    AfihanCameraPermission? cameraPermission,
  }) {
    return PageRouteBuilder<AfihanLivenessResult>(
      fullscreenDialog: true,
      settings: const RouteSettings(name: 'afihan_trueface_liveness'),
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          AfihanLivenessPage(
        session: session,
        config: config,
        theme: theme,
        onEvent: onEvent,
        cameraPermission: cameraPermission,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }
}

/// A full screen page that runs the check and pops itself with the result.
///
/// Usually shown through [AfihanTrueFaceLiveness.start].
class AfihanLivenessPage extends StatefulWidget {
  /// Creates the page.
  const AfihanLivenessPage({
    required this.session,
    this.config = const AfihanLivenessConfig(),
    this.theme = const AfihanLivenessTheme(),
    this.onEvent,
    this.cameraPermission,
    super.key,
  });

  /// The session created by your backend.
  final AfihanLivenessSession session;

  /// Behaviour settings.
  final AfihanLivenessConfig config;

  /// Colours and text of the native screens.
  final AfihanLivenessTheme theme;

  /// Called for every event.
  final ValueChanged<AfihanLivenessEvent>? onEvent;

  /// Overrides how camera access is requested.
  final AfihanCameraPermission? cameraPermission;

  @override
  State<AfihanLivenessPage> createState() => _AfihanLivenessPageState();
}

class _AfihanLivenessPageState extends State<AfihanLivenessPage> {
  bool _popped = false;

  void _finish(AfihanLivenessResult result) {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = LivenessPalette(widget.theme);
    final overlayStyle =
        palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: palette.background,
      ),
      child: ColoredBox(
        color: palette.background,
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: SafeArea(
            child: AfihanLivenessView(
              session: widget.session,
              config: widget.config,
              theme: widget.theme,
              onEvent: widget.onEvent,
              cameraPermission: widget.cameraPermission,
              onResult: _finish,
            ),
          ),
        ),
      ),
    );
  }
}
