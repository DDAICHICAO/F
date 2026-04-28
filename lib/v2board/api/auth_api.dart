import 'package:fl_clash/v2board/api/api_paths.dart';
import 'package:fl_clash/v2board/api/v2board_api.dart';
import 'package:fl_clash/v2board/models/auth.dart';

class AuthApi {
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await v2boardApi.post(
      ApiPaths.login,
      data: {'email': email, 'password': password},
    );
    final resp = data['data'] as Map<String, Object?>;
    return AuthResponse.fromJson(resp);
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
    String? recaptchaData,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (emailCode != null) body['email_code'] = emailCode;
    if (inviteCode != null) body['invite_code'] = inviteCode;
    if (recaptchaData != null) body['recaptcha_data'] = recaptchaData;

    final data = await v2boardApi.post(ApiPaths.register, data: body);
    final resp = data['data'] as Map<String, Object?>;
    return AuthResponse.fromJson(resp);
  }

  Future<void> forget({
    required String email,
    required String emailCode,
    required String password,
  }) async {
    await v2boardApi.post(
      ApiPaths.forget,
      data: {
        'email': email,
        'email_code': emailCode,
        'password': password,
      },
    );
  }

  Future<void> sendEmailVerify({required String email}) async {
    await v2boardApi.post(
      ApiPaths.sendEmailVerify,
      data: {'email': email},
    );
  }

  Future<CheckLoginResult> checkLogin() async {
    final data = await v2boardApi.get(ApiPaths.userCheckLogin);
    final resp = data['data'] as Map<String, Object?>?;
    if (resp == null) {
      return const CheckLoginResult(isLogin: false);
    }
    return CheckLoginResult(
      isLogin: resp['is_login'] as bool? ?? false,
      isAdmin: resp['is_admin'] as bool? ?? false,
    );
  }
}

class CheckLoginResult {
  final bool isLogin;
  final bool isAdmin;

  const CheckLoginResult({required this.isLogin, this.isAdmin = false});
}

final authApi = AuthApi();
