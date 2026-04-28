import 'package:fl_clash/v2board/api/notice_api.dart';
import 'package:fl_clash/v2board/config/v2board_local_storage.dart';
import 'package:fl_clash/v2board/models/notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoticeState {
  final List<Notice> notices;
  final bool loading;
  final int? unreadCount;

  const NoticeState({
    this.notices = const [],
    this.loading = false,
    this.unreadCount,
  });

  NoticeState copyWith({
    List<Notice>? notices,
    bool? loading,
    int? unreadCount,
  }) =>
      NoticeState(
        notices: notices ?? this.notices,
        loading: loading ?? this.loading,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

final noticeProvider = NotifierProvider<NoticeNotifier, NoticeState>(
  NoticeNotifier.new,
);

class NoticeNotifier extends Notifier<NoticeState> {
  @override
  NoticeState build() => const NoticeState();

  Future<void> fetchList() async {
    state = state.copyWith(loading: true);
    try {
      final notices = await noticeApi.fetchList();
      final storage = await V2boardLocalStorage.getInstance();
      final lastTime = storage.lastNoticeTime;
      int unread = 0;
      if (lastTime != null && notices.isNotEmpty) {
        final lastDt = DateTime.tryParse(lastTime);
        if (lastDt != null) {
          unread = notices.where((n) => n.createdAt != null && n.createdAt!.isAfter(lastDt)).length;
        }
      } else if (notices.isNotEmpty) {
        unread = notices.length;
      }
      state = state.copyWith(notices: notices, loading: false, unreadCount: unread);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> markAllRead() async {
    final storage = await V2boardLocalStorage.getInstance();
    await storage.setLastNoticeTime(DateTime.now().toIso8601String());
    state = state.copyWith(unreadCount: 0);
  }
}
