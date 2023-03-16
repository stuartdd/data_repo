import 'dart:ui';
import "path.dart";
import 'package:http/http.dart' as http;
import 'package:http_status_code/http_status_code.dart';
import 'dart:io';
import 'dart:convert';

class JsonException implements Exception {
  final dynamic message;
  final Path path;
  JsonException(this.message, this.path);
  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "JsonException";
    if (path.isEmpty()) {
      return "Exception: $message";
    }
    return "Exception: $message: Json:$path";
  }
}

class DataValueRow {
  final String _name;
  final String _value;
  final Path _path;
  final String _type;
  final bool _isValue;
  final int _mapSize;

  DataValueRow(this._name, this._value, this._path, this._type, this._isValue, this._mapSize);

  Path getFullPath() {
    return _path.cloneAppend([_name]);
  }

  String get name => _name;
  String get value => _value;
  Path get path => _path;
  String get type => _type;
  bool get isValue => _isValue;
  int get mapSize => _mapSize;

  bool isLink() {
    if (_isValue) {
      var t = _value.toLowerCase();
      if (t.startsWith("http://") || t.startsWith("https://")) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() {
    if (_isValue) {
      return "Name:$_name ($_type) = $_value";
    }
    return "Name:$_name [$_mapSize]";
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

  static String fromFile(String fileName) {
    return File(fileName).readAsStringSync();
  }

  static Map<String, dynamic> jsonFromString(String json) {
    final parsedJson = jsonDecode(json);
    return parsedJson;
  }

  static Map<String, dynamic> jsonFromFile(String fileName) {
    final json = DataLoad.fromFile(fileName);
    return jsonFromString(json);
  }

  static dynamic _nodeFromJson(Map<String, dynamic> json, Path path, String type) {
    if (path.isEmpty()) {
      throw JsonException("_nodeFromJson: Empty Path", path);
    }
    dynamic node = json;
    for (var i = 0; i < path.length(); i++) {
      node = node[path.peek(i)];
      if (node != null && i == (path.length() - 1)) {
        return node;
      }
    }
    throw JsonException("_nodeFromJson: $type Node was NOT found", path);
  }

  static String stringFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "String");
    if (node is String) {
      return node;
    }
    throw JsonException("stringFromJson: Node found was NOT a String node", path);
  }

  static num numFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "number");
    if (node is num) {
      return node;
    }
    throw JsonException("intFromJson: Node found [$node] was NOT a Number node", path);
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
          throw JsonException("colorFromJson: Node found [$node] could not be parsed", path);
        }
      }
    }
    throw JsonException("colorFromJson: Node found [$node] was NOT a Hex Colour (6 or 8 chars)", path);
  }

  static bool boolFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "bool");
    if (node is bool) {
      return node;
    }
    throw JsonException("intFromJson: Node found [$node] was NOT a bool node", path);
  }

  static Map<String, dynamic> mapFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "Map");
    if (node is Map<String, dynamic>) {
      return node;
    }
    throw JsonException("mapFromJson: Node found was NOT a Map node", path);
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

  static List<DataValueRow> dataValueListFromJson(Map<String, dynamic> json, Path path) {
    List<DataValueRow> lm = List.empty(growable: true);
    List<DataValueRow> lv = List.empty(growable: true);
    for (var element in json.entries) {
      if (element.value is Map) {
        lm.add(DataValueRow(element.key, "", path, element.value.runtimeType.toString(), false, (element.value as Map).length));
      } else if (element.value is List) {
        lm.add(DataValueRow(element.key, "", path, element.value.runtimeType.toString(), false, (element.value as List).length));
      } else {
        lv.add(DataValueRow(element.key, element.value.toString(), path, element.value.runtimeType.toString(), true, 0));
      }
    }
    lm.addAll(lv);
    return lm;
  }

  static List<dynamic> listFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path, "List");
    if (node is List<dynamic>) {
      return node;
    }
    throw JsonException("listFromJson: Node found was NOT a List node", path);
  }
}
