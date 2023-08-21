import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

const double _divScale = 1000;
const _desktopDefault = ApplicationScreen(100, 100, 500, 500, 400, true, isDefault: true);
const _mobileDefault = ApplicationScreen(0, 0, -1, -1, 400, false, isDefault: true);

class ApplicationScreen {
  final int x;
  final int y;
  final int w;
  final int h;
  final int _div;
  final bool isDefault;
  final bool isDesktop;

  static int _convertDiv(double div) {
    return (div * _divScale).round();
  }

  const ApplicationScreen(this.x, this.y, this.w, this.h, this._div, this.isDesktop, {this.isDefault = false});

  factory ApplicationScreen.empty(bool isDesktop) {
    if (isDesktop) {
      return _desktopDefault;
    }
    return _mobileDefault;
  }

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

  factory ApplicationScreen.fromJson(final dynamic map, bool isDesktop, void Function(String) log) {
    try {
      return ApplicationScreen(map['x'] as int, map['y'] as int, map['w'] as int, map['h'] as int, map['divPos'] as int, isDesktop);
    } catch (e) {
      log("__APP STATE:__ Failed to parse Application State 'screen' json");
      return ApplicationScreen.empty(isDesktop);
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

  void writeAppStateConfigFile() {
    _shouldWriteFile = false;
    File(_appStateConfigFileName).writeAsStringSync(toString());
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

  String activeAppStateFileName() {
    if (File(_appStateConfigFileName).existsSync()) {
      return  _appStateConfigFileName;
    }
    return "";
  }

  bool deleteAppStateConfigFile() {
    File(_appStateConfigFileName).deleteSync();
    return activeAppStateFileName().isEmpty;
  }

  static ApplicationState readAppStateConfigFile(final String appStateConfigFileName, final Function(String) log)  {
    final bool isDesktop = ApplicationState.appIsDesktop();
    late final String content;
    try {
      content = File(appStateConfigFileName).readAsStringSync();
      log("__APP STATE:__ Read from $appStateConfigFileName");
      final json = jsonDecode(content);
      log("__APP STATE__ Parsed OK");
      return ApplicationState.fromJson(json, appStateConfigFileName, isDesktop, log);
    } catch (e) {
      if (e is PathNotFoundException) {
        log("__APP STATE:__ ${isDesktop ? "Desktop" : "Mobile"} File Not Found $appStateConfigFileName");
      } else {
        log("__APP STATE EXCEPTION:__ ${isDesktop ? 'Desktop' : 'Mobile'} File $appStateConfigFileName ignored");
        log("__E:__ $e");
      }
      log("__APP STATE:__ Using default  ${isDesktop ? "Desktop" : "Mobile"} State");
      return ApplicationState(ApplicationScreen.empty(isDesktop), [], appStateConfigFileName, log);
    }
  }

  factory ApplicationState.fromJson(final dynamic map, final String fileName, final bool isDesktop, final Function(String) log) {
    dynamic lastFineMap = map["lastFind"];
    final List<String> lastFindList = List.empty(growable: true);
    if (lastFineMap != null) {
      lastFineMap.forEach((v) {
        lastFindList.add(v.toString());
      });
    } else {
      log("__APP STATE:__ Failed to find Application State 'lastFind' json");
    }
    dynamic applicationScreenMap = map['screen'];
    final ApplicationScreen applicationScreen;
    if (applicationScreenMap == null) {
      log("__APP STATE:__ Failed to find Application State 'screen' json");
      applicationScreen = ApplicationScreen.empty(isDesktop);
    } else {
      applicationScreen = ApplicationScreen.fromJson(applicationScreenMap, isDesktop, log);
    }
    if (applicationScreen.isDefault) {
      log("__APP STATE:__ Using default ${isDesktop ? "Desktop" : "Mobile"} Screen");
    }
    return ApplicationState(applicationScreen, lastFindList, fileName, log);
  }

  set screenNotMaximised(bool notMax) {
    _screenNotMaximised = notMax;
  }

  void updateDividerPosState(final double d) {
    if (screen.divIsNotEqual(d)) {
      _shouldWriteFile = true;
      screen = ApplicationScreen(screen.x, screen.y, screen.w, screen.h, ApplicationScreen._convertDiv(d), screen.isDesktop, isDefault: false);
    }
  }

  void updateScreenPos(final double x, y, w, h) {
    if (_screenNotMaximised && appIsDesktop() && screen.posIsNotEqual(x, y, w, h)) {
      screen = ApplicationScreen(x.round(), y.round(), w.round(), h.round(), screen._div, screen.isDesktop, isDefault: false);
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
}
