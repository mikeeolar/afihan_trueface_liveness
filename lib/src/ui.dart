import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'liveness_theme.dart';

/// The default background, matching the hosted Afihan page.
const Color afihanBackgroundColor = Color(0xFFEEF1F5);

/// The default accent, matching the hosted Afihan page's buttons.
const Color afihanAccentColor = Color(0xFF075FC7);

/// The default text colour, matching the hosted Afihan page.
const Color afihanForegroundColor = Color(0xFF111318);

const Color _white = Color(0xFFFFFFFF);

/// Resolved colours for the native screens.
@immutable
class LivenessPalette {
  /// Resolves [theme] against the Afihan defaults.
  LivenessPalette(AfihanLivenessTheme theme)
      : background = theme.backgroundColor ?? afihanBackgroundColor,
        foreground = theme.foregroundColor ?? afihanForegroundColor,
        accent = theme.accentColor ?? afihanAccentColor;

  /// Background colour.
  final Color background;

  /// Text and icon colour.
  final Color foreground;

  /// Indicator and primary button colour.
  final Color accent;

  /// Whether the background is dark.
  bool get isDark => background.computeLuminance() < 0.4;

  /// A raised surface colour for cards and dialogs.
  Color get surface => isDark ? const Color(0xFF1E2128) : _white;
}

/// The base text style of the native screens.
TextStyle livenessTextStyle(Color color) => TextStyle(
      color: color,
      fontSize: 15,
      height: 1.4,
      decoration: TextDecoration.none,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );

/// Whether to follow iOS conventions.
bool get livenessUsesCupertino =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Fades its child in and out, and ignores touches while hidden.
class LivenessOverlay extends StatelessWidget {
  /// Creates the overlay.
  const LivenessOverlay({
    required this.visible,
    required this.background,
    required this.child,
    super.key,
  });

  /// Whether the overlay is shown.
  final bool visible;

  /// The overlay's opaque background.
  final Color background;

  /// The overlay content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: ExcludeSemantics(
          excluding: !visible,
          // Hidden overlays stop their animations to save battery.
          child: TickerMode(
            enabled: visible,
            child: ColoredBox(color: background, child: child),
          ),
        ),
      ),
    );
  }
}

/// The screen shown while the camera is prepared and the page loads.
class LivenessLoadingScreen extends StatelessWidget {
  /// Creates the screen.
  const LivenessLoadingScreen({required this.theme, super.key});

  /// The theme to use.
  final AfihanLivenessTheme theme;

