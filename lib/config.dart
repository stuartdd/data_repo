import 'package:flutter/material.dart';
import 'data_container.dart';
import 'path.dart';
import 'data_types.dart';
import 'dart:io';

const String defaultRemoteGetUrl = "http://localhost:8080/file";
const String defaultRemotePostUrl = "http://localhost:8080/file";
const String defaultDataFileName = "data.json";
const String defaultAppStateFileName = "data_repo_appState.json";
const String defaultConfigFileNmae = "data_repo_config.json";

const String defaultPrimaryColour = "blue";
const String defaultSecondaryColour = "green";
const String defaultHiLightColour = "yellow";
const String defaultErrorColour = "red";
const String defaultDarkMode = "false";
const String defaultUserName = "User";
const int defaultFetchTimeoutMillis = 1000;
const String defaultDataEmptyString = "";
const String defaultAppTitle = "Data Repo";
const String defaultFontFamily = "Roboto";
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
final titlePath = Path.fromList(["application", "title"]);
final rootNodeNamePath = Path.fromList(["application", "rootNodeName"]);
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

const List<String> defaultTreeNodeToolTip = ["Data only", "Collapse", "Expand", "Has Data"];
const List<IconData> defaultTreeNodeIconData = [Icons.last_page, Icons.arrow_downward, Icons.arrow_forward, Icons.dataset];
const defaultTreeNodeIconDataBase = 0;
const defaultTreeNodeIconDataHasData = 3;

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
  late final TextStyle tsLargeItalic;
  late final TextStyle tsMedium;
  late final TextStyle tsMediumBold;
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
  late final TextSelectionThemeData textSelectionThemeData;

  AppThemeData._(this.primary, this.secondary, this.hiLight, this.error, String font, double scale, Color errC, this.darkMode, this.desktop) {
    tsScale = scale;
    tsLarge = TextStyle(fontSize: (25.0 * scale), color: screenForegroundColour(true));
    tsLargeDisabled = TextStyle(fontSize: (25.0 * scale), color: screenForegroundColour(false));
    tsLargeItalic = TextStyle(fontSize: (25.0 * scale), fontStyle: FontStyle.italic, color: screenForegroundColour(true));
    tsLargeError = TextStyle(fontSize: (25.0 * scale), color: errC);
    tsMedium = TextStyle(fontSize: (20.0 * scale), color: screenForegroundColour(true));
    tsMediumBold = TextStyle(fontSize: (20.0 * scale), fontWeight: FontWeight.bold, color: screenForegroundColour(true));
    tsMediumDisabled = TextStyle(fontSize: (20.0 * scale), color: screenForegroundColour(false));
    tsMediumError = TextStyle(fontSize: (20.0 * scale), color: errC);
    tsSmall = TextStyle(fontSize: (15.0 * scale), color: screenForegroundColour(true));
    tsSmallDisabled = TextStyle(fontSize: (15.0 * scale), color: screenForegroundColour(false));
    tsSmallError = TextStyle(fontSize: (15.0 * scale), color: errC);
    tsTreeViewLabel = TextStyle(fontSize: (20.0 * scale), color: screenForegroundColour(true));
    tsTreeViewParentLabel = TextStyle(fontSize: (25.0 * scale), fontWeight: FontWeight.w600, color: screenForegroundColour(true));
    treeNodeHeight = defaultTreeNodeHeight;
    treeNodeIcons = List.empty(growable: true);
    for (int i = 0; i < defaultTreeNodeIconData.length; i++) {
      treeNodeIcons.add(Icon(
        defaultTreeNodeIconData[i],
        size: treeNodeHeight - 11,
        color: screenForegroundColour(true),
      ));
    }
    textSelectionThemeData = darkMode ? TextSelectionThemeData(
      cursorColor: Colors.black,
      selectionColor: Colors.green.shade900,
      selectionHandleColor: Colors.cyan,
    ) : const TextSelectionThemeData(
      cursorColor: Colors.black,
      selectionColor: Colors.yellow,
      selectionHandleColor: Colors.blue,
    );
    debugPrint("AppThemeData: Created!");
  }

  Size textSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr)..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
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
    return darkMode ? Colors.white : Colors.black;
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
  late final DataContainer _data;
  late final String _appStateFileName;
  late final String _appStateLocalDir;
  late final String _title;
  late final int _dataFetchTimeoutMillis;
  Function()? _onUpdate;
  AppThemeData? _appThemeData;
  String _rootNodeName = "";
  String _dataFileName = "";
  String _getDataFileUrl = "";
  String _postDataFileUrl = "";
  String _dataFileLocalDir = ""; // Where the data file is. Desktop: defined by config. Mobile: Always _applicationDefaultDir
  ColorPallet _appColoursPrimary = ColorPallet.fromMaterialColor(Colors.blue, 'blue');
  ColorPallet _appColoursSecondary = ColorPallet.fromMaterialColor(Colors.green, 'green');
  ColorPallet _appColoursHiLight = ColorPallet.fromMaterialColor(Colors.yellow, 'yellow');
  ColorPallet _appColoursError = ColorPallet.fromMaterialColor(Colors.red, 'red');
  bool _darkMode = false;

  List<String> dir(List<String> extensions, List<String> hidden) {
    final l = List<String>.empty(growable: true);
    final dirList = Directory(_dataFileLocalDir).listSync(recursive: false);
    for (var element in dirList) {
      if (element is File) {
        final fileName = File(element.path).uri.pathSegments.last;
        if (!fileName.startsWith('.') && !hidden.contains(fileName)) {
          if (extensions.isEmpty) {
            l.add(fileName);
          } else {
            final ext = fileName.split('.').last.toLowerCase();
            if (ext.isNotEmpty) {
              if (extensions.contains(ext)) {
                l.add(fileName);
              }
            }
          }
        }
      }
    }
    return l;
  }

  ConfigData(this._applicationDefaultDir, this._configFileName, this._isDesktop, this.log) {
    log("__PLATFORM:__ ${_isDesktop ? 'DESKTOP' : 'MOBILE'}");
    if (!_isDesktop) {
      log("__DOCUMENTS DIR:__ $_applicationDefaultDir");
    }
    _fullFileName = _pathFromStrings(_applicationDefaultDir, _configFileName);
    var resp = DataContainer.loadFromFile(_fullFileName);
    if (resp.hasException) {
      if (resp.exception is PathNotFoundException) {
        resp = SuccessState(true, message: "", value: defaultConfig);
        log("__WARN:__ Config '$_configFileName' file not found using defaults");
      } else {
        log("__EXCEPTION:__ ${resp.exception.toString()}");
        throw resp.exception as Object;
      }
    } else {
      log("__CONFIG FILE:__ Loaded: $_fullFileName");
    }
    _data = DataContainer(resp.value, FileDataPrefix.empty(), "", "", "", "");

    if (_isDesktop) {
      _appStateLocalDir = _data.getStringFromJson(appStateLocalDirPath, fallback: _applicationDefaultDir);
    } else {
      _appStateLocalDir = _applicationDefaultDir;
    }
    _appStateFileName = _data.getStringFromJson(appStateFileNamePath, fallback: defaultAppStateFileName);

    update();
    _title = _data.getStringFromJson(titlePath, fallback: defaultAppTitle);
    _dataFetchTimeoutMillis = _data.getNumFromJson(dataFetchTimeoutMillisPath, fallback: defaultFetchTimeoutMillis) as int;
    log("__LOCAL DATA FILE:__ ${getDataFileLocal()}");
    log("__REMOTE DATA GET:__ ${getGetDataFileUrl()}");
    log("__REMOTE DATA POST:__ ${getPostDataFileUrl()}");
    log("__LOCAL STATE FILE:__ ${getAppStateFileLocal()}");
  }

  void update({bool callOnUpdate = true}) {
    _getDataFileUrl = _data.getStringFromJson(getDataUrlPath, fallback: defaultRemoteGetUrl, create: true);
    _postDataFileUrl = _data.getStringFromJson(postDataUrlPath, fallback: defaultRemotePostUrl, create: true);
    _dataFileName = _data.getStringFromJson(dataFileLocalNamePath, fallback: defaultDataFileName, create: true);
    if (_isDesktop) {
      _dataFileLocalDir = _data.getStringFromJson(dataFileLocalDirPath, fallback: _applicationDefaultDir, create: true);
    } else {
      _dataFileLocalDir = _applicationDefaultDir;
    }
    _appColoursPrimary = validColour(_data.getStringFromJson(appColoursPrimaryPath, fallback: defaultPrimaryColour, create: true), appColoursPrimaryPath);
    _appColoursSecondary = validColour(_data.getStringFromJson(appColoursSecondaryPath, fallback: defaultSecondaryColour, create: true), appColoursSecondaryPath);
    _appColoursHiLight = validColour(_data.getStringFromJson(appColoursHiLightPath, fallback: defaultHiLightColour, create: true), appColoursHiLightPath);
    _appColoursError = validColour(_data.getStringFromJson(appColoursErrorPath, fallback: defaultErrorColour, create: true), appColoursErrorPath);
    _darkMode = _data.getBoolFromJson(appColoursDarkMode, fallback: false);
    _rootNodeName = _data.getStringFromJson(rootNodeNamePath, fallback: "?");
    _appThemeData = null;
    if (_onUpdate != null && callOnUpdate) {
      _onUpdate!();
    }
  }

  AppThemeData getAppThemeData() {
    _appThemeData ??= AppThemeData._(_appColoursPrimary, _appColoursSecondary, _appColoursHiLight, _appColoursError, defaultFontFamily, _isDesktop ? defaultFontScaleDesktop : defaultFontScaleMobile, Colors.red.shade500, _darkMode, _isDesktop);
    return _appThemeData!;
  }

  set onUpdate(void Function() onUpdateFunc) {
    _onUpdate = onUpdateFunc;
  }

  DataContainer getDataContainer() {
    return _data;
  }

  String localFileExists(String fileName) {
    if (File(_pathFromStrings(getDataFileDir(), fileName)).existsSync()) {
      return "Local file exists";
    }
    return "";
  }

  Map<String, dynamic> getMinimumDataContentMap() {
    final dt = DateTime.now();
    final result = '${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}:${dt.second}';
    return DataContainer.convertStringToMap('{"Data":{"Info":{"Created":"$result"}}}', "");
  }

  String getStringFromJsonOptional(Path path) {
    return _data.getStringFromJsonOptional(path);
  }

  String getStringFromJson(Path path, {String fallback = "", bool create = false}) {
    return _data.getStringFromJson(path, fallback: fallback);
  }

  bool getBoolFromJson(Path path, {bool? fallback}) {
    return _data.getBoolFromJson(path, fallback: fallback);
  }

  num getNumFromJson(Path path, {num? fallback}) {
    return _data.getNumFromJson(path, fallback: fallback);
  }

  String setValueForJsonPath(Path path, dynamic value) {
    return _data.setValueForJsonPath(path, value);
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
      final sc = DataContainer.saveToFile(_fullFileName, _data.dataToStringFormatted());
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

  String getDataFileLocalAlt(final String fileName) {
    return _pathFromStrings(_dataFileLocalDir, fileName);
  }

  String getDataFileName() {
    return _dataFileName;
  }

  String getAppStateFileName() {
    return _appStateFileName;
  }

  String getRootNodeName() {
    if (_rootNodeName == '?') {
      return "";
    }
    return _rootNodeName;
  }

  String getDataFileDir() {
    return _dataFileLocalDir;
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

  @override
  String toString() {
    return "Url:${getGetDataFileUrl()} File:${getDataFileLocal()}";
  }
}
