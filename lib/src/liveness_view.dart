import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'bridge_script.dart';
import 'camera_permission.dart';
import 'liveness_config.dart';
import 'liveness_event.dart';
import 'liveness_flow.dart';
import 'liveness_result.dart';
import 'liveness_session.dart';
import 'liveness_theme.dart';
import 'navigation_policy.dart';
import 'ui.dart';

/// Runs an Afihan liveness check inside your own layout.
///
/// Most apps should call `AfihanTrueFaceLiveness.start`, which shows this
/// view full screen and returns the result. Use the view directly when you
/// need to place the check inside your own page.
///
/// The view asks for camera access, loads the hosted check with no browser
/// chrome, listens to the page's result messages, and intercepts the page's
/// final redirect so the user never leaves your app. [onResult] is called
/// exactly once.
class AfihanLivenessView extends StatefulWidget {
  /// Creates the view.
  const AfihanLivenessView({
    required this.session,
    required this.onResult,
    this.config = const AfihanLivenessConfig(),
    this.theme = const AfihanLivenessTheme(),
    this.onEvent,
    this.cameraPermission,
    super.key,
  });

  /// The session created by your backend.
  final AfihanLivenessSession session;

  /// Called once with the final result.
  final ValueChanged<AfihanLivenessResult> onResult;

  /// Behaviour settings.
  final AfihanLivenessConfig config;

  /// Colours and text of the native screens.
  final AfihanLivenessTheme theme;

  /// Called for every event, for example to log analytics.
  final ValueChanged<AfihanLivenessEvent>? onEvent;

  /// Overrides how camera access is requested.
  ///
  /// Defaults to [AfihanCameraPermission.platform].
  final AfihanCameraPermission? cameraPermission;

  @override
  State<AfihanLivenessView> createState() => _AfihanLivenessViewState();
}

