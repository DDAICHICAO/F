import 'package:fl_clash/v2board/api/auth_api.dart';
import 'package:fl_clash/v2board/api/subscribe_bridge.dart';
import 'package:fl_clash/v2board/config/v2board_local_storage.dart';
import 'package:fl_clash/v2board/models/auth.dart';
import 'package:fl_clash/v2board/api/v2board_api.dart';
import 'package:fl_clash/v2board/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthStateData {
  final bool isLoggedIn;
  final String? authData;
  final String? token;
  final bool isAdmin;

  const AuthStateData({
    this.isLoggedIn = false,
    this.authData,
    this.token,
    this.isAdmin = false,
  });
}

final authProvider = NotifierProvider<AuthNotifier, AuthStateData>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthStateData> {
  @override
  AuthStateData build() => const AuthStateData();

  Future<void> restore() async {
    final storage = await V2boardLocalStorage.getInstance();
    final authData = storage.authData;
    final token = storage.token;

    if (authData == null || token == null) {
      state = const AuthStateData();
      return;
    }

    v2boardApi.setAuthData(authData);

    try {
      final result = await authApi.checkLogin();
      if (!result.isLogin) {
        await _clearAuth(storage);
        return;
      }

      state = AuthStateData(
        isLoggedIn: true,
        authData: authData,
        token: token,
        isAdmin: result.isAdmin,
      );

      // 启动时加载用户数据和订阅信息
      await _loadUserData();
    } catch (e) {
      await _clearAuth(storage);
    }
  }

  Future<void> onLoginSuccess(AuthResponse authResponse) async {
    final storage = await V2boardLocalStorage.getInstance();
    await Future.wait([
      storage.setAuthData(authResponse.authData),
      storage.setToken(authResponse.token),
      storage.setIsAdmin(authResponse.isAdmin),
    ]);

    v2boardApi.setAuthData(authResponse.authData);

    state = AuthStateData(
      isLoggedIn: true,
      authData: authResponse.authData,
      token: authResponse.token,
      isAdmin: authResponse.isAdmin,
    );

    // 登录成功后加载用户数据 + 订阅桥接
    await _loadUserData();
    try {
      await ref.read(subscribeBridgeProvider).attachProfile();
    } catch (e) {
      // 订阅桥接失败不阻塞登录
    }
  }

  Future<void> logout() async {
    final storage = await V2boardLocalStorage.getInstance();
    try {
      await _removeActiveSession();
    } catch (_) {}
    await _clearAuth(storage);
  }

  Future<void> _loadUserData() async {
    try {
      await ref.read(userProvider.notifier).fetchAll();
    } catch (_) {}
  }

  Future<void> _removeActiveSession() async {
    try {
      // TODO: 调 getActiveSession 获取 session_id 再 removeActiveSession
      ref.read(userProvider).subscribeInfo;
    } catch (_) {}
  }

  Future<void> _clearAuth(V2boardLocalStorage storage) async {
    v2boardApi.setAuthData(null);
    await storage.clearAuth();
    state = const AuthStateData();
  }
}
