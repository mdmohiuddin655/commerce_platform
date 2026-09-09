import 'package:cp_contracts/cp_contracts.dart';
import 'package:flutter/material.dart';

/// Root widget of the admin app.
///
/// Deliberately shows only a foundation placeholder. Role features live under
/// `lib/features/<feature>/{domain,application,data,presentation}` and are
/// owned by the ROLE-* tasks, gated on FND-002/003/004.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  static const String role = 'admin';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin',
      debugShowCheckedModeBanner: false,
      // FND-004 replaces this with cp_design_system themes.
      theme: ThemeData(useMaterial3: true),
      home: const _FoundationPlaceholder(role: role),
    );
  }
}

class _FoundationPlaceholder extends StatelessWidget {
  const _FoundationPlaceholder({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(role, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('contract v${ContractVersion.current}'),
            const SizedBox(height: 8),
            const Text('Foundation shell — no features implemented (FND-001).'),
          ],
        ),
      ),
    );
  }
}
