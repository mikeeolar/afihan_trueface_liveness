import 'package:meta/meta.dart';

/// What to do with a navigation started by the liveness page.
enum LivenessNavigation {
  /// Let the web view load it.
  allow,

  /// Cancel it and treat it as the hosted page returning to the app.
  callback,

  /// Cancel it and stay on the current page.
  block,
}

/// Decides which navigations stay inside the check, and which ones mean the
/// hosted page is sending the user back to the app.
@internal
@immutable
class LivenessNavigationPolicy {
  /// Creates a policy for a widget hosted at [widgetUrl].
  LivenessNavigationPolicy({
    required this.widgetUrl,
    this.callbackUrl,
    Set<String> trustedHosts = const <String>{},
  }) : trustedHosts = {
          widgetUrl.host.toLowerCase(),
          for (final host in trustedHosts) host.trim().toLowerCase(),
        };

  /// The liveness page.
  final Uri widgetUrl;

  /// The expected redirect, if the app configured one.
  final Uri? callbackUrl;

  /// Hosts the page may load without ending the check.
  final Set<String> trustedHosts;

  static const _inlineSchemes = {'about', 'data', 'blob', 'javascript'};

  /// Classifies a navigation to [target].
  LivenessNavigation classify(Uri target, {required bool isMainFrame}) {
    final scheme = target.scheme.toLowerCase();

    if (callbackUrl != null && matchesCallback(target)) {
      return isMainFrame
          ? LivenessNavigation.callback
          : LivenessNavigation.block;
    }
    if (!isMainFrame) {
      return _inlineSchemes.contains(scheme) || _isWeb(scheme)
          ? LivenessNavigation.allow
          : LivenessNavigation.block;
    }
    if (_inlineSchemes.contains(scheme)) {
      return scheme == 'javascript'
          ? LivenessNavigation.block
          : LivenessNavigation.allow;
    }
    if (_isWeb(scheme) && trustedHosts.contains(target.host.toLowerCase())) {
      return LivenessNavigation.allow;
    }
    // The hosted page only leaves its own host to return to the caller, so
    // any other main frame navigation (another website, or a custom app
    // scheme such as myapp://done) is the end of the check.
    return LivenessNavigation.callback;
  }

  /// Whether [target] is the configured [callbackUrl] or a URL below it.
  bool matchesCallback(Uri target) {
    final callback = callbackUrl;
    if (callback == null) return false;
    if (target.scheme.toLowerCase() != callback.scheme.toLowerCase()) {
      return false;
    }
    if (target.host.toLowerCase() != callback.host.toLowerCase()) return false;
    if (callback.hasPort && target.port != callback.port) return false;
    final base = _trimSlash(callback.path);
    final path = _trimSlash(target.path);
    return base.isEmpty || path == base || path.startsWith('$base/');
  }

  static bool _isWeb(String scheme) => scheme == 'http' || scheme == 'https';

  static String _trimSlash(String path) =>
      path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}

/// Reads a pass or fail decision from the query of a redirect URL.
///
/// Recognises `status`, `success`, `result`, `passed`, `verified` and
/// `liveness` parameters. Returns `null` when the URL does not say.
@internal
bool? outcomeFromCallback(Uri url) {
  const keys = [
    'status',
    'success',
    'result',
    'passed',
    'verified',
    'liveness'
  ];
  const passWords = {
    'true', '1', 'yes', 'pass', 'passed', 'success', 'successful', //
    'succeeded', 'verified', 'approved', 'ok', 'completed', 'complete',
  };
  const failWords = {
    'false', '0', 'no', 'fail', 'failed', 'failure', 'error', 'rejected', //
    'declined', 'unverified', 'denied',
  };
  final params = <String, String>{
    for (final entry in url.queryParameters.entries)
      entry.key.toLowerCase(): entry.value.trim().toLowerCase(),
  };
  for (final key in keys) {
    final value = params[key];
    if (value == null) continue;
    if (passWords.contains(value)) return true;
    if (failWords.contains(value)) return false;
  }
  return null;
}
