import 'dart:convert';

import 'package:meta/meta.dart';

/// Name of the JavaScript handler the hosted page reports to.
@internal
const livenessBridgeHandler = 'afihanTrueFaceLiveness';

/// Builds the script injected at document start into the liveness page.
///
/// The hosted page reports its result with `window.parent.postMessage`, and
/// only when it runs inside a frame. Loading it directly (which gives the
/// camera the best support on Android and iOS) means it has no parent, so
/// this script provides one: `window.parent` is a replaceable property, and
/// the script sets it to an object whose `postMessage` forwards to Flutter.
/// It also gives the page a referrer, which the page uses as the target
/// origin of its messages.
///
/// The script also removes web-only touches (tap highlights, text selection
/// and callouts outside form fields) so the page feels native.
@internal
String buildLivenessBridgeScript({required String origin}) {
  final encodedOrigin = jsonEncode('$origin/');
  final handler = jsonEncode(livenessBridgeHandler);
  return '''
(function () {
  if (window.__afihanTrueFaceBridge) return;
  window.__afihanTrueFaceBridge = true;
  var handler = $handler;
  function send(message) {
    try {
      var payload = typeof message === 'string' ? message : JSON.stringify(message);
      window.flutter_inappwebview.callHandler(handler, payload);
    } catch (e) {}
  }
  var bridge = { postMessage: function (message) { send(message); } };
  if (window.parent === window) {
    try { window.parent = bridge; } catch (e) {}
    try {
      Object.defineProperty(document, 'referrer', {
        configurable: true,
        get: function () { return $encodedOrigin; }
      });
    } catch (e) {}
  }
  window.addEventListener('message', function (event) {
    if (event.source === window && event.data && typeof event.data === 'object' &&
        typeof event.data.type === 'string' && event.data.type.indexOf('liveness_') === 0) {
      send(event.data);
    }
  });
  var css = '*{-webkit-tap-highlight-color:transparent;-webkit-touch-callout:none;}' +
    'body{-webkit-user-select:none;user-select:none;overscroll-behavior:none;}' +
    'input,textarea,[contenteditable]{-webkit-user-select:text;user-select:text;}';
  function addStyle() {
    var style = document.createElement('style');
    style.setAttribute('data-afihan-trueface', '');
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);
  }
  if (document.head) { addStyle(); }
  else { document.addEventListener('DOMContentLoaded', addStyle, { once: true }); }
})();
''';
}
