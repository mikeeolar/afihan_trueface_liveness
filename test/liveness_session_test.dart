import 'package:afihan_trueface_liveness/afihan_trueface_liveness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AfihanLivenessSession.fromJson', () {
    test('parses the full initiate response', () {
      final session = AfihanLivenessSession.fromJson(const {
        'message': 'Liveness check initiated',
        'data': {
          'widget_url':
              'https://livenessstaging.afihan.com/?widget_id=8rNssS6yVkmqlTW59NptjfQSz&mode=live&v=2',
          'widget_id': '8rNssS6yVkmqlTW59NptjfQSz',
          'mode': 'live',
        },
      });

      expect(session.widgetId, '8rNssS6yVkmqlTW59NptjfQSz');
      expect(session.mode, 'live');
      expect(session.message, 'Liveness check initiated');
      expect(session.origin, 'https://livenessstaging.afihan.com');
      expect(session.widgetUrl.queryParameters['v'], '2');
    });

    test('accepts the inner data object on its own', () {
      final session = AfihanLivenessSession.fromJson(const {
        'widget_url': 'https://liveness.afihan.com/?widget_id=abc&mode=live',
      });

      expect(session.widgetId, 'abc');
      expect(session.mode, 'live');
      expect(session.message, isNull);
    });

    test('falls back to the URL query when ids are missing or blank', () {
      final session = AfihanLivenessSession.fromJson(const {
        'data': {
          'widget_url':
              'https://liveness.afihan.com/?widget_id=fromUrl&mode=kyc',
          'widget_id': '  ',
        },
      });

      expect(session.widgetId, 'fromUrl');
      expect(session.mode, 'kyc');
    });

    test('prefers explicit ids over the URL query', () {
      final session = AfihanLivenessSession.fromJson(const {
        'data': {
          'widget_url': 'https://liveness.afihan.com/?widget_id=old',
          'widget_id': ' new ',
          'mode': 'live',
        },
      });

      expect(session.widgetId, 'new');
    });

    test('throws a FormatException without a widget_url', () {
      expect(
        () =>
            AfihanLivenessSession.fromJson(const {'data': <String, Object?>{}}),
        throwsFormatException,
      );
      expect(
        () => AfihanLivenessSession.fromJson(const {'widget_url': 42}),
        throwsFormatException,
      );
    });

    test('throws a FormatException for an unsafe widget_url', () {
      expect(
        () => AfihanLivenessSession.fromJson(const {
          'widget_url': 'http://liveness.afihan.com/?widget_id=a',
        }),
        throwsFormatException,
      );
    });
  });

  group('URL validation', () {
    test('accepts HTTPS URLs', () {
      expect(
        AfihanLivenessSession.fromUrl('https://liveness.afihan.com/x').origin,
        'https://liveness.afihan.com',
      );
    });

    test('accepts plain HTTP only on development hosts', () {
      for (final url in [
        'http://localhost:3000/',
        'http://127.0.0.1:3000/',
        'http://10.0.2.2:3000/',
        'http://verify.localhost/',
      ]) {
        expect(() => AfihanLivenessSession.fromUrl(url), returnsNormally);
      }
      expect(
        () => AfihanLivenessSession.fromUrl('http://liveness.afihan.com/'),
        throwsArgumentError,
      );
    });

    test('rejects relative, credentialed and non web URLs', () {
      for (final url in [
        '/relative',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'https://user:pass@liveness.afihan.com/',
        'ftp://liveness.afihan.com/',
      ]) {
        expect(
          () => AfihanLivenessSession.fromUrl(url),
          throwsArgumentError,
          reason: url,
        );
      }
    });
  });

  test('sessions with the same values are equal', () {
    final a = AfihanLivenessSession.fromUrl(
      'https://liveness.afihan.com/?widget_id=a&mode=live',
    );
    final b = AfihanLivenessSession.fromUrl(
      'https://liveness.afihan.com/?widget_id=a&mode=live',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.toString(), contains('widgetId: a'));
  });
}
