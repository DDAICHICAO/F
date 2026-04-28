import 'dart:convert';

class RemoteConfig {
  final List<String> hosts;
  final String? inviteLink;
  final String? updateUrl;
  final String? customer;
  final String? crisp;
  final int notice;
  final int exchange;
  final int trafficDetails;
  final int onlineTicket;
  final String? authentication;
  final String? hostSource;
  final List<String> carousel;
  final List<String> campusHosts;

  const RemoteConfig({
    required this.hosts,
    this.inviteLink,
    this.updateUrl,
    this.customer,
    this.crisp,
    this.notice = 1,
    this.exchange = 1,
    this.trafficDetails = 1,
    this.onlineTicket = 1,
    this.authentication,
    this.hostSource,
    this.carousel = const [],
    this.campusHosts = const [],
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> json) => RemoteConfig(
        hosts: (json['hosts'] as List?)?.map((e) => e.toString()).toList() ?? [],
        inviteLink: json['InviteLink'] as String?,
        updateUrl: json['UpdateUrl'] as String?,
        customer: json['Customer'] as String?,
        crisp: json['crisp'] as String?,
        notice: (json['notice'] as num?)?.toInt() ?? 1,
        exchange: (json['exchange'] as num?)?.toInt() ?? 1,
        trafficDetails: (json['TrafficDetails'] as num?)?.toInt() ?? 1,
        onlineTicket: (json['OnlineTicket'] as num?)?.toInt() ?? 1,
        authentication: json['Authentication'] as String?,
        hostSource: json['host_source'] as String?,
        carousel: (json['Carousel'] as List?)?.map((e) => e.toString()).toList() ?? [],
        campusHosts: (json['campusHosts'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'hosts': hosts,
        if (inviteLink != null) 'InviteLink': inviteLink,
        if (updateUrl != null) 'UpdateUrl': updateUrl,
        if (customer != null) 'Customer': customer,
        if (crisp != null) 'crisp': crisp,
        'notice': notice,
        'exchange': exchange,
        'TrafficDetails': trafficDetails,
        'OnlineTicket': onlineTicket,
        if (authentication != null) 'Authentication': authentication,
        if (hostSource != null) 'host_source': hostSource,
        'Carousel': carousel,
        'campusHosts': campusHosts,
      };

  static RemoteConfig? fromRawJson(String jsonStr) {
    try {
      return RemoteConfig.fromJson(
        json.decode(jsonStr) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static RemoteConfig? fromBase64(String base64Str) {
    try {
      final jsonStr = utf8.decode(base64Decode(base64Str.trim()));
      return fromRawJson(jsonStr);
    } catch (_) {
      return null;
    }
  }
}
