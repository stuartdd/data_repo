import "package:data_repo/config.dart";
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert' as json_tools;
import 'package:data_repo/appState.dart';

StringBuffer eventLog = StringBuffer();
void log(String text) {
  debugPrint(text);
  eventLog.write("|");
  eventLog.write(text);
  eventLog.writeln('|');
}

void main() {


  test('Test ApplicationScreen', () async {
    ApplicationScreen xx = const ApplicationScreen(1, 2, 3, 4, 432, false);
    expect(xx.isDefault, false);
    expect(xx.isDesktop, false);

    ApplicationScreen as = const ApplicationScreen(1, 2, 3, 4, 432, true, isDefault: true);
    expect(as.isDefault, true);
    expect(as.isDesktop, true);


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
    final sc1 = ApplicationState(const ApplicationScreen(10, 20, 30, 40, 400, false), 0, ["Last1", "Last2", "Last3"], "test/data/as.tmp", log);
    try {
      sc1.deleteAppStateConfigFile();
    } catch (e) {
      // Expecting exception unless test failed previously
    }
    final scStr1 = sc1.toString();
    expect(scStr1, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":400},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');
    sc1.writeAppStateConfigFile();

    final sc2 = ApplicationState.readAppStateConfigFile("test/data/as.tmp", log);
    final scStr2 = sc2.toString();

    expect(scStr1, scStr2);
    try {
      sc1.deleteAppStateConfigFile();
    } catch (e) {
      // Expecting exception.
    }
  });

  test('Test Get From Server', () async {
    final cfg = ConfigData("test/data", "config.json", true, log);
    expect(cfg.toString(), "Url:http://192.168.1.1:8080/files/user/stuart/loc/mydb/name/mydb.data File:test/mydb.data");
    expect(cfg.getGetDataFileUrl(), "http://192.168.1.1:8080/files/user/stuart/loc/mydb/name/mydb.data");
    expect(cfg.getDataFileLocal(), "test/mydb.data");
    expect(cfg.getAppStateFileLocal(), "test/appState.json");
  });

  test('Test Screen', () async {
    const sc1 = ApplicationScreen(10, 20, 30, 40, 100, true);
    final scStr1 = sc1.toString();
    expect(scStr1, '{"x":10,"y":20,"w":30,"h":40,"divPos":100}');
    final map1 = json_tools.jsonDecode(scStr1);
    final sc2 = ApplicationScreen.fromJson(map1, true, log);
    final scStr2 = sc2.toString();
    expect(scStr2, '{"x":10,"y":20,"w":30,"h":40,"divPos":100}');

    eventLog.clear();
    var as = ApplicationScreen.fromJson(json_tools.jsonDecode('{"g":10,"y":20,"w":30,"h":40,"divPos":100}'), true, log);
    expect(eventLog.toString().contains("Failed to parse Application State 'screen'"), true);
    expect(as.isDefault, true);

    eventLog.clear();
    as = ApplicationScreen.fromJson(json_tools.jsonDecode('{"x":10,"y":20,"w":30,"h":40,"xxx":100}'), true, log);
    expect(eventLog.toString().contains("Failed to parse Application State 'screen'"), true);
    expect(as.isDefault, true);

    eventLog.clear();
    as = ApplicationScreen.fromJson(json_tools.jsonDecode('{"x":10,"y":20,"w":30,"h":40,"divPos":100.9}'), true, log);
    expect(eventLog.toString().contains("Failed to parse Application State 'screen'"), true);
    expect(as.isDefault, true);
   });

  test('Test Application State', () async {
    final sc1 = ApplicationState(const ApplicationScreen(10, 20, 30, 40, 100, true), 0, ["Last1", "Last2", "Last3"], "test/data/as.tmp", log);
    final scStr1 = sc1.toString();
    expect(scStr1, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');
    final map1 = json_tools.jsonDecode(scStr1);
    final sc2 = ApplicationState.fromJson(map1, "test/data/as.tmp", true, log);
    final scStr2 = sc2.toString();
    expect(scStr2, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');

    final sc3 = ApplicationState(const ApplicationScreen(10, 20, 30, 40, 100, true), -1, ["Last1", "Last2", "Last3"], "test/data/as.tmp", log);
    final scStr3 = sc3.toString();
    expect(scStr3, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":-1,"lastFind":["Last1","Last2","Last3"]}');
    final map4 = json_tools.jsonDecode(scStr3);
    final sc4 = ApplicationState.fromJson(map4, "test/data/as.tmp", true, log);
    final scStr4 = sc4.toString();
    expect(scStr4, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":-1,"lastFind":["Last1","Last2","Last3"]}');


    eventLog.clear();
    var m1 = json_tools.jsonDecode('{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"lasFind":["Last1","Last2","Last3"]}');
    var as =  ApplicationState.fromJson(m1, "test/data/as.tmp", true, log);
    expect(eventLog.toString().contains("Failed to find Application State 'lastFind'"), true);
    expect(eventLog.toString().contains("Using default Desktop Screen"), false);
    expect(as.screen.isDefault, false);

    eventLog.clear();
    m1 = json_tools.jsonDecode('{"sceen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');
    as =  ApplicationState.fromJson(m1, "test/data/as.tmp", false, log);
    expect(eventLog.toString().contains("Failed to find Application State 'screen'"), true);
    expect(eventLog.toString().contains("Using default Mobile Screen"), true);
    expect(as.screen.isDefault, true);
    expect(as.screen.isDesktop, false);

    eventLog.clear();
    m1 = json_tools.jsonDecode('{"screen":{"x":10,"y":20,"w":30,"h":40,"xxx":100},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');
    as =  ApplicationState.fromJson(m1, "test/data/as.tmp", true, log);
    expect(eventLog.toString().contains("Failed to parse Application State 'screen'"), true);
    expect(eventLog.toString().contains("Using default Desktop Screen"), true);
    expect(as.screen.isDefault, true);
    expect(as.screen.isDesktop, true);
  });
}
