import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'data_load.dart';
import 'path.dart';
import 'dart:io';

const Map<String, MaterialColor> _colourNames = <String, MaterialColor>{
  'red': Colors.red,
  'pink': Colors.pink,
  'purple': Colors.purple,
  'deepPurple': Colors.deepPurple,
  'indigo': Colors.indigo,
  'blue': Colors.blue,
  'lightBlue': Colors.lightBlue,
  'cyan': Colors.cyan,
  'teal': Colors.teal,
  'green': Colors.green,
  'lightGreen': Colors.lightGreen,
  'lime': Colors.lime,
  'yellow': Colors.yellow,
  'amber': Colors.amber,
  'orange': Colors.orange,
  'deepOrange': Colors.deepOrange,
  'brown': Colors.brown,
  // The grey swatch is intentionally omitted because when picking a color
  // randomly from this list to colorize an application, picking grey suddenly
  // makes the app look disabled.
  'blueGrey': Colors.blueGrey,
};

class AppColours {
  var primary = _colourNames["blue"]!;
  var secondary = _colourNames["green"]!;
  var hiLight = _colourNames["yellow"]!;
  var error = _colourNames["red"]!;

  AppColours(Map<String, dynamic> json, Path path) {
    final coloursAt = DataLoad.mapFromJson(json, path);
    StringBuffer sb = StringBuffer();
    sb.write("Invalid colours at config:application.colours: ");
    int notFoundCount = 0;
    coloursAt.forEach((n, v) {
      if (v.runtimeType == String) {
        final name = n.trim().toLowerCase();
        final value = (v.toString()).trim().toLowerCase();

        final colour = _colourNames[value];
        if (colour != null) {
          switch (name) {
            case "primary":
              primary = colour;
              break;
            case "secondary":
              secondary = colour;
              break;
            case "hilight":
              hiLight = colour;
              break;
            case "error":
              error = colour;
              break;
          }
        } else {
          notFoundCount++;
          sb.write(value);
          sb.write(", ");
        }
      }
    });
    if (notFoundCount > 0) {
      throw Exception(sb.toString());
    }
  }

  MaterialColor hiLowColor(bool isHiLight) {
    return isHiLight ? hiLight: primary;
  }
}

class ApplicationScreen {
  ApplicationScreen(this.x, this.y, this.w, this.h, this.hDiv);
  final double x;
  final double y;
  final double w;
  final double h;
  final double hDiv;

  @override
  String toString() {
    return '{"x":$x,"y":$y,"w":$w,"h":$h,"hDiv":$hDiv}';
  }

  factory ApplicationScreen.fromJson(dynamic map) {
    try {
      return ApplicationScreen(map['x'] as double, map['y'] as double, map['w'] as double, map['h'] as double, map['hDiv'] as double);
    } catch (e) {
      throw JsonException(message: "Cannot create ApplicationScreen from Json", null);
    }
  }
}

class ApplicationState {
  ApplicationState(this.screen, this._lastFind, this._fileName);
  int writeTimer = 0;
  final String _fileName;
  List<String> _lastFind;
  ApplicationScreen screen;
  Timer? countdownTimer;
  bool _shouldWriteFile = true;
  bool _shouldUpdateScreen = true;
  int settleTime = 4;

  String getFileName() {
    return _fileName;
  }

