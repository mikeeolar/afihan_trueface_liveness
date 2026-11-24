import 'package:afihan_trueface_liveness/afihan_trueface_liveness.dart';
import 'package:afihan_trueface_liveness/src/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCameraPermission extends AfihanCameraPermission {
  FakeCameraPermission({required this.grant, this.throws = false});

  bool grant;
  final bool throws;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<bool> request() async {
    requests++;
    if (throws) throw StateError('no plugin');
    return grant;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

final session = AfihanLivenessSession.fromUrl(
  'https://liveness.afihan.com/?widget_id=w1&mode=live',
);

/// A minimal app without Material or Cupertino, to prove the package needs
/// neither.
class TestApp extends StatelessWidget {
  const TestApp({required this.home, super.key});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF075FC7),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, __) => builder(context),
      ),
      // Reduced motion keeps the loading spinner still, so the tests can
      // wait for every animation to settle.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: home,
    );
  }
}

/// A launcher button that starts a check and stores the result.
class Launcher extends StatefulWidget {
  const Launcher({required this.permission, this.config, super.key});

  final AfihanCameraPermission permission;
  final AfihanLivenessConfig? config;

  @override
  State<Launcher> createState() => LauncherState();
}

class LauncherState extends State<Launcher> {
  AfihanLivenessResult? result;
  final events = <AfihanLivenessEvent>[];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () async {
          final value = await AfihanTrueFaceLiveness.start(
            context,
            session: session,
            config: widget.config ?? const AfihanLivenessConfig(),
            cameraPermission: widget.permission,
            onEvent: events.add,
          );
          setState(() => result = value);
        },
        child: const Text('start', textDirection: TextDirection.ltr),
      ),
    );
  }
}

void main() {
  const strings = AfihanLivenessStrings();

  testWidgets('shows a native loading screen while the check starts',
      (tester) async {
    final permission = FakeCameraPermission(grant: true);
    await tester.pumpWidget(
      TestApp(home: Launcher(permission: permission)),
    );
    await tester.tap(find.text('start').hitTestable());
    await tester.pumpAndSettle();

    expect(permission.requests, 1);
    expect(find.text(strings.loading).hitTestable(), findsOneWidget);
    expect(find.byType(LivenessSpinner), findsOneWidget);
    expect(find.text(strings.cameraDeniedTitle).hitTestable(), findsNothing);
  });

  testWidgets('back while loading cancels without asking', (tester) async {
    final permission = FakeCameraPermission(grant: true);
    await tester.pumpWidget(TestApp(home: Launcher(permission: permission)));
    await tester.tap(find.text('start').hitTestable());
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();

    final launcher = tester.state<LauncherState>(find.byType(Launcher));
    expect(
      launcher.result,
      const AfihanLivenessResult.cancelled(widgetId: 'w1'),
    );
    expect(find.text('start').hitTestable(), findsOneWidget);
  });

  testWidgets('explains a refused camera and lets the user open settings',
      (tester) async {
    final permission = FakeCameraPermission(grant: false);
    await tester.pumpWidget(TestApp(home: Launcher(permission: permission)));
    await tester.tap(find.text('start').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text(strings.cameraDeniedTitle).hitTestable(), findsOneWidget);
    expect(
        find.text(strings.cameraDeniedMessage).hitTestable(), findsOneWidget);

    await tester.tap(find.text(strings.openSettings).hitTestable());
    await tester.pumpAndSettle();
    expect(permission.settingsOpened, 1);

    // Back from settings with access granted: the check continues.
    permission.grant = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(permission.requests, 2);
    expect(find.text(strings.loading).hitTestable(), findsOneWidget);
  });

  testWidgets('cancel on the camera screen returns a permission error',
      (tester) async {
    await tester.pumpWidget(
      TestApp(home: Launcher(permission: FakeCameraPermission(grant: false))),
    );
    await tester.tap(find.text('start').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.cancel).hitTestable());
    await tester.pumpAndSettle();

    final launcher = tester.state<LauncherState>(find.byType(Launcher));
    expect(launcher.result?.status, AfihanLivenessStatus.error);
    expect(
      launcher.result?.errorReason,
      AfihanLivenessErrorReason.cameraPermissionDenied,
    );
  });

  testWidgets('a failing permission plugin does not trap the user',
      (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: Launcher(
          permission: FakeCameraPermission(grant: true, throws: true),
        ),
      ),
    );
    await tester.tap(find.text('start').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text(strings.cameraDeniedTitle).hitTestable(), findsOneWidget);
  });

  testWidgets('uses custom strings and colours', (tester) async {
    const custom = AfihanLivenessTheme(
      backgroundColor: Color(0xFF101114),
      accentColor: Color(0xFF22C55E),
      strings: AfihanLivenessStrings(
        cameraDeniedTitle: 'Kamera ni a nilo',
        openSettings: 'Ṣii Eto',
      ),
    );
    await tester.pumpWidget(
      TestApp(
        home: AfihanLivenessPage(
          session: session,
          theme: custom,
          cameraPermission: FakeCameraPermission(grant: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kamera ni a nilo').hitTestable(), findsOneWidget);
    expect(find.text('Ṣii Eto').hitTestable(), findsOneWidget);
    final box = tester.widget<ColoredBox>(find.byType(ColoredBox).first);
    expect(box.color, const Color(0xFF101114));
  });

  testWidgets('a custom loading builder replaces the spinner', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: AfihanLivenessPage(
          session: session,
          theme: AfihanLivenessTheme(
            loadingBuilder: (context) =>
                const Text('brand loader', textDirection: TextDirection.ltr),
          ),
          cameraPermission: FakeCameraPermission(grant: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('brand loader').hitTestable(), findsOneWidget);
    expect(find.byType(LivenessSpinner), findsNothing);
  });

  testWidgets('the view reports its result through onResult', (tester) async {
    AfihanLivenessResult? result;
    await tester.pumpWidget(
      TestApp(
        home: AfihanLivenessView(
          session: session,
          cameraPermission: FakeCameraPermission(grant: false),
          onResult: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.cancel).hitTestable());
    await tester.pump();

    expect(
        result?.errorReason, AfihanLivenessErrorReason.cameraPermissionDenied);
  });

  group('exit dialog', () {
    Future<Future<bool>> open(WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      final answer = showLivenessExitDialog(
        context,
        const AfihanLivenessTheme(),
      );
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('returns true when the user leaves', (tester) async {
      final answer = await open(tester);
      expect(find.text(strings.exitTitle).hitTestable(), findsOneWidget);
      await tester.tap(find.text(strings.exitConfirm).hitTestable());
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
    });

    testWidgets('returns false when the user stays', (tester) async {
      final answer = await open(tester);
      await tester.tap(find.text(strings.exitStay).hitTestable());
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    testWidgets('buttons are announced as buttons', (tester) async {
      final handle = tester.ensureSemantics();
      final answer = await open(tester);
      expect(
        tester.getSemantics(find.byType(LivenessButton).first),
        matchesSemantics(
          label: strings.exitStay,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text(strings.exitStay).hitTestable());
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
      handle.dispose();
    });
  });
}
