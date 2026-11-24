import 'package:afihan_trueface_liveness/afihan_trueface_liveness.dart';
import 'package:afihan_trueface_liveness/src/liveness_flow.dart';
import 'package:afihan_trueface_liveness/src/navigation_policy.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final session = AfihanLivenessSession.fromUrl(
    'https://liveness.afihan.com/?widget_id=w1&mode=live&v=2',
  );

  late List<AfihanLivenessResult> results;
  late List<AfihanLivenessEvent> events;

  LivenessFlow createFlow([
    AfihanLivenessConfig config = const AfihanLivenessConfig(),
  ]) {
    return LivenessFlow(
      session: session,
      config: config,
      onFinish: results.add,
      onEvent: events.add,
    );
  }

  LivenessFlow readyFlow([
    AfihanLivenessConfig config = const AfihanLivenessConfig(),
  ]) {
    return createFlow(config)
      ..cameraPermissionResolved(granted: true)
      ..pageLoadStarted()
      ..pageLoaded(session.widgetUrl);
  }

  Map<String, Object?> complete({required bool success}) => {
        'type': 'liveness_complete',
        'success': success,
        'widget_id': 'w1',
      };

  setUp(() {
    results = [];
    events = [];
  });

  group('phases', () {
    test('moves from camera to loading to ready', () {
      final flow = createFlow();
      expect(flow.phase, LivenessPhase.preparingCamera);

      flow.cameraPermissionResolved(granted: true);
      expect(flow.phase, LivenessPhase.loading);

      flow.pageLoaded(session.widgetUrl);
      expect(flow.phase, LivenessPhase.ready);
      expect(events, [AfihanLivenessPageLoaded(session.widgetUrl)]);
    });

    test('shows the camera screen when access is refused', () {
      final flow = createFlow()..cameraPermissionResolved(granted: false);
      expect(flow.phase, LivenessPhase.cameraDenied);
      expect(flow.shouldConfirmExit, isFalse);

      flow.close();
      expect(results.single.errorReason,
          AfihanLivenessErrorReason.cameraPermissionDenied);
    });

    test('recovers from a load failure on retry', () {
      final flow = createFlow()
        ..cameraPermissionResolved(granted: true)
        ..pageFailed('net::ERR_INTERNET_DISCONNECTED');
      expect(flow.phase, LivenessPhase.loadFailed);
      expect(flow.loadError, 'net::ERR_INTERNET_DISCONNECTED');

      // The error page finishing must not hide the error screen.
      flow.pageLoaded(session.widgetUrl);
      expect(flow.phase, LivenessPhase.loadFailed);

      flow
        ..retry()
        ..pageLoaded(session.widgetUrl);
      expect(flow.phase, LivenessPhase.ready);
      expect(flow.loadError, isNull);
    });

    test('reports a load failure when the user gives up', () {
      createFlow()
        ..cameraPermissionResolved(granted: true)
        ..pageFailed('HTTP 503')
        ..close();
      expect(results.single.errorReason, AfihanLivenessErrorReason.loadFailed);
      expect(results.single.message, 'HTTP 503');
    });
  });

  group('pass', () {
    test('waits for the redirect, then returns the callback URL', () {
      fakeAsync((async) {
        final flow = readyFlow()..handleBridgeMessage(complete(success: true));
        async.elapse(const Duration(milliseconds: 2500));
        expect(results, isEmpty);

        final callback = Uri.parse('https://lendo.example/cb?ref=1');
        final decision = flow.handleNavigation(callback, isMainFrame: true);

        expect(decision, LivenessNavigation.callback);
        expect(
          results.single,
          AfihanLivenessResult.passed(widgetId: 'w1', callbackUrl: callback),
        );
        expect(events.last, AfihanLivenessRedirected(callback));

        // The pending timer must not deliver a second result.
        async.elapse(const Duration(seconds: 10));
        expect(results, hasLength(1));
      });
    });

    test('closes after the timeout when no redirect comes', () {
      fakeAsync((async) {
        readyFlow().handleBridgeMessage(complete(success: true));
        async.elapse(const Duration(milliseconds: 3999));
        expect(results, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(
            results.single, const AfihanLivenessResult.passed(widgetId: 'w1'));
      });
    });

    test('stays open when closeOnPass is off', () {
      fakeAsync((async) {
        final flow = readyFlow(const AfihanLivenessConfig(closeOnPass: false))
          ..handleBridgeMessage(complete(success: true));
        async.elapse(const Duration(seconds: 30));
        expect(results, isEmpty);
        expect(flow.shouldConfirmExit, isFalse);

        flow.close();
        expect(results.single.isPassed, isTrue);
      });
    });
  });

  group('fail and retry', () {
    test('lets the user retry, then reports the last outcome on close', () {
      final flow = readyFlow()..handleBridgeMessage(complete(success: false));
      expect(results, isEmpty);
      expect(flow.lastOutcome?.isFailed, isTrue);

      flow.handleBridgeMessage({'type': 'liveness_close'});
      expect(results.single, const AfihanLivenessResult.failed(widgetId: 'w1'));
    });

    test('a later pass replaces an earlier fail', () {
      fakeAsync((async) {
        readyFlow()
          ..handleBridgeMessage(complete(success: false))
          ..handleBridgeMessage(complete(success: true));
        async.elapse(const Duration(seconds: 5));
        expect(results.single.isPassed, isTrue);
      });
    });

    test('closes at once when closeOnFailure is on', () {
      readyFlow(const AfihanLivenessConfig(closeOnFailure: true))
          .handleBridgeMessage(complete(success: false));
      expect(results.single.isFailed, isTrue);
    });

    test('a later fail cancels a pending pass timer', () {
      fakeAsync((async) {
        final flow = readyFlow()
          ..handleBridgeMessage(complete(success: true))
          ..handleBridgeMessage(complete(success: false));
        async.elapse(const Duration(seconds: 10));
        expect(results, isEmpty);
        flow.close();
        expect(results.single.isFailed, isTrue);
      });
    });
  });

  group('errors', () {
    test('keeps the page open by default and reports on close', () {
      final flow = readyFlow()
        ..handleBridgeMessage({
          'type': 'liveness_error',
          'reason': 'invalid_session',
          'widget_id': 'w1',
        });
      expect(results, isEmpty);

      flow.handleBridgeMessage({'type': 'liveness_close'});
      expect(
        results.single,
        const AfihanLivenessResult.error(
          AfihanLivenessErrorReason.invalidSession,
          widgetId: 'w1',
          message: 'invalid_session',
        ),
      );
    });

    test('closes at once when closeOnError is on', () {
      readyFlow(const AfihanLivenessConfig(closeOnError: true))
          .handleBridgeMessage({
        'type': 'liveness_error',
        'reason': 'unavailable',
        'widget_id': 'w1',
      });
      expect(results.single.errorReason, AfihanLivenessErrorReason.unavailable);
    });

    test('an error then a redirect without status keeps the error', () {
      final flow = readyFlow()
        ..handleBridgeMessage({
          'type': 'liveness_error',
          'reason': 'unavailable',
          'widget_id': 'w1',
        })
        ..handleNavigation(
          Uri.parse('https://lendo.example/cb?status=failed'),
          isMainFrame: true,
        );
      expect(flow.result?.isError, isTrue);
    });
  });

  group('redirects', () {
    test('a redirect with an explicit status wins', () {
      readyFlow().handleNavigation(
        Uri.parse('https://lendo.example/cb?status=failed'),
        isMainFrame: true,
      );
      expect(results.single.isFailed, isTrue);
      expect(results.single.callbackUrl?.host, 'lendo.example');
    });

    test('a redirect without a status after a fail is a fail', () {
      readyFlow()
        ..handleBridgeMessage(complete(success: false))
        ..handleNavigation(
          Uri.parse('myapp://liveness'),
          isMainFrame: true,
        );
      expect(results.single.isFailed, isTrue);
    });

    test('a bare redirect counts as a pass', () {
      readyFlow().handleNavigation(
        Uri.parse('https://lendo.example/cb'),
        isMainFrame: true,
      );
      expect(results.single.isPassed, isTrue);
    });

    test('navigations inside the widget host are allowed', () {
      final flow = readyFlow();
      expect(
        flow.handleNavigation(
          Uri.parse('https://liveness.afihan.com/next'),
          isMainFrame: true,
        ),
        LivenessNavigation.allow,
      );
      expect(results, isEmpty);
    });
  });

  group('closing', () {
    test('confirms exit only while a check is in progress', () {
      final flow = createFlow();
      expect(flow.shouldConfirmExit, isFalse);
      flow
        ..cameraPermissionResolved(granted: true)
        ..pageLoaded(session.widgetUrl);
      expect(flow.shouldConfirmExit, isTrue);

      final noConfirm = readyFlow(
        const AfihanLivenessConfig(confirmBeforeExit: false),
      );
      expect(noConfirm.shouldConfirmExit, isFalse);
    });

    test('cancels when nothing happened yet', () {
      readyFlow().close();
      expect(
        results.single,
        const AfihanLivenessResult.cancelled(widgetId: 'w1'),
      );
    });

    test('delivers exactly one result and ignores later input', () {
      final flow = readyFlow()
        ..close()
        ..close()
        ..handleBridgeMessage(complete(success: true))
        ..pageFailed('late');
      expect(results, hasLength(1));
      expect(flow.phase, LivenessPhase.finished);
      expect(
        flow.handleNavigation(
          Uri.parse('https://liveness.afihan.com/'),
          isMainFrame: true,
        ),
        LivenessNavigation.block,
      );
    });

    test('ignores messages for another widget', () {
      final flow = readyFlow();
      expect(
        flow.handleBridgeMessage({
          'type': 'liveness_complete',
          'success': true,
          'widget_id': 'someone-else',
        }),
        isNull,
      );
      expect(flow.lastOutcome, isNull);
    });

    test('does not deliver after dispose', () {
      fakeAsync((async) {
        readyFlow()
          ..handleBridgeMessage(complete(success: true))
          ..dispose();
        async.elapse(const Duration(seconds: 10));
        expect(results, isEmpty);
      });
    });
  });
}
