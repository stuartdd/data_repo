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
  test('Test Set Node', () async {
    final appTitle = Path.fromDotPath("application.title");
    final appAdd1 = Path.fromDotPath("application.added1");
    final appAdd2 = Path.fromDotPath("application.added2.add");
    final appAdd3 = Path.fromDotPath("application.added2.add3");
    var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").fileContent);
    expect(DataLoad.setValueForJsonPath(s, Path.empty(), "abc"), "Path is empty");
    expect(DataLoad.getStringFromJson(s, appTitle), "Data Repository");
    expect(DataLoad.setValueForJsonPath(s, appTitle, "title"), "");
    expect(DataLoad.getStringFromJson(s, appTitle), "title");

    expect(DataLoad.setValueForJsonPath(s, appAdd1, "appAdd1"), "");
    expect(DataLoad.getStringFromJson(s, appTitle), "title");
    expect(DataLoad.getStringFromJson(s, appAdd1), "appAdd1");

    expect(DataLoad.setValueForJsonPath(s, appAdd2, "appAdd2add"), "");
    expect(DataLoad.getStringFromJson(s, appTitle), "title");
    expect(DataLoad.getStringFromJson(s, appAdd1), "appAdd1");
    expect(DataLoad.getStringFromJson(s, appAdd2), "appAdd2add");

    expect(DataLoad.setValueForJsonPath(s, appAdd2, "appAdd2add"), "");
    expect(DataLoad.getStringFromJson(s, appTitle), "title");
    expect(DataLoad.getStringFromJson(s, appAdd1), "appAdd1");
    expect(DataLoad.getStringFromJson(s, appAdd2), "appAdd2add");

    expect(DataLoad.setValueForJsonPath(s, appAdd3, true), "");
    expect(DataLoad.getBoolFromJson(s, appAdd3), true);
    expect(DataLoad.getStringFromJson(s, appTitle), "title");
    expect(DataLoad.getStringFromJson(s, appAdd1), "appAdd1");
    expect(DataLoad.getStringFromJson(s, appAdd2), "appAdd2add");
    expect(DataLoad.setValueForJsonPath(s, appAdd3, false), "");
    expect(DataLoad.getBoolFromJson(s, appAdd3), false);
    expect(DataLoad.setValueForJsonPath(s, appAdd3, 99), "");
    expect(DataLoad.getNumFromJson(s, appAdd3), 99);
    expect(DataLoad.setValueForJsonPath(s, appAdd3, 99.9), "");
    expect(DataLoad.getNumFromJson(s, appAdd3), 99.9);
    expect(DataLoad.setValueForJsonPath(s, appAdd3, "String"), "");
    expect(DataLoad.getStringFromJson(s, appAdd3), "String");
  });

  test('Test Get From Server', () async {
    await startTestServer();
    final r = await DataLoad.fromHttpGet("http://localhost:$serverPort/files/data01.json");
    if (r.isFail) {
      fail(r.exception.toString());
    }
    if (!r.fileContent.contains("\"Stuart\": {")) {
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
    f = await DataLoad.fromHttpGet("http://localhost:$serverPort/files/data_with_prefix.json", prefix: "ABC123.X");
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
    assertContainsAll(["void main()"], state.fileContent);
    expect(state.isSuccess, true);
  });

  test('Test Find Node in Json', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").fileContent);
      assertContainsAll(["height: 1362"], DataLoad.getNodeFromJson(s, Path.fromDotPath("screen")).toString());
      assertContainsAll(["backupfile:"], DataLoad.getNodeFromJson(s, Path.fromDotPath("file")).toString());
      assertContainsAll(["path: test", "pre: mydb-"], DataLoad.getNodeFromJson(s, Path.fromDotPath("file.backupfile")).toString());
      assertContainsAll(["null"], DataLoad.getNodeFromJson(s, Path.fromDotPath("fiole.backupfile")).toString());
      assertContainsAll(["null"], DataLoad.getNodeFromJson(s, Path.fromDotPath("file.backup")).toString());
      assertContainsAll(["backupfile:"], DataLoad.getNodeFromJson(s, Path.fromDotPath("file.")).toString());
      assertContainsNone(["backupfile:"], DataLoad.getNodeFromJson(s, Path.fromDotPath("file.backupfile")).toString());
    } catch (e) {
      fail("threw an exception. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON String Not Found', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").fileContent);
      expect(DataLoad.getStringFromJson(s, Path.fromList(["application", "colours", "xxx"]), fallback: "green"), "green");
      expect(DataLoad.getStringFromJson(s, Path.fromList(["application", "colours", "xxx"])), "green");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["getStringFromJson", "Node was NOT found"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a ConfigException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON bool', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").fileContent);
      expect(DataLoad.getBoolFromJson(s, Path.fromList(["log", "active"])), true);
      expect(DataLoad.getNumFromJson(s, Path.fromList(["log", "active"])), 0);
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
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").fileContent);
      expect(DataLoad.getNumFromJson(s, Path.fromList(["screen", "height"])), 1362);
      expect(DataLoad.getNumFromJson(s, Path.fromList(["file", "backupfile", "max"])), 10);
      expect(DataLoad.getStringFromJson(s, Path.fromList(["file", "backupfile", "max"])), 10);
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["NOT a String node: Path:file.backupfile.max"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a ConfigException. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON Map', () async {
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").fileContent);
      assertContainsAll(["max: 10"], DataLoad.getMapFromJson(s, Path.fromList(["file", "backupfile"])).toString());
      expect(DataLoad.getStringFromJson(s, Path.fromList(["file", "backupfile"])), "mydb-");
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
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").fileContent);
      expect(DataLoad.getStringFromJson(s, Path.fromList(["file"])), "?");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["Node found was NOT a String node: Path:file"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a JsonException. Got $e ${e.runtimeType.toString()}");
    }
    try {
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/config.json").fileContent);
      expect(DataLoad.getStringFromJson(s, Path.fromList(["file", "backupfile", "pre"])), "mydb-");
      expect(DataLoad.getStringFromJson(s, Path.fromList(["file", "backupfile"])), "?");
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
      var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/json_test_data_simple.json").fileContent);
      expect(DataLoad.getStringFromJson(s, Path.fromList(["name"])), "Pizza da Mario");
      expect(DataLoad.getStringFromJson(s, Path.fromList(["cuisine"])), "This is valid");
      expect(DataLoad.getStringFromJson(s, Path.fromList(["nome"])), "Pizza da Mario");
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
      json_tools.jsonDecode(DataLoad.loadFromFile("test/data/json_test_data_empty.json").fileContent);
      fail("Did not throw any Exception");
    } on FormatException catch (e) {
      assertContainsAll(["Unexpected end of input"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a FormatException. Got $e ${e.runtimeType.toString()}");
    }

    try {
      json_tools.jsonDecode(DataLoad.loadFromFile("test/data/json_test_data_invalid.json").fileContent);
      fail("Did not throw any Exception");
    } on FormatException catch (e) {
      assertContainsAll(["Unexpected character"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a FormatException. Got $e ${e.runtimeType.toString()}");
    }

    final v = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/json_test_data_simple.json").fileContent);
    expect(v["name"], "Pizza da Mario");
    expect(v.length, 2);
  });
}
