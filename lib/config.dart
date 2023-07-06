import 'dart:async';

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
const String defaultHilightColour = "yellow";
const String defaultErrorColour = "red";
const String defaultUserName = "User";
const int defaultFetchTimeoutMillis = 2000;
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

final _getDataUrlPath = Path.fromList(["file", "getDataUrl"]);
final _postDataUrlPath = Path.fromList(["file", "postDataUrl"]);
final _dataFileLocalNamePath = Path.fromList(["file", "datafile"]);
final _dataFileLocalDirPath = Path.fromList(["file", "datafilePath"]);
final _appStateFileNamePath = Path.fromList(["user", "appStateFile"]);
final _appStateLocalDirPath = Path.fromList(["user", "appStatePath"]);
final _userNamePath = Path.fromList(["user", "name"]);
final _userIdPath = Path.fromList(["user", "id"]);
final _titlePath = Path.fromList(["application", "title"]);
final _appColoursPrimaryPath = Path.fromList(["application", "colours", "primary"]);
final _appColoursSecondaryPath = Path.fromList(["application", "colours", "secondary"]);
final _appColoursHiLightPath = Path.fromList(["application", "colours", "hilight"]);
final _appColoursErrorPath = Path.fromList(["application", "colours", "error"]);
final _dataFetchTimeoutMillisPath = Path.fromList(["application", "dataFetchTimeoutMillis"]);

final List<SettingDetail> _settingsData = [
  SettingDetail("User Name", "The users proper name", _userNamePath, "ES", "User", true),
  SettingDetail("Server URL (GET)", "The web address of the host server", _getDataUrlPath, "URL", defaultRemoteGetUrl, true),
  SettingDetail("Server URL (SAVE)", "The web address of the host server", _postDataUrlPath, "URL", defaultRemotePostUrl, true),
  SettingDetail("Local Data file path", "The directory for the data file", _dataFileLocalDirPath, "DIR", defaultDataFilePath, false),
  SettingDetail("Data file Name", "The name of the server file", _dataFileLocalNamePath, "FILE", defaultDataFilePath, true),
  SettingDetail("Primary Colour", "The main colour theme", _appColoursPrimaryPath, "COLOUR", defaultPrimaryColour, true),
  SettingDetail("Preview Colour", "The Markdown 'Preview' colour", _appColoursSecondaryPath, "COLOUR", defaultSecondaryColour, true),
  SettingDetail("Help Colour", "The Markdown 'Help' colour", _appColoursHiLightPath, "COLOUR", defaultHilightColour, true),
  SettingDetail("Error Colour", "The Error colour theme", _appColoursErrorPath, "COLOUR", defaultErrorColour, true),
];

const List<IconData> defaultTreeNodeIconData = [Icons.list_sharp, Icons.arrow_downward, Icons.arrow_forward];

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

class ColourNameException implements Exception {
  final String message;
  ColourNameException(this.message);
  @override
  String toString() {
    return "ColourNameException: $message";
  }
}

class SettingDetail {
  final String title;
  final String hint;
  final Path path;
  final String valueType;
  final String fallback;
  final bool desktopOnly;
  const SettingDetail(this.title, this.hint, this.path, this.valueType, this.fallback, this.desktopOnly);
}

class SettingControl {
  final SettingDetail detail;
  final String oldValue;
  var error = false;
  final controller = TextEditingController();

  SettingControl(this.detail, this.oldValue) {
    controller.text = oldValue;
  }
  String get value {
    return controller.text.trim();
  }

  bool get changed {
    return oldValue.trim() != value;
  }

  @override
  String toString() {
    return "${error ? 'Error' : 'OK'}: ${changed ? '*' : ''} Old:'$oldValue' New:'$value' Path:${detail.path} ";
  }
}

class AppThemeData {
  final MaterialColor primary;
  final MaterialColor secondary;
  final MaterialColor hiLight;
  final MaterialColor error;
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

