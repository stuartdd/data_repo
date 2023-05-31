import 'dart:convert';
import 'dart:io';

//
// Run from project root:
//     dart run test/testServer.dart
//
// Config Data
//            "postDataUrl": "http://localhost:4040/file",
//             "getDataUrl": "http://localhost:4040/file",
//             "datafile": "data03.json",
//             "datafilePath": "test/data"
//
const String remoteDataDirectory = "test/remote";
const String remoteConfigDirectory = "test/remote";
Future<void> main() async {
  final server = await createServer();
  print('Server started: ${server.address} port ${server.port}');
  await handleRequests(server);
}

Future<HttpServer> createServer() async {
  final address = InternetAddress.loopbackIPv4;
  const port = 4040;
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
    case 'config':
      handleGetFile(request, remoteConfigDirectory, urlParts);
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
      handlePostFile(request, remoteConfigDirectory, urlParts, body);
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
