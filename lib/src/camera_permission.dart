import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Asks the operating system for camera access before the check starts.
///
/// The default, [AfihanCameraPermission.platform], uses `permission_handler`.
/// Provide your own implementation if your app already manages permissions.
abstract class AfihanCameraPermission {
  /// Allows subclasses to have const constructors.
  const AfihanCameraPermission();

  /// The default implementation, backed by `permission_handler`.
  ///
  /// It asks natively on Android. On iOS it asks only when
  /// [requestOnIOS] is true, because the web view shows the system camera
  /// prompt itself.
  const factory AfihanCameraPermission.platform({
    bool requestOnIOS,
    bool includeMicrophone,
  }) = _PlatformCameraPermission;

  /// Requests access and returns whether the camera may be used.
  Future<bool> request();

  /// Opens the app's system settings so the user can allow the camera.
  ///
  /// Returns whether the settings screen could be opened.
  Future<bool> openSettings();
}

class _PlatformCameraPermission extends AfihanCameraPermission {
  const _PlatformCameraPermission({
    this.requestOnIOS = false,
    this.includeMicrophone = false,
  });

  final bool requestOnIOS;
  final bool includeMicrophone;

  @override
  Future<bool> request() async {
    if (kIsWeb) return true;
    final platform = defaultTargetPlatform;
    final shouldAsk = platform == TargetPlatform.android ||
        (platform == TargetPlatform.iOS && requestOnIOS);
    if (!shouldAsk) return true;

    final permissions = [
      Permission.camera,
      if (includeMicrophone) Permission.microphone,
    ];
    final statuses = await permissions.request();
    return statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}
