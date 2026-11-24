import 'package:afihan_trueface_liveness/afihan_trueface_liveness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AfihanLivenessEvent? parse(Object? message, {String? widgetId = 'w1'}) =>
      AfihanLivenessEvent.fromBridgeMessage(
        message,
        expectedWidgetId: widgetId,
      );

  test('parses a pass from a JSON string', () {
    expect(
      parse('{"type":"liveness_complete","success":true,"widget_id":"w1"}'),
      const AfihanLivenessCompleted(passed: true, widgetId: 'w1'),
    );
  });

  test('parses a fail from a map', () {
    expect(
      parse({'type': 'liveness_complete', 'success': false, 'widget_id': 'w1'}),
      const AfihanLivenessCompleted(passed: false, widgetId: 'w1'),
    );
  });

  test('parses errors and maps their reasons', () {
    expect(
      parse({
        'type': 'liveness_error',
        'reason': 'invalid_session',
        'widget_id': 'w1',
      }),
      const AfihanLivenessFailedToRun(
        reason: AfihanLivenessErrorReason.invalidSession,
        rawReason: 'invalid_session',
        widgetId: 'w1',
      ),
    );
    final unknown = parse({'type': 'liveness_error', 'reason': 'boom'});
    expect(
      (unknown! as AfihanLivenessFailedToRun).reason,
      AfihanLivenessErrorReason.unknown,
    );
  });

  test('parses close, which carries no widget id', () {
    expect(parse({'type': 'liveness_close'}), const AfihanLivenessClosed());
  });

  test('ignores messages for another widget', () {
    expect(
      parse({'type': 'liveness_complete', 'success': true, 'widget_id': 'w2'}),
      isNull,
    );
  });

  test('accepts any widget when none is expected', () {
    expect(
      parse({
        'type': 'liveness_complete',
        'success': true,
        'widget_id': 'w2',
      }, widgetId: null),
      isA<AfihanLivenessCompleted>(),
    );
  });

  test('ignores malformed and unknown messages', () {
    for (final message in <Object?>[
      null,
      42,
      'not json',
      '[1,2]',
      {'type': 'something_else'},
      {'type': 'liveness_complete'},
      {'type': 'liveness_complete', 'success': 'yes'},
      {'type': 'liveness_complete', 'success': true, 'widget_id': 7},
    ]) {
      expect(parse(message), isNull, reason: '$message');
    }
  });

  test('events have value equality and readable strings', () {
    final url = Uri.parse('https://example.com');
    expect(AfihanLivenessRedirected(url), AfihanLivenessRedirected(url));
    expect(AfihanLivenessPageLoaded(url), AfihanLivenessPageLoaded(url));
    expect(
      const AfihanLivenessClosed().hashCode,
      const AfihanLivenessClosed().hashCode,
    );
    expect(
      const AfihanLivenessCompleted(passed: true).toString(),
      contains('passed: true'),
    );
  });
}