  Future<bool> writeToFile(bool now) async {
    if (now) {
      File(getFileName()).writeAsString(toString());
      return true;
    }
    countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_shouldWriteFile && settleTime <= 0) {
        _shouldWriteFile = false;
        print("Write state: $this.toString()");
        File(getFileName()).writeAsString(toString());
      }
      settleTime--;
    });
    _shouldWriteFile = true;
    return true;
  }

  Future<bool> deleteFile() async {
    await File(getFileName()).delete(recursive: false);
    return true;
  }

  static Future<ApplicationState> readFromFile(String fileName) async {
    late final String content;
    try {
      content = await File(fileName).readAsString();
    } catch (e) {
      stderr.writeln("Default App State loaded. Reason: $e");
      final appState = ApplicationState(ApplicationScreen(100, 100, 500, 500, 0.4), ["Last1", "Last2", "Last3"], fileName);
      return appState;
    }
    final json = DataLoad.jsonFromString(content);
    final appData = ApplicationState.fromJson(json, fileName);
    return appData;
  }

  bool updateScreen(double x, y, w, h) {
    if (_shouldUpdateScreen) {
      if (x == screen.x && y == screen.y && w == screen.w && h == screen.h) {
        return false;
      }
      screen = ApplicationScreen(x, y, w, h, screen.hDiv);
      return true;
    }
    return false;
  }

  void setShouldUpdateScreen(bool yes) {
    _shouldUpdateScreen = yes;
    print("Should Update $_shouldUpdateScreen");
  }

  bool updateDividerPos(double hDiv) {
    if (hDiv == screen.hDiv) {
      return false;
    }
    screen = ApplicationScreen(screen.x, screen.y, screen.w, screen.h, hDiv);
    return true;
  }

  bool isDesktop() {
    return (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }

  void addLastFind(String find, int max) {
    if (find.isEmpty) {
      return;
    }
    List<String> newList = List.empty(growable: true);
    newList.add(find);
    for (int i = 0; i < _lastFind.length; i++) {
      if (_lastFind[i] != find) {
        newList.add(_lastFind[i]);
      }
      if (newList.length >= max) {
        break;
      }
    }
    _lastFind = newList;
  }

  List<String> getLastFindList() {
    return _lastFind;
  }

  @override
  String toString() {
    return '{"screen":$screen,"lastFind":${jsonEncode(_lastFind)}}';
  }

  factory ApplicationState.fromJson(dynamic map, String fileName) {
    dynamic lf = map["lastFind"];
    if (lf == null) {
      throw JsonException(message: "Cannot locate 'lastFind' list in Json", Path.fromList(["lastFind"]));
    }
    List<String> ls = [];
    lf.forEach((v) {
      ls.add(v.toString());
    });

    dynamic ms = map['screen'];
    if (ms == null) {
      throw JsonException(message: "Cannot locate 'screen' Map in Json", Path.fromList(["screen"]));
    }
    final as = ApplicationScreen.fromJson(ms);

    return ApplicationState(as, ls, fileName);
  }
}

class ConfigData {
  final String _fileName;
  late final String _getDataFileUrl;
  late final String _dataFileName;
  late final String _dataFilePath;
  late final String _appStatePath;
  late final String _appStateFileName;
  late final String _title;
  late final String _userName;
  late final String _userId;
  late final AppColours _appColours;

  ConfigData(this._fileName) {
    final s = DataLoad.loadFromFile(_fileName);
    final json = DataLoad.jsonFromString(s.value);
    _getDataFileUrl = DataLoad.stringFromJson(json, Path.fromList(["file", "getDataUrl"]));
    _dataFileName = DataLoad.stringFromJson(json, Path.fromList(["file", "datafile"]));
    _dataFilePath = DataLoad.stringFromJson(json, Path.fromList(["file", "datafilePath"]));
    _appStatePath = DataLoad.stringFromJson(json, Path.fromList(["user", "appStatePath"]));
    _appStateFileName = DataLoad.stringFromJson(json, Path.fromList(["user", "appStateFile"]));
    _userName = DataLoad.stringFromJson(json, Path.fromList(["user", "name"]));
    _userId = DataLoad.stringFromJson(json, Path.fromList(["user", "id"]));
    _title = DataLoad.stringFromJson(json, Path.fromList(["application", "title"]));
    _appColours = AppColours(json, Path.fromList(["application", "colours"]));
  }

  AppColours getAppColours() {
    return _appColours;
  }

  String getDataFileUrl() {
    return "$_getDataFileUrl/${getDataFileName()}";
  }

  String getDataFileLocal() {
    return "$_dataFilePath${Platform.pathSeparator}${getDataFileName()}";
  }

  String getStateFileLocal() {
    return "$_appStatePath${Platform.pathSeparator}$_appStateFileName";
  }

  String getDataFilePath() {
    return _dataFilePath;
  }

  String getDataFileName() {
    return _dataFileName;
  }

  String getTitle() {
    return _title;
  }

  String getUserName() {
    return _userName;
  }

  String getUserId() {
    return _userId;
  }

  @override
  String toString() {
    return "Url:${getDataFileUrl()} File:${getDataFileLocal()}";
  }
}
