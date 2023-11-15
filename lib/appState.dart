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
  // Data stored in the file
  final String _appStateConfigFileName;
  late final Timer? _countdownTimer;
  String _currentJson = "";
  List<String> _lastFind; // A new list is created when a fine is added.
  ApplicationScreen screen; // A new Screen is created each time the screen is updated.
  int _isDataSorted = 0; // State of tree and detail sort type, none asc, dec..

  // Data to manage the file.
  bool _saveScreenSizeAndPos = true; // Indicates that the state should NOT be saved (maximised or minimised)!
  final Function(String) log;

  ApplicationState._(this.screen, this._isDataSorted, this._lastFind, this._appStateConfigFileName, this.log) {
    _countdownTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final json = toString();
      if (json != _currentJson) {
        _currentJson = json;
        writeAppStateConfigFile();
      }
    });
    _currentJson = toString();
  }

  void clear(final bool isDesktop) {
    _lastFind.clear();
    _isDataSorted = 0;
    _currentJson = "";
    screen = ApplicationScreen.empty(isDesktop);
  }

  void writeAppStateConfigFile() {
    File(_appStateConfigFileName).writeAsStringSync(toString());
    debugPrint("Write state: $this");
  }

  String activeAppStateFileName() {
    if (File(_appStateConfigFileName).existsSync()) {
      return _appStateConfigFileName;
    }
    return "";
  }

  bool deleteAppStateConfigFile() {
    File(_appStateConfigFileName).deleteSync();
    return activeAppStateFileName().isEmpty;
  }

  factory ApplicationState.fromFile(final String appStateConfigFileName, final Function(String) log) {
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
      return ApplicationState._(ApplicationScreen.empty(isDesktop), 0, [], appStateConfigFileName, log);
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
    dynamic isDataSorted = map['isDataSorted'];
    if (isDataSorted is! int) {
      isDataSorted = 0;
    }
    return ApplicationState._(applicationScreen, isDataSorted, lastFindList, fileName, log);
  }

  set saveScreenSizeAndPos(bool save) {
    _saveScreenSizeAndPos = save;
  }

  void updateDividerPosState(final double d) {
    if (screen.divIsNotEqual(d)) {
      screen = ApplicationScreen(screen.x, screen.y, screen.w, screen.h, ApplicationScreen._convertDiv(d), screen.isDesktop, isDefault: false);
    }
  }

  void updateScreenPos(final double x, y, w, h) {
    if (_saveScreenSizeAndPos && appIsDesktop() && screen.posIsNotEqual(x, y, w, h)) {
      screen = ApplicationScreen(x.round(), y.round(), w.round(), h.round(), screen._div, screen.isDesktop, isDefault: false);
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
    _lastFind = newList;
  }

  List<String> getLastFindList() {
    return _lastFind;
  }

  void get flipDataSorted {
    _isDataSorted = isDataSorted + 1;
    if (_isDataSorted > 1) {
      _isDataSorted = -1;
    }
  }

  int get isDataSorted {
    return _isDataSorted;
  }

  @override
  String toString() {
    return '{"screen":$screen,"isDataSorted":$_isDataSorted,"lastFind":${jsonEncode(_lastFind)}}';
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
}
