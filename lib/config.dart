import 'package:flutter/material.dart';
import 'dart:convert';
import 'data_load.dart';
import 'path.dart';
import 'data_types.dart';
import 'dart:io';

const String defaultRemoteGetUrl = "http://localhost:8080/file";
const String defaultRemotePostUrl = "http://localhost:8080/file";
const String defaultDataFileName = "data.json";
const String defaultAppStateFileName = "appState.json";
const String defaultPrimaryColour = "blue";
const String defaultSecondaryColour = "green";
const String defaultHiLightColour = "yellow";
const String defaultErrorColour = "red";
const String defaultDarkMode = "false";
const String defaultUserName = "User";
const int defaultFetchTimeoutMillis = 1000;
const String defaultDataFilePath = "";
const String defaultAppTitle = "Data Repo";
const String defaultFontFamily = "Code128";
const double defaultFontScaleDesktop = 1.0;
const double defaultFontScaleMobile = 0.8;
const double defaultTreeNodeHeight = 35.0;

const defaultConfig = """  {
        "application" : {
            "title": "Data Repository"
        },
        "file": {
            "postDataUrl": "http://10.0.2.2:3000/file",
            "getDataUrl": "http://10.0.2.2:3000/file",
            "datafile": "data.json"
        }
    } """;

final getDataUrlPath = Path.fromList(["file", "getDataUrl"]);
final postDataUrlPath = Path.fromList(["file", "postDataUrl"]);
final dataFileLocalNamePath = Path.fromList(["file", "datafile"]);
final dataFileLocalDirPath = Path.fromList(["file", "datafilePath"]);
final appStateFileNamePath = Path.fromList(["user", "appStateFile"]);
final appStateLocalDirPath = Path.fromList(["user", "appStatePath"]);
final userNamePath = Path.fromList(["user", "name"]);
final userIdPath = Path.fromList(["user", "id"]);
final titlePath = Path.fromList(["application", "title"]);
final appColoursDarkMode = Path.fromList(["application", "darkMode"]);
final appColoursPrimaryPath = Path.fromList(["application", "colours", "primary"]);
final appColoursSecondaryPath = Path.fromList(["application", "colours", "secondary"]);
final appColoursHiLightPath = Path.fromList(["application", "colours", "hilight"]);
final appColoursErrorPath = Path.fromList(["application", "colours", "error"]);
final dataFetchTimeoutMillisPath = Path.fromList(["application", "dataFetchTimeoutMillis"]);

class ColorPallet {
  final String colorName;
  final Color lightest;
  final Color light;
  final Color medLight;
  final Color med;
  final Color medDark;
  final Color dark;
  final Color darkest;

  const ColorPallet(this.colorName, this.lightest, this.light, this.medLight, this.med, this.medDark, this.dark, this.darkest);

  factory ColorPallet.fromMaterialColor(MaterialColor mc, String colorName) {
    return ColorPallet(colorName, mc.shade200, mc.shade300, mc.shade400, mc.shade500, mc.shade600, mc.shade800, mc.shade900);
  }
}

const List<IconData> defaultTreeNodeIconData = [Icons.list_sharp, Icons.arrow_downward, Icons.arrow_forward, Icons.tour_outlined];

