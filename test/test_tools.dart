import 'package:data_repo/data_container.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_status_code/http_status_code.dart';
import 'dart:io';

assertContainsAll(List<String> list, String s) {
  for (var i = 0; i < list.length; i++) {
    if (!s.contains(list[i])) {
      fail("Message Text [$s] does not contain all of '${list[i]}'");
    }
  }
}

assertContainsNone(List<String> list, String s) {
  for (var i = 0; i < list.length; i++) {
    if (s.contains(list[i])) {
      fail("Message Text [$s] should not contain '${list[i]}'");
    }
  }
}

const serverPort = 8888;

Future<void> startTestServer() async {
  _startServer();
  Exception? eee;
  int resp = 0;
  for (int i = 0; i < 10; i++) {
    sleep(const Duration(milliseconds: 100));
    try {
      resp = await _pingServer();
      if (resp == 200) {
        return;
      }
    } catch (e) {
      eee ??= e as Exception;
    }
  }
  if (eee != null) {
    fail("Test server failed to respond to a ping. ${eee.toString()}");
  }
  fail("Test server failed to respond to a ping. RC:$resp");
}

Future<HttpServer> _startServer() async {
  var server = await HttpServer.bind(InternetAddress.anyIPv6, serverPort);
  await server.forEach((HttpRequest request) {
    final parts = request.requestedUri.pathSegments;
    final last = parts[parts.length - 1];
    if (last == "ping") {
      request.response.write("ping");
    } else {
      final resp = DataContainer.loadFromFile("test/data/$last");
      if (resp.isFail) {
        request.response.statusCode = 404;
      } else {
        request.response.write(resp.value);
      }
    }
    request.response.close();
  });
  return server;
}

Future<int> _pingServer() async {
  final uri = Uri.parse("http://localhost:$serverPort/ping");
  final response = await http.get(uri).timeout(
    const Duration(seconds: 2),
    onTimeout: () {
      return http.Response('Error:', StatusCode.REQUEST_TIMEOUT);
    },
  );
  return response.statusCode;
}
