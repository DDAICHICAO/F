import 'package:fl_clash/v2board/api/api_paths.dart';
import 'package:fl_clash/v2board/api/v2board_api.dart';
import 'package:fl_clash/v2board/models/site_config.dart';

class GuestApi {
  Future<GuestConfig> getGuestConfig() async {
    final data = await v2boardApi.get(ApiPaths.guestConfig);
    final resp = data['data'] as Map<String, Object?>;
    return GuestConfig.fromJson(resp);
  }
}

final guestApi = GuestApi();
