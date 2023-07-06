import "path.dart";
import 'package:http/http.dart' as http;
import 'package:http_status_code/http_status_code.dart';
import 'dart:io';
import 'dart:convert';
import 'encrypt.dart';
import 'data_types.dart';

const timeStampPrefix = "TS:";
const timeStampPrefixClear = "${timeStampPrefix}C:";
const timeStampPrefixEnc = "${timeStampPrefix}E:";
const JsonEncoder formattedJsonEncoder = JsonEncoder.withIndent('  ');

class FilePrefixData {
  final bool hasData;
  final int timeStamp;
  final int startPos;
  final bool encrypted;
  FilePrefixData(this.hasData, this.timeStamp, this.startPos, this.encrypted);

  factory FilePrefixData.fromString(String s) {
    bool hasTimeStampData = false;
    bool enc = false;
    int pos = 0;
    int ts = -1;
    if (s.startsWith(timeStampPrefixClear)) {
      hasTimeStampData = true;
      enc = false;
      pos = timeStampPrefixClear.length;
    } else {
      if (s.startsWith(timeStampPrefixEnc)) {
        hasTimeStampData = true;
        enc = true;
        pos = timeStampPrefixEnc.length;
      }
    }

    if (hasTimeStampData) {
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

  factory FilePrefixData.empty() {
    return FilePrefixData(false, -1, 0, false);
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
    if (path == null || path!.isEmpty) {
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
  final String source;
  late final int _timeStamp;
  late final String _password;
  late final Map<String, dynamic> _dataMap;

  factory DataContainer.empty() {
    return DataContainer("", FilePrefixData.empty(), "", "");
  }

  DataContainer(final String fileContents, final FilePrefixData filePrefixData, this.source, final String pw) {
    _password = pw;
    _timeStamp = filePrefixData.timeStamp;
    _dataMap = DataLoad.convertStringToMap(fileContents, pw);
  }

  String get timeStampString {
    if (_timeStamp == -1) {
      return "None";
    }
    return DateTime.fromMillisecondsSinceEpoch(_timeStamp).toString();
  }

  String get password {
    return _password;
  }

  bool get hasPassword {
    return _password.isNotEmpty;
  }

  Iterable<String> get keys {
    return _dataMap.keys;
  }

  bool get isEmpty {
    return _dataMap.isEmpty;
  }

  bool get isNotEmpty {
    return _dataMap.isNotEmpty;
  }

  Map<String, dynamic> get dataMap {
    return _dataMap;
  }
}

class DataLoad {
  static String convertMapToStringWithTs(Map<String, dynamic> json, String pw, {bool addTimeStamp = true}) {
    String tsString = "";
    if (addTimeStamp) {
      final ts = DateTime.timestamp().millisecondsSinceEpoch;
      tsString = "${pw.isEmpty?timeStampPrefixClear:timeStampPrefixEnc}$ts:";
    }
    if (pw.isEmpty) {
      return "$tsString${formattedJsonEncoder.convert(json)}";
    } else {
      return "$tsString${EncryptData.encryptAES(jsonEncode(json), pw).base64}";
    }
  }

  static Map<String, dynamic> convertStringToMap(String jsonText, String pw) {
    if (jsonText.isEmpty) {
      return <String, dynamic>{};
    }
    if (pw.isNotEmpty) {
      return jsonDecode(EncryptData.decrypt(jsonText, pw));
    } else {
      return jsonDecode(jsonText);
    }
  }

  static Future<SuccessState> toHttpPost(final String url, final String body, {void Function(String)? log}) async {
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

  static Future<SuccessState> fromHttpGet(final String url, {final void Function(String)? log, final int timeoutMillis = 2000, final String prefix = ""}) async {
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

  static SuccessState saveToFile(final String fileName, final String contents) {
    try {
      File(fileName).writeAsStringSync(contents);
      return SuccessState(true, message: "Data Saved OK");
    } catch (e, s) {
      stderr.write("DataLoad:saveToFile: $e\n$s");
      return SuccessState(false, message: e.toString(), exception: e as Exception);
    }
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

  static dynamic getNodeFromJson(Map<String, dynamic> json, Path path) {
    if (path.isEmpty) {
      throw JsonException(message: "_nodeFromJson: Empty Path", path);
    }
    dynamic node = json;
    for (var i = 0; i < path.length; i++) {
      final name = path.peek(i);
      node = node[name];
      if (node == null) {
        return null;
      }
      if (i == (path.length - 1)) {
        return node;
      }
    }
    return null;
  }

  static String setValueForJsonPath(Map<String, dynamic> json, Path path, dynamic value) {
    if (path.isEmpty) {
      return "Path is empty";
    }
    dynamic node = json;
    dynamic parent = json;
    for (int i = 0; i < path.length; i++) {
      final name = path.peek(i);
      parent = node;
      node = parent[name];
      if (node == null) {
        parent[name] = {};
        if (i == path.length - 1) {
          parent[name] = value;
          return "";
        } else {
          node = parent[name];
        }
      } else {
        if (i == path.length - 1) {
          parent[name] = value;
          return "";
        }
      }
    }
    return "";
  }

  static String getStringFromJson(Map<String, dynamic> json, Path path, {String fallback = "", bool create = false}) {
    final node = getNodeFromJson(json, path);
    if (node == null) {
      if (create) {
        setValueForJsonPath(json, path, fallback);
        return fallback;
      } else {
        if (fallback.isNotEmpty) {
          return fallback;
        }
      }
      throw JsonException(message: "getStringFromJson: String Node was NOT found", path);
    }
    if (node is String) {
      return node;
    }
    throw JsonException(message: "getStringFromJson: Node found was NOT a String node", path);
  }

  static num getNumFromJson(Map<String, dynamic> json, Path path, {num? fallback}) {
    final node = getNodeFromJson(json, path);
    if (node == null) {
      if (fallback != null) {
        return fallback;
      }
      throw JsonException(message: "getNumFromJson: number Node was NOT found", path);
    }
    if (node is num) {
      return node;
    }
    throw JsonException(message: "getNumFromJson: Node found [$node] was NOT a Number node", path);
  }

  static bool geBoolFromJson(Map<String, dynamic> json, Path path) {
    final node = getNodeFromJson(json, path);
    if (node == null) {
      throw JsonException(message: "geBoolFromJson: bool Node was NOT found", path);
    }
    if (node is bool) {
      return node;
    }
    throw JsonException(message: "geBoolFromJson: Node found [$node] was NOT a bool node", path);
  }

  static Map<String, dynamic> getMapFromJson(Map<String, dynamic> json, Path path) {
    final node = getNodeFromJson(json, path);
    if (node == null) {
      throw JsonException(message: "getMapFromJson: Map Node was NOT found", path);
    }
    if (node is Map<String, dynamic>) {
      return node;
    }
    throw JsonException(message: "getMapFromJson: Node found was NOT a Map node", path);
  }
}