Map<String, ColorPallet> colourNames = <String, ColorPallet>{
  'black': const ColorPallet("white", Colors.white, Colors.black12, Colors.black26, Colors.black38, Colors.black45, Colors.black54, Colors.black),
  'white': const ColorPallet("black", Colors.black, Colors.black54, Colors.black45, Colors.black38, Colors.black26, Colors.black12, Colors.white),
  'red': ColorPallet.fromMaterialColor(Colors.red, "red"),
  'pink': ColorPallet.fromMaterialColor(Colors.pink, 'pink'),
  'purple': ColorPallet.fromMaterialColor(Colors.purple, 'purple'),
  'deepPurple': ColorPallet.fromMaterialColor(Colors.deepPurple, 'deepPurple'),
  'indigo': ColorPallet.fromMaterialColor(Colors.indigo, 'indigo'),
  'blue': ColorPallet.fromMaterialColor(Colors.blue, 'blue'),
  'lightBlue': ColorPallet.fromMaterialColor(Colors.lightBlue, 'lightBlue'),
  'cyan': ColorPallet.fromMaterialColor(Colors.cyan, 'cyan'),
  'teal': ColorPallet.fromMaterialColor(Colors.teal, 'teal'),
  'green': ColorPallet.fromMaterialColor(Colors.green, 'green'),
  'lightGreen': ColorPallet.fromMaterialColor(Colors.lightGreen, 'lightGreen'),
  'lime': ColorPallet.fromMaterialColor(Colors.lime, 'lime'),
  'yellow': ColorPallet.fromMaterialColor(Colors.yellow, 'yellow'),
  'amber': ColorPallet.fromMaterialColor(Colors.amber, 'amber'),
  'orange': ColorPallet.fromMaterialColor(Colors.orange, 'orange'),
  'deepOrange': ColorPallet.fromMaterialColor(Colors.deepOrange, 'deepOrange'),
  'brown': ColorPallet.fromMaterialColor(Colors.brown, 'brown'),
  'blueGrey': ColorPallet.fromMaterialColor(Colors.blueGrey, 'blueGrey'),
};

class ColourNameException implements Exception {
  final String message;
  ColourNameException(this.message);
  @override
  String toString() {
    return "ColourNameException: $message";
  }
}

class AppThemeData {
  final ColorPallet primary;
  final ColorPallet secondary;
  final ColorPallet hiLight;
  final ColorPallet error;
  final bool darkMode;
  final bool desktop;
  late final TextStyle tsLarge;
  late final TextStyle tsLargeDisabled;
  late final TextStyle tsMedium;
  late final TextStyle tsMediumDisabled;
  late final TextStyle tsSmall;
  late final TextStyle tsSmallDisabled;
  late final TextStyle tsTreeViewLabel;
  late final TextStyle tsTreeViewParentLabel;
  late final TextStyle tsLargeError;
  late final TextStyle tsMediumError;
  late final TextStyle tsSmallError;
  late final double tsScale;
  late final double treeNodeHeight;
  late final List<Icon> treeNodeIcons;

  AppThemeData._(this.primary, this.secondary, this.hiLight, this.error, String font, double scale, Color errC, this.darkMode, this.desktop) {
    tsScale = scale;
    tsLarge = TextStyle(fontFamily: font, fontSize: (25.0 * scale), color: screenForegroundColour(true));
    tsLargeDisabled = TextStyle(fontFamily: font, fontSize: (25.0 * scale), color: screenForegroundColour(false));
    tsLargeError = TextStyle(fontFamily: font, fontSize: (25.0 * scale), color: errC);
    tsMedium = TextStyle(fontFamily: font, fontSize: (20.0 * scale), color: screenForegroundColour(true));
    tsMediumDisabled = TextStyle(fontFamily: font, fontSize: (20.0 * scale), color: screenForegroundColour(false));
    tsMediumError = TextStyle(fontFamily: font, fontSize: (20.0 * scale), color: errC);
    tsSmall = TextStyle(fontFamily: font, fontSize: (15.0 * scale), color: screenForegroundColour(true));
    tsSmallDisabled = TextStyle(fontFamily: font, fontSize: (15.0 * scale), color: screenForegroundColour(false));
    tsSmallError = TextStyle(fontFamily: font, fontSize: (15.0 * scale), color: errC);
    tsTreeViewLabel = TextStyle(fontFamily: font, fontSize: (20.0 * scale), color: screenForegroundColour(true));
    tsTreeViewParentLabel = TextStyle(fontFamily: font, fontSize: (25.0 * scale), fontWeight: FontWeight.w600, color: screenForegroundColour(true));
    treeNodeHeight = defaultTreeNodeHeight;
    treeNodeIcons = List.empty(growable: true);
    for (int i = 0; i < defaultTreeNodeIconData.length; i++) {
      treeNodeIcons.add(Icon(
        defaultTreeNodeIconData[i],
        size: treeNodeHeight - 11,
        color: screenForegroundColour(true),
      ));
    }
    debugPrint("AppThemeData: Created!");
  }

  selectedAndHiLightColour(final bool sel, final bool upd) {
    if (upd) {
      return sel ? secondary.lightest : secondary.light;
    }
    return sel ? primary.lightest : primary.light;
  }

