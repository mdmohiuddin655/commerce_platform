import 'dart:async';

import 'package:flutter/widgets.dart';

/// Composition root for the agent app.
///
/// Everything environment-specific (Firebase init, dependency wiring, error
/// reporting, feature flags) is installed here — never inside feature code —
/// so that a feature can be tested without booting the platform.
///
/// FND-001 provides the seam only. Firebase/auth/cache/queue wiring is
/// FND-004 and must not be added by a role feature task.
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  // FND-004: install error reporting, then platform services, then run.
  runApp(builder());
}
