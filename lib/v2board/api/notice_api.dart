import 'package:fl_clash/v2board/api/api_paths.dart';
import 'package:fl_clash/v2board/api/v2board_api.dart';
import 'package:fl_clash/v2board/models/notice.dart';

class NoticeApi {
  Future<List<Notice>> fetchList() async {
    final data = await v2boardApi.get(ApiPaths.noticeFetch);
    final list = data['data'] as List? ?? [];
    return list.map((e) => Notice.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final noticeApi = NoticeApi();