  @override
  Widget build(BuildContext context) {
    final custom = theme.loadingBuilder;
    if (custom != null) return custom(context);
    final palette = LivenessPalette(theme);
    return Center(
      child: Semantics(
        liveRegion: true,
        label: theme.strings.loading,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LivenessSpinner(color: palette.accent),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  theme.strings.loading,
                  textAlign: TextAlign.center,
                  style: livenessTextStyle(
                    palette.foreground.withValues(alpha: 0.72),
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full screen message with a primary and a secondary action.
class LivenessMessageScreen extends StatelessWidget {
  /// Creates the screen.
  const LivenessMessageScreen({
    required this.theme,
    required this.glyph,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    super.key,
  });

  /// The theme to use.
  final AfihanLivenessTheme theme;

  /// The illustration.
  final LivenessGlyph glyph;

  /// The headline.
  final String title;

  /// The explanation.
  final String message;

  /// Label of the main action.
  final String primaryLabel;

  /// Runs the main action.
  final VoidCallback onPrimary;

  /// Label of the other action.
  final String secondaryLabel;

  /// Runs the other action.
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final palette = LivenessPalette(theme);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: CustomPaint(
                      painter: _GlyphPainter(glyph, palette.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: livenessTextStyle(palette.foreground).copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: livenessTextStyle(
                    palette.foreground.withValues(alpha: 0.7),
                  ).copyWith(height: 1.45),
                ),
                const SizedBox(height: 32),
                LivenessButton(
                  label: primaryLabel,
                  onPressed: onPrimary,
                  background: palette.accent,
                  foreground: _white,
                ),
                const SizedBox(height: 8),
                LivenessButton(
                  label: secondaryLabel,
                  onPressed: onSecondary,
                  foreground: palette.foreground.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill button with press feedback, built without a design library.
class LivenessButton extends StatefulWidget {
  /// Creates the button. With no [background] it is a plain text button.
  const LivenessButton({
    required this.label,
    required this.onPressed,
    required this.foreground,
    this.background,
    this.isDestructive = false,
    super.key,
  });

  /// The text.
  final String label;

  /// Runs when tapped.
  final VoidCallback onPressed;

  /// Text colour.
  final Color foreground;

  /// Fill colour, if any.
  final Color? background;

  /// Whether the action discards something.
  final bool isDestructive;

  @override
  State<LivenessButton> createState() => _LivenessButtonState();
}

class _LivenessButtonState extends State<LivenessButton> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.background;
    final foreground =
        widget.isDestructive ? const Color(0xFFD92D20) : widget.foreground;
    return Semantics(
      button: true,
      enabled: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: widget.onPressed,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.6 : 1,
            duration: const Duration(milliseconds: 120),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
                border: _focused
                    ? Border.all(
                        color: (background ?? foreground).withValues(
                          alpha: 0.5,
                        ),
                        width: 2,
                      )
                    : null,
              ),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: livenessTextStyle(foreground).copyWith(
                  fontSize: 16,
                  fontWeight:
                      background == null ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A smooth indeterminate progress spinner.
class LivenessSpinner extends StatefulWidget {
  /// Creates the spinner.
  const LivenessSpinner({required this.color, this.size = 36, super.key});

  /// Arc colour.
  final Color color;

  /// Diameter.
  final double size;

  @override
  State<LivenessSpinner> createState() => _LivenessSpinnerState();
}

class _LivenessSpinnerState extends State<LivenessSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Users who asked for reduced motion get a still indicator.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(painter: _ArcPainter(widget.color)),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.5;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas
      ..drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 0.6,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}

/// Illustrations for the message screens.
enum LivenessGlyph {
  /// A camera with a slash.
  cameraOff,

  /// A broken connection.
  offline,
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final LivenessGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    switch (glyph) {
      case LivenessGlyph.cameraOff:
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.06, h * 0.26, w * 0.88, h * 0.6),
          Radius.circular(w * 0.12),
        );
        canvas
          ..drawRRect(body, paint)
          ..drawLine(
            Offset(w * 0.36, h * 0.26),
            Offset(w * 0.42, h * 0.14),
            paint,
          )
          ..drawLine(
            Offset(w * 0.42, h * 0.14),
            Offset(w * 0.58, h * 0.14),
            paint,
          )
          ..drawLine(
            Offset(w * 0.58, h * 0.14),
            Offset(w * 0.64, h * 0.26),
            paint,
          )
          ..drawCircle(Offset(w * 0.5, h * 0.56), w * 0.16, paint)
          ..drawLine(
              Offset(w * 0.08, h * 0.06), Offset(w * 0.92, h * 0.94), paint);
      case LivenessGlyph.offline:
        final center = Offset(w * 0.5, h * 0.82);
        for (final radius in [0.28, 0.52, 0.76]) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: w * radius),
            -math.pi * 0.78,
            math.pi * 0.56,
            false,
            paint,
          );
        }
        canvas
          ..drawCircle(center, w * 0.04, paint..style = PaintingStyle.fill)
          ..drawLine(
            Offset(w * 0.08, h * 0.06),
            Offset(w * 0.92, h * 0.94),
            paint..style = PaintingStyle.stroke,
          );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// Shows a confirmation dialog before leaving a check in progress.
///
/// Built on [showGeneralDialog] so it needs no design library.
Future<bool> showLivenessExitDialog(
  BuildContext context,
  AfihanLivenessTheme theme,
) async {
  final palette = LivenessPalette(theme);
  final strings = theme.strings;
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.exitStay,
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: strings.exitTitle,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          strings.exitTitle,
                          textAlign: TextAlign.center,
                          style: livenessTextStyle(palette.foreground).copyWith(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.exitMessage,
                          textAlign: TextAlign.center,
                          style: livenessTextStyle(
                            palette.foreground.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        LivenessButton(
                          label: strings.exitStay,
                          background: palette.accent,
                          foreground: _white,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        const SizedBox(height: 4),
                        LivenessButton(
                          label: strings.exitConfirm,
                          isDestructive: true,
                          foreground: palette.foreground,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}
