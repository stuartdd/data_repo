import 'dart:ui';

import "path.dart";
import 'package:http/http.dart' as http;
import 'package:http_status_code/http_status_code.dart';
import 'dart:io';
import 'dart:convert';
import 'encrypt.dart';

const timeStampPrefix = "TS:";
const timeStampPrefixClear = "${timeStampPrefix}C:";
const timeStampPrefixEnc = "${timeStampPrefix}E:";

class FilePrefixData {
  final bool hasData;
  final int timeStamp;
  final int startPos;
  final bool encrypted;
  FilePrefixData(this.hasData, this.timeStamp, this.startPos, this.encrypted);

  factory FilePrefixData.empty() {
    return FilePrefixData(false, -1, 0, false);
  }

  String getTimeStamp() {
    if (timeStamp == -1) {
      return "None";
    }
    return DateTime.fromMillisecondsSinceEpoch(timeStamp).toString();
  }

  bool isLaterThan(FilePrefixData other) {
    if (timeStamp == -1) {
      return false;
    }
    if (other.timeStamp == -1) {
      return true;
    }
    return timeStamp > other.timeStamp;
  }
}

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

class DataLoadException implements Exception {
  final String message;
  DataLoadException(this.message);
  @override
  String toString() {
    return "JsonException: $message";
  }
}

class DataContainer {
  final String _fileContents;
  final FilePrefixData filePrefixData;
  final String source;
  late final String _password;
  late final Map<String, dynamic> _dataMap;

  factory DataContainer.empty() {
    return DataContainer("", FilePrefixData.empty(), "", "");
  }

  DataContainer(this._fileContents, this.filePrefixData, this.source, String pw) {
    if (_fileContents.isEmpty) {
      _password = "";
      _dataMap = <String, dynamic>{};
      return;
    }
    _password = pw;
    if (_password.isNotEmpty && filePrefixData.encrypted) {
      final temp = EncryptData.decrypt(_fileContents, _password);
      _dataMap = jsonDecode(temp);
    } else {
      _dataMap = jsonDecode(_fileContents);
    }
  }

  String dataAsString() {
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    final ts = DateTime.timestamp().millisecondsSinceEpoch;
    final text = encoder.convert(_dataMap);
    if (_password.isNotEmpty) {
      return "$timeStampPrefixEnc$ts:${EncryptData.encryptAES(text, _password).base64}";
    }
    return "$timeStampPrefixClear$ts:$text";
  }

  bool get hasPassword {
    return _password.isNotEmpty;
  }

  Iterable<String> get keys {
    return _dataMap.keys;
  }

  bool get isEmpty {
    return _fileContents.isEmpty;
  }

  bool get hasData {
    return _dataMap.isNotEmpty;
  }

  Map<String, dynamic> get dataMap {
    return _dataMap;
  }
}

class SuccessState {
  final String message;
  final String value;
  final bool _isSuccess;
  late final Exception? _exception;
  SuccessState(this._isSuccess, {this.message = "", this.value = "", Exception? exception, void Function(String)? log}) {
    _exception = exception;
    if (log != null) {
      if (_exception != null) {
        if (message.isEmpty) {
          log("__EXCEPTION:__ ${_exception.toString()}");
        } else {
          log("__EXCEPTION:__ $message. ${_exception.toString()}");
        }
      } else {
        if (!_isSuccess) {
          log("__FAIL:__ '$message'");
        } else {
          if (message.isNotEmpty) {
            log("__OK:__ $message");
          }
        }
      }
    }
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

  bool get isFail {
    return !isSuccess;
  }

  Exception? get exception {
    return _exception;
  }

  String toLogString({bool bold = true}) {
    final bb = bold ? "__" : "";
    if (_exception != null) {
      if (message.isEmpty) {
        return "${bb}EXCEPTION:$bb ${_exception.toString()}";
      } else {
        return "${bb}EXCEPTION:$bb $message. ${_exception.toString()}";
      }
    } else {
      if (isFail) {
        if (message.isNotEmpty) {
          return "${bb}FAIL:$bb $message";
        }
        return "${bb}FAIL$bb";
      } else {
        if (message.isNotEmpty) {
          return "${bb}OK:$bb $message";
        }
        return "${bb}OK$bb";
      }
    }
  }

  @override
  String toString() {
    return toLogString(bold: false);
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
  static Future<SuccessState> toHttpPost(String url, String body, {void Function(String)? log}) async {
    try {
      final uri = Uri.parse(url);
      var response = await http.post(uri, headers: {"Content-Type": "application/json"}, body: body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SuccessState(true, message: "Remote file sent: Status:${response.statusCode} [${response.body}]", log: log);
      } else {
        return SuccessState(false, message: "Remote file send:${response.statusCode} [${response.body}]", log: log);
      }
    } catch (e) {
      return SuccessState(false, message: "Remote file send", exception: e as Exception, log: log);
    }
  }

  static Future<SuccessState> fromHttpGet(String url, {void Function(String)? log, int timeoutMillis = 2000, String prefix = ""}) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(
        Duration(milliseconds: timeoutMillis),
        onTimeout: () {
          return http.Response('Error:', StatusCode.REQUEST_TIMEOUT);
        },
      );
      if (response.statusCode != StatusCode.OK) {
        return SuccessState(false, message: "Remote Data loaded Failed. Status:${response.statusCode} Msg:${getStatusMessage(response.statusCode)}", log: log);
      }
      final body = response.body.trim();
      if (body.isEmpty) {
        return SuccessState(false, message: "Remote Data was empty:", log: log);
      }

      if (prefix.isNotEmpty && body.startsWith(prefix)) {
        return SuccessState(true, value: body.substring(prefix.length), message: "Remote Data loaded OK", log: log);
      }
      final body100 = body.length > 100 ? body.substring(0, 100).toLowerCase() : body;
      if (body100.contains("<html>") || body100.contains("<!DOCTYPE")) {
        return SuccessState(false, message: "Remote Data Load contains html:", log: log);
      }
      if (body.startsWith('{') || body.startsWith('[') || body.startsWith(timeStampPrefix)) {
        return SuccessState(true, value: body, message: "Remote Data loaded OK", log: log);
      }
      return SuccessState(false, message: "Remote Data Load was not JSON:", log: log);
    } catch (e) {
      return SuccessState(false, message: "Remote Data Load:", exception: e as Exception, log: log);
    }
  }

