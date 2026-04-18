import 'dart:convert';
import 'package:http/http.dart' as http;
import '../common/globs.dart';
import 'package:flutter/foundation.dart';

class ServiceCall {
  static String userUUID = "";

  static void post(Map<String, dynamic> parameter, String path,
      ResSuccess? withSuccess, ResFailure? failure) {
    Future(() {
      try {
        var headers = {
          "Content-Type": 'application/x-www-form-urlencoded',
          "X-API-KEY": SVKey.apiKey
        };
        http
            .post(Uri.parse(path), body: parameter, headers: headers)
            .then((value) {
          if (kDebugMode) {
            print(value.body);
          }

          try {
            var jsonObj =
                json.decode(value.body) as Map<String, dynamic>? ?? {};
            if (withSuccess != null) withSuccess(jsonObj);
          } catch (e) {
            if (failure != null) failure(e);
          }
        }).catchError((e) {
          if (failure != null) failure(e);
        });
      } catch (e) {
        if (failure != null) failure(e);
      }
    });
  }
}

typedef ResSuccess = Future<void> Function(Map<String, dynamic>);
typedef ResFailure = Future<void> Function(dynamic);

