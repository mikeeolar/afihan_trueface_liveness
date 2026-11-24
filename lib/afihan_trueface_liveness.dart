/// Run the Afihan TrueFace liveness check in a Flutter app.
///
/// Create a session on your backend, parse it with
/// [AfihanLivenessSession.fromJson], then call
/// [AfihanTrueFaceLiveness.start]. The check opens full screen with camera
/// access ready, and returns an [AfihanLivenessResult] when the hosted page
/// finishes or redirects.
library;

export 'src/camera_permission.dart' show AfihanCameraPermission;
export 'src/liveness_config.dart' show AfihanLivenessConfig;
export 'src/liveness_event.dart'
    show
        AfihanLivenessClosed,
        AfihanLivenessCompleted,
        AfihanLivenessEvent,
        AfihanLivenessFailedToRun,
        AfihanLivenessPageLoaded,
        AfihanLivenessRedirected;
export 'src/liveness_page.dart' show AfihanLivenessPage, AfihanTrueFaceLiveness;
export 'src/liveness_result.dart'
    show AfihanLivenessErrorReason, AfihanLivenessResult, AfihanLivenessStatus;
export 'src/liveness_session.dart' show AfihanLivenessSession;
export 'src/liveness_theme.dart'
    show AfihanLivenessStrings, AfihanLivenessTheme;
export 'src/liveness_view.dart' show AfihanLivenessView;
export 'src/ui.dart'
    show afihanAccentColor, afihanBackgroundColor, afihanForegroundColor;