class _AfihanLivenessViewState extends State<AfihanLivenessView>
    with WidgetsBindingObserver {
  late LivenessFlow _flow;
  InAppWebViewController? _controller;
  bool _requestingPermission = false;
  bool _exitDialogOpen = false;

  AfihanCameraPermission get _permission =>
      widget.cameraPermission ??
      AfihanCameraPermission.platform(
        requestOnIOS: widget.config.requestCameraPermissionOnIOS,
        includeMicrophone: widget.config.allowMicrophone,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flow = _createFlow();
    unawaited(_requestCamera());
  }

  LivenessFlow _createFlow() {
    return LivenessFlow(
      session: widget.session,
      config: widget.config,
      onFinish: _deliver,
      onEvent: (event) => widget.onEvent?.call(event),
    )..addListener(_onFlowChanged);
  }

  @override
  void didUpdateWidget(covariant AfihanLivenessView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _flow
        ..removeListener(_onFlowChanged)
        ..dispose();
      _flow = _createFlow();
      _controller = null;
      unawaited(_requestCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the settings app: check the camera again.
    if (state == AppLifecycleState.resumed &&
        _flow.phase == LivenessPhase.cameraDenied) {
      unawaited(_requestCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flow
      ..removeListener(_onFlowChanged)
      ..dispose();
    super.dispose();
  }

  void _onFlowChanged() {
    if (mounted) setState(() {});
  }

  void _deliver(AfihanLivenessResult result) {
    widget.onResult(result);
  }

  Future<void> _requestCamera() async {
    if (_requestingPermission) return;
    _requestingPermission = true;
    final flow = _flow;
    var granted = false;
    try {
      granted = await _permission.request();
    } on Object catch (error) {
      // A missing manifest entry or plugin should not trap the user.
      debugPrint('afihan_trueface_liveness: camera request failed: $error');
      granted = false;
    } finally {
      _requestingPermission = false;
    }
    if (!mounted || flow != _flow) return;
    flow.cameraPermissionResolved(granted: granted);
  }

  Future<void> _retryLoad() async {
    _flow.retry();
    final controller = _controller;
    if (controller != null) {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri.uri(widget.session.widgetUrl)),
      );
    }
  }

  Future<void> _handleBack() async {
    if (_flow.isFinished || _exitDialogOpen) return;
    if (_flow.shouldConfirmExit) {
      _exitDialogOpen = true;
      final leave = await _confirmExit();
      _exitDialogOpen = false;
      if (!leave || !mounted) return;
    }
    _flow.close();
  }

  Future<bool> _confirmExit() => showLivenessExitDialog(context, widget.theme);

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final background = LivenessPalette(theme).background;
    final phase = _flow.phase;
    final showWebView = phase == LivenessPhase.loading ||
        phase == LivenessPhase.ready ||
        phase == LivenessPhase.loadFailed ||
        (phase == LivenessPhase.finished && _controller != null);

    return PopScope<Object?>(
      canPop: _flow.isFinished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: ColoredBox(
        color: background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showWebView && InAppWebViewPlatform.instance != null)
              _buildWebView(background),
            LivenessOverlay(
              visible: phase == LivenessPhase.preparingCamera ||
                  phase == LivenessPhase.loading,
              background: background,
              child: LivenessLoadingScreen(theme: theme),
            ),
            LivenessOverlay(
              visible: phase == LivenessPhase.cameraDenied,
              background: background,
              child: LivenessMessageScreen(
                theme: theme,
                glyph: LivenessGlyph.cameraOff,
                title: theme.strings.cameraDeniedTitle,
                message: theme.strings.cameraDeniedMessage,
                primaryLabel: theme.strings.openSettings,
                onPrimary: () => unawaited(_openSettings()),
                secondaryLabel: theme.strings.cancel,
                onSecondary: _flow.close,
              ),
            ),
            LivenessOverlay(
              visible: phase == LivenessPhase.loadFailed,
              background: background,
              child: LivenessMessageScreen(
                theme: theme,
                glyph: LivenessGlyph.offline,
                title: theme.strings.loadFailedTitle,
                message: theme.strings.loadFailedMessage,
                primaryLabel: theme.strings.tryAgain,
                onPrimary: () => unawaited(_retryLoad()),
                secondaryLabel: theme.strings.cancel,
                onSecondary: _flow.close,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final opened = await _permission.openSettings();
    // Some devices cannot open settings; asking again shows the system
    // prompt where the platform still allows it.
    if (!opened && mounted) await _requestCamera();
  }

  Widget _buildWebView(Color background) {
    final session = widget.session;
    final config = widget.config;
    return InAppWebView(
      key: ValueKey(session.widgetUrl),
      initialUrlRequest: URLRequest(url: WebUri.uri(session.widgetUrl)),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: buildLivenessBridgeScript(origin: session.origin),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          // The script itself only acts for the top window. Origin rules
          // are left open because Android and iOS expect different formats.
        ),
      ]),
      initialSettings: _settings(background, config),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: livenessBridgeHandler,
          callback: (arguments) async {
            final current = await controller.getUrl();
            if (current == null ||
                current.host.toLowerCase() !=
                    session.widgetUrl.host.toLowerCase()) {
              return null;
            }
            _flow.handleBridgeMessage(
              arguments.isEmpty ? null : arguments.first,
            );
            return null;
          },
        );
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url;
        if (url == null) return NavigationActionPolicy.ALLOW;
        final decision = _flow.handleNavigation(
          url,
          isMainFrame: action.isForMainFrame,
        );
        return decision == LivenessNavigation.allow
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onCreateWindow: (controller, action) async {
        final url = action.request.url;
        if (url != null &&
            _flow.handleNavigation(url, isMainFrame: true) ==
                LivenessNavigation.allow) {
          await controller.loadUrl(urlRequest: URLRequest(url: url));
        }
        return false;
      },
      onLoadStart: (controller, url) => _flow.pageLoadStarted(),
      onLoadStop: (controller, url) => _flow.pageLoaded(url),
      onReceivedError: (controller, request, error) {
        if (!request.isForMainFrame.orTrue || _isBenign(request, error)) return;
        _flow.pageFailed(error.description);
      },
      onReceivedHttpError: (controller, request, response) {
        final status = response.statusCode ?? 0;
        if (!request.isForMainFrame.orTrue || status < 400) return;
        if (request.url.host.toLowerCase() !=
            session.widgetUrl.host.toLowerCase()) {
          return;
        }
        _flow.pageFailed('HTTP $status');
      },
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
          resources: request.resources,
          action: _shouldGrant(request)
              ? PermissionResponseAction.GRANT
              : PermissionResponseAction.DENY,
        );
      },
      onRenderProcessGone: (controller, detail) {
        _flow.pageFailed('The page stopped unexpectedly.');
      },
      onWebContentProcessDidTerminate: (controller) {
        _flow.pageFailed('The page stopped unexpectedly.');
      },
    );
  }

  bool _shouldGrant(PermissionRequest request) {
    if (request.origin.host.toLowerCase() !=
        widget.session.widgetUrl.host.toLowerCase()) {
      return false;
    }
    final allowed = <PermissionResourceType>{
      PermissionResourceType.CAMERA,
      if (widget.config.allowMicrophone) ...[
        PermissionResourceType.MICROPHONE,
        PermissionResourceType.CAMERA_AND_MICROPHONE,
      ],
    };
    return request.resources.isNotEmpty &&
        request.resources.every(allowed.contains);
  }

  bool _isBenign(WebResourceRequest request, WebResourceError error) {
    // Cancelling a navigation, such as the intercepted redirect, is reported
    // as an error on some platforms. Errors for other hosts always come from
    // navigations this view cancelled itself.
    return error.type == WebResourceErrorType.CANCELLED ||
        request.url.host.toLowerCase() !=
            widget.session.widgetUrl.host.toLowerCase();
  }

  static InAppWebViewSettings _settings(
    Color background,
    AfihanLivenessConfig config,
  ) {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      useShouldOverrideUrlLoading: true,
      // Camera
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      allowsPictureInPictureMediaPlayback: false,
      allowsAirPlayForMediaPlayback: false,
      iframeAllow: config.allowMicrophone ? 'camera; microphone' : 'camera',
      // Native look: no zoom, bounce, scroll bars, menus or link previews
      transparentBackground: true,
      underPageBackgroundColor: background,
      supportZoom: false,
      builtInZoomControls: false,
      displayZoomControls: false,
      disallowOverScroll: true,
      overScrollMode: OverScrollMode.NEVER,
      verticalScrollBarEnabled: false,
      horizontalScrollBarEnabled: false,
      disableContextMenu: true,
      disableLongPressContextMenuOnLinks: true,
      allowsLinkPreview: false,
      allowsBackForwardNavigationGestures: false,
      disableInputAccessoryView: true,
      disableDefaultErrorPage: true,
      // Safety
      javaScriptCanOpenWindowsAutomatically: false,
      supportMultipleWindows: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      allowFileAccess: false,
      allowContentAccess: false,
      allowFileAccessFromFileURLs: false,
      allowUniversalAccessFromFileURLs: false,
      incognito: config.incognito,
      cacheEnabled: !config.incognito,
      isInspectable: kDebugMode,
      applicationNameForUserAgent: 'AfihanTrueFaceLiveness',
    );
  }
}

extension on bool? {
  bool get orTrue => this ?? true;
}
