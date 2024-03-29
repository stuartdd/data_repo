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
    expect(xx.isDesktop, false);

    ApplicationScreen as = const ApplicationScreen(1, 2, 3, 4, 432, true);
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
    final sc1 = ApplicationState.fromJson(json_tools.jsonDecode('{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":400},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}'), "test/data/as.tmp", true, log);
    try {
      sc1.deleteAppStateConfigFile();
    } catch (e) {
      // Expecting exception unless test failed previously
    }
    final scStr1 = sc1.toString();
    expect(scStr1, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":400},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');
    sc1.writeAppStateConfigFile();

    final sc2 = ApplicationState.fromFile("test/data/as.tmp", log);
    final scStr2 = sc2.toString();

    expect(scStr1, scStr2);
    try {
      sc1.deleteAppStateConfigFile();
    } catch (e) {
      // Expecting exception.
    }
  });

  test('Test Get Config data', () async {
    final cfg = ConfigData("test/data", "config.json", true, log);

    expect(cfg.toString(), "Url:http://192.168.1.1:8080/files/user/mydb.xxxx File:test/data/mydb.xxxx");
    expect(cfg.getGetDataFileUrl(), "http://192.168.1.1:8080/files/user/mydb.xxxx");
    expect(cfg.getPostDataFileUrl(), "http://192.168.1.1:8080/files/user/mydb.xxxx");
    expect(cfg.getRemoteTestFileUrl(), "http://192.168.1.1:8080/files/user/remoteTestFile.rtf");
    expect(cfg.getListDataUrl(), "http://192.168.1.1:8080/files/user/list");
    expect(cfg.getDataFileLocalPath(), "test/data/mydb.xxxx");
    expect(cfg.getAppStateFileLocal(), "test/data/data_repo_appState.json");

    expect(cfg.getDataFileName(mode: FileExtensionState.asIs), "mydb.xxxx");
    expect(cfg.getDataFileName(mode: FileExtensionState.forceData), "mydb.data");
    expect(cfg.getDataFileName(mode: FileExtensionState.forceJson), "mydb.json");
    expect(cfg.getDataFileName(mode: FileExtensionState.checkPassword), "mydb.json");
    expect(cfg.getDataFileName(mode: FileExtensionState.checkPassword, pw: ""), "mydb.json");
    expect(cfg.getDataFileName(mode: FileExtensionState.checkPassword, pw: "abc"), "mydb.data");

    expect(cfg.getDataFileLocalPath(mode: FileExtensionState.asIs), "test/data/mydb.xxxx");
    expect(cfg.getDataFileLocalPath(mode: FileExtensionState.forceData), "test/data/mydb.data");
    expect(cfg.getDataFileLocalPath(mode: FileExtensionState.forceJson), "test/data/mydb.json");
    expect(cfg.getDataFileLocalPath(mode: FileExtensionState.checkPassword, pw: ""), "test/data/mydb.json");
    expect(cfg.getDataFileLocalPath(mode: FileExtensionState.checkPassword, pw: "abc"), "test/data/mydb.data");
    expect(cfg.getDataFileNameForCreate("fred.dat", "abc"), "fred.data");
    expect(cfg.getDataFileNameForCreate("fred.dat", ""), "fred.json");
    expect(cfg.getDataFileNameForCreate("fred.dat", "abc", fullPath: true), "test/data/fred.data");
    expect(cfg.getDataFileNameForCreate("fred.dat", "", fullPath: true), "test/data/fred.json");
    expect(cfg.getDataFileNameForSaveAs("abc"), "mydb.data");
    expect(cfg.getDataFileNameForSaveAs(""), "mydb.json");
    expect(cfg.getDataFileNameForSaveAs("abc", fullPath: true), "test/data/mydb.data");
    expect(cfg.getDataFileNameForSaveAs("", fullPath: true), "test/data/mydb.json");

    expect(cfg.getPostDataFileUrl(), "http://192.168.1.1:8080/files/user/mydb.xxxx");
    expect(cfg.getPostDataFileUrl(mode: FileExtensionState.asIs), "http://192.168.1.1:8080/files/user/mydb.xxxx");
    expect(cfg.getPostDataFileUrl(mode: FileExtensionState.forceData), "http://192.168.1.1:8080/files/user/mydb.data");
    expect(cfg.getPostDataFileUrl(mode: FileExtensionState.forceJson), "http://192.168.1.1:8080/files/user/mydb.json");
    expect(cfg.getPostDataFileUrl(mode: FileExtensionState.checkPassword, pw: ""), "http://192.168.1.1:8080/files/user/mydb.json");
    expect(cfg.getPostDataFileUrl(mode: FileExtensionState.checkPassword, pw: "abc"), "http://192.168.1.1:8080/files/user/mydb.data");

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

    eventLog.clear();
    as = ApplicationScreen.fromJson(json_tools.jsonDecode('{"x":10,"y":20,"w":30,"h":40,"xxx":100}'), true, log);
    expect(eventLog.toString().contains("Failed to parse Application State 'screen'"), true);

    eventLog.clear();
    as = ApplicationScreen.fromJson(json_tools.jsonDecode('{"x":10,"y":20,"w":30,"h":40,"divPos":100.9}'), true, log);
    expect(eventLog.toString().contains("Failed to parse Application State 'screen'"), true);
  });

  test('Test Application State', () async {
    final sc1 = ApplicationState.fromJson(json_tools.jsonDecode('{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}'), "", true, log);
    final scStr1 = sc1.toString();
    expect(scStr1, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');
    final map1 = json_tools.jsonDecode(scStr1);
    final sc2 = ApplicationState.fromJson(map1, "test/data/as.tmp", true, log);
    final scStr2 = sc2.toString();
    expect(scStr2, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');

    final sc3 = ApplicationState.fromJson(json_tools.jsonDecode('{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":-1,"lastFind":["Last1","Last2","Last3"]}'), "", true, log);
    final scStr3 = sc3.toString();
    expect(scStr3, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":-1,"lastFind":["Last1","Last2","Last3"]}');
    final map4 = json_tools.jsonDecode(scStr3);
    final sc4 = ApplicationState.fromJson(map4, "test/data/as.tmp", true, log);
    final scStr4 = sc4.toString();
    expect(scStr4, '{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":-1,"lastFind":["Last1","Last2","Last3"]}');

    eventLog.clear();
    var m1 = json_tools.jsonDecode('{"screen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"lasFind":["Last1","Last2","Last3"]}');
    var as = ApplicationState.fromJson(m1, "test/data/as.tmp", true, log);
    expect(eventLog.toString().contains("Failed to find Application State 'lastFind'"), true);

    eventLog.clear();
    m1 = json_tools.jsonDecode('{"sceen":{"x":10,"y":20,"w":30,"h":40,"divPos":100},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');
    as = ApplicationState.fromJson(m1, "test/data/as.tmp", false, log);
    expect(eventLog.toString().contains("Failed to find Application State 'screen'"), true);
    expect(as.screen.isDesktop, false);

    eventLog.clear();
    m1 = json_tools.jsonDecode('{"screen":{"x":10,"y":20,"w":30,"h":40,"xxx":100},"isDataSorted":0,"lastFind":["Last1","Last2","Last3"]}');
    as = ApplicationState.fromJson(m1, "test/data/as.tmp", true, log);
    expect(eventLog.toString().contains("Failed to parse Application State 'screen'"), true);
    expect(as.screen.isDesktop, true);
  });
}
