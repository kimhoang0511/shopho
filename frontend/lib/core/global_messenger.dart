import 'package:flutter/material.dart';

/// A global ScaffoldMessengerKey so services outside the widget tree
/// (e.g. FcmService) can show SnackBars from anywhere.
final globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showGlobalError(String message, {Duration duration = const Duration(seconds: 6)}) {
  globalMessengerKey.currentState
    ?..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.orange.shade800,
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ));
}
