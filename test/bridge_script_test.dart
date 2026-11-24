import 'package:afihan_trueface_liveness/src/bridge_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = buildLivenessBridgeScript(
    origin: 'https://liveness.afihan.com',
  );

  test('forwards parent messages to the Flutter handler', () {
    expect(script, contains('callHandler(handler, payload)'));
    expect(script, contains('"$livenessBridgeHandler"'));
    expect(script, contains('window.parent = bridge'));
  });

  test('only replaces the parent of a top level page', () {
    expect(script, contains('if (window.parent === window)'));
  });

  test('provides the widget origin as the referrer', () {
    expect(script, contains('"https://liveness.afihan.com/"'));
    expect(script, contains("Object.defineProperty(document, 'referrer'"));
  });

  test('runs once per page', () {
    expect(script, contains('if (window.__afihanTrueFaceBridge) return;'));
  });

  test('encodes the origin safely', () {
    final hostile =
        buildLivenessBridgeScript(origin: 'https://a.com"</script>');
    expect(hostile, contains(r'"https://a.com\"</script>/"'));
  });

  test('removes web-only touch effects', () {
    expect(script, contains('-webkit-tap-highlight-color:transparent'));
    expect(script, contains('-webkit-touch-callout:none'));
  });
}
