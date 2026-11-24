import 'package:afihan_trueface_liveness/afihan_trueface_liveness.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class FakePermissionPlatform extends PermissionHandlerPlatform {
  FakePermissionPlatform(this.statuses);

  final Map<Permission, PermissionStatus> statuses;
  final requested = <List<Permission>>[];
  int settingsOpened = 0;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requested.add(permissions);
    return {for (final p in permissions) p: statuses[p]!};
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }
}

void main() {
  late FakePermissionPlatform platform;

  void install(Map<Permission, PermissionStatus> statuses) {
    platform = FakePermissionPlatform(statuses);
    PermissionHandlerPlatform.instance = platform;
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('asks for the camera natively on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    install({Permission.camera: PermissionStatus.granted});

    expect(await const AfihanCameraPermission.platform().request(), isTrue);
    expect(platform.requested.single, [Permission.camera]);
  });

  test('reports a refusal on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    install({Permission.camera: PermissionStatus.permanentlyDenied});

    expect(await const AfihanCameraPermission.platform().request(), isFalse);
  });

  test('includes the microphone only when asked', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    install({
      Permission.camera: PermissionStatus.granted,
      Permission.microphone: PermissionStatus.denied,
    });

    final permission = const AfihanCameraPermission.platform(
      includeMicrophone: true,
    );
    expect(await permission.request(), isFalse);
    expect(platform.requested.single, [
      Permission.camera,
      Permission.microphone,
    ]);
  });

  test('leaves iOS to the web view by default', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    install({Permission.camera: PermissionStatus.denied});

    expect(await const AfihanCameraPermission.platform().request(), isTrue);
    expect(platform.requested, isEmpty);
  });

  test('asks on iOS when enabled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    install({Permission.camera: PermissionStatus.limited});

    final permission = const AfihanCameraPermission.platform(
      requestOnIOS: true,
    );
    expect(await permission.request(), isTrue);
    expect(platform.requested, hasLength(1));
  });

  test('opens the app settings', () async {
    install({});
    expect(
        await const AfihanCameraPermission.platform().openSettings(), isTrue);
    expect(platform.settingsOpened, 1);
  });
}
