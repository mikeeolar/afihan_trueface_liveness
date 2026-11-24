import 'package:afihan_trueface_liveness/afihan_trueface_liveness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('named constructors set the status and helpers', () {
    expect(const AfihanLivenessResult.passed().isPassed, isTrue);
    expect(const AfihanLivenessResult.failed().isFailed, isTrue);
    expect(const AfihanLivenessResult.cancelled().isCancelled, isTrue);
    const error = AfihanLivenessResult.error(
      AfihanLivenessErrorReason.unavailable,
      message: 'timeout',
    );
    expect(error.isError, isTrue);
    expect(error.errorReason, AfihanLivenessErrorReason.unavailable);
  });

  test('has value equality', () {
    final url = Uri.parse('https://a.com/cb');
    expect(
      AfihanLivenessResult.passed(widgetId: 'w', callbackUrl: url),
      AfihanLivenessResult.passed(widgetId: 'w', callbackUrl: url),
    );
    expect(
      const AfihanLivenessResult.passed(widgetId: 'w').hashCode,
      const AfihanLivenessResult.passed(widgetId: 'w').hashCode,
    );
    expect(
      const AfihanLivenessResult.passed(widgetId: 'w'),
      isNot(const AfihanLivenessResult.failed(widgetId: 'w')),
    );
  });

  test('describes itself', () {
    expect(
      const AfihanLivenessResult.error(
        AfihanLivenessErrorReason.invalidSession,
        widgetId: 'w',
      ).toString(),
      'AfihanLivenessResult(status: error, widgetId: w, '
      'errorReason: invalidSession)',
    );
  });

  test('maps wire reasons', () {
    expect(
      AfihanLivenessErrorReason.fromWire('invalid_session'),
      AfihanLivenessErrorReason.invalidSession,
    );
    expect(
      AfihanLivenessErrorReason.fromWire('unavailable'),
      AfihanLivenessErrorReason.unavailable,
    );
    expect(
      AfihanLivenessErrorReason.fromWire(null),
      AfihanLivenessErrorReason.unknown,
    );
  });

  test('config copyWith replaces only the given fields', () {
    const config = AfihanLivenessConfig();
    final copy = config.copyWith(
      closeOnFailure: true,
      callbackUrl: Uri.parse('myapp://done'),
    );
    expect(copy.closeOnFailure, isTrue);
    expect(copy.callbackUrl, Uri.parse('myapp://done'));
    expect(copy.closeOnPass, config.closeOnPass);
    expect(copy.passRedirectTimeout, config.passRedirectTimeout);
    expect(copy.allowMicrophone, isFalse);
  });
}
