import 'package:fl_clash/v2board/api/invite_api.dart';
import 'package:fl_clash/v2board/models/invite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InviteState {
  final InviteData? data;
  final bool loading;

  const InviteState({this.data, this.loading = false});

  InviteState copyWith({InviteData? data, bool? loading}) =>
      InviteState(data: data ?? this.data, loading: loading ?? this.loading);
}

final inviteProvider = NotifierProvider<InviteNotifier, InviteState>(
  InviteNotifier.new,
);

class InviteNotifier extends Notifier<InviteState> {
  @override
  InviteState build() => const InviteState();

  Future<void> fetchData() async {
    state = state.copyWith(loading: true);
    try {
      final data = await inviteApi.fetchData();
      state = state.copyWith(data: data, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> generateCode() async {
    await inviteApi.generateCode();
    await fetchData();
  }
}
