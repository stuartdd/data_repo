/*
 * Copyright (C) 2023 Stuart Davies (stuartdd)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import 'dart:convert';
import 'dart:io';

//
// Run from project root:
//     dart run test/testServer.dart
//
// Config Data Linux
//             "postDataUrl": "http://localhost:3000/file",
//             "getDataUrl": "http://localhost:3000/file",
//             "datafile": "data.json",
//             "datafilePath": "test/data"
// Config Data Android Emulator
//             "postDataUrl": "http://10.0.2.2:3000/file",
//             "getDataUrl": "http://10.0.2.2:3000/file",
//             "datafile": "data.json"
//
const String remoteDataDirectory = "../data_repo_server/remote";
const String remoteLocalDirectory = "../data_repo_server/local";
const port = 3000;

Future<void> main() async {
  final server = await createServer();
  print('Server started: ${server.address} port ${server.port}');
  if (!_ensureExists(remoteDataDirectory)) {
    exit(1);
  }
  if (!_ensureExists(remoteLocalDirectory)) {
    exit(1);
  }
  await handleRequests(server);
}

bool _ensureExists(String dir) {
  Directory d = Directory(dir);
  if (!d.existsSync()) {
    d.createSync(recursive: true);
    if (!d.existsSync()) {
      print('Server dir could not be created:${d.absolute}');
      return false;
    } else {
      print('Server dir created:${d.absolute}');
      return true;
    }
  }
  print('Server dir found:${d.absolute}');
  return true;
}

Future<HttpServer> createServer() async {
  final address = InternetAddress.loopbackIPv4;
  return await HttpServer.bind(address, port);
}

Future<void> handleRequests(HttpServer server) async {
  await for (HttpRequest request in server) {
    switch (request.method) {
      case 'GET':
        handleGet(request);
        break;
      case 'POST':
        handlePost(request);
        break;
      default:
        handleUnsupportedMethod(request);
    }
  }
}

/// GET requests

void handleGet(HttpRequest request) {
  final urlParts = request.uri.pathSegments;
  print("GET:Parts:$urlParts");
  switch (urlParts[0]) {
    case 'file':
      handleGetFile(request, remoteDataDirectory, urlParts);
      break;
    case 'local':
      handleGetFile(request, remoteLocalDirectory, urlParts);
      break;
    default:
      handleBadRequest(request);
  }
}

void handleGetFile(HttpRequest request, String filePath, List<String> urlParts) {
  final fn = urlParts[1];
  final fp = "$filePath/$fn";
  print("GET:File:$fn FilePath:$fp");
  final String jsonString;
  try {
    jsonString = File(fp).readAsStringSync();
  } catch (e) {
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('File not found:$fn.')
      ..close();
    return;
  }
  request.response
    ..statusCode = HttpStatus.ok
    ..write(jsonString)
    ..close();
  return;
}

/// POST requests
Future<void> handlePost(HttpRequest request) async {
  final urlParts = request.uri.pathSegments;
  final body = await utf8.decoder.bind(request).join();
  print("POST:Parts:$urlParts");
  switch (urlParts[0]) {
    case 'file':
      handlePostFile(request, remoteDataDirectory, urlParts, body);
      break;
    case 'config':
      handlePostFile(request, remoteLocalDirectory, urlParts, body);
      break;
    default:
      handleBadRequest(request);
  }
}

Future<void> handlePostFile(HttpRequest request, String filePath, List<String> urlParts, String content) async {
  final fn = urlParts[1];
  final fp = "$filePath/$fn";
  print("POST:File:$fn FilePath:$fp \n$content\n");
  try {
    File(fp).writeAsStringSync(content);
    request.response
      ..write('Remote File Saved')
      ..close();
  } catch (e) {
    request.response
      ..statusCode = HttpStatus.notModified
      ..write('Remote File Not Saved')
      ..close();
  }
}

/// Other HTTP method requests

void handleUnsupportedMethod(HttpRequest request) {
  request.response
    ..statusCode = HttpStatus.methodNotAllowed
    ..write('Unsupported method: ${request.method}.')
    ..close();
}

void handleBadRequest(HttpRequest request) {
  request.response
    ..statusCode = HttpStatus.badRequest
    ..write('Bad request: ${request.uri}.')
    ..close();
}

void handleNotFound(HttpRequest request, String file) {
  request.response
    ..statusCode = HttpStatus.notFound
    ..write('Not Found: $file')
    ..close();
}
