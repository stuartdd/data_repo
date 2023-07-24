import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'data_load.dart';
import 'path.dart';
import 'dart:io';

const double _divScale = 1000;

class ApplicationScreen {
  final int x;
  final int y;
  final int w;
  final int h;
  final int _div;

  static int _convertDiv(double div) {
    return (div * _divScale).round();
  }

  ApplicationScreen(this.x, this.y, this.w, this.h, this._div);


  @override
  String toString() {
    return '{"x":$x,"y":$y,"w":$w,"h":$h,"divPos":$_div}';
  }

  double get divPos {
    return _div.toDouble() / _divScale;
  }

  bool posIsNotEqual(double ox, oy, ow, oh) {
    return (x != ox.round() || y != oy.round() || w != ow.round() || h != oh.round());
  }

  bool divIsNotEqual(double d) {
    return (_div != _convertDiv(d));
  }

  factory ApplicationScreen.fromJson(final dynamic map) {
    try {
      return ApplicationScreen(map['x'] as int, map['y'] as int, map['w'] as int, map['h'] as int, map['divPos'] as int);
    } catch (e) {
      throw JsonException(message: "Cannot create ApplicationScreen from Json", null);
    }
  }
}

class ApplicationState {
  final String _appStateConfigFileName;
  final Function(String) log;
  late final Timer? countdownTimer;
  List<String> _lastFind; // A new list is created when a fine is added.
  ApplicationScreen screen; // A new Screen is created each time the screen is updated.
  bool _shouldWriteFile = false;
  bool _screenNotMaximised = true;

  ApplicationState(this.screen, this._lastFind, this._appStateConfigFileName, this.log) {
    countdownTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_shouldWriteFile) {
        writeAppStateConfigFile();
      }
    });
  }

  Future<void> writeAppStateConfigFile() async {
    _shouldWriteFile = false;
    File(_appStateConfigFileName).writeAsString(toString());
    debugPrint("Write state: $this");
  }
  // Called by main to locate the user file storage location
  //   On Android and IOS this is the only place we should store files.
  //   On Desktop this is the current path;
  static Future<String> getApplicationDefaultDir() async {
    if (ApplicationState.appIsDesktop()) {
      return Directory.current.path;
    }
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static bool appIsDesktop() {
    return (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }

  static Future<ApplicationState> readAppStateConfigFile(final String appStateConfigFileName, final Function(String) log) async {
    final bool isDesktop = ApplicationState.appIsDesktop();
    late final String content;
    try {
      content = await File(appStateConfigFileName).readAsString();
      log("__APP STATE:__ Read from $appStateConfigFileName");
    } catch (e) {
      if (e is PathNotFoundException) {
        log("__APP STATE:__ ${isDesktop ? "Desktop" : "Mobile"} Default State. Not Found $appStateConfigFileName");
      } else {
        log("__STATE EXCEPTION:__ $appStateConfigFileName");
        log("__E:__ $e");
      }
      if (isDesktop) {
        return ApplicationState(
          ApplicationScreen(
            100,
            100,
            500,
            500,
            400,
          ),
          [], // Last Find
          appStateConfigFileName,
          log,
        );
      } else {
        return ApplicationState(ApplicationScreen(0, 0, -1, -1, 400), [], appStateConfigFileName, log);
      }
    }
    final json = jsonDecode(content);
    log("__APP STATE__ Parsed OK");
    return ApplicationState.fromJson(json, appStateConfigFileName, isDesktop, log);
  }

  set screenNotMaximised(bool notMax) {
    _screenNotMaximised = notMax;
  }

  Future<bool> deleteAppStateConfigFile() async {
    await File(_appStateConfigFileName).delete(recursive: false);
    return true;
  }

  void updateDividerPosState(final double d) {
    if (screen.divIsNotEqual(d)) {
      _shouldWriteFile = true;
      screen = ApplicationScreen(screen.x, screen.y, screen.w, screen.h, ApplicationScreen._convertDiv(d));
    }
  }

  void updateScreenPos(final double x, y, w, h) {
    if (_screenNotMaximised && appIsDesktop() && screen.posIsNotEqual(x, y, w, h)) {
      screen = ApplicationScreen(
        x.round(),
        y.round(),
        w.round(),
        h.round(),
        screen._div,
      );
      _shouldWriteFile = true;
    }
  }

  void addLastFind(final String find, final int max) {
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
    _shouldWriteFile = true;
    _lastFind = newList;
  }

  List<String> getLastFindList() {
    return _lastFind;
  }

  @override
  String toString() {
    return '{"screen":$screen,"lastFind":${jsonEncode(_lastFind)}}';
  }

  factory ApplicationState.fromJson(final dynamic map, final String fileName, final bool isDesktop, final Function(String) log) {
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

    return ApplicationState(as, ls, fileName, log);
  }
}
