import 'package:meta/meta.dart';

/// A liveness session created by your backend.
///
/// Your backend obtains a session by calling the Afihan initiate endpoint
/// (for example `POST /api/customers/liveness/v2/initiate`), which answers:
///
/// ```json
/// {
///   "message": "Liveness check initiated",
///   "data": {
///     "widget_url": "https://liveness.afihan.com/?widget_id=abc&mode=live&v=2",
///     "widget_id": "abc",
///     "mode": "live"
///   }
/// }
/// ```
///
/// Pass that JSON to [AfihanLivenessSession.fromJson] and hand the session to
/// `AfihanTrueFaceLiveness.start`.
@immutable
class AfihanLivenessSession {
  /// Creates a session from its parts.
  ///
  /// Throws an [ArgumentError] when [widgetUrl] is not an absolute HTTPS URL
  /// (plain HTTP is accepted only for `localhost` style development hosts),
  /// or when it contains user credentials.
  AfihanLivenessSession({
    required Uri widgetUrl,
    String? widgetId,
    String? mode,
    this.message,
  })  : widgetUrl = validateWidgetUrl(widgetUrl),
        widgetId = _nonEmpty(widgetId) ??
            _nonEmpty(widgetUrl.queryParameters['widget_id']),
        mode = _nonEmpty(mode) ?? _nonEmpty(widgetUrl.queryParameters['mode']);

  /// Parses the response of the Afihan initiate endpoint.
  ///
  /// Accepts either the full envelope (`{"message": ..., "data": {...}}`) or
  /// just the inner `data` object. Throws a [FormatException] when the JSON
  /// does not contain a usable `widget_url`.
  factory AfihanLivenessSession.fromJson(Map<String, Object?> json) {
    final data = json['data'];
    final body = data is Map ? data.cast<String, Object?>() : json;
    final rawUrl = body['widget_url'];
    if (rawUrl is! String || rawUrl.trim().isEmpty) {
      throw const FormatException(
        'The initiate response does not contain a "widget_url".',
      );
    }
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      throw FormatException('"widget_url" is not a valid URL.', rawUrl);
    }
    final message = json['message'];
    try {
      return AfihanLivenessSession(
        widgetUrl: uri,
        widgetId:
            body['widget_id'] is String ? body['widget_id']! as String : null,
        mode: body['mode'] is String ? body['mode']! as String : null,
        message: message is String ? message : null,
      );
    } on ArgumentError catch (error) {
      throw FormatException(
          '"widget_url" is not allowed: ${error.message}', rawUrl);
    }
  }

  /// Creates a session from a widget URL string.
  ///
  /// Throws an [ArgumentError] when [widgetUrl] cannot be parsed or is not
  /// allowed (see the default constructor).
  factory AfihanLivenessSession.fromUrl(String widgetUrl) {
    final uri = Uri.tryParse(widgetUrl.trim());
    if (uri == null) {
      throw ArgumentError.value(widgetUrl, 'widgetUrl', 'Is not a valid URL.');
    }
    return AfihanLivenessSession(widgetUrl: uri);
  }

  /// The hosted liveness page to open.
  final Uri widgetUrl;

  /// The single-use widget identifier, taken from the response or the URL.
  final String? widgetId;

  /// The verification mode, for example `live`.
  final String? mode;

  /// The human readable message returned by the initiate endpoint, if any.
  final String? message;

  /// The origin of [widgetUrl], for example `https://liveness.afihan.com`.
  String get origin => widgetUrl.origin;

  /// Checks that [uri] is safe to load as a liveness widget and returns it.
  ///
  /// Throws an [ArgumentError] otherwise.
  static Uri validateWidgetUrl(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final isSecure = scheme == 'https';
    final isLocalHttp = scheme == 'http' && isDevelopmentHost(uri.host);
    if (!uri.isAbsolute ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !(isSecure || isLocalHttp)) {
      throw ArgumentError.value(
        uri.toString(),
        'widgetUrl',
        'Must be an absolute HTTPS URL without credentials.',
      );
    }
    return uri;
  }

  /// Whether [host] is a local development host on which plain HTTP is
  /// tolerated.
  static bool isDevelopmentHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'localhost' ||
        lower == '127.0.0.1' ||
        lower == '10.0.2.2' ||
        lower == '::1' ||
        lower == '[::1]' ||
        lower.endsWith('.localhost');
  }

  @override
  bool operator ==(Object other) =>
      other is AfihanLivenessSession &&
      other.widgetUrl == widgetUrl &&
      other.widgetId == widgetId &&
      other.mode == mode &&
      other.message == message;

  @override
  int get hashCode => Object.hash(widgetUrl, widgetId, mode, message);

  @override
  String toString() =>
      'AfihanLivenessSession(widgetId: $widgetId, mode: $mode, origin: $origin)';
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
