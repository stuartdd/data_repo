import "path.dart";
import 'package:http/http.dart' as http;
import 'package:http_status_code/http_status_code.dart';
import 'dart:io';
import 'dart:convert';
import 'encrypt.dart';
import 'data_types.dart';

const timeStampPrefix = "TS:";
const timeStampPrefixUnEnc = "${timeStampPrefix}C:";
const timeStampPrefixEnc = "${timeStampPrefix}E:";
const codePointFor0 = 48;
const codePointFor9 = 57;
const codePointForColon = 58;

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

  DataContainer(final String fileContents, final FileDataPrefix filePrefixData, this.remoteSourcePath, this.localSourcePath, this.fileName, final String pw, {final Function(String)? log}) {
    password = pw;
    _timeStamp = filePrefixData.timeStamp;
    _dataMap = staticConvertStringToMap(fileContents, pw);
    warning = "";
    visitEachSubNode((key, path, value) {
      if (key.contains('.')) {
        if (warning.isEmpty) {
          warning = "Check logs for warnings!";
        }
        if (log != null) {
          log("## __ALERT__ Node:$path has a '.' in the node name");
        }
      }
    });
  }

  String get timeStampString {
    return staticTimeStampString(_timeStamp);
  }

  bool get hasPassword {
    return password.isNotEmpty;
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

  static Map<String, dynamic> staticConvertStringToMap(String jsonText, String pw) {
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

  static String staticDataToStringFormattedWithTs(Map<String, dynamic> map, final String pw, {final bool addTimeStamp = true, final bool isNew = false}) {
    String tsString = "";
    if (addTimeStamp) {
      final ts = isNew ? 0 : DateTime.timestamp().millisecondsSinceEpoch;
      tsString = "${pw.isEmpty ? timeStampPrefixUnEnc : timeStampPrefixEnc}$ts:";
    }
    if (pw.isEmpty) {
      return "$tsString${staticDataToStringFormatted(map)}";
    } else {
      return "$tsString${EncryptData.encryptAES(staticDataToStringUnFormatted(map), pw).base64}";
    }
  }

  static Future<SuccessState> sendHttpPost(final String url, final String body, {void Function(String)? log}) async {
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

  static Future<void> testHttpGet(final String url, Function(String) callMe, {String prefix = ""}) async {
    try {
      String resp = "";
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(
        const Duration(milliseconds: 1000),
        onTimeout: () {
          return http.Response('${prefix}Timeout:', StatusCode.REQUEST_TIMEOUT);
        },
      );
      if (response.statusCode != StatusCode.OK) {
        callMe("${prefix}Status:${response.statusCode} ${getStatusMessage(response.statusCode)}");
        return;
      }
      callMe(resp);
    } catch (e) {
      callMe("$prefix$e");
    }
  }

  static Future<SuccessState> receiveHttpGet(final String url, {final void Function(String)? log, final int timeoutMillis = 2000, final String prefix = ""}) async {
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
        return SuccessState(true, path: url, value: body.substring(prefix.length), message: "Remote Data loaded OK", log: log);
      }
      final body100 = body.length > 100 ? body.substring(0, 100).toLowerCase() : body;
      if (body100.contains("<html>") || body100.contains("<!DOCTYPE")) {
        return SuccessState(false, path: url, message: "Remote Data Load contains html:", log: log);
      }
      if (body.startsWith('{') || body.startsWith('[') || body.startsWith(timeStampPrefix)) {
        return SuccessState(true, path: url, value: body, message: "Remote Data loaded OK", log: log);
      }
      return SuccessState(false, path: url, message: "Remote Data Load was not JSON:", log: log);
    } catch (e) {
      return SuccessState(false, path: url, message: "Remote Data Load:", exception: e as Exception, log: log);
    }
  }

  static SuccessState saveToFile(final String fileName, final String contents, {final void Function(String)? log}) {
    try {
      File(fileName).writeAsStringSync(contents);
      return SuccessState(true, path: fileName, message: "Data Saved OK", log: log);
    } catch (e, s) {
      stderr.write("DataLoad:saveToFile: $e\n$s");
      return SuccessState(false, path: fileName, message: e.toString(), exception: e as Exception, log: log);
    }
  }

  static SuccessState loadFromFile(String fileName, {void Function(String)? log}) {
    try {
      final contents = File(fileName).readAsStringSync();
      return SuccessState(true, path: fileName, value: contents, message: "Local Data loaded OK", log: log);
    } catch (e) {
      if (e is PathNotFoundException) {
        return SuccessState(false, path: fileName, message: "Local Data file not found", value: "", exception: e, log: log);
      }
      return SuccessState(false, path: fileName, message: "Exception loading Local Data file", value: "", exception: e as Exception, log: log);
    }
  }
}

