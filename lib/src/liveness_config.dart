import 'package:meta/meta.dart';

/// Behaviour settings for a liveness check.
///
/// The defaults suit most apps: the check closes by itself shortly after a
/// pass, while after a failure or error the user stays on the hosted result
/// screen, where they can try again or close it.
@immutable
class AfihanLivenessConfig {
  /// Creates a configuration.
  const AfihanLivenessConfig({
    this.callbackUrl,
    this.trustedHosts = const <String>{},
    this.closeOnPass = true,
    this.closeOnFailure = false,
    this.closeOnError = false,
    this.passRedirectTimeout = const Duration(seconds: 4),
    this.confirmBeforeExit = true,
    this.allowMicrophone = false,
    this.requestCameraPermissionOnIOS = false,
    this.incognito = false,
  });

  /// The URL your backend asks the liveness service to redirect to when the
  /// check passes, for example `https://myapp.com/liveness/done` or
  /// `myapp://liveness`.
  ///
  /// It is optional. Any navigation away from the liveness host is already
  /// treated as the end of the check. Setting it makes matching exact, which
  /// also lets the callback live on the same host as the widget.
  final Uri? callbackUrl;

  /// Extra hosts the liveness page may navigate to without ending the check.
  ///
  /// The host of the widget URL is always trusted.
  final Set<String> trustedHosts;

  /// Whether to return to the app after a pass.
  ///
  /// The hosted page redirects to its callback URL about 2.5 seconds after a
  /// pass. The check closes on that redirect, or after [passRedirectTimeout]
  /// when no redirect comes.
  final bool closeOnPass;

  /// Whether to return to the app as soon as a capture fails.
  ///
  /// When `false` (the default) the user can try again on the hosted page.
  final bool closeOnFailure;

  /// Whether to return to the app as soon as the hosted page reports that
  /// the session is invalid or the service is unavailable.
  ///
  /// When `false` (the default) the user reads the message on the hosted page
  /// and closes it with its button.
  final bool closeOnError;

  /// How long to wait for the hosted page's redirect after a pass.
  final Duration passRedirectTimeout;

  /// Whether the system back gesture asks for confirmation before leaving a
  /// check that is in progress.
  final bool confirmBeforeExit;

  /// Whether the page may use the microphone as well as the camera.
  ///
  /// The Afihan check only needs the camera. Enable this only if your hosted
  /// flow records audio, and add the matching Android and iOS permissions.
  final bool allowMicrophone;

  /// Whether to ask for camera access natively on iOS before the page loads.
  ///
  /// On iOS the web view asks for camera access by itself, so this is off by
  /// default. Turn it on only after enabling `PERMISSION_CAMERA=1` for
  /// `permission_handler` in your `ios/Podfile`. On Android the camera is
  /// always requested natively first.
  final bool requestCameraPermissionOnIOS;

  /// Whether the web view keeps no cookies, cache or storage after the check.
  final bool incognito;

  /// Returns a copy with the given fields replaced.
  AfihanLivenessConfig copyWith({
    Uri? callbackUrl,
    Set<String>? trustedHosts,
    bool? closeOnPass,
    bool? closeOnFailure,
    bool? closeOnError,
    Duration? passRedirectTimeout,
    bool? confirmBeforeExit,
    bool? allowMicrophone,
    bool? requestCameraPermissionOnIOS,
    bool? incognito,
  }) {
    return AfihanLivenessConfig(
      callbackUrl: callbackUrl ?? this.callbackUrl,
      trustedHosts: trustedHosts ?? this.trustedHosts,
      closeOnPass: closeOnPass ?? this.closeOnPass,
      closeOnFailure: closeOnFailure ?? this.closeOnFailure,
      closeOnError: closeOnError ?? this.closeOnError,
      passRedirectTimeout: passRedirectTimeout ?? this.passRedirectTimeout,
      confirmBeforeExit: confirmBeforeExit ?? this.confirmBeforeExit,
      allowMicrophone: allowMicrophone ?? this.allowMicrophone,
      requestCameraPermissionOnIOS:
          requestCameraPermissionOnIOS ?? this.requestCameraPermissionOnIOS,
      incognito: incognito ?? this.incognito,
    );
  }
}
