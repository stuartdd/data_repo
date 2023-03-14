import "package:data_repo/config.dart";
import 'package:flutter_test/flutter_test.dart';
import 'test_tools.dart';
import 'package:data_repo/data_load.dart';

void main() {

  test('Test Write Application State', () async {
    final sc1 = ApplicationState(ApplicationScreen(10, 20, 30, 40, 100), ["Last1", "Last2", "Last3"], "test/data/as.tmp");
    try {
      await sc1.deleteFile();
    } catch (e) {
      // Expecting exception unless test failed previously
    }
    final scStr1 = sc1.toString();
    expect(scStr1, '{"screen":{"x":10.0,"y":20.0,"w":30.0,"h":40.0,"hDiv":100.0},"lastFind":["Last1","Last2","Last3"]}');
    await sc1.writeToFile(true);

    final sc2 = await ApplicationState.readFromFile("test/data/as.tmp");
    final scStr2 = sc2.toString();

    expect(scStr1, scStr2);
    try {
      await sc1.deleteFile();
    } catch (e) {
      // Expecting exception.
    }
  });

  test('Test Get From Server', () async {
    final cfg = ConfigData("test/data/config.json");
    expect(cfg.toString(), "Url:http://192.168.1.243:8080/files/user/stuart/loc/mydb/name/mydb.data File:test/mydb.data");
    expect(cfg.getDataFileUrl(), "http://192.168.1.243:8080/files/user/stuart/loc/mydb/name/mydb.data");
    expect(cfg.getDataFileLocal(), "test/mydb.data");
    expect(cfg.getStateFileLocal(), "test/data/appState.json.tmp");
  });

  test('Test Screen', () async {
    final sc1 = ApplicationScreen(10, 20, 30, 40, 100);
    final scStr1 = sc1.toString();
    expect(scStr1, '{"x":10.0,"y":20.0,"w":30.0,"h":40.0,"hDiv":100.0}');
    final map1 = DataLoad.jsonFromString(scStr1);
    final sc2 = ApplicationScreen.fromJson(map1);
    final scStr2 = sc2.toString();
    expect(scStr2, '{"x":10.0,"y":20.0,"w":30.0,"h":40.0,"hDiv":100.0}');
    try {
      final map1 = DataLoad.jsonFromString('{"z":10,"y":20,"w":30,"h":40,"hDiv":100}');
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
    final sc1 = ApplicationState(ApplicationScreen(10, 20, 30, 40, 100), ["Last1", "Last2", "Last3"], "test/data/as.tmp");
    final scStr1 = sc1.toString();
    expect(scStr1, '{"screen":{"x":10.0,"y":20.0,"w":30.0,"h":40.0,"hDiv":100.0},"lastFind":["Last1","Last2","Last3"]}');
    final map1 = DataLoad.jsonFromString(scStr1);
    final sc2 = ApplicationState.fromJson(map1, "test/data/as.tmp");
    final scStr2 = sc2.toString();
    expect(scStr2, '{"screen":{"x":10.0,"y":20.0,"w":30.0,"h":40.0,"hDiv":100.0},"lastFind":["Last1","Last2","Last3"]}');
    try {
      final map1 = DataLoad.jsonFromString('{"screen":{"x":10.0,"y":20.0,"w":30.0,"h":40.0,"hDiv":100.0},"lasFind":["Last1","Last2","Last3"]}');
      ApplicationState.fromJson(map1, "test/data/as.tmp");
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
      final map1 = DataLoad.jsonFromString('{"screens":{"x":10,"y":20,"w":30,"h":40,"hDiv":100},"lastFind":["Last1","Last2","Last3"]}');
      ApplicationState.fromJson(map1, "test/data/as.tmp");
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
      final map1 = DataLoad.jsonFromString('{"screen":{"x":10,"y":20,"w":30,"h":40,"xxx":100},"lastFind":["Last1","Last2","Last3"]}');
      ApplicationState.fromJson(map1, "test/data/as.tmp");
      fail("Did not throw any Exception");
    } on JsonException catch (e) {
      assertContainsAll(["Cannot create ApplicationScreen", "xxx: 100"], e.toString());
    } on TestFailure catch (e) {
      fail("TestFailure $e : ${e.runtimeType.toString()}");
    } on TypeError catch (e) {
      assertContainsAll(["is not a subtype of type 'List<String>'"], e.toString());
    } catch (e) {
      fail("E $e : ${e.runtimeType.toString()}");
    }
  });
}
