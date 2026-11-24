import 'package:afihan_trueface_liveness/src/navigation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final widget = Uri.parse('https://liveness.afihan.com/?widget_id=w1');

  group('LivenessNavigationPolicy', () {
    final policy = LivenessNavigationPolicy(
      widgetUrl: widget,
      trustedHosts: {' CDN.Afihan.com '},
    );

    LivenessNavigation main(String url) =>
        policy.classify(Uri.parse(url), isMainFrame: true);

    test('keeps the widget host and trusted hosts inside the check', () {
      expect(
          main('https://liveness.afihan.com/step2'), LivenessNavigation.allow);
      expect(main('https://LIVENESS.afihan.com/'), LivenessNavigation.allow);
      expect(main('https://cdn.afihan.com/x'), LivenessNavigation.allow);
      expect(main('about:blank'), LivenessNavigation.allow);
    });

    test('treats leaving the host as the return to the app', () {
      expect(
        main('https://lendo.example/liveness/callback?status=success'),
        LivenessNavigation.callback,
      );
      expect(main('myapp://liveness/done'), LivenessNavigation.callback);
      expect(main('intent://scan#Intent;end'), LivenessNavigation.callback);
    });

    test('never runs javascript URLs in the main frame', () {
      expect(main('javascript:alert(1)'), LivenessNavigation.block);
    });

    test('lets sub frames load web content but not app schemes', () {
      expect(
        policy.classify(Uri.parse('https://other.com'), isMainFrame: false),
        LivenessNavigation.allow,
      );
      expect(
        policy.classify(Uri.parse('myapp://x'), isMainFrame: false),
        LivenessNavigation.block,
      );
    });
  });

  group('configured callback URL', () {
    final policy = LivenessNavigationPolicy(
      widgetUrl: widget,
      callbackUrl: Uri.parse('https://liveness.afihan.com/done/'),
    );

    test('matches the callback even on the widget host', () {
      expect(
        policy.classify(
          Uri.parse('https://liveness.afihan.com/done?status=passed'),
          isMainFrame: true,
        ),
        LivenessNavigation.callback,
      );
      expect(
        policy.classify(
          Uri.parse('https://liveness.afihan.com/done/extra'),
          isMainFrame: true,
        ),
        LivenessNavigation.callback,
      );
    });

    test('does not match look-alike paths', () {
      expect(
        policy.matchesCallback(Uri.parse('https://liveness.afihan.com/donex')),
        isFalse,
      );
      expect(
        policy.classify(
          Uri.parse('https://liveness.afihan.com/donex'),
          isMainFrame: true,
        ),
        LivenessNavigation.allow,
      );
    });

    test('checks scheme, host and port', () {
      final withPort = LivenessNavigationPolicy(
        widgetUrl: widget,
        callbackUrl: Uri.parse('http://localhost:8080/cb'),
      );
      expect(withPort.matchesCallback(Uri.parse('http://localhost:8080/cb')),
          isTrue);
      expect(withPort.matchesCallback(Uri.parse('http://localhost:9090/cb')),
          isFalse);
      expect(withPort.matchesCallback(Uri.parse('https://localhost:8080/cb')),
          isFalse);
    });

    test('blocks the callback inside a sub frame', () {
      expect(
        policy.classify(
          Uri.parse('https://liveness.afihan.com/done'),
          isMainFrame: false,
        ),
        LivenessNavigation.block,
      );
    });

    test('matches every URL on a host-only callback', () {
      final hostOnly = LivenessNavigationPolicy(
        widgetUrl: widget,
        callbackUrl: Uri.parse('myapp://liveness'),
      );
      expect(
          hostOnly.matchesCallback(Uri.parse('myapp://liveness/any')), isTrue);
    });
  });

  group('outcomeFromCallback', () {
    bool? outcome(String url) => outcomeFromCallback(Uri.parse(url));

    test('reads common pass values', () {
      expect(outcome('https://a.com/?status=success'), isTrue);
      expect(outcome('https://a.com/?success=true'), isTrue);
      expect(outcome('https://a.com/?Result=PASSED'), isTrue);
      expect(outcome('https://a.com/?verified=1'), isTrue);
    });

    test('reads common fail values', () {
      expect(outcome('https://a.com/?status=failed'), isFalse);
      expect(outcome('https://a.com/?success=false'), isFalse);
      expect(outcome('https://a.com/?result=rejected'), isFalse);
    });

    test('returns null when the URL does not say', () {
      expect(outcome('https://a.com/done'), isNull);
      expect(outcome('https://a.com/?status=pending'), isNull);
    });
  });
}
