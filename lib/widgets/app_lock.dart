import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';

class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});
  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  final service = AppLockService.instance;
  bool _covered = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!service.enabled) return;
    setState(() => _covered = state != AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed) service.lock();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: service,
      builder: (_, __) {
        final blocked = service.enabled && (service.locked || _covered);
        return Stack(children: [
          Offstage(
              offstage: blocked,
              child: ExcludeFocus(
                  excluding: blocked,
                  child: TickerMode(enabled: !blocked, child: widget.child))),
          if (blocked)
            Positioned.fill(
                child: Material(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: SafeArea(
                        child: Center(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock, size: 48),
                                      const SizedBox(height: 16),
                                      const Text('Empréstimos bloqueado'),
                                      if (service.error != null)
                                        Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Text(service.error!,
                                                textAlign: TextAlign.center)),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                          onPressed: service.authenticating
                                              ? null
                                              : service.unlock,
                                          icon: const Icon(Icons.fingerprint),
                                          label: const Text('Desbloquear')),
                                    ])))))),
        ]);
      });
}
