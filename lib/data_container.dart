import 'package:data_repo/main.dart';

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

class DataContainer {
  final String remoteSourcePath;
  final String localSourcePath;
  final String fileName;
  late final int _timeStamp;
  late final Map<String, dynamic> _dataMap;
  String password = "";
  String warning = "";

  factory DataContainer.empty() {
    return DataContainer("", FileDataPrefix.empty(), "", "", "", "");
  }

  DataContainer(final String fileContents, final FileDataPrefix filePrefixData, this.remoteSourcePath, this.localSourcePath, this.fileName, final String pw) {
    password = pw;
    _timeStamp = filePrefixData.timeStamp;
    _dataMap = convertStringToMap(fileContents, pw);
    warning = "";
    visitEachSubNode((key, path, value) {
      if (key.contains('.')) {
        if (warning.isEmpty) {
          warning = "Check logs for warnings!";
        }
        log("## __ALERT__ Node:$path has a '.' in the node name");
      }
    });
  }

  String get timeStampString {
    if (_timeStamp == -1) {
      return "None";
    }
    return DateTime.fromMillisecondsSinceEpoch(_timeStamp).toString();
  }

  bool get hasPassword {
    return password.isNotEmpty;
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

  String remove(Path path, bool isValue, {required bool dryRun}) {
    final intoNode = getNodeFromJson(path);
    if (intoNode == null) {
      return "Into not found";
    }
    final parentNode = getNodeFromJson(path.cloneParentPath());
    if (parentNode == null) {
      return "Into parent not found";
    }
    if (parentNode is! Map<String, dynamic>) {
      return "Into is not a group";
    }
    if (!dryRun) {
      parentNode.remove(path.last);
    }
    return "";
  }

  String copyInto(Path into, Path from, bool isValue, {required bool dryRun}) {
    final intoNode = getNodeFromJson(into);
    if (intoNode == null) {
      return "Into not found";
    }
    if (intoNode is! Map<String, dynamic>) {
      return "Into is not a group";
    }
    final fromNode = getNodeFromJson(from);
    if (fromNode == null) {
      return "From not found";
    }
    final fromName = from.last;
    if (intoNode.containsKey(fromName)) {
      return "Duplicate Key";
    }
    if (isValue) {
      if (!dryRun) {
        intoNode[fromName] = fromNode;
      }
      return "";
    }
    if (!dryRun) {
      final fromStr = jsonEncode(fromNode);
      final fromClone = json.decode(fromStr);
      intoNode[fromName] = fromClone;
    }
    return "";
  }

  dynamic getNodeFromJson(Path path) {
    if (path.isEmpty) {
      throw JsonException(message: "getNodeFromJson: Empty Path", path);
    }
    dynamic node = _dataMap;
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

  String getStringFromJsonOptional(Path path) {
    final node = getNodeFromJson(path);
    if (node == null) {
      return "";
    }
    return node.toString();
  }

  String getStringFromJson(Path path, {String fallback = "", bool create = false}) {
    final node = getNodeFromJson(path);
    if (node == null) {
      if (create) {
        setValueForJsonPath(path, fallback);
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

  num getNumFromJson(Path path, {num? fallback}) {
    final node = getNodeFromJson(path);
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

  bool getBoolFromJson(Path path, {bool? fallback}) {
    final node = getNodeFromJson(path);
    if (node == null) {
      if (fallback != null) {
        return fallback;
      }
      throw JsonException(message: "geBoolFromJson: bool Node was NOT found", path);
    }
    if (node is bool) {
      return node;
    }
    throw JsonException(message: "geBoolFromJson: Node found [$node] was NOT a bool node", path);
  }

  Map<String, dynamic> getMapFromJson(Path path) {
    final node = getNodeFromJson(path);
    if (node == null) {
      throw JsonException(message: "getMapFromJson: Map Node was NOT found", path);
    }
    if (node is Map<String, dynamic>) {
      return node;
    }
    throw JsonException(message: "getMapFromJson: Node found was NOT a Map node", path);
  }

  String setValueForJsonPath(Path path, dynamic value) {
    if (path.isEmpty) {
      return "Path is empty";
    }
    dynamic node = _dataMap;
    dynamic parent = _dataMap;
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

  String dataToStringFormatted() {
    return staticDataToStringFormatted(_dataMap);
  }

  String dataToStringUnFormatted() {
    return staticDataToStringUnFormatted(_dataMap);
  }

  String dataToStringFormattedWithTs(final String pw, {final bool addTimeStamp = true}) {
    return staticDataToStringFormattedWithTs(_dataMap, pw);
  }

  void visitEachSubNode(final void Function(String, Path, dynamic) func) {
    staticVisitEachSubNode(dataMap, Path.empty(), func);
  }

  //
  // ****************************************************************************************************************
  //
  // Static tools to store and load files
  //

  static void staticVisitEachSubNode(Map<String, dynamic> map, Path p, final void Function(String, Path, dynamic) func) {
    for (var key in map.keys) {
      final me = map[key];
      final pp = p.cloneAppendList([key]);
      if (me is Map<String, dynamic>) {
        func(key, pp, me);
        staticVisitEachSubNode(me, pp, func);
      } else {
        func(key, pp, me);
      }
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

  static String staticDataToStringFormatted(Map<String, dynamic> map) {
    return formattedJsonEncoder.convert(map);
  }

  static String staticDataToStringUnFormatted(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  static String staticDataToStringFormattedWithTs(Map<String, dynamic> map, final String pw, {final bool addTimeStamp = true}) {
    String tsString = "";
    if (addTimeStamp) {
      final ts = DateTime.timestamp().millisecondsSinceEpoch;
      tsString = "${pw.isEmpty ? timeStampPrefixClear : timeStampPrefixEnc}$ts:";
    }
    if (pw.isEmpty) {
      return "$tsString${staticDataToStringFormatted(map)}";
    } else {
      return "$tsString${EncryptData.encryptAES(staticDataToStringUnFormatted(map), pw).base64}";
    }
  }

  static Future<SuccessState> toHttpPost(final String url, final String body, {void Function(String)? log}) async {
    try {
      final uri = Uri.parse(url);
      var response = await http.post(uri, headers: {"Content-Type": "application/json"}, body: body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SuccessState(true, path: url, message: "Remote file sent: Status:${response.statusCode} [${response.body}]", log: log);
      } else {
        return SuccessState(false, path: url, message: "Remote file send:${response.statusCode} [${response.body}]", log: log);
      }
    } catch (e) {
      return SuccessState(false, path: url, message: "Remote file send", exception: e as Exception, log: log);
    }
  }

  static Future<String> testHttpGet(final String url, String pre) async {
    try {
      String resp = "";
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(
        const Duration(milliseconds: 1000),
        onTimeout: () {
          return http.Response('${pre}Timeout:', StatusCode.REQUEST_TIMEOUT);
        },
      );
      if (response.statusCode != StatusCode.OK) {
        return "${pre}Status:${response.statusCode} ${getStatusMessage(response.statusCode)}";
      }
      return resp;
    } catch (e) {
      return "$pre$e";
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
        return SuccessState(false, path: url, message: "Remote Data loaded Failed. Status:${response.statusCode} Msg:${getStatusMessage(response.statusCode)}", log: log);
      }
      final body = response.body.trim();
      if (body.isEmpty) {
        return SuccessState(false, path: url, message: "Remote Data was empty:", log: log);
      }

      if (prefix.isNotEmpty && body.startsWith(prefix)) {
        return SuccessState(true, path: url, fileContent: body.substring(prefix.length), message: "Remote Data loaded OK", log: log);
      }
      final body100 = body.length > 100 ? body.substring(0, 100).toLowerCase() : body;
      if (body100.contains("<html>") || body100.contains("<!DOCTYPE")) {
        return SuccessState(false, path: url, message: "Remote Data Load contains html:", log: log);
      }
      if (body.startsWith('{') || body.startsWith('[') || body.startsWith(timeStampPrefix)) {
        return SuccessState(true, path: url, fileContent: body, message: "Remote Data loaded OK", log: log);
      }
      return SuccessState(false, path: url, message: "Remote Data Load was not JSON:", log: log);
    } catch (e) {
      return SuccessState(false, path: url, message: "Remote Data Load:", exception: e as Exception, log: log);
    }
  }

  static SuccessState saveToFile(final String fileName, final String contents) {
    try {
      File(fileName).writeAsStringSync(contents);
      return SuccessState(true, path: fileName, message: "Data Saved OK");
    } catch (e, s) {
      stderr.write("DataLoad:saveToFile: $e\n$s");
      return SuccessState(false, path: fileName, message: e.toString(), exception: e as Exception);
    }
  }

  static SuccessState loadFromFile(String fileName, {void Function(String)? log}) {
    try {
      final contents = File(fileName).readAsStringSync();
      return SuccessState(true, path: fileName, fileContent: contents, message: "Local Data loaded OK", log: log);
    } catch (e) {
      if (e is PathNotFoundException) {
        return SuccessState(false, path: fileName, message: "Local Data file not found", fileContent: "", exception: e, log: log);
      }
      return SuccessState(false, path: fileName, message: "Exception loading Local Data file", fileContent: "", exception: e as Exception, log: log);
    }
  }
}

class FileDataPrefix {
  final bool hasData;
  final int timeStamp;
  final int startPos;
  final bool encrypted;
  FileDataPrefix(this.hasData, this.timeStamp, this.startPos, this.encrypted);

  factory FileDataPrefix.fromString(String s) {
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
        return FileDataPrefix(true, ts, p1 + 1, enc);
      } catch (e) {
        return FileDataPrefix.empty();
      }
    }
    return FileDataPrefix.empty();
  }

  factory FileDataPrefix.empty() {
    return FileDataPrefix(false, -1, 0, false);
  }

  bool isLaterThan(FileDataPrefix other) {
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
