class GuestConfig {
  final String tosUrl;
  final int isEmailVerify;
  final int isInviteForce;
  final String emailWhitelistSuffix;
  final int isRecaptcha;
  final String recaptchaSiteKey;
  final String appDescription;
  final String appUrl;
  final String logo;

  const GuestConfig({
    this.tosUrl = '',
    this.isEmailVerify = 0,
    this.isInviteForce = 0,
    this.emailWhitelistSuffix = '',
    this.isRecaptcha = 0,
    this.recaptchaSiteKey = '',
    this.appDescription = '',
    this.appUrl = '',
    this.logo = '',
  });

  factory GuestConfig.fromJson(Map<String, dynamic> json) => GuestConfig(
        tosUrl: json['tos_url'] as String? ?? '',
        isEmailVerify: json['is_email_verify'] as int? ?? 0,
        isInviteForce: json['is_invite_force'] as int? ?? 0,
        emailWhitelistSuffix: json['email_whitelist_suffix'] as String? ?? '',
        isRecaptcha: json['is_recaptcha'] as int? ?? 0,
        recaptchaSiteKey: json['recaptcha_site_key'] as String? ?? '',
        appDescription: json['app_description'] as String? ?? '',
        appUrl: json['app_url'] as String? ?? '',
        logo: json['logo'] as String? ?? '',
      );
}

class UserCommConfig {
  final int isTelegram;
  final String telegramDiscussLink;
  final String stripePk;
  final List<dynamic> withdrawMethods;
  final int withdrawClose;
  final String currency;
  final String currencySymbol;
  final int surplusEnable;
  final int autoRenewalEnable;

  const UserCommConfig({
    this.isTelegram = 0,
    this.telegramDiscussLink = '',
    this.stripePk = '',
    this.withdrawMethods = const [],
    this.withdrawClose = 0,
    this.currency = '',
    this.currencySymbol = '',
    this.surplusEnable = 0,
    this.autoRenewalEnable = 0,
  });

  factory UserCommConfig.fromJson(Map<String, dynamic> json) => UserCommConfig(
        isTelegram: json['is_telegram'] as int? ?? 0,
        telegramDiscussLink: json['telegram_discuss_link'] as String? ?? '',
        stripePk: json['stripe_pk'] as String? ?? '',
        withdrawMethods: json['withdraw_methods'] as List? ?? [],
        withdrawClose: json['withdraw_close'] as int? ?? 0,
        currency: json['currency'] as String? ?? '',
        currencySymbol: json['currency_symbol'] as String? ?? '',
        surplusEnable: json['surplus_enable'] as int? ?? 0,
        autoRenewalEnable: json['auto_renewal_enable'] as int? ?? 0,
      );
}
