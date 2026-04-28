import 'package:fl_clash/v2board/api/api_paths.dart';
import 'package:fl_clash/v2board/api/v2board_api.dart';
import 'package:fl_clash/v2board/models/site_config.dart';
import 'package:fl_clash/v2board/models/user_info.dart';

class UserApi {
  Future<UserInfo> getUserInfo() async {
    final data = await v2boardApi.get(ApiPaths.userInfo);
    return UserInfo.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<List<int>> getStat() async {
    final data = await v2boardApi.get(ApiPaths.userStat);
    final list = data['data'] as List?;
    if (list == null || list.length < 3) return [0, 0, 0];
    return list.map((e) => e as int).toList();
  }

  Future<SubscribeInfo> getSubscribe() async {
    final data = await v2boardApi.get(ApiPaths.userSubscribe);
    return SubscribeInfo.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<UserCommConfig> getCommConfig() async {
    final data = await v2boardApi.get(ApiPaths.userCommConfig);
    return UserCommConfig.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> update({int? autoRenewal}) async {
    final body = <String, dynamic>{};
    if (autoRenewal != null) body['auto_renewal'] = autoRenewal;
    await v2boardApi.post(ApiPaths.userUpdate, data: body);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await v2boardApi.post(
      ApiPaths.userChangePassword,
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }

  Future<Map<String, dynamic>> resetSecurity() async {
    final data = await v2boardApi.get(ApiPaths.userResetSecurity);
    return data['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<dynamic>> getActiveSession() async {
    final data = await v2boardApi.get(ApiPaths.userActiveSession);
    return data['data'] as List? ?? [];
  }

  Future<void> removeActiveSession(String sessionId) async {
    await v2boardApi.post(
      ApiPaths.userRemoveActiveSession,
      data: {'session_id': sessionId},
    );
  }
}

final userApi = UserApi();
