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
import 'package:flutter/cupertino.dart';

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

class DataContainerException implements Exception {
  final String message;
  DataContainerException(this.message);
  @override
  String toString() {
    return "DataContainerException: $message";
  }
}

class DataContainer {
  final String remoteSourcePath;
  final String localSourcePath;
  final String fileName;
  final bool Function()? canSaveAlt;
  late final int _timeStamp;
  late final Map<String, dynamic> _dataMap;
  String password = "";
  String warning = "";

  factory DataContainer.empty() {
    return DataContainer("", FileDataPrefix.empty(), "", "", "", null, "");
  }

  factory DataContainer.fromJson(final String json, {final Function(String)? log}) {
    return DataContainer(json, FileDataPrefix.empty(), "", "", "", null, "", log: log);
  }

  DataContainer(final String fileContents, final FileDataPrefix filePrefixData, this.remoteSourcePath, this.localSourcePath, this.fileName, this.canSaveAlt, final String pw, {final Function(String)? log}) {
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

  bool canSaveAltFile() {
    if (canSaveAlt != null) {
      return canSaveAlt!();
    }
    return true;
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

  dynamic getNodeFromJson(final Path path, {final String sub = ""}) {
    if (path.isEmpty) {
      throw JsonException(message: "getNodeFromJson: Empty Path", path);
    }
    dynamic node = _dataMap;
    for (var i = 0; i < path.length; i++) {
      final name = path.peek(i);
      if (name == Path.substituteElement && sub.isNotEmpty) {
        node = node[sub];
      } else {
        node = node[name];
      }
      if (node == null) {
        return null;
      }
      if (i == (path.length - 1)) {
        return node;
      }
      if (node is! Map) {
        return null;
      }
    }
    return null;
  }

  String getStringFromJsonOptional(final Path path, {final String sub1 = "", final String sub2 = ""}) {
    var node = getNodeFromJson(path, sub: sub1);
    if (node == null) {
      if (sub2.isNotEmpty) {
        node = getNodeFromJson(path, sub: sub2);
      }
    }
    if (node == null) {
      return "";
    }
    return node.toString();
  }

  String getStringFromJson(final Path path, {final String fallback = "", final String sub1 = "", final String sub2 = ""}) {
    var node = getNodeFromJson(path, sub: sub1);
    if (node == null) {
      if (sub2.isNotEmpty) {
        node = getNodeFromJson(path, sub: sub2);
      }
      if (node == null) {
        if (fallback.isNotEmpty) {
          return fallback;
        }
        throw JsonException(message: "getStringFromJson: Node was NOT found", path.cloneSub(sub2));
      }
    }
    if (node is String) {
      return node;
    }
    throw JsonException(message: "getStringFromJson: Node found was NOT a String node", path.cloneSub(sub2));
  }

  num getNumFromJson(final Path path, {final num? fallback, final String sub1 = "", final String sub2 = ""}) {
    var node = getNodeFromJson(path, sub: sub1);
    if (node == null) {
      if (sub2.isNotEmpty) {
        node = getNodeFromJson(path, sub: sub2);
      }
      if (node == null) {
        if (fallback != null) {
          return fallback;
        }
        throw JsonException(message: "getNumFromJson: Node was NOT found", path.cloneSub(sub2));
      }
    }
    if (node is num) {
      return node;
    }
    throw JsonException(message: "getNumFromJson: Node found [$node] was NOT a Number node", path.cloneSub(sub2));
  }

  bool getBoolFromJson(final Path path, {final bool? fallback, final String sub1 = "", final String sub2 = ""}) {
    var node = getNodeFromJson(path, sub: sub1);
    if (node == null) {
      if (sub2.isNotEmpty) {
        node = getNodeFromJson(path, sub: sub2);
      }
      if (node == null) {
        if (fallback != null) {
          return fallback;
        }
        throw JsonException(message: "getBoolFromJson: Node was NOT found", path.cloneSub(sub2));
      }
    }
    if (node is bool) {
      return node;
    }
    throw JsonException(message: "geBoolFromJson: Node found [$node] was NOT a bool node", path.cloneSub(sub2));
  }

  Map<String, dynamic> getMapFromJson(final Path path, {final String sub1 = "", final String sub2 = ""}) {
    var node = getNodeFromJson(path, sub: sub1);
    if (node == null) {
      if (sub2.isNotEmpty) {
        node = getNodeFromJson(path, sub: sub2);
      }
      if (node == null) {
        throw JsonException(message: "getMapFromJson: Node was NOT found", path.cloneSub(sub2));
      }
    }
    if (node is Map<String, dynamic>) {
      return node;
    }
    throw JsonException(message: "getMapFromJson: Node found was NOT a Map node", path.cloneSub(sub2));
  }

  String setValueForJsonPath(final Path path, final dynamic value) {
    if (path.isEmpty) {
      return "Path is empty";
    }
    debugPrint("setValueForJsonPath $path --> $value");
    dynamic node = _dataMap;
    dynamic parent = _dataMap;
    if (parent is! Map) {
      throw JsonException(path, message: "Root Node '${path.peek(0)}' (not a Map). Cannot create");
    }
    for (int i = 0; i < path.length; i++) {
      final name = path.peek(i);
      parent = node;
      if (parent is! Map) {
        throw JsonException(path, message: "Existing Node '${path.peek(i - 1)}' (not a Map). Cannot create");
      }
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
  static void staticVisitEachList(List<dynamic> list, Path p, final void Function(String, Path, dynamic) func) {
    for (var index = 0; index < list.length; index++) {
      final item = list[index];
      final pp = p.cloneAppend("$index");
      if (item is Map<String, dynamic>) {
        func("$index", pp, item);
        staticVisitEachSubNode(item, pp, func);
      } else {
        if (item is List<dynamic>) {
          for (var item in item) {
            staticVisitEachList(item, pp, func);
          }
        } else {
          func("$index", pp, item);
        }
      }
    }
  }

  static void staticVisitEachSubNode(Map<String, dynamic> map, Path p, final void Function(String, Path, dynamic) func) {
    for (var key in map.keys) {
      final me = map[key];
      final pp = p.cloneAppend(key);
      if (me is Map<String, dynamic>) {
        func(key, pp, me);
        staticVisitEachSubNode(me, pp, func);
      } else {
        if (me is List<dynamic>) {
          staticVisitEachList(me, pp, func);
        } else {
          func(key, pp, me);
        }
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

  /*
  Return the map as a String (or encrypted String if pw provided) with a Prefix timestamp.
  */
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
    debugPrint("POST:$url");
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
    debugPrint("TEST:$url");
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

  static Future<SuccessState> listHttpGet(final String url, {final void Function(String)? log, final void Function(String)? onFind, final int timeoutMillis = 2000, final String prefix = ""}) async {
    debugPrint("LIST:$url");
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
      final body100 = body.length > 100 ? body.substring(0, 100).toLowerCase() : body.toLowerCase();
      if (body100.contains("<html>") || body100.contains("<!doctype")) {
        return SuccessState(false, path: url, message: "Remote Data Load contains html:", log: log);
      }
      if (body.startsWith('{') || body.startsWith('[')) {
        final data = DataContainer.fromJson(body, log: log);
        data.visitEachSubNode((name, path, node) {
          if (path.length == 4 && path.peek(0) == "files" && path.toString().endsWith("name.name") && node is String) {
            if (onFind != null) {
              onFind(node.toString());
            }
          }
        });
        return SuccessState(true, path: url, value: body, message: "Remote Data loaded OK", log: log);
      }
      return SuccessState(false, path: url, message: "Remote Data Load was not JSON:", log: log);
    } catch (e) {
      return SuccessState(false, path: url, message: "Remote Data Load:", exception: e as Exception, log: log);
    }
  }

  static Future<SuccessState> receiveHttpGet(final String url, {final void Function(String)? log, final int timeoutMillis = 2000, final String prefix = ""}) async {
    debugPrint("GET:$url");
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
      final body100 = body.length > 100 ? body.substring(0, 100).toLowerCase() : body.toLowerCase();
      if (body100.contains("<html>") || body100.contains("<!doctype")) {
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

  static SuccessState saveToFile(final String fullFilePath, final String contents, {final bool noClobber = false, final void Function(String)? log}) {
    try {
      if (noClobber && File(fullFilePath).existsSync()) {
        return SuccessState(false, path: fullFilePath, message: "File already exists", log: log);
      }
      File(fullFilePath).writeAsStringSync(contents);
      return SuccessState(true, path: fullFilePath, message: "Data Saved OK", log: log);
    } catch (e, s) {
      stderr.write("DataLoad:saveToFile: $e\n$s");
      return SuccessState(false, path: fullFilePath, message: e.toString(), exception: e as Exception, log: log);
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

  FileDataPrefix selectWithNoErrorOrLatest(FileDataPrefix other, {Function(String log)? log}) {
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

String staticTimeStampString(final int ts) {
  if (ts <= 0) {
    return "None";
  }
  return DateTime.fromMillisecondsSinceEpoch(ts).toString();
}
