import 'package:pigeon/pigeon.dart';

class PigeonUserDetails {
  final String? userId;
  final String? email;
  final String? name;
  final String? photoUrl;
  final String? provider;

  PigeonUserDetails({
    required this.userId,
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.provider,
  });
}

class PigeonAuthResult {
  final bool success;
  final PigeonUserDetails? user;
  final String? error;

  PigeonAuthResult({
    required this.success,
    this.user,
    this.error,
  });
}

@HostApi()
abstract class AuthApi {
  @async
  PigeonUserDetails? loginWithGoogle();

  // @async
  // PigeonUserDetails? loginWithFacebook(); // Facebook login disabled

  @async
  PigeonAuthResult logout();
}
