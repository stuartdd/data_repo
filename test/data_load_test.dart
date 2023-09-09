import 'package:data_repo/data_container.dart';
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
  //   final r = await DataContainer.fromHttpGet("http://localhost:3000/files/data01.json");
  //   if (r.isFail) {
  //     fail(r.exception.toString());
  //   }
  // });
  test('Visit each node', () async {
    final data = DataContainer(DataContainer.loadFromFile("test/data/config.json").fileContent, FileDataPrefix.empty(), "", "", "", "");
    Path p = Path.empty();
    data.visitEachSubNode((k, p, v) {
      if (k.contains('.')) {
        debugPrint("ERR[$k]: path:$p");
      } else {
        if (v is Map) {
          debugPrint("MAP[$k]: path:$p");
        } else {
          debugPrint("VAL[$k]: val:$v path:$p");
        }
      }
    });
  });


    test('Test Set Node', () async {
    final appTitle = Path.fromDotPath("application.title");
    final appAdd1 = Path.fromDotPath("application.added1");
    final appAdd2 = Path.fromDotPath("application.added2.add");
    final appAdd3 = Path.fromDotPath("application.added2.add3");
    final data = DataContainer(DataContainer.loadFromFile("test/data/config.json").fileContent, FileDataPrefix.empty(), "", "", "", "");

    expect(data.setValueForJsonPath(Path.empty(), "abc"), "Path is empty");
    expect(data.getStringFromJson(appTitle), "Data Repository");
    expect(data.setValueForJsonPath(appTitle, "title"), "");
    expect(data.getStringFromJson(appTitle), "title");

    expect(data.setValueForJsonPath(appAdd1, "appAdd1"), "");
    expect(data.getStringFromJson(appTitle), "title");
    expect(data.getStringFromJson(appAdd1), "appAdd1");

    expect(data.setValueForJsonPath(appAdd2, "appAdd2add"), "");
    expect(data.getStringFromJson(appTitle), "title");
    expect(data.getStringFromJson(appAdd1), "appAdd1");
    expect(data.getStringFromJson(appAdd2), "appAdd2add");

    expect(data.setValueForJsonPath(appAdd2, "appAdd2add"), "");
    expect(data.getStringFromJson(appTitle), "title");
    expect(data.getStringFromJson(appAdd1), "appAdd1");
    expect(data.getStringFromJson(appAdd2), "appAdd2add");

    expect(data.setValueForJsonPath(appAdd3, true), "");
    expect(data.getBoolFromJson(appAdd3), true);
    expect(data.getStringFromJson(appTitle), "title");
    expect(data.getStringFromJson(appAdd1), "appAdd1");
    expect(data.getStringFromJson(appAdd2), "appAdd2add");
    expect(data.setValueForJsonPath(appAdd3, false), "");
    expect(data.getBoolFromJson(appAdd3), false);
    expect(data.setValueForJsonPath(appAdd3, 99), "");
    expect(data.getNumFromJson(appAdd3), 99);
    expect(data.setValueForJsonPath(appAdd3, 99.9), "");
    expect(data.getNumFromJson(appAdd3), 99.9);
    expect(data.setValueForJsonPath(appAdd3, "String"), "");
    expect(data.getStringFromJson(appAdd3), "String");
  });

  test('Test Get From Server', () async {
    await startTestServer();
    final r = await DataContainer.fromHttpGet("http://localhost:$serverPort/files/data01.json");
    if (r.isFail) {
      fail(r.exception.toString());
    }
    if (!r.fileContent.contains("\"Stuart\": {")) {
      fail("Response does not contain \"Stuart\": {");
    }
    var f = await DataContainer.fromHttpGet("http://localhost:$serverPort/files/data0.xxx");
    if (f.isSuccess) {
      fail(r.message);
    }
    if (!f.message.contains("Status:404")) {
      fail("Message does not contain \"Status:404\"");
    }
    f = await DataContainer.fromHttpGet("http://localhost:$serverPort/files/json_test_data_empty.json");
    if (f.isSuccess) {
      fail(r.message);
    }
    f = await DataContainer.fromHttpGet("http://localhost:$serverPort/files/json_test_data.html");
    if (f.isSuccess) {
      fail(r.message);
    }
    f = await DataContainer.fromHttpGet("http://localhost:$serverPort/files/data_with_prefix.json", prefix: "ABC123.X");
    if (f.isFail) {
      fail(r.message);
    }
  });

  test('Test Get From File', () async {
    var state = DataContainer.loadFromFile("abc.txt", log: log);
    assertContainsAll(["Local Data file not found"], state.message);
    assertContainsAll(["PathNotFoundException", "No such file or directory"], state.exception.toString());
    expect(state.isSuccess, false);

    state = DataContainer.loadFromFile("test/data_load_test.dart", log: log);
    assertContainsAll(["Data loaded OK"], state.message);
    assertContainsAll(["void main()"], state.fileContent);
    expect(state.isSuccess, true);
  });

  test('Test Find Node in Json', () async {
    try {
      final data = DataContainer(DataContainer.loadFromFile("test/data/config.json").fileContent, FileDataPrefix.empty(), "", "", "", "");
      assertContainsAll(["height: 1362"], data.getNodeFromJson(Path.fromDotPath("screen")).toString());
      assertContainsAll(["backupfile:"], data.getNodeFromJson(Path.fromDotPath("file")).toString());
      assertContainsAll(["path: test", "pre: mydb-"], data.getNodeFromJson(Path.fromDotPath("file.backupfile")).toString());
      assertContainsAll(["null"], data.getNodeFromJson(Path.fromDotPath("fiole.backupfile")).toString());
      assertContainsAll(["null"], data.getNodeFromJson(Path.fromDotPath("file.backup")).toString());
      assertContainsAll(["backupfile:"], data.getNodeFromJson(Path.fromDotPath("file.")).toString());
      assertContainsNone(["backupfile:"], data.getNodeFromJson(Path.fromDotPath("file.backupfile")).toString());
    } catch (e) {
      fail("threw an exception. Got $e ${e.runtimeType.toString()}");
    }
  });

  test('Test Get JSON String Not Found', () async {
    try {
      final data = DataContainer(DataContainer.loadFromFile("test/data/config.json").fileContent, FileDataPrefix.empty(), "", "", "", "");
      expect(data.getStringFromJson(Path.fromList(["application", "colours", "xxx"]), fallback: "green"), "green");
      expect(data.getStringFromJson(Path.fromList(["application", "colours", "xxx"])), "green");
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
      final data = DataContainer(DataContainer.loadFromFile("test/data/config.json").fileContent, FileDataPrefix.empty(), "", "", "", "");
      expect(data.getBoolFromJson(Path.fromList(["log", "active"])), true);
      expect(data.getNumFromJson(Path.fromList(["log", "active"])), 0);
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
      final data = DataContainer(DataContainer.loadFromFile("test/data/config.json").fileContent, FileDataPrefix.empty(), "", "", "", "");
      expect(data.getNumFromJson(Path.fromList(["screen", "height"])), 1362);
      expect(data.getNumFromJson(Path.fromList(["file", "backupfile", "max"])), 10);
      expect(data.getStringFromJson(Path.fromList(["file", "backupfile", "max"])), 10);
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
      final data = DataContainer(DataContainer.loadFromFile("test/data/config.json").fileContent, FileDataPrefix.empty(), "", "", "", "");
      assertContainsAll(["max: 10"], data.getMapFromJson(Path.fromList(["file", "backupfile"])).toString());
      expect(data.getStringFromJson(Path.fromList(["file", "backupfile"])), "mydb-");
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
      final data = DataContainer(DataContainer.loadFromFile("test/data/config.json").fileContent, FileDataPrefix.empty(), "", "", "", "");
      expect(data.getStringFromJson(Path.fromList(["file"])), "?");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["Node found was NOT a String node: Path:file"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a JsonException. Got $e ${e.runtimeType.toString()}");
    }
    try {
      final data = DataContainer(DataContainer.loadFromFile("test/data/config.json").fileContent, FileDataPrefix.empty(), "", "", "", "");
      expect(data.getStringFromJson(Path.fromList(["file", "backupfile", "pre"])), "mydb-");
      expect(data.getStringFromJson(Path.fromList(["file", "backupfile"])), "?");
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
      final data = DataContainer(DataContainer.loadFromFile("test/data/json_test_data_simple.json").fileContent, FileDataPrefix.empty(), "", "", "", "");
      expect(data.getStringFromJson(Path.fromList(["name"])), "Pizza da Mario");
      expect(data.getStringFromJson(Path.fromList(["cuisine"])), "This is valid");
      expect(data.getStringFromJson(Path.fromList(["nome"])), "Pizza da Mario");
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
      json_tools.jsonDecode(DataContainer.loadFromFile("test/data/json_test_data_empty.json").fileContent);
      fail("Did not throw any Exception");
    } on FormatException catch (e) {
      assertContainsAll(["Unexpected end of input"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a FormatException. Got $e ${e.runtimeType.toString()}");
    }

    try {
      json_tools.jsonDecode(DataContainer.loadFromFile("test/data/json_test_data_invalid.json").fileContent);
      fail("Did not throw any Exception");
    } on FormatException catch (e) {
      assertContainsAll(["Unexpected character"], e.toString());
    } on TestFailure catch (e) {
      fail("$e");
    } catch (e) {
      fail("Did not throw a FormatException. Got $e ${e.runtimeType.toString()}");
    }

    final v = json_tools.jsonDecode(DataContainer.loadFromFile("test/data/json_test_data_simple.json").fileContent);
    expect(v["name"], "Pizza da Mario");
    expect(v.length, 2);
  });
}
