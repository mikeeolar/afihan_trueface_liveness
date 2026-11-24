import 'dart:convert';

import 'package:afihan_trueface_liveness/afihan_trueface_liveness.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const ExampleApp());

/// A small app that starts a liveness check and shows its result.
class ExampleApp extends StatelessWidget {
  /// Creates the app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Afihan TrueFace',
      theme: ThemeData(
        colorSchemeSeed: afihanAccentColor,
        scaffoldBackgroundColor: afihanBackgroundColor,
      ),
      home: const HomePage(),
    );
  }
}

/// Lets you paste a widget URL or an initiate response and run the check.
class HomePage extends StatefulWidget {
  /// Creates the page.
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _input = TextEditingController();
  AfihanLivenessResult? _result;
  String? _error;
  bool _running = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// In a real app, call your backend here. Your backend calls
  /// `POST /api/customers/liveness/v2/initiate` with its credentials and
  /// returns the JSON response to the app. Never ship API keys in the app.
  AfihanLivenessSession _sessionFromInput() {
    final text = _input.text.trim();
    if (text.startsWith('{')) {
      final json = jsonDecode(text) as Map<String, Object?>;
      return AfihanLivenessSession.fromJson(json);
    }
    return AfihanLivenessSession.fromUrl(text);
  }

  Future<void> _start() async {
    final AfihanLivenessSession session;
    try {
      session = _sessionFromInput();
    } on Object catch (error) {
      setState(
        () => _error = 'Paste a widget URL or initiate response. $error',
      );
      return;
    }

    setState(() {
      _error = null;
      _running = true;
    });
    final result = await AfihanTrueFaceLiveness.start(
      context,
      session: session,
      onEvent: (event) => debugPrint('Liveness event: $event'),
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });

    // The result is a client-side signal. Confirm it on your backend with
    // result.widgetId before trusting it.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Afihan TrueFace liveness')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _input,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Widget URL or initiate response',
                hintText: 'https://liveness.afihan.com/?widget_id=...',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _running ? null : _start,
              icon: const Icon(Icons.face_retouching_natural),
              label: const Text('Start face check'),
            ),
            if (_result case final result?) ...[
              const SizedBox(height: 24),
              _ResultCard(result: result),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final AfihanLivenessResult result;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title) = switch (result.status) {
      AfihanLivenessStatus.passed => (
        Icons.verified_rounded,
        Colors.green,
        'Passed',
      ),
      AfihanLivenessStatus.failed => (
        Icons.highlight_off_rounded,
        Colors.red,
        'Failed',
      ),
      AfihanLivenessStatus.cancelled => (
        Icons.close_rounded,
        Colors.grey,
        'Cancelled',
      ),
      AfihanLivenessStatus.error => (
        Icons.error_outline_rounded,
        Colors.orange,
        'Could not run: ${result.errorReason?.name}',
      ),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 36),
        title: Text(title),
        subtitle: Text(
          [
            if (result.widgetId != null) 'Widget: ${result.widgetId}',
            if (result.callbackUrl != null) 'Redirect: ${result.callbackUrl}',
          ].join('\n'),
        ),
      ),
    );
  }
}