  AppThemeData._(this.primary, this.secondary, this.hiLight, this.error, String font, double scale, Color col, Color errC) {
    tsScale = scale;
    tsLarge = TextStyle(fontFamily: font, fontSize: (25.0 * scale), color: col);
    tsLargeDisabled = TextStyle(fontFamily: font, fontSize: (25.0 * scale), color: col.withAlpha(10));
    tsLargeError = TextStyle(fontFamily: font, fontSize: (25.0 * scale), color: errC);
    tsMedium = TextStyle(fontFamily: font, fontSize: (20.0 * scale), color: col);
    tsMediumDisabled = TextStyle(fontFamily: font, fontSize: (20.0 * scale), color: col.withAlpha(10));
    tsMediumError = TextStyle(fontFamily: font, fontSize: (20.0 * scale), color: errC);
    tsSmall = TextStyle(fontFamily: font, fontSize: (15.0 * scale), color: col);
    tsSmallDisabled = TextStyle(fontFamily: font, fontSize: (15.0 * scale), color: col.withAlpha(10));
    tsSmallError = TextStyle(fontFamily: font, fontSize: (15.0 * scale), color: errC);
    tsTreeViewLabel = TextStyle(fontFamily: font, fontSize: (20.0 * scale), color: col);
    tsTreeViewParentLabel = TextStyle(fontFamily: font, fontSize: (25.0 * scale), fontWeight: FontWeight.w600, color: col);
    treeNodeHeight = defaultTreeNodeHeight;
    treeNodeIcons = List.empty(growable: true);
    for (int i = 0; i < defaultTreeNodeIconData.length; i++) {
      treeNodeIcons.add(Icon(
        defaultTreeNodeIconData[i],
        size: treeNodeHeight - 11,
      ));
    }
    debugPrint("AppThemeData: Created!");
  }

  selectedAndHiLightColour(final bool sel, final bool upd) {
    if (upd) {
      return sel ? secondary.shade300 : secondary.shade500;
    }
    return sel ? primary.shade300 : primary.shade500;
  }

