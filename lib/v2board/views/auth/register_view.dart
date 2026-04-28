import 'package:dio/dio.dart';
import 'package:fl_clash/v2board/api/auth_api.dart';
import 'package:fl_clash/v2board/models/api_error.dart';
import 'package:fl_clash/v2board/providers/auth_provider.dart';
import 'package:fl_clash/v2board/providers/site_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _codeSent = false; // ignore: unused_field
  int _countdown = 0;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailCodeController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '请输入邮箱');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await authApi.sendEmailVerify(email: email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _countdown = 60;
      });
      _startCountdown();
    } on DioException catch (e) {
      final error = e.error;
      setState(() => _error = error is ApiError ? error.message : '发送失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
        _startCountdown();
      }
    });
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入邮箱和密码');
      return;
    }

    if (password.length < 8) {
      setState(() => _error = '密码至少8位');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authResponse = await authApi.register(
        email: email,
        password: password,
        emailCode: _emailCodeController.text.trim().isNotEmpty
            ? _emailCodeController.text.trim()
            : null,
        inviteCode: _inviteCodeController.text.trim().isNotEmpty
            ? _inviteCodeController.text.trim()
            : null,
      );
      if (!mounted) return;
      await ref.read(authProvider.notifier).onLoginSuccess(authResponse);
    } on DioException catch (e) {
      final error = e.error;
      setState(() => _error = error is ApiError ? error.message : '注册失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guestAsync = ref.watch(guestConfigProvider);
    final siteConfig = guestAsync.value;

    final needEmailVerify = (siteConfig?.isEmailVerify ?? 0) == 1;
    final needInvite = (siteConfig?.isInviteForce ?? 0) == 1;
    final whitelist = siteConfig?.emailWhitelistSuffix ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: '邮箱',
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                    helperText: whitelist.isNotEmpty ? '仅支持: $whitelist' : null,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                ),
                if (needEmailVerify) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailCodeController,
                          decoration: const InputDecoration(
                            labelText: '邮箱验证码',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !_loading,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: FilledButton.tonal(
                          onPressed: _countdown > 0 || _loading
                              ? null
                              : _sendCode,
                          child: Text(
                            _countdown > 0 ? '${_countdown}s' : '发送',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    helperText: '至少8位',
                  ),
                  obscureText: _obscurePassword,
                  enabled: !_loading,
                ),
                if (needInvite) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _inviteCodeController,
                    decoration: const InputDecoration(
                      labelText: '邀请码',
                      prefixIcon: Icon(Icons.card_giftcard),
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_loading,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
