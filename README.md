# afihan_trueface_liveness

[![pub package](https://img.shields.io/pub/v/afihan_trueface_liveness.svg)](https://pub.dev/packages/afihan_trueface_liveness)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Run the Afihan TrueFace liveness check in your Flutter app on **Android and iOS**,
with a native feel and a typed result.

- **One call, one result.** `AfihanTrueFaceLiveness.start()` opens the check full
  screen and returns an `AfihanLivenessResult` when it is done.
- **Returns to your app by itself.** The package listens to the hosted page's
  result messages and intercepts its final redirect, so users never land on a
  web page they have to close.
- **Camera that works.** Built on
  [`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview) with
  inline camera playback on iOS, runtime camera permission on Android, and no
  second "allow camera" prompt from the web page.
- **Does not look like a web view.** No zoom, bounce, scroll bars, text
  selection, link previews, long-press menus or tap highlights. Native loading,
  camera-denied and offline screens match the Afihan colours.
- **Safe by default.** Only the camera is granted, only to the liveness host;
  result messages for another widget are ignored; mixed content and file access
  are off.
- **No design-library lock-in.** The UI uses only `package:flutter/widgets.dart`,
  so it works in Material, Cupertino or custom-styled apps.

## How it works

```text
Your app ──► your backend ──► POST /api/customers/liveness/v2/initiate
   │                                │
   │◄────────── widget_url ─────────┘
   │
   └─► AfihanTrueFaceLiveness.start(session)
          ├─ asks for the camera (Android)
          ├─ loads widget_url full screen
          ├─ listens for liveness_complete / liveness_error / liveness_close
          ├─ intercepts the redirect to your callback URL
          └─► returns AfihanLivenessResult to your app
```

## Requirements

| | Minimum |
| --- | --- |
| Flutter | 3.27 (tested on 3.27.4 and 3.50.1) |
| Dart | 3.6 |
| Android | API 24 (Android 7.0) |
| iOS | 12.0 |

## Install

```yaml
dependencies:
  afihan_trueface_liveness: ^0.1.0
```

### Android

Add the camera permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    ...
</manifest>
```

`minSdk` must be 24 or higher, which is already the default for new Flutter apps.

### iOS

Add a camera description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We use your camera to confirm it is really you during the face check.</string>
```

That is all. On iOS the web view shows the system camera prompt itself, so no
`Podfile` changes are needed. If you would rather ask natively before the check
opens, set `requestCameraPermissionOnIOS: true` and enable `PERMISSION_CAMERA=1`
for [`permission_handler`](https://pub.dev/packages/permission_handler#setup).

## Use

### 1. Create a session on your backend

Your backend calls the initiate endpoint with its own credentials and returns
the response to the app:

```json
{
  "message": "Liveness check initiated",
  "data": {
    "widget_url": "https://liveness.afihan.com/?widget_id=8rNssS6y...&mode=live&v=2",
    "widget_id": "8rNssS6y...",
    "mode": "live"
  }
}
```

Never put API keys in your app.

### 2. Run the check

```dart
import 'package:afihan_trueface_liveness/afihan_trueface_liveness.dart';

Future<void> verifyFace(BuildContext context) async {
  final json = await myBackend.initiateLiveness(); // your API call
  final session = AfihanLivenessSession.fromJson(json);

  final result = await AfihanTrueFaceLiveness.start(context, session: session);

  switch (result.status) {
    case AfihanLivenessStatus.passed:
      // Confirm with your backend using result.widgetId, then continue.
      break;
    case AfihanLivenessStatus.failed:
      // The face could not be verified.
      break;
    case AfihanLivenessStatus.cancelled:
      // The user left the check.
      break;
    case AfihanLivenessStatus.error:
      // result.errorReason: invalidSession, unavailable,
      // cameraPermissionDenied, loadFailed or unknown.
      break;
  }
}
```

Already have just the URL? Use `AfihanLivenessSession.fromUrl(widgetUrl)`.

> The result is a client-side signal. Always confirm the outcome on your
> backend with `result.widgetId` before granting access.

## Results

| Status | When |
| --- | --- |
| `passed` | The hosted page reported a pass, or redirected to the callback URL. |
| `failed` | The capture could not be verified and the user closed the check. |
| `cancelled` | The user left before any outcome. |
| `error` | See `errorReason` below. |

| `errorReason` | Meaning |
| --- | --- |
| `invalidSession` | The widget link expired or was already used. Create a new session. |
| `unavailable` | The service could not confirm a result, usually a network problem. |
| `cameraPermissionDenied` | The user refused camera access. |
| `loadFailed` | The check could not load. `result.message` has the detail. |
| `unknown` | The page reported an error this version does not know. |

`result.callbackUrl` holds the redirect the page tried to open, if any.

## Configure

```dart
await AfihanTrueFaceLiveness.start(
  context,
  session: session,
  config: AfihanLivenessConfig(
    // Optional: match your redirect exactly (it may also be an app link).
    callbackUrl: Uri.parse('https://myapp.com/liveness/done'),
    closeOnPass: true,       // return as soon as the check passes (default)
    closeOnFailure: false,   // let users retry on the hosted page (default)
    closeOnError: false,     // show the hosted error message first (default)
    confirmBeforeExit: true, // ask before the back gesture leaves a check
    incognito: false,        // keep no cookies or storage when true
  ),
  theme: const AfihanLivenessTheme(
    backgroundColor: Color(0xFFEEF1F5),
    accentColor: Color(0xFF075FC7),
    strings: AfihanLivenessStrings(loading: 'Getting your camera ready…'),
  ),
  onEvent: (event) => analytics.log('liveness', event.toString()),
);
```

Every native string can be translated through `AfihanLivenessStrings`, and
`AfihanLivenessTheme.loadingBuilder` replaces the loading screen with your own.

### Embed in your own layout

```dart
AfihanLivenessView(
  session: session,
  onResult: (result) => Navigator.of(context).pop(result),
)
```

### Your own permission flow

Pass an `AfihanCameraPermission` implementation as `cameraPermission` if your app
already manages permissions.

## Events

`onEvent` receives, in order:

| Event | Meaning |
| --- | --- |
| `AfihanLivenessPageLoaded` | The check is visible. |
| `AfihanLivenessCompleted` | Pass or fail. After a fail the user may retry, so more may follow. |
| `AfihanLivenessFailedToRun` | The session is invalid or the service is unavailable. |
| `AfihanLivenessRedirected` | The page tried to leave for the callback URL; the package stopped it. |
| `AfihanLivenessClosed` | The user tapped the page's own back or close button. |

## Troubleshooting

**The camera screen says access is needed.** On Android, check the manifest
permission. Users who chose "Don't ask again" can use the Open Settings button;
the check continues by itself when they come back.

**The camera is black on iOS.** Check `NSCameraUsageDescription`. The package
already enables inline media playback, which iOS requires for web cameras.

**The check never closes after a pass.** It closes on the page's redirect or
after `passRedirectTimeout` (4 seconds). If your redirect stays on the liveness
host, set `callbackUrl` so the package can recognise it.

## Example

See [`example/`](example) for a complete app with the Android and iOS setup.

## License

MIT. See [LICENSE](LICENSE).
