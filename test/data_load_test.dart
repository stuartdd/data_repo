import 'package:data_repo/data_load.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_tools.dart';
import 'package:data_repo/path.dart';
import 'dart:convert' as json_tools;

void log(String text) {
  debugPrint(text);
}
void main() {
  // test('Test Fake Server', () async {
  //   final r = await DataLoad.fromHttpGet("http://localhost:3000/files/data01.json");
  //   if (r.isFail) {
  //     fail(r.exception.toString());
  //   }
  // });

  test('Test Get From Server', () async {
    await startTestServer();
    final r = await DataLoad.fromHttpGet("http://localhost:$serverPort/files/data01.json");
    if (r.isFail) {
      fail(r.exception.toString());
    }
    if (!r.value.contains("\"Stuart\": {")) {
      fail("Response does not contain \"Stuart\": {");
    }
    var f = await DataLoad.fromHttpGet("http://localhost:$serverPort/files/data0.xxx");
    if (f.isSuccess) {
      fail(r.message);
    }
    if (!f.message.contains("Status:404")) {
      fail("Message does not contain \"Status:404\"");
    }
    f = await DataLoad.fromHttpGet("http://localhost:$serverPort/files/json_test_data_empty.json");
    if (f.isSuccess) {
      fail(r.message);
    }
    f = await DataLoad.fromHttpGet("http://localhost:$serverPort/files/json_test_data.html");
    if (f.isSuccess) {
      fail(r.message);
    }
    f = await DataLoad.fromHttpGet("http://localhost:$serverPort/files/data_with_prefix.json",prefix: "ABC123.X");
    if (f.isFail) {
      fail(r.message);
    }
  });

  test('Test Get From File', () async {
    var state = DataLoad.loadFromFile("abc.txt", log: log);
    assertContainsAll(["Local Data file not found"], state.message);
    assertContainsAll(["PathNotFoundException", "No such file or directory"], state.exception.toString());
    expect(state.isSuccess, false);

    state = DataLoad.loadFromFile("test/data_load_test.dart", log: log);
    assertContainsAll(["Data loaded OK"], state.message);
    assertContainsAll(["void main()"], state.value);
    expect(state.isSuccess, true);
  });

  test('Test Find Node in Json', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").value);
      assertContainsAll(["height: 1362"], DataLoad.findLastMapNodeForPath(s, Path.fromDotPath("screen")).toString());
      assertContainsAll(["backupfile:"], DataLoad.findLastMapNodeForPath(s, Path.fromDotPath("file")).toString());
      assertContainsAll(["path: test", "pre: mydb-"], DataLoad.findLastMapNodeForPath(s, Path.fromDotPath("file.backupfile")).toString());
      assertContainsAll(["null"], DataLoad.findLastMapNodeForPath(s, Path.fromDotPath("fiole.backupfile")).toString());
      assertContainsAll(["null"], DataLoad.findLastMapNodeForPath(s, Path.fromDotPath("file.backup")).toString());
      assertContainsAll(["backupfile:"], DataLoad.findLastMapNodeForPath(s, Path.fromDotPath("file.")).toString());
      assertContainsNone(["backupfile:"], DataLoad.findLastMapNodeForPath(s, Path.fromDotPath("file.backupfile")).toString());
    } catch (e) {
      fail("threw an exception. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON String Not Found', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").value);
      expect(DataLoad.stringFromJson(s, Path.fromList(["application", "colours", "xxx"]), fallback: "green"), "green");
      expect(DataLoad.stringFromJson(s, Path.fromList(["application", "colours", "xxx"])), "green");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["stringFromJson", "Node was NOT found"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a ConfigException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON Colour', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").value);
      expect(DataLoad.stringFromJson(s, Path.fromList(["application", "colours", "primary"])), "green");
      expect(DataLoad.colorFromHexJson(s, Path.fromList(["test-data", "colourHex"])).value.toRadixString(16), "ff2196ff");
      expect(DataLoad.colorFromHexJson(s, Path.fromList(["test-data", "colourBad"])), 0);
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["[x2196f3] was NOT a Hex Colour", "Path:test-data.colourBad"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a ConfigException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON bool', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").value);
      expect(DataLoad.boolFromJson(s, Path.fromList(["log", "active"])), true);
      expect(DataLoad.numFromJson(s, Path.fromList(["log", "active"])), 0);
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["NOT a Number node: Path:log.active"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a ConfigException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON Int', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").value);
      expect(DataLoad.numFromJson(s, Path.fromList(["screen", "height"])), 1362);
      expect(DataLoad.numFromJson(s, Path.fromList(["file", "backupfile", "max"])), 10);
      expect(DataLoad.stringFromJson(s, Path.fromList(["file", "backupfile", "max"])), 10);
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["NOT a String node: Path:file.backupfile.max"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a ConfigException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON List', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").value);
      assertContainsAll(["FolderSync", "EE", "lloyds"], DataLoad.listFromJson(s, Path.fromList(["search", "lastGoodList"])).toString());
      expect(DataLoad.mapFromJson(s, Path.fromList(["search", "lastGoodList"])), "mydb-");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["NOT a Map node: Path:search.lastGoodList"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a JsonException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON Map', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").value);
      assertContainsAll(["max: 10"], DataLoad.mapFromJson(s, Path.fromList(["file", "backupfile"])).toString());
      expect(DataLoad.stringFromJson(s, Path.fromList(["file", "backupfile"])), "mydb-");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["NOT a String node: Path:file.backupfile"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a JsonException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON Config', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").value);
      expect(DataLoad.stringFromJson(s, Path.fromList(["file"])), "?");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["Node found was NOT a String node: Path:file"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a JsonException. Got $e ${e.runtimeType.toString()}");
    }
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").value);
      expect(DataLoad.stringFromJson(s, Path.fromList(["file", "backupfile", "pre"])), "mydb-");
      expect(DataLoad.stringFromJson(s, Path.fromList(["file", "backupfile"])), "?");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["Node found was NOT a String node: Path:file.backupfile"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a JsonException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON simple ', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/json_test_data_simple.json").value);
      expect(DataLoad.stringFromJson(s, Path.fromList(["name"])), "Pizza da Mario");
      expect(DataLoad.stringFromJson(s, Path.fromList(["cuisine"])), "This is valid");
      expect(DataLoad.stringFromJson(s, Path.fromList(["nome"])), "Pizza da Mario");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["String Node was NOT found: Path:nome"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a JsonException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON From File', () async {
    try {
      json_tools.jsonDecode(DataLoad.loadFromFile("test/data/json_test_data_empty.json").value);
      fail("Did not throw any Exception");
    } on FormatException catch (e) {
      assertContainsAll(["Unexpected end of input"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a FormatException. Got $e ${e.runtimeType.toString()}");
    }

    try {
      json_tools.jsonDecode(DataLoad.loadFromFile("test/data/json_test_data_invalid.json").value);
      fail("Did not throw any Exception");
    } on FormatException catch (e) {
      assertContainsAll(["Unexpected character"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a FormatException. Got $e ${e.runtimeType.toString()}");
    }

    final v =json_tools.jsonDecode(DataLoad.loadFromFile("test/data/json_test_data_simple.json").value);
    expect(v["name"], "Pizza da Mario");
    expect(v.length, 2);
  });
}