  static FilePrefixData readFilePrefixData(String s) {
    bool hasData = false;
    bool enc = false;
    int pos = 0;
    int ts = -1;
    if (s.startsWith(timeStampPrefixClear)) {
      hasData = true;
      enc = false;
      pos = timeStampPrefixClear.length;
    } else {
      if (s.startsWith(timeStampPrefixEnc)) {
        hasData = true;
        enc = true;
        pos = timeStampPrefixEnc.length;
      }
    }

    if (hasData) {
      final sb = StringBuffer();
      var p1 = pos;
      var cp = s.codeUnits[p1];
      while (cp >= 48 && cp <= 57) {
        sb.writeCharCode(cp);
        p1++;
        cp = s.codeUnits[p1];
      }
      try {
        ts = int.parse(sb.toString());
        return FilePrefixData(true, ts, p1 + 1, enc);
      } catch (e) {
        return FilePrefixData.empty();
      }
    }
    return FilePrefixData.empty();
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

  static SuccessState saveToFile(final String fileName, final String contents) {
    try {
      File(fileName).writeAsStringSync(contents);
      return SuccessState(true, message: "Data Saved OK");
    } catch (e, s) {
      stderr.write("DataLoad:saveToFile: $e\n$s");
      return SuccessState(false, message: e.toString(), exception: e as Exception);
    }
  }

  static mapToString(final Map<String, dynamic> contents) {
    return jsonEncode(contents);
  }

  static SuccessState loadFromFile(String fileName, {void Function(String)? log}) {
    try {
      final contents = File(fileName).readAsStringSync();
      return SuccessState(true, value: contents, message: "Local Data loaded OK", log: log);
    } catch (e) {
      if (e is PathNotFoundException) {
        return SuccessState(false, message: "Local Data file not found", value: "", exception: e, log: log);
      }
      return SuccessState(false, message: "Exception loading Local Data file", value: "", exception: e as Exception, log: log);
    }
  }

  static dynamic _nodeFromJson(Map<String, dynamic> json, Path path) {
    if (path.isEmpty()) {
      throw JsonException(message: "_nodeFromJson: Empty Path", path);
    }
    dynamic node = json;
    for (var i = 0; i < path.length(); i++) {
      final name = path.peek(i);
      node = node[name];
      if (node == null) {
        return null;
      }
      if (i == (path.length() - 1)) {
        return node;
      }
    }
    return null;
  }

  static String stringFromJson(Map<String, dynamic> json, Path path, {String fallback = "", bool create = false}) {
    final node = _nodeFromJson(json, path);
    if (node == null) {
      if (create) {
        setValueForJsonPath(json, path, fallback);
        return fallback;
      } else {
        if (fallback.isNotEmpty) {
          return fallback;
        }
      }
      throw JsonException(message: "stringFromJson: String Node was NOT found", path);
    }
    if (node is String) {
      return node;
    }
    throw JsonException(message: "stringFromJson: Node found was NOT a String node", path);
  }

  static String setValueForJsonPath(Map<String, dynamic> json, Path path, dynamic value) {
    if (path.isEmpty()) {
      return "Path is empty";
    }
    dynamic node = json;
    dynamic parent = json;
    for (int i = 0; i < path.length(); i++) {
      final name = path.peek(i);
      parent = node;
      node = parent[name];
      if (node == null) {
        parent[name] = {};
        if (i == path.length() - 1) {
          parent[name] = value;
          return "";
        } else {
          node = parent[name];
        }
      } else {
        if (i == path.length() - 1) {
          parent[name] = value;
          return "";
        }
      }
    }
    return "";
  }

  static num numFromJson(Map<String, dynamic> json, Path path, {num? fallback}) {
    final node = _nodeFromJson(json, path);
    if (node == null) {
      if (fallback != null) {
        return fallback;
      }
      throw JsonException(message: "numFromJson: number Node was NOT found", path);
    }
    if (node is num) {
      return node;
    }
    throw JsonException(message: "intFromJson: Node found [$node] was NOT a Number node", path);
  }

  static Color colorFromHexJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path);
    if (node == null) {
      throw JsonException(message: "colorFromHexJson: Hex:Color Node was NOT found", path);
    }
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
    final node = _nodeFromJson(json, path);
    if (node == null) {
      throw JsonException(message: "boolFromJson: bool Node was NOT found", path);
    }
    if (node is bool) {
      return node;
    }
    throw JsonException(message: "intFromJson: Node found [$node] was NOT a bool node", path);
  }

  static Map<String, dynamic> mapFromJson(Map<String, dynamic> json, Path path) {
    final node = _nodeFromJson(json, path);
    if (node == null) {
      throw JsonException(message: "mapFromJson: Map Node was NOT found", path);
    }
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
    final node = _nodeFromJson(json, path);
    if (node == null) {
      throw JsonException(message: "mapFromJson: List Node was NOT found", path);
    }
    if (node is List<dynamic>) {
      return node;
    }
    throw JsonException(message: "listFromJson: Node found was NOT a List node", path);
  }
}
