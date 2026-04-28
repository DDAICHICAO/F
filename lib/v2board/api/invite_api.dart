import 'package:fl_clash/v2board/api/api_paths.dart';
import 'package:fl_clash/v2board/api/v2board_api.dart';
import 'package:fl_clash/v2board/models/invite.dart';

class InviteApi {
  Future<InviteData> fetchData() async {
    final data = await v2boardApi.get(ApiPaths.inviteFetch);
    return InviteData.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> generateCode() async {
    await v2boardApi.get(ApiPaths.inviteSave);
  }
}

final inviteApi = InviteApi();
