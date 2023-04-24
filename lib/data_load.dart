import 'dart:ui';
import "path.dart";
import 'package:http/http.dart' as http;
import 'package:http_status_code/http_status_code.dart';
import 'dart:io';
import 'dart:convert';

class JsonException implements Exception {
  final String message;
  final Path? path;
  JsonException(this.path, {required this.message});
  @override
  String toString() {
    Object? message = this.message;
    if (path == null || path!.isEmpty()) {
      return "JsonException: $message";
    }
    return "JsonException: $message: Path:$path";
  }
}

class SuccessState {
  final String message;
  final String value;
  final bool _isSuccess;
  late final Exception? _exception;
  SuccessState(this._isSuccess, {this.message = "", this.value = "", Exception? exception}) {
    _exception = exception;
  }

  bool get hasException {
    return (_exception != null);
  }

  bool get isSuccess {
    if (hasException) {
      return false;
    }
    return _isSuccess;
  }

  String get status {
    if (hasException) {
      return "Exception:";
    }
    if (isSuccess) {
      return "OK:";
    }
    return "Error:";
  }

  Exception? get exception {
    return _exception;
  }

  @override
  String toString() {
    return '$status $message';
  }

  bool isDifferentFrom(SuccessState other) {
    if (isSuccess != other.isSuccess) {
      return true;
    }
    if (value != other.value) {
      return true;
    }
    if (message != other.message) {
      return true;
    }
    return false;
  }
}

class DataLoad {
  static Future<String> fromHttpGet(String url) async {
    final uri = Uri.parse(url);
    final response = await http.get(uri).timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        return http.Response('Error:', StatusCode.REQUEST_TIMEOUT);
      },
    );
    if (response.statusCode != StatusCode.OK) {
      throw http.ClientException("Failed to GET data from server. Status:${response.statusCode} Msg:${getStatusMessage(response.statusCode)}.", uri);
    }
    return response.body;
  }

  static void pathsForMapNodes(Map<String, dynamic> json, Function(String) callBack) {
    _pathsForMapNodesRecurse(json, "", callBack);
  }

  static void _pathsForMapNodesRecurse(Map<String, dynamic> json, String kk, Function(String) callBack) {
    if (kk.isNotEmpty) {
      callBack(kk);
    }
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        if (kk.isEmpty) {
          _pathsForMapNodesRecurse(value, key, callBack);
        } else {
          _pathsForMapNodesRecurse(value, '$kk|$key', callBack);
        }
      }
    });
  }

  static SuccessState saveToFile(final String fileName, final Map<String, dynamic> contents) {
    try {
      JsonEncoder encoder = const JsonEncoder.withIndent('  ');
      File(fileName).writeAsStringSync(encoder.convert(contents));
      return SuccessState(true, message: "Data Saved OK");
    } catch (e, s) {
      stderr.write("DataLoad:saveToFile: $e\n$s");
      return SuccessState(false, message: e.toString(), exception: e as Exception);
    }
  }

  static mapToString(final Map<String, dynamic> contents) {
    return jsonEncode(contents);
  }

  static SuccessState loadFromFile(String fileName) {
    try {
      final contents = File(fileName).readAsStringSync();
      return SuccessState(true, value: contents, message: "Data loaded OK");
    } catch (e, s) {
      stderr.write("DataLoad:loadFromFile: $e\n$s");
      return SuccessState(false, message: "Failed to load Data file", value: "", exception: e as Exception);
    }
  }

  static Map<String, dynamic> jsonFromString(String json) {
    final parsedJson = jsonDecode(json);
    return parsedJson;
  }

  static Map<String, dynamic> jsonLoadFromFile(String fileName) {
    final json = DataLoad.loadFromFile(fileName);
    return jsonFromString(json.value);
  }

  static dynamic _nodeFromJson(Map<String, dynamic> json, Path path, String type) {
    if (path.isEmpty()) {
      throw JsonException(message: "_nodeFromJson: Empty Path", path);
    }
    dynamic node = json;
    for (var i = 0; i < path.length(); i++) {
      node = node[path.peek(i)];
      if (node != null && i == (path.length() - 1)) {
        return node;
      }
    }
    throw JsonException(message: "_nodeFromJson: $type Node was NOT found", path);
  }

  static String stringFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "String");
    if (node is String) {
      return node;
    }
    throw JsonException(message: "stringFromJson: Node found was NOT a String node", path);
  }

  static num numFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "number");
    if (node is num) {
      return node;
    }
    throw JsonException(message: "intFromJson: Node found [$node] was NOT a Number node", path);
  }

  static Color colorFromHexJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "Hex:Color");
    if (node is String) {
      var hexColor = node.replaceAll("#", "");
      if (hexColor.length == 6) {
        hexColor = "FF$hexColor";
      }
      if (hexColor.length == 8) {
        try {
          return Color(int.parse("0x$hexColor"));
        } catch (e) {
          throw JsonException(message: "colorFromJson: Node found [$node] could not be parsed", path);
        }
      }
    }
    throw JsonException(message: "colorFromJson: Node found [$node] was NOT a Hex Colour (6 or 8 chars)", path);
  }

  static bool boolFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "bool");
    if (node is bool) {
      return node;
    }
    throw JsonException(message: "intFromJson: Node found [$node] was NOT a bool node", path);
  }

  static Map<String, dynamic> mapFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "Map");
    if (node is Map<String, dynamic>) {
      return node;
    }
    throw JsonException(message: "mapFromJson: Node found was NOT a Map node", path);
  }

  /// Finds the map at the path.
  ///   If the last FOUND node is not a map and not a list it returns the parent node of the FOUND node.
  ///   If the last FOUND node is a map or a list it returns the FOUND node.
  ///
  static Map<String, dynamic>? findLastMapNodeForPath(final Map<String, dynamic> json, Path path) {
    if (json.isEmpty || path.isEmpty()) {
      return null;
    }
    var j = json;
    String key;
    dynamic f;
    for (int i = 0; i < path.length(); i++) {
      key = path.peek(i);
      if (key.isNotEmpty) {
        f = j[key];
        if (f == null) {
          return null;
        }
        if (f is! Map<String, dynamic> && f is! List<dynamic>) {
          return j;
        }
        j = f;
      }
    }
    return f;
  }

  static List<dynamic> listFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "List");
    if (node is List<dynamic>) {
      return node;
    }
    throw JsonException(message: "listFromJson: Node found was NOT a List node", path);
  }
}
