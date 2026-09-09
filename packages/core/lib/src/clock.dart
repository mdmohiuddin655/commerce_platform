import 'package:meta/meta.dart';

/// Time source. Client wall-clock time is never commercial truth: events
/// retain **server** time, so anything that must be authoritative reads the
/// server-issued timestamp instead of this clock.
abstract interface class Clock {
  DateTime nowUtc();
}

/// Device clock. Suitable for UI and local scheduling only.
@immutable
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
