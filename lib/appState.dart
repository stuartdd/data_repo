import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'data_load.dart';
import 'path.dart';
import 'dart:io';

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

  factory ApplicationScreen.fromJson(final dynamic map) {
    try {
      return ApplicationScreen(map['x'] as double, map['y'] as double, map['w'] as double, map['h'] as double, map['hDiv'] as double);
    } catch (e) {
      throw JsonException(message: "Cannot create ApplicationScreen from Json", null);
    }
  }
}

class ApplicationState {
  ApplicationState(this.screen, this._lastFind, this._appStateConfigFileName, this.log);
  final String _appStateConfigFileName;
  final Function(String) log;
  List<String> _lastFind;
  ApplicationScreen screen;
  Timer? countdownTimer;
  bool _shouldWriteFile = true;
  bool _shouldUpdateScreen = true;
  int settleTime = 4;

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
          log("__APP STATE:__ ${isDesktop?"Desktop":"Mobile"} Default State. Not Found $appStateConfigFileName");
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
            0.4,
          ),
          ["Desktop"],
          appStateConfigFileName,
          log,
        );
      } else {
        return ApplicationState(ApplicationScreen(0, 0, -1, -1, 0.4), ["Mobile"], appStateConfigFileName, log);
      }
    }
    final json = jsonDecode(content);
    log("__APP STATE__ Parsed OK");
    return ApplicationState.fromJson(json, appStateConfigFileName, isDesktop, log);
  }

  Future<bool> writeAppStateConfigFile(final bool now) async {
    if (now) {
      File(_appStateConfigFileName).writeAsString(toString());
      return true;
    }
    countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_shouldWriteFile && settleTime <= 0) {
        _shouldWriteFile = false;
        debugPrint("Write state: $this.toString()");
        File(_appStateConfigFileName).writeAsString(toString());
      }
      settleTime--;
    });
    _shouldWriteFile = true;
    return true;
  }

  Future<bool> deleteAppStateConfigFile() async {
    await File(_appStateConfigFileName).delete(recursive: false);
    return true;
  }

  bool updateDividerPosState(final double hDiv) {
    if (hDiv == screen.hDiv) {
      return false;
    }
    screen = ApplicationScreen(screen.x, screen.y, screen.w, screen.h, hDiv);
    return true;
  }

  bool updateScreenState(final double x, y, w, h) {
    if (_shouldUpdateScreen) {
      if (x == screen.x && y == screen.y && w == screen.w && h == screen.h) {
        return false;
      }
      screen = ApplicationScreen(
        x,
        y,
        w,
        h,
        screen.hDiv,
      );
      return true;
    }
    return false;
  }

  void setShouldUpdateScreen(final bool yes) {
    _shouldUpdateScreen = yes;
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
