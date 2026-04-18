import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/service_call.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketManager {
  static final SocketManager singleton = SocketManager._internal();
  SocketManager._internal();
  static SocketManager get shared => singleton;
  
  IO.Socket? socket;

  String? get id => socket?.id;

  void init(String baseUrl) {
    socket = IO.io(baseUrl, {
      "transports": ['websocket'],
      "autoConnect": true
    });

    socket?.on("connect", (data) {
      if (kDebugMode) {
        print("Socket Connect Done");
      }
      updateSocketIdApi();
    });

    socket?.on("connect_error", (data) {
      if (kDebugMode) {
        print("Socket Connect Error");
        print(data);
      }
    });

    socket?.on("error", (data) {
      if (kDebugMode) {
        print("Socket Error");
        print(data);
      }
    });

    socket?.on("disconnect", (data) {
      if (kDebugMode) {
        print("Socket Disconnect");
        print(data);
      }
    });

    socket?.on("UpdateSocket", (data) {
      print("UpdateSocket : -------------");
      print(data);
    });
  }

  void on(String event, Function(dynamic) callback) {
    socket?.on(event, callback);
  }

  void disconnect() {
    socket?.disconnect();
  }

  Future updateSocketIdApi() async {
    if (ServiceCall.userUUID == "") {
      return;
    }

    try {
      socket?.emit("UpdateSocket", jsonEncode({'uuid': ServiceCall.userUUID}));
    } catch (e) {
      if (kDebugMode) {
        print("Socket Disconnect");
        print(e.toString());
      }
    }
  }
}
