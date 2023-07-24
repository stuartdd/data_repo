import "package:data_repo/config.dart";
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_tools.dart';
import 'dart:convert' as json_tools;
import 'package:data_repo/data_load.dart';
import 'package:data_repo/appState.dart';

void log(String text) {
 debugPrint(text);
}

void main() {


  test('Test ApplicationScreen', () async {
    ApplicationScreen as = ApplicationScreen(1, 2, 3, 4, 432);
    expect(as.posIsNotEqual(1.0, 2.0, 3.0, 4.0), false);
    expect(as.posIsNotEqual(2.0, 2.0, 3.0, 4.0), true);
    expect(as.posIsNotEqual(1.0, 1.0, 3.0, 4.0), true);
    expect(as.posIsNotEqual(1.0, 2.0, 4.0, 4.0), true);
    expect(as.posIsNotEqual(1.0, 2.0, 3.0, 3.0), true);
    expect(as.divIsNotEqual(0.432), false);
    expect(as.divIsNotEqual(0.4321), false);
    expect(as.divIsNotEqual(0.4325), true);
    expect(as.divIsNotEqual(0.0), true);
    expect(as.divIsNotEqual(0.021), true);

    expect(as.x, 1);
    expect(as.y, 2);
    expect(as.w, 3);
    expect(as.h, 4);
    expect(as.divPos, 0.432);

  });

  test('Test Write Application State', () async {
    final sc1 = ApplicationState(ApplicationScreen(10, 20, 30, 40, 400), ["Last1", "Last2", "Last3"], "test/data/as.tmp", log);
    try {
      await sc1.deleteAppStateConfigFile();
    } catch (e) {
      // Expecting exception unless test failed previously
    }
    final scStr1 = sc1.toString();
    expect(scStr1, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":400},"lastFind":["Last1","Last2","Last3"]}');
    await sc1.writeAppStateConfigFile();

    final sc2 = await ApplicationState.readAppStateConfigFile("test/data/as.tmp", log);
    final scStr2 = sc2.toString();

    expect(scStr1, scStr2);
    try {
      await sc1.deleteAppStateConfigFile();
    } catch (e) {
      // Expecting exception.
    }
  });

  test('Test Get From Server', () async {
    final cfg = ConfigData("test/data", "config.json", true, log);
    expect(cfg.toString(), "Url:http://192.168.1.1:8080/files/user/stuart/loc/mydb/name/mydb.data File:test/mydb.data");
    expect(cfg.getGetDataFileUrl(), "http://192.168.1.1:8080/files/user/stuart/loc/mydb/name/mydb.data");
    expect(cfg.getDataFileLocal(), "test/mydb.data");
    expect(cfg.getAppStateFileLocal(), "test/data/appState.json.tmp");
  });

  test('Test Screen', () async {
    final sc1 = ApplicationScreen(10, 20, 30, 40, 100);
    final scStr1 = sc1.toString();
    expect(scStr1, '{"x":10,"y":20,"w":30,"h":40,"divPos":100}');
    final map1 = json_tools.jsonDecode(scStr1);
    final sc2 = ApplicationScreen.fromJson(map1);
    final scStr2 = sc2.toString();
    expect(scStr2, '{"x":10,"y":20,"w":30,"h":40,"divPos":100}');
    try {
      final map1 = json_tools.jsonDecode('{"z":10,"y":20,"w":30,"h":40,"divPos":100}');
      ApplicationScreen.fromJson(map1);
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["Cannot create ApplicationScreen from Json"], e.toString());
    } on TestFailure catch (e) {
      fail("TestFailure $e : ${e.runtimeType.toString()}");
    } on TypeError catch (e) {
      assertContainsAll(["ype 'Null' is not a subtype of type 'int'"], e.toString());
    } catch (e) {
      fail("E $e : ${e.runtimeType.toString()}");
    }
  });

  test('Test Application State', () async {
    final sc1 = ApplicationState(ApplicationScreen(10, 20, 30, 40, 100), ["Last1", "Last2", "Last3"], "test/data/as.tmp", log);
    final scStr1 = sc1.toString();
    expect(scStr1, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"lastFind":["Last1","Last2","Last3"]}');
    final map1 = json_tools.jsonDecode(scStr1);
    final sc2 = ApplicationState.fromJson(map1, "test/data/as.tmp", true, log);
    final scStr2 = sc2.toString();
    expect(scStr2, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"lastFind":["Last1","Last2","Last3"]}');
    try {
      final map1 = json_tools.jsonDecode('{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"lasFind":["Last1","Last2","Last3"]}');
      ApplicationState.fromJson(map1, "test/data/as.tmp", true, log);
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["Cannot locate 'lastFind'"], e.toString());
    } on TestFailure catch (e) {
      fail("TestFailure $e : ${e.runtimeType.toString()}");
    } on TypeError catch (e) {
      assertContainsAll(["is not a subtype of type 'List<String>'"], e.toString());
    } catch (e) {
      fail("E $e : ${e.runtimeType.toString()}");
    }

    try {
      final map1 = json_tools.jsonDecode('{"screens":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"lastFind":["Last1","Last2","Last3"]}');
      ApplicationState.fromJson(map1, "test/data/as.tmp", true, log);
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["Cannot locate 'screen'"], e.toString());
    } on TestFailure catch (e) {
      fail("TestFailure $e : ${e.runtimeType.toString()}");
    } on TypeError catch (e) {
      assertContainsAll(["is not a subtype of type 'List<String>'"], e.toString());
    } catch (e) {
      fail("E $e : ${e.runtimeType.toString()}");
    }

    try {
      final map1 = json_tools.jsonDecode('{"screen":{"x":10,"y":20,"w":30,"h":40,"xxx":100},"lastFind":["Last1","Last2","Last3"]}');
      ApplicationState.fromJson(map1, "test/data/as.tmp", true, log);
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["Cannot create ApplicationScreen"], e.toString());
    } on TestFailure catch (e) {
      fail("TestFailure $e : ${e.runtimeType.toString()}");
    } on TypeError catch (e) {
      assertContainsAll(["is not a subtype of type 'List<String>'"], e.toString());
    } catch (e) {
      fail("E $e : ${e.runtimeType.toString()}");
    }
  });
}
