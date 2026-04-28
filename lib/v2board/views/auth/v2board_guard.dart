import 'package:fl_clash/v2board/providers/auth_provider.dart';
import 'package:fl_clash/v2board/providers/remote_config_provider.dart';
import 'package:fl_clash/v2board/views/auth/config_error_view.dart';
import 'package:fl_clash/v2board/views/auth/login_view.dart';
import 'package:fl_clash/v2board/views/auth/splash_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class V2boardGuard extends ConsumerStatefulWidget {
  final Widget child;

  const V2boardGuard({super.key, required this.child});

  @override
  ConsumerState<V2boardGuard> createState() => _V2boardGuardState();
}

class _V2boardGuardState extends ConsumerState<V2boardGuard> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ref.read(remoteConfigProvider.notifier).init();
    final configState = ref.read(remoteConfigProvider);
    if (configState.status == RemoteConfigStatus.ready) {
      await ref.read(authProvider.notifier).restore();
    }
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(remoteConfigProvider);
    final authState = ref.watch(authProvider);

    if (!_initialized) {
      return const SplashView();
    }

    return switch (configState.status) {
      RemoteConfigStatus.loading => const SplashView(),
      RemoteConfigStatus.error => const ConfigErrorView(),
      RemoteConfigStatus.ready => authState.isLoggedIn
          ? widget.child
          : const LoginView(),
    };
  }
}
