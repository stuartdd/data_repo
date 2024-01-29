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
import 'package:flutter/material.dart';
import 'data_container.dart';
import 'path.dart';
import 'build_date.dart';
import 'data_types.dart';
import 'dart:io';

const String defaultServerPath = "http://localhost:8080";
const String defaultRemoteGetUrl = "files/user/stuart/loc/mydb/name/%dataFileName%";
const String defaultRemotePostUrl = "files/user/stuart/loc/mydb/name/%dataFileName%";
const String defaultRemoteTestFileUrl = "files/user/stuart/loc/mydb/name/%testFileName%";
const String defaultRemoteListDataUrl = "files/user/stuart/loc/mydb";
const String defaultDataFileName = "data.json";
const String defaultAppStateFileName = "data_repo_appState.json";
const String defaultConfigFileName = "data_repo_config.json";
const String defaultRemoteTestFileName = "remoteTestFile.rtf";

const String defaultPrimaryColourName = "blue";
const String defaultSecondaryColourName = "green";
const String defaultHiLightColourName = "yellow";
const String defaultErrorColourName = "red";
const String fallbackColorName = "red";
const String defaultRootNodeName = "?";
const bool defaultDarkMode = false;
const bool defaultHideDataPath = false;
const String defaultUserName = "User";
const int defaultFetchTimeoutMillis = 1000;
const String defaultDataEmptyString = "";
const String defaultAppTitle = "Data Repo";
const String defaultRepoName = "https://github.com/stuartdd/data_repo";
const String defaultAuthorEmail = "sdd.davies@gmail.com";
const String defaultFontFamily = "Roboto";
const double defaultFontScaleDesktop = 1.0;
const double defaultFontScaleMobile = 0.8;
const double defaultTreeNodeHeight = 30.0;

const defaultAppBarHeight = 50.0;
const defaultButtonHeight = 50.0;
const defaultTextInputFieldHeight = 50.0;
const defaultButtonGap = 15;
const defaultIconSize = 30;
const defaultIconGap = 20;
const defaultVerticalGap = 10;

const defaultConfig = """  {
        "application" : {
            "title": "Data Repository",
            "authorEmail": "sdd.davies@gmail.com",
            "repoName": "https://github.com/stuartdd/data_repo",
        },
        "file": {
            "serverPath": "http://192.168.1.243:8080",
            "getDataUrl": "files/user/stuart/loc/mydb/name/%dataFileName%",
            "postDataUrl": "files/user/stuart/loc/mydb/name/%dataFileName%",
            "getTestFileUrl": "/files/user/stuart/loc/mydb/name/%testFileName%",
            "getListDataUrl": "files/user/stuart/loc/mydb",
            "datafileName": "data.json",
            "datafilePath": "."
        }
    } """;

enum FileExtensionState { asIs, forceJson, forceData, checkPassword }

const fileExtensionJson = ".json";
const fileExtensionData = ".data";
const fileExtensionDataList = [fileExtensionData, fileExtensionJson];

final getServerPathPath = Path.fromList(["file", "serverPath"]);
final getDataUrlPath = Path.fromList(["file", "getDataUrl"]);
final postDataUrlPath = Path.fromList(["file", "postDataUrl"]);
final getTestFileUrlPath = Path.fromList(["file", "getTestFileUrl"]);
final getListDataUrlPath = Path.fromList(["file", "getListDataUrl"]);

final dataFileLocalNamePath = Path.fromList(["file", "datafileName"]);
final dataFileLocalDirPath = Path.fromList(["file", "datafilePath"]);
final appStateFileNamePath = Path.fromList(["file", "appStateFile"]);
final appStateLocalDirPath = Path.fromList(["file", "appStatePath"]);
final shouldIsolatePath = Path.fromList(["application", "shouldIsolate"]);
final repoPath = Path.fromList(["application", "repoName"]);
final titlePath = Path.fromList(["application", "title"]);
final authorEmailPath = Path.fromList(["application", "authorEmail"]);
final appTextScalePath = Path.fromList(["application", "textScale"]);
final dataFetchTimeoutMillisPath = Path.fromList(["application", "dataFetchTimeoutMillis"]);

const defaultThemeReplace = "default";
const defaultThemeRootName = "theme";

