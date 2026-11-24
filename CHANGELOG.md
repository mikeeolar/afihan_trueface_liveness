## 0.1.0

- First release.
- `AfihanTrueFaceLiveness.start()` runs the hosted Afihan liveness check full
  screen and returns a typed `AfihanLivenessResult`.
- `AfihanLivenessSession.fromJson()` parses the initiate endpoint response.
- Listens to the hosted page's `liveness_complete`, `liveness_error` and
  `liveness_close` messages without an iframe wrapper.
- Intercepts the hosted page's redirect so the user returns to the app.
- Native camera permission on Android, inline camera on iOS, camera granted
  only to the liveness host.
- Native loading, camera-denied and offline screens, exit confirmation, and
  web view chrome removed (zoom, bounce, menus, selection, tap highlights).
- Works with Material, Cupertino or custom-styled apps.
