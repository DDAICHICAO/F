import 'package:fl_clash/v2board/api/ticket_api.dart';
import 'package:fl_clash/v2board/models/ticket.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TicketState {
  final List<Ticket> tickets;
  final Ticket? currentTicket;
  final bool loading;

  const TicketState({
    this.tickets = const [],
    this.currentTicket,
    this.loading = false,
  });

  TicketState copyWith({
    List<Ticket>? tickets,
    Ticket? currentTicket,
    bool? loading,
  }) =>
      TicketState(
        tickets: tickets ?? this.tickets,
        currentTicket: currentTicket ?? this.currentTicket,
        loading: loading ?? this.loading,
      );
}

final ticketProvider = NotifierProvider<TicketNotifier, TicketState>(
  TicketNotifier.new,
);

class TicketNotifier extends Notifier<TicketState> {
  @override
  TicketState build() => const TicketState();

  Future<void> fetchList() async {
    state = state.copyWith(loading: true);
    try {
      final tickets = await ticketApi.fetchList();
      state = state.copyWith(tickets: tickets, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> fetchDetail(int id) async {
    state = state.copyWith(loading: true);
    try {
      final ticket = await ticketApi.fetchDetail(id);
      state = state.copyWith(currentTicket: ticket, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }
}
