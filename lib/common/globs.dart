import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? prefs;

class Globs {
  static const appName = "Enjaz7";

  static void udStringSet(String data, String key) {
    prefs?.setString(key, data);
  }

  static String udValueString(String key) {
    return prefs?.getString(key) ?? "";
  }
}

class SVKey {
  static const apiKey = "ENJAZ7_SECURE_KEY_8f9a2b3c4d5e6f7G8H9I0J1K2L3M4N5O";
  // عدل هذا الرابط بعد أن ترفع السيرفر على Render واحصل منه على الرابط
  static const mainUrl = "https://enjaz7-server.onrender.com";
  static const baseUrl = "$mainUrl/api/";
  static const nodeUrl = mainUrl;

  static const nvCarJoin = "car_join";
  static const nvCarUpdateLocation = "car_update_location";

  static const svCarJoin = "$baseUrl$nvCarJoin";
  static const svCarUpdateLocation = "$baseUrl$nvCarUpdateLocation";
}

class KKey {
  static const payload = "payload";
  static const status = "status";
  static const message = "message";
}

class MSG {
  static const success = "success";
  static const fail = "fail";
}
