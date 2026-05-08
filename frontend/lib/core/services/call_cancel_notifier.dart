import 'package:flutter/foundation.dart';

/// Notified with a callId whenever a remote call-cancel signal arrives.
/// The active call screen listens here to dismiss itself immediately.
final callCancelNotifier = ValueNotifier<String?>(null);
