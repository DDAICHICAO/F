import 'package:fl_clash/v2board/api/guest_api.dart';
import 'package:fl_clash/v2board/models/site_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final guestConfigProvider = FutureProvider<GuestConfig>((ref) async {
  return guestApi.getGuestConfig();
});
