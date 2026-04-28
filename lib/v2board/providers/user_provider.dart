import 'package:fl_clash/v2board/api/user_api.dart';
import 'package:fl_clash/v2board/models/user_info.dart';
import 'package:fl_clash/v2board/models/site_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserState {
  final SubscribeInfo? subscribeInfo;
  final UserInfo? userInfo;
  final UserCommConfig? commConfig;
  final List<int> stat;

  const UserState({
    this.subscribeInfo,
    this.userInfo,
    this.commConfig,
    this.stat = const [0, 0, 0],
  });

  UserState copyWith({
    SubscribeInfo? subscribeInfo,
    UserInfo? userInfo,
    UserCommConfig? commConfig,
    List<int>? stat,
  }) =>
      UserState(
        subscribeInfo: subscribeInfo ?? this.subscribeInfo,
        userInfo: userInfo ?? this.userInfo,
        commConfig: commConfig ?? this.commConfig,
        stat: stat ?? this.stat,
      );
}

final userProvider = NotifierProvider<UserNotifier, UserState>(
  UserNotifier.new,
);

class UserNotifier extends Notifier<UserState> {
  @override
  UserState build() => const UserState();

  Future<void> fetchAll() async {
    final results = await Future.wait([
      userApi.getSubscribe(),
      userApi.getUserInfo(),
      userApi.getCommConfig(),
      userApi.getStat(),
    ]);
    state = state.copyWith(
      subscribeInfo: results[0] as SubscribeInfo,
      userInfo: results[1] as UserInfo,
      commConfig: results[2] as UserCommConfig,
      stat: results[3] as List<int>,
    );
  }

  Future<void> syncSubscribeInfo() async {
    try {
      final sub = await userApi.getSubscribe();
      state = state.copyWith(subscribeInfo: sub);
    } catch (_) {}
  }

  Future<void> fetchCommConfig() async {
    try {
      final config = await userApi.getCommConfig();
      state = state.copyWith(commConfig: config);
    } catch (_) {}
  }
}
