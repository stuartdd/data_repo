import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'data_load.dart';
import 'path.dart';
import 'dart:io';

const defaultConfig = """  {
        "application" : {
            "title": "Data Repository",
            "colours": {
                "primary": "blue"
            }
        },
        "user" : {
            "name" : "Stuart",
            "id" : "Stuart",
            "appStatePath": "test",
            "appStateFile": "appState.json"
        },
        "file": {
            "backupfile": {
                "path": "test",
                "sep": "/",
                "pre": "mydb-",
                "mask": "%d-%h%m",
                "post": ".data",
                "max": 10
            },
            "postDataUrl": "http://192.168.1.243:8080/files/user/stuart/loc/mydb/name",
            "getDataUrl": "http://192.168.1.243:8080/files/user/stuart/loc/mydb/name",
            "datafile": "data03.json",
            "datafilePath": "test/data"
        }
    }""";

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
    return isHiLight ? hiLight : primary;
  }
}

class ConfigData {
  final String _configFileName;
  final String _defaultPath;
  final bool _isDesktop;
  final Function(String) log;
  late final String _getDataFileUrl;
  late final String _dataFileName;
  late final String _dataFilePath;
  late final String _appStatePath;
  late final String _appStateFileName;
  late final String _title;
  late final String _userName;
  late final String _userId;
  late final AppColours _appColours;

  ConfigData(this._defaultPath, this._configFileName, this._isDesktop, this.log) {
    final fullName = _pathFromStrings(_defaultPath, _configFileName);
    var resp = DataLoad.loadFromFile(fullName);
    if (resp.hasException) {
      if (resp.exception is PathNotFoundException) {
        resp = SuccessState(true, message: "", value: defaultConfig);
        log("__WARNING:__ Config not found. Using default config");
      } else {
        log("__EXCEPTION:__ ${resp.exception.toString()}");
        throw resp.exception as Object;
      }
    } else {
      log("__CONFIG:__ Loaded: $fullName");
    }
    final json = DataLoad.jsonFromString(resp.value);
    _getDataFileUrl = DataLoad.stringFromJson(json, Path.fromList(["file", "getDataUrl"]));
    _dataFileName = DataLoad.stringFromJson(json, Path.fromList(["file", "datafile"]));
    _dataFilePath = DataLoad.stringFromJson(json, Path.fromList(["file", "datafilePath"]), fallback: "");
    _appStateFileName = DataLoad.stringFromJson(json, Path.fromList(["user", "appStateFile"]));
    _appStatePath = DataLoad.stringFromJson(json, Path.fromList(["user", "appStatePath"]), fallback: "");
    _userName = DataLoad.stringFromJson(json, Path.fromList(["user", "name"]));
    _userId = DataLoad.stringFromJson(json, Path.fromList(["user", "id"]));
    _title = DataLoad.stringFromJson(json, Path.fromList(["application", "title"]));
    _appColours = AppColours(json, Path.fromList(["application", "colours"]));
    log("__CONFIG LOCAL DATA FILE:__ ${getDataFileLocal()}");
    log("__CONFIG REMOTE DATA FILE:__ ${getDataFileUrl()}");
    log("__CONFIG USER:__ ID(${getUserId()}) ${getUserName()}");
  }

  String _pathFromStrings(String path, String fileName) {
    if (path.isEmpty) {
      return fileName;
    }
    return "$path${Platform.pathSeparator}$fileName";
  }

  bool isDesktop() {
    return _isDesktop;
  }

  AppColours getAppColours() {
    return _appColours;
  }

  String getDataFileUrl() {
    return "$_getDataFileUrl/$_dataFileName";
  }

  String getDataFileLocal() {
    return _pathFromStrings(getDataFilePath(), getDataFileName());
  }

  String getAppStateFileLocal() {
    return _pathFromStrings(getAppStateFilePath(), getAppStateFileName());
  }

  String getDataFilePath() {
    if (isDesktop()) {
      return _dataFilePath;
    }
    return _defaultPath;
  }

  String getAppStateFilePath() {
    if (isDesktop()) {
      return _appStatePath;
    }
    return _defaultPath;
  }

  String getDataFileName() {
    return _dataFileName;
  }

  String getAppStateFileName() {
    return _appStateFileName;
  }

  String getTitle() {
    if (isDesktop()) {
      return "DT:$_title";
    }
    return "MO:$_title";
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
