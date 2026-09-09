/// Platform-neutral notification boundary and the dated capability table that
/// says what each platform can actually do.
///
/// This package intentionally depends on **no** notification vendor SDK. The
/// choice between the Firebase Messaging stack and the Awesome Notifications
/// stack is unresolved and is an owner decision — see
/// `docs/decisions/ADR-0005-notification-stack-decision-required.md`. Adapters
/// arrive in FND-004, after that decision and after device validation.
library;

export 'package:cp_notifications/src/notification_capability.dart';
export 'package:cp_notifications/src/notification_dedupe.dart';
export 'package:cp_notifications/src/notification_service.dart';
