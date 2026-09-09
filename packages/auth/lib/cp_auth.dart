/// Platform-neutral auth capability description.
///
/// FND-002A delivers the strategy table and its invariants only. No provider
/// flow, no Firebase dependency and no token handling is implemented here —
/// the Windows system-browser/PKCE flow cannot be exercised without a Windows
/// runner, and the mobile plugin path needs a Firebase project. Both are
/// FND-004 work.
library;

export 'package:cp_auth/src/auth_capability.dart';