final appDarkModePathC = Path.fromList([defaultThemeRootName, Path.substituteElement, "darkMode"]);
final appRootNodeNamePathC = Path.fromList([defaultThemeRootName, Path.substituteElement, "rootNodeName"]);
final hideDataPathPathC = Path.fromList([defaultThemeRootName, Path.substituteElement, "hideDataPath"]);
final appColoursPrimaryPathC = Path.fromList([defaultThemeRootName, Path.substituteElement, "colours", "primary"]);
final appColoursSecondaryPathC = Path.fromList([defaultThemeRootName, Path.substituteElement, "colours", "secondary"]);
final appColoursHiLightPathC = Path.fromList([defaultThemeRootName, Path.substituteElement, "colours", "hilight"]);
final appColoursErrorPathC = Path.fromList([defaultThemeRootName, Path.substituteElement, "colours", "error"]);

class FileListEntry {
  final String name;
  final bool _remote;
  bool _local;
  FileListEntry._(this.name, this._local, this._remote);

  factory FileListEntry.local(final String name) {
    return FileListEntry._(name, true, false);
  }

  factory FileListEntry.remote(final String name) {
    return FileListEntry._(name, false, true);
  }

  bool equals(String toName) {
    return name == toName;
  }

  void setLocal() {
    _local = true;
  }

  @override
  String toString() {
    return "${_local ? 'L' : '-'}${_remote ? 'R' : '-'} : $name";
  }

  static IconData get localIcon {
    return Icons.file_open;
  }

  static IconData get remoteIcon {
    return Icons.cloud_download;
  }

  static IconData get syncedIcon {
    return Icons.cloud_sync;
  }

  IconData get locationIcon {
    if (_local && _remote) {
      return syncedIcon;
    }
    if (_local) {
      return localIcon;
    }
    return remoteIcon;
  }

  IconData get stateIcon {
    if (name.endsWith(fileExtensionData)) {
      return Icons.lock;
    }
    if (name.endsWith(fileExtensionJson)) {
      return Icons.lock_open;
    }
    return Icons.question_mark;
  }
}

class AboutData {
  final String title;
  final String author;
  final String email;
  final String buildDate;
  final String localBuildPath;
  final String repoName;
  final String language;
  final String license;
  final String desc;
  AboutData(this.title, this.author, this.email, this.buildDate, this.localBuildPath, this.repoName, this.language, this.license, this.desc);

  String sub(String s, String t1, t2, title, bool nl) {
    final x = s.split("|");
    StringBuffer sb = StringBuffer();
    if (nl) {
      sb.writeln("$t1 $title");
    }
    for (var i = 0; i < x.length; i++) {
      sb.writeln((i == 0 && !nl) ? '$t1 $title ${x[i]}' : '$t1 $t2 ${x[i]}');
    }
    return sb.toString();
  }

  String getMD() {
    return """
# __Author:__ Stuart Davies.
## __Email:__ $email
---
## __Build Date:__ $buildDate
### __Local Path:__ $localBuildPath
---
${sub(repoName, "##", "-", "__Repository:__", true)}
---
## __Language:__ $language
${sub(license, "##", "-", "__License:__", false)}
---
${sub(desc, "##", "-", "__Purpose:__", true)}
""";
  }
}

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

  bool containsColor(Color c) {
    for (int i = 0; i < 7; i++) {
      if (c.value == indexed(i).value) {
        return true;
      }
    }
    return false;
  }

  Color indexed(int i) {
    switch (i) {
      case 0:
        return lightest;
      case 1:
        return light;
      case 2:
        return medLight;
      case 3:
        return med;
      case 4:
        return medDark;
      case 5:
        return dark;
      case 6:
        return darkest;
      default:
        return med;
    }
  }

  @override
  String toString() {
    return colorName;
  }

  static bool colorNameExists(String name) {
    return _colourNames.containsKey(name.toLowerCase());
  }

  factory ColorPallet.forName(String name, {String fallback = fallbackColorName}) {
    final cp = _colourNames[name.toLowerCase()];
    if (cp == null) {
      return _colourNames[fallback.toLowerCase()]!;
    }
    return cp;
  }

  factory ColorPallet.fromMaterialColor(MaterialColor mc, String colorName) {
    return ColorPallet(colorName, mc.shade200, mc.shade300, mc.shade400, mc.shade500, mc.shade600, mc.shade800, mc.shade900);
  }
}

const List<String> defaultTreeNodeToolTip = ["Data only", "Collapse", "Expand", "Has Data"];
const List<IconData> defaultTreeNodeIconData = [Icons.last_page, Icons.arrow_downward, Icons.arrow_forward, Icons.dataset];