class FileDataPrefix {
  final bool hasData;
  final bool error;
  final String errorReason;
  final int timeStamp;
  final int startPos;
  final bool encrypted;
  final String content;
  final String tag;
  FileDataPrefix(this.hasData, this.timeStamp, this.startPos, this.encrypted, this.error, this.errorReason, this.content, this.tag);

  @override
  String toString() {
    return "$hasData:$timeStamp:$startPos:$encrypted:$error${errorReason.isEmpty ? "" : ":"}$errorReason${tag.isEmpty ? "" : ":"}$tag";
  }

  String get timeStampString {
    return staticTimeStampString(timeStamp);
  }

  factory FileDataPrefix.fromFileContent(final String content, final String tag, {Function(String log)? log}) {
    bool hasTimeStampPrefix = false;
    bool enc = false;
    int pos = 0;
    int ts = 0;

    if (content.isEmpty) {
      return FileDataPrefix.error("No content", log: log);
    }

    if (content.startsWith(timeStampPrefixUnEnc)) {
      hasTimeStampPrefix = true;
      enc = false;
      pos = timeStampPrefixUnEnc.length;
    } else {
      if (content.startsWith(timeStampPrefixEnc)) {
        hasTimeStampPrefix = true;
        enc = true;
        pos = timeStampPrefixEnc.length;
      }
    }

    if (hasTimeStampPrefix) {
      final sb = StringBuffer();
      if (pos >= content.length) {
        return FileDataPrefix.error("No Timestamp data", log: log);
      }
      var p1 = pos;
      var cp = content.codeUnits[p1];
      while (cp >= codePointFor0 && cp <= codePointFor9) {
        sb.writeCharCode(cp);
        p1++;
        if (p1 >= content.length) {
          return FileDataPrefix.error("No data after Timestamp", log: log);
        }
        cp = content.codeUnits[p1];
        if (cp == codePointForColon) {
          p1++;
          break;
        }
      }
      try {
        if (p1 >= content.length) {
          return FileDataPrefix.error("No content", log: log);
        }
        ts = int.parse(sb.toString());
        if (log != null) {
          log("__FILE_DATA:__ Valid TS: $tag timestamp ${staticTimeStampString(ts)}");
        }
        return FileDataPrefix(true, ts, p1, enc, false, "", content.substring(p1), tag);
      } catch (e) {
        return FileDataPrefix.error("Invalid Timestamp", log: log);
      }
    }
    return FileDataPrefix.noTimestampPrefix(content, tag, log: log);
  }

  factory FileDataPrefix.empty() {
    return FileDataPrefix(false, 0, 0, false, false, "", "", "empty");
  }

  factory FileDataPrefix.noTimestampPrefix(final String content, final String tag, {Function(String log)? log}) {
    if (log != null) {
      log("__FILE_DATA:__ Warning: $tag data dose not have a timestamp");
    }
    return FileDataPrefix(false, 0, 0, false, false, "", content, tag);
  }

  factory FileDataPrefix.error(final String reason, {Function(String log)? log}) {
    if (log != null) {
      log("__FILE_DATA:__ Error: $reason");
    }
    return FileDataPrefix(false, 0, 0, false, true, reason, "", "");
  }

  FileDataPrefix selectThisOrThat(FileDataPrefix other, {Function(String log)? log}) {
    // return the one that is NOT in error.
    if (error && other.error) {
      if (log != null) {
        log("__FILE_DATA:__ Error: Cannot select file data");
      }
      return FileDataPrefix.error("Cannot select file data");
    }
    if (other.error) {
      if (log != null) {
        log("__FILE_DATA:__ Selecting: $tag");
      }
      return this;
    }
    if (error) {
      if (log != null) {
        log("__FILE_DATA:__ Selecting: ${other.tag}");
      }
      return other;
    }

    // If they are equal return either!
    if (isEqual(other)) {
      if (log != null) {
        log("__FILE_DATA:__ Timestamps are the same, Selecting ${other.tag}");
      }
      return other;
    }
    // Return the one with the latest timestamp
    if (timeStamp > other.timeStamp) {
      if (log != null) {
        log("__FILE_DATA:__ Selecting later $tag");
      }
      return this;
    }
    if (log != null) {
      log("__FILE_DATA:__ Selecting later ${other.tag}");
    }
    return other;
  }

  bool isEqual(FileDataPrefix other) {
    return timeStamp == other.timeStamp;
  }

  bool isNotEqual(FileDataPrefix other) {
    return timeStamp != other.timeStamp;
  }
}

class DataContainerException implements Exception {
  final String message;
  DataContainerException(this.message);
  @override
  String toString() {
    return "DataContainerException: $message";
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

String staticTimeStampString(final int ts) {
  if (ts <= 0) {
    return "None";
  }
  return DateTime.fromMillisecondsSinceEpoch(ts).toString();
}
