import 'package:flutter/widgets.dart';

/// Text shown by the native screens around the hosted check.
///
/// Override any field to translate or rebrand the screens.
@immutable
class AfihanLivenessStrings {
  /// Creates the strings. Every field has an English default.
  const AfihanLivenessStrings({
    this.loading = 'Preparing your face check…',
    this.cameraDeniedTitle = 'Camera access needed',
    this.cameraDeniedMessage =
        'Allow camera access to complete your face check. '
            'Your camera is only used during the check.',
    this.openSettings = 'Open Settings',
    this.tryAgain = 'Try again',
    this.cancel = 'Cancel',
    this.loadFailedTitle = 'Something went wrong',
    this.loadFailedMessage = 'We could not start the face check. '
        'Check your internet connection and try again.',
    this.exitTitle = 'Leave face check?',
    this.exitMessage = 'Your progress will be lost.',
    this.exitConfirm = 'Leave',
    this.exitStay = 'Stay',
  });

  /// Shown while the check is loading.
  final String loading;

  /// Title of the screen shown when camera access is refused.
  final String cameraDeniedTitle;

  /// Body of the screen shown when camera access is refused.
  final String cameraDeniedMessage;

  /// Button that opens the app settings.
  final String openSettings;

  /// Button that retries.
  final String tryAgain;

  /// Button that leaves the check.
  final String cancel;

  /// Title of the screen shown when the check cannot load.
  final String loadFailedTitle;

  /// Body of the screen shown when the check cannot load.
  final String loadFailedMessage;

  /// Title of the dialog shown before leaving a check in progress.
  final String exitTitle;

  /// Body of the dialog shown before leaving a check in progress.
  final String exitMessage;

  /// Dialog button that leaves the check.
  final String exitConfirm;

  /// Dialog button that stays in the check.
  final String exitStay;
}

/// Colours of the native screens around the hosted check.
///
/// Fields left `null` fall back to the ambient theme.
@immutable
class AfihanLivenessTheme {
  /// Creates a theme.
  const AfihanLivenessTheme({
    this.backgroundColor,
    this.foregroundColor,
    this.accentColor,
    this.strings = const AfihanLivenessStrings(),
    this.loadingBuilder,
  });

  /// Background behind the check, also used while the page loads.
  ///
  /// Matching it to the hosted page's background avoids any flash.
  final Color? backgroundColor;

  /// Colour of text and icons on the native screens.
  final Color? foregroundColor;

  /// Colour of the progress indicator and primary buttons.
  final Color? accentColor;

  /// Text of the native screens.
  final AfihanLivenessStrings strings;

  /// Replaces the default loading indicator.
  final WidgetBuilder? loadingBuilder;
}