  Color screenForegroundColour(final bool enabled) {
    if (enabled) {
      return darkMode ? Colors.white : Colors.black;
    }
    return Colors.black26;
  }

  Color get screenBackgroundColor {
    return primary.med;
  }

  ColorPallet primaryOrSecondaryPallet(bool sec) {
    return sec ? secondary : primary;
  }

  Color get dialogBackgroundColor {
    return primary.med;
  }

  Color get detailBackgroundColor {
    return primary.light;
  }

  Color get cursorColor {
    return darkMode ? Colors.black : Colors.white;
  }

  Color get screenBackgroundErrorColor {
    return error.med;
  }

  ColorPallet getColorPalletForName(String name) {
    final cp = colourNames[name];
    if (cp != null) {
      return cp;
    }
    return ColorPallet.fromMaterialColor(Colors.red, "red");
  }
}

class ConfigData {
  final String _configFileName; // The file name for the config file
  final String _applicationDefaultDir; // Desktop: current path, Mobile: defined by OS. Needs to be writeable.
  final bool _isDesktop;
  final Function(String) log;
  late final String _fullFileName;
  late final dynamic _configJson;
  late final String _appStateFileName;
  late final String _appStateLocalDir;
  late final String _title;
  late final int _dataFetchTimeoutMillis;
  AppThemeData? _appThemeData;
  String _userName = "";
  String _userId = "";
  String _dataFileName = "";
  String _getDataFileUrl = "";
  String _postDataFileUrl = "";
  String _dataFileLocalDir = ""; // Where the data file is. Desktop: defined by config. Mobile: Always _applicationDefaultDir
  ColorPallet _appColoursPrimary = ColorPallet.fromMaterialColor(Colors.blue, 'blue');
  ColorPallet _appColoursSecondary = ColorPallet.fromMaterialColor(Colors.green, 'green');
  ColorPallet _appColoursHiLight = ColorPallet.fromMaterialColor(Colors.yellow, 'yellow');
  ColorPallet _appColoursError = ColorPallet.fromMaterialColor(Colors.red, 'red');
  bool _darkMode = false;

  String screenModeColourName(final bool enabled) {
    if (enabled) {
      return _darkMode ? "white" : "black";
    }
    return "brown";
  }

  ConfigData(this._applicationDefaultDir, this._configFileName, this._isDesktop, this.log) {
    log("__PLATFORM:__ ${_isDesktop ? 'DESKTOP' : 'MOBILE'}");
    if (!_isDesktop) {
      log("__DOCUMENTS DIR:__ $_applicationDefaultDir");
    }
    _fullFileName = _pathFromStrings(_applicationDefaultDir, _configFileName);
    var resp = DataLoad.loadFromFile(_fullFileName);
    if (resp.hasException) {
      if (resp.exception is PathNotFoundException) {
        resp = SuccessState(true, message: "", fileContent: defaultConfig);
        log("__WARN:__ Config '$_configFileName' file not found using defaults");
      } else {
        log("__EXCEPTION:__ ${resp.exception.toString()}");
        throw resp.exception as Object;
      }
    } else {
      log("__CONFIG FILE:__ Loaded: $_fullFileName");
    }
    _configJson = jsonDecode(resp.fileContent);

    if (_isDesktop) {
      _appStateLocalDir = DataLoad.getStringFromJson(getJson(), appStateLocalDirPath, fallback: _applicationDefaultDir);
    } else {
      _appStateLocalDir = _applicationDefaultDir;
    }
    _appStateFileName = DataLoad.getStringFromJson(getJson(), appStateFileNamePath, fallback: defaultAppStateFileName);

    update();
    _title = DataLoad.getStringFromJson(getJson(), titlePath, fallback: defaultAppTitle);
    _dataFetchTimeoutMillis = DataLoad.getNumFromJson(_configJson, dataFetchTimeoutMillisPath, fallback: defaultFetchTimeoutMillis) as int;
    log("__LOCAL DATA FILE:__ ${getDataFileLocal()}");
    log("__REMOTE DATA GET:__ ${getGetDataFileUrl()}");
    log("__REMOTE DATA POST:__ ${getPostDataFileUrl()}");
    log("__LOCAL STATE FILE:__ ${getAppStateFileLocal()}");
    log("__USER:__ ID(${getUserId()}) ${getUserName()}");
  }