Map<String, ColorPallet> _colourNames = <String, ColorPallet>{
  'black': const ColorPallet("black", Colors.white, Colors.black12, Colors.black26, Colors.black38, Colors.black45, Colors.black54, Colors.black),
  'white': const ColorPallet("white", Colors.black, Colors.black54, Colors.black45, Colors.black38, Colors.black26, Colors.black12, Colors.white),
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
  final bool hideDataPath;
  final String themeContext;
  late final double verticalGap;
  late final double iconSize;
  late final double iconGap;
  late final double buttonHeight;
  late final double buttonGap;
  late final double textInputFieldHeight;

  late final TextStyle tsLarge;
  late final TextStyle tsLargeBold;
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

  AppThemeData._(this.primary, this.secondary, this.hiLight, this.error, this.themeContext, String font, double textScale, Color errC, this.darkMode, this.desktop, this.hideDataPath) {
    tsScale = textScale;
    tsLarge = TextStyle(fontSize: (25.0 * textScale), color: screenForegroundColour(true));
    tsLargeBold = TextStyle(fontSize: (25.0 * textScale), fontWeight: FontWeight.bold, color: screenForegroundColour(true));
    tsLargeDisabled = TextStyle(fontSize: (25.0 * textScale), color: screenForegroundColour(false));
    tsLargeItalic = TextStyle(fontSize: (25.0 * textScale), fontStyle: FontStyle.italic, color: screenForegroundColour(true));
    tsLargeError = TextStyle(fontSize: (25.0 * textScale), color: errC);
    tsMedium = TextStyle(fontSize: (20.0 * textScale), color: screenForegroundColour(true));
    tsMediumBold = TextStyle(fontSize: (20.0 * textScale), fontWeight: FontWeight.bold, color: screenForegroundColour(true));
    tsMediumDisabled = TextStyle(fontSize: (20.0 * textScale), color: screenForegroundColour(false));
    tsMediumError = TextStyle(fontSize: (20.0 * textScale), color: errC);
    tsSmall = TextStyle(fontSize: (15.0 * textScale), color: screenForegroundColour(true));
    tsSmallDisabled = TextStyle(fontSize: (15.0 * textScale), color: screenForegroundColour(false));
    tsSmallError = TextStyle(fontSize: (15.0 * textScale), color: errC);
    tsTreeViewLabel = TextStyle(fontSize: (25.0 * textScale), color: screenForegroundColour(true));
    tsTreeViewParentLabel = TextStyle(fontSize: (30.0 * textScale), fontWeight: FontWeight.w600, color: screenForegroundColour(true));
    treeNodeHeight = defaultTreeNodeHeight * (textScale * 1.5);
    treeNodeIcons = List.empty(growable: true);
    iconSize = defaultIconSize * textScale;
    iconGap = defaultIconGap * textScale;
    buttonHeight = defaultButtonHeight * textScale;
    buttonGap = defaultButtonGap * textScale;
    verticalGap = defaultVerticalGap * textScale;
    textInputFieldHeight = defaultTextInputFieldHeight * textScale;
    for (int i = 0; i < defaultTreeNodeIconData.length; i++) {
      treeNodeIcons.add(Icon(
        defaultTreeNodeIconData[i],
        size: iconSize,
        color: screenForegroundColour(true),
      ));
    }
    textSelectionThemeData = darkMode
        ? TextSelectionThemeData(
            cursorColor: Colors.black,
            selectionColor: Colors.green.shade900,
            selectionHandleColor: Colors.cyan,
          )
        : const TextSelectionThemeData(
            cursorColor: Colors.black,
            selectionColor: Colors.yellow,
            selectionHandleColor: Colors.blue,
          );
  }

  Size textSize(final String text, final TextStyle style) {
    final TextPainter textPainter = TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr)..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  selectedAndHiLightColour(final bool sel, final bool upd, final bool group) {
    if (upd) {
      return sel ? secondary.lightest : secondary.light;
    }
    if (group) {
      return sel ? primary.medDark : primary.dark;
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

  ColorPallet primaryOrSecondaryPallet(final bool sec) {
    return sec ? secondary : primary;
  }

  RoundedRectangleBorder get rectangleBorderShape {
    return RoundedRectangleBorder(borderRadius: borderRadius);
  }

  BorderRadius get borderRadius {
    return const BorderRadius.all(Radius.circular(4));
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

  Widget buttonGapBox(final int count) {
    return SizedBox(width: buttonGap * count);
  }

  Widget iconGapBox(final int count) {
    return SizedBox(width: iconGap * count);
  }

  Widget verticalGapBox(final int count) {
    return SizedBox(height: verticalGap * count);
  }

  Widget get horizontalLine {
    return Container(height: 1, color: screenForegroundColour(true));
  }

  ColorPallet getColorPalletWithColourInIt(final Color findIt) {
    for (final pallet in _colourNames.values) {
      if (pallet.containsColor(findIt)) {
        return pallet;
      }
    }
    return _colourNames.values.first;
  }

  List<Color> getColorsAsList(final int offset) {
    final List<Color> l = [];
    int index = 0;
    for (final c in _colourNames.values) {
      if (index >= offset) {
        l.add(c.indexed(0));
        l.add(c.indexed(1));
        l.add(c.indexed(2));
        l.add(c.indexed(3));
        l.add(c.indexed(4));
        l.add(c.indexed(5));
        l.add(c.indexed(6));
      }
      index++;
    }
    return l;
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
  late final String _repoName;
  late final String _authorEmail;

  late final int _dataFetchTimeoutMillis;
  Function()? _onUpdate;
  AppThemeData? _appThemeData;
  double _textScale = 0;
  String _themeContext = defaultThemeReplace;
  String _rootNodeName = "";
  String _dataFileName = "";
  String _listDataUrl = "";
  String _serverPath = "";
  String _getDataFileUrl = "";
  String _postDataFileUrl = "";
  String _getTestFileUrl = "";
  String _dataFileLocalDir = ""; // Where the data file is. Desktop: defined by config. Mobile: Always _applicationDefaultDir
  ColorPallet _appColoursPrimary = ColorPallet.fromMaterialColor(Colors.blue, 'blue');
  ColorPallet _appColoursSecondary = ColorPallet.fromMaterialColor(Colors.green, 'green');
  ColorPallet _appColoursHiLight = ColorPallet.fromMaterialColor(Colors.yellow, 'yellow');
  ColorPallet _appColoursError = ColorPallet.fromMaterialColor(Colors.red, 'red');
  bool _darkMode = false;
  bool _hideDataPath = false;
  bool _shouldIsolate = true;

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
    _data = DataContainer(resp.value, FileDataPrefix.empty(), "", "", "", null, "");
    if (_isDesktop) {
      _appStateLocalDir = _data.getStringFromJson(appStateLocalDirPath, fallback: _applicationDefaultDir);
    } else {
      _appStateLocalDir = _applicationDefaultDir;
    }
    _appStateFileName = _data.getStringFromJson(appStateFileNamePath, fallback: defaultAppStateFileName);

    update();
    _repoName = _data.getStringFromJson(repoPath, fallback: defaultRepoName);
    _title = _data.getStringFromJson(titlePath, fallback: defaultAppTitle);
    _authorEmail = _data.getStringFromJson(authorEmailPath, fallback: defaultAuthorEmail);
    _dataFetchTimeoutMillis = _data.getNumFromJson(dataFetchTimeoutMillisPath, fallback: defaultFetchTimeoutMillis) as int;
    log("__LOCAL DATA FILE:__ ${getDataFileLocalPath()}");
    log("__REMOTE DATA GET:__ ${getGetDataFileUrl()}");
    log("__REMOTE DATA POST:__ ${getPostDataFileUrl()}");
    log("__LOCAL STATE FILE:__ ${getAppStateFileLocal()}");
  }

  void update({final bool callOnUpdate = true}) {
    _shouldIsolate = _data.getBoolFromJson(shouldIsolatePath, fallback: true);
    _serverPath = _data.getStringFromJson(getServerPathPath, fallback: defaultServerPath);
    _dataFileName = _data.getStringFromJson(dataFileLocalNamePath, fallback: defaultDataFileName);
    _getDataFileUrl = _substituteForUrl(_data.getStringFromJson(getDataUrlPath, fallback: defaultRemoteGetUrl));
    _postDataFileUrl = _substituteForUrl(_data.getStringFromJson(postDataUrlPath, fallback: defaultRemotePostUrl));
    _getTestFileUrl = _substituteForUrl(_data.getStringFromJson(getTestFileUrlPath, fallback: defaultRemoteTestFileUrl));
    _listDataUrl = _substituteForUrl(_data.getStringFromJson(getListDataUrlPath, fallback: defaultRemoteListDataUrl));
    if (_isDesktop) {
      _dataFileLocalDir = _data.getStringFromJson(dataFileLocalDirPath, fallback: _applicationDefaultDir);
    } else {
      _dataFileLocalDir = _applicationDefaultDir;
    }

    _appColoursPrimary = validColour(_data.getStringFromJson(appColoursPrimaryPathC, fallback: defaultPrimaryColourName, sub2: defaultThemeReplace, sub1: _themeContext), appColoursPrimaryPathC);

    _appColoursSecondary = validColour(_data.getStringFromJson(appColoursSecondaryPathC, fallback: defaultSecondaryColourName, sub2: defaultThemeReplace, sub1: _themeContext), appColoursSecondaryPathC);

    _appColoursHiLight = validColour(_data.getStringFromJson(appColoursHiLightPathC, fallback: defaultHiLightColourName, sub2: defaultThemeReplace, sub1: _themeContext), appColoursHiLightPathC);

    _appColoursError = validColour(_data.getStringFromJson(appColoursErrorPathC, fallback: defaultErrorColourName, sub2: defaultThemeReplace, sub1: _themeContext), appColoursErrorPathC);

    _darkMode = _data.getBoolFromJson(appDarkModePathC, fallback: defaultDarkMode, sub2: defaultThemeReplace, sub1: _themeContext);

    _hideDataPath = _data.getBoolFromJson(hideDataPathPathC, fallback: defaultHideDataPath, sub2: defaultThemeReplace, sub1: _themeContext);

    _rootNodeName = _data.getStringFromJson(appRootNodeNamePathC, fallback: defaultRootNodeName, sub2: defaultThemeReplace, sub1: _themeContext);

    _textScale = _data.getNumFromJson(appTextScalePath, fallback: (_isDesktop ? defaultFontScaleDesktop : defaultFontScaleMobile)).toDouble();
    _appThemeData = null;
    if (_onUpdate != null && callOnUpdate) {
      _onUpdate!();
    }
  }

  String _substituteForUrl(String value, {final FileExtensionState mode = FileExtensionState.asIs, final String pw = ""}) {
    var v = _replaceFileNameExtension(_dataFileName, mode, pw);
    var s = value.replaceAll("%dataFileName%", v);
    s = s.replaceAll("%testFileName%", defaultRemoteTestFileName);
    return "$_serverPath/$s";
  }

  AppThemeData getAppThemeData() {
    _appThemeData ??= AppThemeData._(_appColoursPrimary, _appColoursSecondary, _appColoursHiLight, _appColoursError, _themeContext, defaultFontFamily, _textScale, Colors.red.shade500, _darkMode, _isDesktop, _hideDataPath);
    return _appThemeData!;
  }

  set onUpdate(void Function() onUpdateFunc) {
    _onUpdate = onUpdateFunc;
  }

  String clearThemeForFile(final String fileName) {
    final tn = _fileNameToThemeName(fileName);
    final resp = _data.remove(Path.fromList([defaultThemeRootName, tn]), false, dryRun: false);
    if (resp.isEmpty) {
      update();
    }
    return resp;
  }

  set themeContext(final String fileName) {
    final tn = _fileNameToThemeName(fileName);
    if (_themeContext != tn) {
      _themeContext = tn;
      update();
    }
  }

  String get themeContext {
    return _themeContext;
  }

  Map<String, dynamic> getMinimumDataContentMap() {
    final dt = DateTime.now();
    final result = '${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}:${dt.second}';
    return DataContainer.staticConvertStringToMap('{"Data":{"Info":{"Created":"$result"}}}', "");
  }

  double get iconSize {
    return (defaultIconSize * _textScale);
  }

  bool get shouldIsolate {
    return _shouldIsolate;
  }

  double get scale {
    return _textScale;
  }

  double get iconGap {
    return (defaultIconGap * _textScale);
  }

  double get appBarHeight {
    return defaultAppBarHeight * _textScale;
  }

  double get appBarIconTop {
    return (appBarHeight - iconSize) / 2.0;
  }

  double get appButtonHeight {
    return defaultButtonHeight * _textScale;
  }

  String getStringFromJsonOptional(final Path path, {final String sub1 = "", final String sub2 = ""}) {
    return _data.getStringFromJsonOptional(path, sub1: sub1, sub2: sub2);
  }

  String getStringFromJson(final Path path, {final String fallback = "", final String sub1 = "", final String sub2 = ""}) {
    return _data.getStringFromJson(path, fallback: fallback, sub1: sub1, sub2: sub2);
  }

  bool getBoolFromJson(final Path path, {final bool? fallback, final String sub1 = "", final String sub2 = ""}) {
    return _data.getBoolFromJson(path, fallback: fallback, sub1: sub1, sub2: sub2);
  }

  num getNumFromJson(final Path path, {final num? fallback, final String sub1 = "", final String sub2 = ""}) {
    return _data.getNumFromJson(path, fallback: fallback, sub1: sub1, sub2: sub2);
  }

  String setValueForJsonPath(final Path path, final dynamic value) {
    return _data.setValueForJsonPath(path, value);
  }

  ColorPallet getPrimaryColour() {
    return _appColoursPrimary;
  }

  ColorPallet validColour(final String colourName, final Path path) {
    final c = _colourNames[colourName];
    if (c == null) {
      throw ColourNameException("Invalid colour name at path:${path.toString()}");
    }
    return c;
  }

  String _pathFromStrings(String path, String fileName) {
    if (path.isEmpty) {
      return fileName;
    }
    if (fileName.isEmpty) {
      return path;
    }
    return "$path${Platform.pathSeparator}$fileName";
  }

  SuccessState save(Function(String log) log) {
    try {
      final sc = DataContainer.saveToFile(_fullFileName, _data.dataToStringFormatted(), log: log);
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

  bool hideDataPath() {
    return _hideDataPath;
  }

  int getDataFetchTimeoutMillis() {
    return _dataFetchTimeoutMillis;
  }

  String getConfigFileName() {
    return _pathFromStrings(_applicationDefaultDir, _configFileName);
  }

  String get getRemoteTestFileName {
    return defaultRemoteTestFileName;
  }

  String getListDataUrl() {
    return _listDataUrl;
  }

  String getGetDataFileUrl() {
    return _getDataFileUrl;
  }

  String getRemoteTestFileUrl() {
    return _getTestFileUrl;
  }

  String getPostDataFileUrl({final FileExtensionState mode = FileExtensionState.asIs, final String pw = ""}) {
    if (mode == FileExtensionState.asIs) {
      return _postDataFileUrl;
    }
    return _substituteForUrl(_data.getStringFromJson(postDataUrlPath, fallback: defaultRemotePostUrl), mode: mode, pw: pw);
  }

  /*
  LOCAL DATA FILE Accessors
   */
  String getDataFileNameForSaveAs(String pw, {bool fullPath = false}) {
    if (pw.isEmpty) {
      if (fullPath) {
        return _pathFromStrings(_dataFileLocalDir, getDataFileName(mode: FileExtensionState.forceJson));
      }
      return getDataFileName(mode: FileExtensionState.forceJson);
    } else {
      if (fullPath) {
        return _pathFromStrings(_dataFileLocalDir, getDataFileName(mode: FileExtensionState.forceData));
      }
      return getDataFileName(mode: FileExtensionState.forceData);
    }
  }

  String getDataFileNameForCreate(String fileName, String pw, {bool fullPath = false}) {
    if (fullPath) {
      return _pathFromStrings(_dataFileLocalDir, _replaceFileNameExtension(fileName, FileExtensionState.checkPassword, pw));
    }
    return _replaceFileNameExtension(fileName, FileExtensionState.checkPassword, pw);
  }

  bool localFileExists(final String fileName) {
    return (File(_pathFromStrings(getDataFileDir(), fileName)).existsSync());
  }

  bool localDataFileExists() {
    return (File(_pathFromStrings(getDataFileDir(), getDataFileName())).existsSync());
  }

  String getDataFileNameAlt() {
    final current = getDataFileName().toLowerCase();
    if (current.endsWith(fileExtensionJson)) {
      return getDataFileName(mode: FileExtensionState.forceData);
    }
    if (current.endsWith(fileExtensionData)) {
      return getDataFileName(mode: FileExtensionState.forceJson);
    }
    return getDataFileName(mode: FileExtensionState.asIs);
  }

  bool canSaveAltFile() {
    return !localFileExists(getDataFileNameAlt());
  }

  String removeLocalFile() {
    try {
      (File(getDataFileLocalPath())).deleteSync();
    } catch(e) {
      return "$e";
    }
    if (localDataFileExists()) {
      return "File still exists";
    }
    return "";
  }

  String getDataFileLocalPath({final FileExtensionState mode = FileExtensionState.asIs, final String pw = ""}) {
    return _pathFromStrings(_dataFileLocalDir, getDataFileName(mode: mode, pw: pw));
  }

  String getDataFileName({final FileExtensionState mode = FileExtensionState.asIs, final String pw = ""}) {
    if (mode == FileExtensionState.asIs) {
      return _dataFileName;
    }
    return _replaceFileNameExtension(_dataFileName, mode, pw);
  }

  String getAppStateFileName() {
    return _appStateFileName;
  }

  String getRootNodeName() {
    if (_rootNodeName == defaultRootNodeName) {
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

  String get buildDate {
    return "${buildDateExt.day}-${buildDateExt.month}-${buildDateExt.year} ${buildDateExt.hour}:${buildDateExt.minute}";
  }

  String get buildLocalPath {
    return buildPathExt;
  }

  String get authorEmail {
    return _authorEmail;
  }

  String get repoName {
    return _repoName;
  }

  String get title {
    if (isDesktop()) {
      return "DT: $_title";
    }
    return "MO: $_title";
  }

  Future<void> remoteDir(final List<String> extension, final Function(String) onFail, final Function(String) onFound) async {
    final getUrl = getListDataUrl();
    final res = await DataContainer.listHttpGet(
      getUrl,
      timeoutMillis: 2000,
      log: log,
      onFind: (value) {
        final vlc = value.toLowerCase();
        for (int i = 0; i < extension.length; i++) {
          if (vlc.endsWith(extension[i]) && !vlc.contains("config") && !vlc.startsWith(".")) {
            onFound(value);
          }
        }
      },
    );
    if (res.isFail) {
      onFail("__LIST_REMOTE__ ${res.message}");
    }
  }

  List<FileListEntry> dir(final List<String> extensions, final List<String> hidden, final List<FileListEntry> remote, final Function(List<String>, bool) onFail) {
    final dir = Directory(getDataFileDir());
    final List<FileListEntry> finalList = List.from(remote, growable: true);
    if (!dir.existsSync()) {
      onFail(["Config Data Error:", "Element '$dataFileLocalDirPath'", "", "Path not found:", getDataFileDir()], true);
      return [];
    }
    final dirList = dir.listSync(recursive: false);
    for (var element in dirList) {
      if (element is File) {
        final fileName = File(element.path).uri.pathSegments.last;
        if (!fileName.startsWith('.') && !hidden.contains(fileName)) {
          if (extensions.isEmpty) {
            _mergeFileList(finalList, fileName);
          } else {
            final ext = fileName.split('.').last.toLowerCase();
            if (ext.isNotEmpty) {
              if (extensions.contains(".$ext")) {
                _mergeFileList(finalList, fileName);
              }
            }
          }
        }
      }
    }
    return finalList;
  }

  void _mergeFileList(final List<FileListEntry> into, String localName) {
    for (var fle in into) {
      if (fle.equals(localName)) {
        fle.setLocal();
        return;
      }
    }
    into.add(FileListEntry.local(localName));
  }

  @override
  String toString() {
    return "Url:${getGetDataFileUrl()} File:${getDataFileLocalPath()}";
  }

  static String _replaceFileNameExtension(final String fn, final FileExtensionState mode, final String pw) {
    if (mode == FileExtensionState.asIs) {
      return fn;
    }
    String ext = "";
    switch (mode) {
      case FileExtensionState.forceData:
        {
          ext = fileExtensionData;
          break;
        }
      case FileExtensionState.forceJson:
        {
          ext = fileExtensionJson;
          break;
        }
      case FileExtensionState.checkPassword:
        {
          ext = pw.isEmpty ? fileExtensionJson : fileExtensionData;
          break;
        }
      default:
        break;
    }

    final p = fn.lastIndexOf('.');
    if (p == -1) {
      return "$fn$ext";
    }
    return "${fn.substring(0, p)}$ext";
  }

  static String _fileNameToThemeName(final String fileNane) {
    StringBuffer sb = StringBuffer();
    for (var e in fileNane.runes) {
      if ((e >= 48 && e <= 57) || (e >= 65 && e <= 90) || (e >= 97 && e <= 122) || (e == 95) || (e == 46)) {
        sb.writeCharCode(e);
      }
    }
    return sb.toString();
  }
}
