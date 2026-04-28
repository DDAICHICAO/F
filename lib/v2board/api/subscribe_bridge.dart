import 'package:fl_clash/v2board/api/user_api.dart';
import 'package:fl_clash/v2board/config/v2board_local_storage.dart';
import 'package:fl_clash/v2board/providers/user_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscribeBridge {
  final Ref _ref;

  SubscribeBridge(this._ref);

  /// 登录/注册成功后：获取订阅并创建 Profile
  Future<void> attachProfile() async {
    try {
      final sub = await userApi.getSubscribe();

      _ref.read(userProvider.notifier).syncSubscribeInfo();

      final subscribeUrl = sub.subscribeUrl;
      if (subscribeUrl.isEmpty) {
        debugPrint('SubscribeBridge: subscribe_url is empty');
        return;
      }

      final url = Uri.parse(subscribeUrl).replace(
        queryParameters: {'flag': 'meta'},
      ).toString();

      debugPrint('SubscribeBridge: profile url = $url');

      final storage = await V2boardLocalStorage.getInstance();

      // 通过 FlClash 已有的 Request 实例创建 Profile
      // Profile 创建逻辑需要在 AppController 中集成
      // 这里只存储 URL，由 AppController 完成实际的 Profile 创建
      await storage.setProfileId(0); // placeholder, 将由 controller 更新

      // 标记需要创建 profile
      _pendingSubscribeUrl = url;
    } catch (e) {
      debugPrint('SubscribeBridge: attachProfile failed $e');
      rethrow;
    }
  }

  /// 定时同步订阅信息
  Future<void> syncInfo() async {
    await _ref.read(userProvider.notifier).syncSubscribeInfo();
  }

  static String? _pendingSubscribeUrl;
  static String? get pendingSubscribeUrl => _pendingSubscribeUrl;
  static void clearPendingUrl() => _pendingSubscribeUrl = null;
}

final subscribeBridgeProvider = Provider<SubscribeBridge>(
  (ref) => SubscribeBridge(ref),
);