  void update() {
    _userName = DataLoad.getStringFromJson(_configJson, userNamePath, fallback: defaultUserName, create: true);
    _userId = DataLoad.getStringFromJson(_configJson, userIdPath, fallback: defaultUserName.toLowerCase(), create: true);
    _getDataFileUrl = DataLoad.getStringFromJson(_configJson, getDataUrlPath, fallback: defaultRemoteGetUrl, create: true);
    _postDataFileUrl = DataLoad.getStringFromJson(_configJson, postDataUrlPath, fallback: defaultRemotePostUrl, create: true);
    _dataFileName = DataLoad.getStringFromJson(_configJson, dataFileLocalNamePath, fallback: defaultDataFileName, create: true);
    if (_isDesktop) {
      _dataFileLocalDir = DataLoad.getStringFromJson(_configJson, dataFileLocalDirPath, fallback: _applicationDefaultDir, create: true);
    } else {
      _dataFileLocalDir = _applicationDefaultDir;
    }
    _appColoursPrimary = validColour(DataLoad.getStringFromJson(_configJson, appColoursPrimaryPath, fallback: screenModeColourName(true), create: true), appColoursPrimaryPath);
    _appColoursSecondary = validColour(DataLoad.getStringFromJson(_configJson, appColoursSecondaryPath, fallback: "green", create: true), appColoursSecondaryPath);
    _appColoursHiLight = validColour(DataLoad.getStringFromJson(_configJson, appColoursHiLightPath, fallback: "yellow", create: true), appColoursHiLightPath);
    _appColoursError = validColour(DataLoad.getStringFromJson(_configJson, appColoursErrorPath, fallback: "red", create: true), appColoursErrorPath);
    _darkMode = DataLoad.getBoolFromJson(_configJson, appColoursDarkMode, fallback: false);
    _appThemeData = null;
  }

  AppThemeData getAppThemeData() {
    _appThemeData ??= AppThemeData._(_appColoursPrimary, _appColoursSecondary, _appColoursHiLight, _appColoursError, defaultFontFamily, _isDesktop ? defaultFontScaleDesktop : defaultFontScaleMobile, Colors.red.shade500, _darkMode, _isDesktop);
    return _appThemeData!;
  }

  dynamic getJson() {
    return _configJson;
  }

  ColorPallet getPrimaryColour() {
    return _appColoursPrimary;
  }

  ColorPallet validColour(String colourName, Path path) {
    final c = colourNames[colourName];
    if (c == null) {
      throw ColourNameException("Invalid colour name at path:${path.toString()}");
    }
    return c;
  }

  String _pathFromStrings(String path, String fileName) {
    if (path.isEmpty) {
      return fileName;
    }
    return "$path${Platform.pathSeparator}$fileName";
  }

  SuccessState save(Function(String log) log) {
    try {
      JsonEncoder encoder = const JsonEncoder.withIndent('  ');
      final contents = encoder.convert(_configJson);
      final sc = DataLoad.saveToFile(_fullFileName, contents);
      if (sc.isFail) {
        return sc;
      }
      return SuccessState(true, message: "Config File Saved", log: log);
    } catch (e) {
      return SuccessState(false, message: "Config File Save Failed", exception: e as Exception, log: log);
    }
  }

  bool isDesktop() {
    return _isDesktop;
  }

  int getDataFetchTimeoutMillis() {
    return _dataFetchTimeoutMillis;
  }

  String getConfigFileName() {
    return _pathFromStrings(_applicationDefaultDir, _configFileName);
  }

  String getGetDataFileUrl() {
    return "$_getDataFileUrl/$_dataFileName";
  }

  String getPostDataFileUrl() {
    return "$_postDataFileUrl/$_dataFileName";
  }

  String getDataFileLocal() {
    return _pathFromStrings(_dataFileLocalDir, _dataFileName);
  }

  String getAppStateFileLocal() {
    return _pathFromStrings(_appStateLocalDir, _appStateFileName);
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
    return "Url:${getGetDataFileUrl()} File:${getDataFileLocal()}";
  }
}