  iconColour(final bool enabled) {
    if (enabled) {
      return Colors.black;
    }
    return Colors.black26;
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
  MaterialColor _appColoursPrimary = Colors.blue;
  MaterialColor _appColoursSecondary = Colors.green;
  MaterialColor _appColoursHiLight = Colors.yellow;
  MaterialColor _appColoursError = Colors.red;

  ConfigData(this._applicationDefaultDir, this._configFileName, this._isDesktop, this.log) {
    log("__PLATFORM:__ ${_isDesktop ? 'DESKTOP' : 'MOBILE'}");
    if (!_isDesktop) {
      log("__DOCUMENTS DIR:__ $_applicationDefaultDir");
    }
    _fullFileName = _pathFromStrings(_applicationDefaultDir, _configFileName);
    var resp = DataLoad.loadFromFile(_fullFileName);
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
    _configJson = jsonDecode(resp.value);

    if (_isDesktop) {
      _appStateLocalDir = DataLoad.getStringFromJson(getJson(), _appStateLocalDirPath, fallback: _applicationDefaultDir);
    } else {
      _appStateLocalDir = _applicationDefaultDir;
    }
    _appStateFileName = DataLoad.getStringFromJson(getJson(), _appStateFileNamePath, fallback: defaultAppStateFileName);

    update();
    _title = DataLoad.getStringFromJson(getJson(), _titlePath, fallback: defaultAppTitle);
    _dataFetchTimeoutMillis = DataLoad.getNumFromJson(_configJson, _dataFetchTimeoutMillisPath, fallback: defaultFetchTimeoutMillis) as int;
    log("__LOCAL DATA FILE:__ ${getDataFileLocal()}");
    log("__REMOTE DATA GET:__ ${getGetDataFileUrl()}");
    log("__REMOTE DATA POST:__ ${getPostDataFileUrl()}");
    log("__LOCAL STATE FILE:__ ${getAppStateFileLocal()}");
    log("__USER:__ ID(${getUserId()}) ${getUserName()}");
  }

  void update() {
    _userName = DataLoad.getStringFromJson(_configJson, _userNamePath, fallback: defaultUserName, create: true);
    _userId = DataLoad.getStringFromJson(_configJson, _userIdPath, fallback: defaultUserName.toLowerCase(), create: true);
    _getDataFileUrl = DataLoad.getStringFromJson(_configJson, _getDataUrlPath, fallback: defaultRemoteGetUrl, create: true);
    _postDataFileUrl = DataLoad.getStringFromJson(_configJson, _postDataUrlPath, fallback: defaultRemotePostUrl, create: true);
    _dataFileName = DataLoad.getStringFromJson(_configJson, _dataFileLocalNamePath, fallback: defaultDataFileName, create: true);
    if (_isDesktop) {
      _dataFileLocalDir = DataLoad.getStringFromJson(_configJson, _dataFileLocalDirPath, fallback: _applicationDefaultDir, create: true);
    } else {
      _dataFileLocalDir = _applicationDefaultDir;
    }
    _appColoursPrimary = validColour(DataLoad.getStringFromJson(_configJson, _appColoursPrimaryPath, fallback: "blue", create: true), _appColoursPrimaryPath);
    _appColoursSecondary = validColour(DataLoad.getStringFromJson(_configJson, _appColoursSecondaryPath, fallback: "green", create: true), _appColoursSecondaryPath);
    _appColoursHiLight = validColour(DataLoad.getStringFromJson(_configJson, _appColoursHiLightPath, fallback: "yellow", create: true), _appColoursHiLightPath);
    _appColoursError = validColour(DataLoad.getStringFromJson(_configJson, _appColoursErrorPath, fallback: "red", create: true), _appColoursErrorPath);
    _appThemeData = null;
  }

  AppThemeData getAppThemeData() {
    _appThemeData ??= AppThemeData._(_appColoursPrimary, _appColoursSecondary, _appColoursHiLight, _appColoursError, defaultFontFamily, _isDesktop ? defaultFontScaleDesktop : defaultFontScaleMobile, Colors.black, Colors.red);
    return _appThemeData!;
  }

  dynamic getJson() {
    return _configJson;
  }

  MaterialColor getPrimaryColour() {
    return _appColoursPrimary;
  }

  MaterialColor validColour(String colourName, Path path) {
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

  String _initialValidate(String value, SettingDetail detail, String Function(String, SettingDetail) onValidate) {
    final vt = value.trim();
    switch (detail.valueType) {
      case "COLOUR":
        {
          if (!_colourNames.containsKey(value)) {
            return "Invalid Colour Name";
          }
          break;
        }
      case "URL":
        {
          if (vt.isEmpty) {
            return "URL name cannot be empty";
          }
          if (vt.length < 8 || !vt.toLowerCase().startsWith("http://")) {
            return "Invalid URL. Must start http://";
          }
          break;
        }
      case "DIR":
        {
          if (vt.isEmpty) {
            return "Directory name cannot be empty";
          }
          final exist = Directory(vt).existsSync();
          if (!exist) {
            return "Directory does not exist";
          }
          break;
        }
      case "FILE":
        {
          if (vt.isEmpty) {
            return "File name cannot be empty";
          }
          break;
        }
    }
    return onValidate(value, detail);
  }

  List<SettingControl> createSettingsControlList() {
    final c = List<SettingControl>.empty(growable: true);
    for (var settingDetail in _settingsData) {
      if (_isDesktop || settingDetail.desktopOnly) {
        c.add(SettingControl(settingDetail, DataLoad.getStringFromJson(getJson(), settingDetail.path, fallback: settingDetail.fallback)));
      }
    }
    return c;
  }

  List<Widget> getSettingsWidgets(Key? key, AppThemeData appThemeData, List<SettingControl> settingsControl, String Function(String, SettingDetail) onValidate) {
    final l = List<Widget>.empty(growable: true);
    for (var scN in settingsControl) {
      if (_isDesktop || scN.detail.desktopOnly) {
        l.add(
          Card(
            margin: EdgeInsetsGeometry.lerp(null, null, 5),
            child: ConfigInputField(
              key: key,
              settingsControl: scN,
              appThemeData: appThemeData,
              onChanged: (val, ocSc) {
                final msg = _initialValidate(val, ocSc.detail, onValidate);
                ocSc.error = msg.isNotEmpty;
                return msg;
              },
            ),
          ),
        );
      }
    }
    return l;
  }
}

class ConfigInputField extends StatefulWidget {
  const ConfigInputField({super.key, required this.settingsControl, required this.onChanged, required this.appThemeData});
  final SettingControl settingsControl;
  final String Function(String, SettingControl) onChanged;
  final AppThemeData appThemeData;
  @override
  State<ConfigInputField> createState() => _ConfigInputFieldState();
}

class _ConfigInputFieldState extends State<ConfigInputField> {
  String help = "";
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final h = help.isEmpty ? widget.settingsControl.detail.hint : "Error: $help";
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: widget.appThemeData.primary.shade300,
          child: ListTile(
            leading: (widget.settingsControl.changed || help.isNotEmpty) ? const Icon(Icons.radio_button_checked) : const Icon(Icons.radio_button_unchecked),
            title: Text(widget.settingsControl.detail.title, style: widget.appThemeData.tsLarge),
            subtitle: Text(h, style: help.isEmpty ? widget.appThemeData.tsSmall : widget.appThemeData.tsSmallError),
          ),
        ),
        Container(
          color: Colors.black,
          height: 2,
        ),
        Container(
          color: widget.appThemeData.primary.shade100,
          padding: const EdgeInsets.all(5.0),
          child: TextField(
            controller: widget.settingsControl.controller,
            style: help.isEmpty ? widget.appThemeData.tsMedium : widget.appThemeData.tsMediumError,
            onChanged: (newValue) {
              setState(() {
                help = widget.onChanged(newValue, widget.settingsControl);
              });
            },
            decoration: const InputDecoration.collapsed(hintText: "Value"),
          ),
        ),
      ],
    );
  }
}
