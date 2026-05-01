import 'package:flutter/foundation.dart';

/// Holds the current access token. GoRouter watches this via refreshListenable
/// to synchronously redirect on auth state changes — no async, no white screen.
final authTokenNotifier = ValueNotifier<String?>(null);
