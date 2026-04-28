import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class V2boardLocalStorage {
  static V2boardLocalStorage? _instance;
  late SharedPreferences _prefs;

  V2boardLocalStorage._();

  static Future<V2boardLocalStorage> getInstance() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = V2boardLocalStorage._().._prefs = prefs;
    return _instance!;
  }

  // ---- Keys ----
  static const _keyOssConfig = 'v2board_oss_config';
  static const _keyOssUrls = 'v2board_oss_urls';
  static const _keyAuthData = 'v2board_auth_data';
  static const _keyToken = 'v2board_token';
  static const _keyIsAdmin = 'v2board_is_admin';
  static const _keyUserEmail = 'v2board_user_email';
  static const _keyProfileId = 'v2board_profile_id';
  static const _keyManualApiUrl = 'v2board_manual_api_url';
  static const _keyActiveApiIndex = 'v2board_active_api_index';
  static const _keyLastNoticeTime = 'v2board_last_notice_time';

  // ---- OSS Config ----
  String? get ossConfig => _prefs.getString(_keyOssConfig);

  Future<void> setOssConfig(String value) =>
      _prefs.setString(_keyOssConfig, value);

  // ---- OSS URLs ----
  List<String> get ossUrls {
    final raw = _prefs.getString(_keyOssUrls);
    if (raw == null) return [];
    return List<String>.from(json.decode(raw));
  }

  Future<void> setOssUrls(List<String> urls) =>
      _prefs.setString(_keyOssUrls, json.encode(urls));

  // ---- Auth Data (JWT) ----
  String? get authData => _prefs.getString(_keyAuthData);

  Future<void> setAuthData(String value) =>
      _prefs.setString(_keyAuthData, value);

  // ---- Token (subscribe token) ----
  String? get token => _prefs.getString(_keyToken);

  Future<void> setToken(String value) =>
      _prefs.setString(_keyToken, value);

  // ---- Is Admin ----
  bool get isAdmin => _prefs.getBool(_keyIsAdmin) ?? false;

  Future<void> setIsAdmin(bool value) =>
      _prefs.setBool(_keyIsAdmin, value);

  // ---- User Email ----
  String? get userEmail => _prefs.getString(_keyUserEmail);

  Future<void> setUserEmail(String value) =>
      _prefs.setString(_keyUserEmail, value);

  // ---- Profile ID ----
  int? get profileId => _prefs.getInt(_keyProfileId);

  Future<void> setProfileId(int value) =>
      _prefs.setInt(_keyProfileId, value);

  // ---- Manual API URL ----
  String? get manualApiUrl => _prefs.getString(_keyManualApiUrl);

  Future<void> setManualApiUrl(String value) =>
      _prefs.setString(_keyManualApiUrl, value);

  // ---- Active API Index ----
  int get activeApiIndex => _prefs.getInt(_keyActiveApiIndex) ?? 0;

  Future<void> setActiveApiIndex(int value) =>
      _prefs.setInt(_keyActiveApiIndex, value);

  // ---- Last Notice Time ----
  String? get lastNoticeTime => _prefs.getString(_keyLastNoticeTime);

  Future<void> setLastNoticeTime(String value) =>
      _prefs.setString(_keyLastNoticeTime, value);

  // ---- Clear Auth ----
  Future<void> clearAuth() async {
    await Future.wait([
      _prefs.remove(_keyAuthData),
      _prefs.remove(_keyToken),
      _prefs.remove(_keyIsAdmin),
      _prefs.remove(_keyProfileId),
    ]);
  }

  // ---- Clear All ----
  Future<void> clearAll() async {
    await Future.wait([
      _prefs.remove(_keyOssConfig),
      _prefs.remove(_keyOssUrls),
      _prefs.remove(_keyAuthData),
      _prefs.remove(_keyToken),
      _prefs.remove(_keyIsAdmin),
      _prefs.remove(_keyUserEmail),
      _prefs.remove(_keyProfileId),
      _prefs.remove(_keyManualApiUrl),
      _prefs.remove(_keyActiveApiIndex),
      _prefs.remove(_keyLastNoticeTime),
    ]);
  }
}
