import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'data_load.dart';
import 'detail_buttons.dart';
import 'path.dart';
import 'config.dart';

final List<SettingDetail> _settingsData = [
//  SettingDetail("User Name", "The users proper name", userNamePath, "ES", "User", true),
  SettingDetail("get", "Server URL (Download)", "Download address of the host server", getDataUrlPath, "URL", defaultRemoteGetUrl, true),
  SettingDetail("put", "Server URL (Upload)", "Upload address of the host server", postDataUrlPath, "URL", defaultRemotePostUrl, true),
  SettingDetail("path", "Local Data file path", "The directory for the data file", dataFileLocalDirPath, "DIR", defaultDataFilePath, false),
  SettingDetail("data", "Data file Name", "The name of the server file", dataFileLocalNamePath, "FILE", defaultDataFilePath, true),
  SettingDetail("timeout", "Server Timeout Milliseconds", "The host server timeout", dataFetchTimeoutMillisPath, "INT", defaultFetchTimeoutMillis.toString(), false),
  SettingDetail("", "Screen Mode", "Icons/Text White or Black. Click below to change", appColoursDarkMode, "BOOL", defaultDarkMode, true, trueValue: "Currently Light", falseValue: "Currently Dark"),
  SettingDetail("", "Primary Colour", "The main colour theme", appColoursPrimaryPath, "COLOUR", defaultPrimaryColour, true),
  SettingDetail("", "Preview Colour", "The Markdown 'Preview' colour", appColoursSecondaryPath, "COLOUR", defaultSecondaryColour, true),
  SettingDetail("", "Help Colour", "The Markdown 'Help' colour", appColoursHiLightPath, "COLOUR", defaultHiLightColour, true),
  SettingDetail("", "Error Colour", "The Error colour theme", appColoursErrorPath, "COLOUR", defaultErrorColour, true),
];

enum SettingState { ok, warning, error }

class SettingValidation {
  final SettingState _state;
  final String _message;
  SettingValidation._(this._state, this._message);

  factory SettingValidation.ok() {
    return SettingValidation._(SettingState.ok, "");
  }
  factory SettingValidation.error(String m) {
    return SettingValidation._(SettingState.error, m);
  }
  factory SettingValidation.warning(String m) {
    return SettingValidation._(SettingState.warning, m);
  }

  @override
  String toString() {
    return "Message:${message('OK')}. State:${_state.name}";
  }

  String get name {
    return _state.name;
  }

  String message(String okMessage) {
    switch (_state) {
      case SettingState.warning:
        return "Warning: $_message";
      case SettingState.error:
        return "Error: $_message";
      default:
        return okMessage;
    }
  }

  bool get isError {
    return (_state == SettingState.error);
  }

  bool get isNotError {
    return (_state != SettingState.error);
  }

  bool isNotEqual(final SettingValidation other) {
    return (_state != other._state) || (_message != other._message);
  }

  bool get isNotOk {
    return (_state != SettingState.ok);
  }

  TextStyle hintStyle(AppThemeData appThemeData) {
    switch (_state) {
      case SettingState.warning:
        return appThemeData.tsSmallError;
      case SettingState.error:
        return appThemeData.tsLargeError;
      default:
        return appThemeData.tsSmall;
    }
  }

  TextStyle textStyle(AppThemeData appThemeData) {
    switch (_state) {
      case SettingState.error:
        return appThemeData.tsLargeError;
      default:
        return appThemeData.tsLarge;
    }
  }

  Text hintText(String okMessage, AppThemeData appThemeData) {
    return Text(message(okMessage), style: hintStyle(appThemeData));
  }
}

class ConfigInputPage extends StatefulWidget {
  final AppThemeData appThemeData;
  final SettingControlList settingsControlList;
  final SettingValidation Function(String, SettingDetail) onValidate;
  final void Function(SettingControlList, bool) onCommit;
  final String Function(bool) stateFileData;
  final double height;
  final double width;

  const ConfigInputPage({
    super.key,
    required this.appThemeData,
    required this.settingsControlList,
    required this.onValidate,
    required this.onCommit,
    required this.stateFileData,
    required this.height,
    required this.width,
  });

  @override
  State<ConfigInputPage> createState() => _ConfigInputPageState();
}

class _ConfigInputPageState extends State<ConfigInputPage> {
  Timer? countdownTimer;

  @override
  void dispose() {
    if (countdownTimer != null) {
      countdownTimer!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (countdownTimer != null) {
      countdownTimer!.cancel();
    }
    countdownTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      SettingValidation sv = SettingValidation.ok();
      final scGet = widget.settingsControlList.getSettingControlForId("get");
      if (scGet == null) {
        return;
      }
      if (scGet.validationState.isError) {
        return;
      }
      final scData = widget.settingsControlList.getSettingControlForId("data");
      if (scData == null) {
        sv = SettingValidation.warning("Setting 'get' setting not found");
      }
      if (sv.isNotError) {
        final response = await DataLoad.testHttpGet("${scGet.getStringValue}/${scData!.getStringValue}","File: ${scData!.getStringValue}." );
        if (response.isNotEmpty) {
          sv = SettingValidation.warning(response);
        }
      }
      if (scGet.validationState.isNotEqual(sv)) {
        setState(() {
          scGet.validationState = sv;
        });
      }
    });

    final canSaveOrApply = widget.settingsControlList.canSaveOrApply;
    final settingsWidgetsList = createSettingsWidgets(
      null,
      widget.appThemeData,
      widget.settingsControlList,
      (stringValue, settingDetail) {
        setState(() {});
        return widget.onValidate(stringValue, settingDetail);
      },
    );
    final stateFilePath = widget.stateFileData(false);
    settingsWidgetsList.insert(
        0,
        DetailButton(
            show: stateFilePath.isNotEmpty,
            onPressed: () {
              setState(() {
                widget.stateFileData(true);
              });
            },
            text: "Clear saved GUI data & Searches",
            appThemeData: widget.appThemeData));
    final scrollContainer = Container(
      width: widget.width,
      height: widget.height,
      color: widget.appThemeData.dialogBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          children: settingsWidgetsList,
        ),
      ),
    );
    final buttons = Row(
      children: [
        DetailButton(
          show: canSaveOrApply,
          text: "SAVE",
          appThemeData: widget.appThemeData,
          onPressed: () {
            widget.onCommit(widget.settingsControlList, true);
          },
        ),
        DetailButton(
          show: canSaveOrApply,
          text: "APPLY",
          appThemeData: widget.appThemeData,
          onPressed: () {
            widget.onCommit(widget.settingsControlList, false);
          },
        ),
        DetailButton(
          text: "CANCEL",
          appThemeData: widget.appThemeData,
          onPressed: () {
            widget.settingsControlList.clear();
            widget.onCommit(widget.settingsControlList, false);
          },
        ),
      ],
    );
    return Column(
      children: [
        scrollContainer,
        const SizedBox(
          height: 10,
        ),
        buttons
      ],
    );
  }

  List<Widget> createSettingsWidgets(Key? key, AppThemeData appThemeData, SettingControlList settingsControlList, SettingValidation Function(String, SettingDetail) onValidate) {
    final l = List<Widget>.empty(growable: true);
    for (var scN in settingsControlList.list) {
      if (widget.appThemeData.desktop || scN.detail.desktopOnly) {
        l.add(
          Card(
            margin: EdgeInsetsGeometry.lerp(null, null, 5),
            child: ConfigInputSection(
              key: key,
              settingsControl: scN,
              appThemeData: appThemeData,
              onChanged: (val, ocSc) {
                final sv = _initialValidate(val, ocSc.detail, settingsControlList, onValidate);
                setState(() {
                  ocSc.validationState = sv;
                });
                return sv;
              },
            ),
          ),
        );
      }
    }
    return l;
  }
}

class ConfigInputSection extends StatefulWidget {
  const ConfigInputSection({super.key, required this.settingsControl, required this.onChanged, required this.appThemeData});
  final SettingControl settingsControl;
  final SettingValidation Function(String, SettingControl) onChanged;
  final AppThemeData appThemeData;
  @override
  State<ConfigInputSection> createState() => _ConfigInputSectionState();
}

class _ConfigInputSectionState extends State<ConfigInputSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: widget.appThemeData.primary.light,
          child: ListTile(
            leading: (widget.settingsControl.changed) ? Icon(Icons.star, color: widget.appThemeData.screenForegroundColour(true)) : Icon(Icons.radio_button_unchecked, color: widget.appThemeData.screenForegroundColour(false)),
            title: Text(widget.settingsControl.detail.title, style: widget.appThemeData.tsLarge),
            subtitle: widget.settingsControl.validationState.hintText(widget.settingsControl.detail.hint, widget.appThemeData),
          ),
        ),
        _configInputField(widget.settingsControl.detail.detailType),
        Container(
          color: widget.appThemeData.screenForegroundColour(true),
          height: 1,
        ),
      ],
    );
  }

  Widget _configInputField(String type) {
    if (type == "BOOL") {
      final set = _stringToBool(widget.settingsControl.getStringValue);
      final iconData = set ? Icon(Icons.circle_outlined, color: widget.appThemeData.screenForegroundColour(true)) : Icon(Icons.circle_rounded, color: widget.appThemeData.screenForegroundColour(true));
      return Container(
        color: widget.appThemeData.primary.med,
        padding: const EdgeInsets.all(5.0),
        child: Row(
          children: [
            Text(widget.settingsControl.getBoolString(set), style: widget.appThemeData.tsLarge),
            IconButton(
              icon: iconData,
              onPressed: () {
                final val = (!set).toString();
                widget.settingsControl.validationState = widget.onChanged(val, widget.settingsControl);
                if (widget.settingsControl.validationState.isNotError) {
                  widget.settingsControl.setStringValue(val);
                }
              },
            ),
          ],
        ),
      );
    }

    if (type == "COLOUR") {
      final p = widget.appThemeData.getColorPalletForName(widget.settingsControl.getStringValue);
      return Container(
        color: p.med,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(5.0),
        child: DropdownButton(
          items: _createDropDownColorList(widget.appThemeData),
          isDense: true,
          elevation: 16,
          dropdownColor: widget.appThemeData.dialogBackgroundColor,
          value: widget.settingsControl.getStringValue,
          style: widget.appThemeData.tsLarge,
          underline: const SizedBox(
            height: 0,
          ),
          iconSize: widget.appThemeData.tsLarge.fontSize! * 1.5,
          iconEnabledColor: widget.appThemeData.screenForegroundColour(true),
          onChanged: (newValue) {
            widget.settingsControl.validationState = widget.onChanged(newValue!, widget.settingsControl);
            if (widget.settingsControl.validationState.isNotError) {
              widget.settingsControl.setStringValue(newValue);
            }
          },
        ),
      );
    }
    return Container(
      color: widget.appThemeData.primary.med,
      padding: const EdgeInsets.all(5.0),
      child: TextField(
        controller: widget.settingsControl.getTextController,
        style: widget.settingsControl.validationState.textStyle(widget.appThemeData),
        onChanged: (newValue) {
          widget.settingsControl.validationState = widget.onChanged(newValue, widget.settingsControl);
        },
        cursorColor: widget.appThemeData.cursorColor,
        decoration: const InputDecoration.collapsed(hintText: "Value"),
      ),
    );
  }
}

class SettingControlList {
  late final List<SettingControl> list;
  SettingControlList(final bool isDeskTop, final dynamic configJson) {
    list = List<SettingControl>.empty(growable: true);
    for (var settingDetail in _settingsData) {
      if (isDeskTop || settingDetail.desktopOnly) {
        switch (settingDetail.detailType) {
          case "BOOL":
            list.add(SettingControl(settingDetail, DataLoad.getBoolFromJson(configJson, settingDetail.path, fallback: _stringToBool(settingDetail.fallback)).toString()));
            break;
          case "INT":
            list.add(SettingControl(settingDetail, DataLoad.getNumFromJson(configJson, settingDetail.path, fallback: num.parse(settingDetail.fallback)).toString()));
            break;
          default:
            list.add(SettingControl(settingDetail, DataLoad.getStringFromJson(configJson, settingDetail.path, fallback: settingDetail.fallback)));
        }
      }
    }
  }

  String getValueForId(String id) {
    final e = getSettingControlForId(id);
    if (e != null) {
      return e.getStringValue;
    }
    return "";
  }

  SettingControl? getSettingControlForId(String id) {
    for (var element in list) {
      if (element.detail.id == id) {
        return element;
      }
    }
    return null;
  }

  void commit(Map<String, dynamic> json) {
    if (canSaveOrApply) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].changed) {
          final sc = list[i];
          DataLoad.setValueForJsonPath(json, sc.detail.path, sc.dynamicValue);
        }
      }
    }
  }

  bool get isNotEmpty {
    return list.isNotEmpty;
  }

  void clear() {
    list.clear();
  }

  bool get canSaveOrApply {
    return hasNoErrors && hasChanges && isNotEmpty;
  }

  bool get hasNoErrors {
    for (final c in list) {
      if (c.validationState.isError) {
        return false;
      }
    }
    return true;
  }

  bool get hasChanges {
    for (final c in list) {
      if (c.changed) {
        return true;
      }
    }
    return false;
  }
}

class SettingDetail {
  final String id;
  final String title;
  final String hint;
  final Path path;
  final String detailType; // BOOL, INT or other. Used for validation/conversion
  final String fallback; // The value if not defined in the config data.
  final bool desktopOnly; // Only applies to the desktop
  final String trueValue; // The text value if true
  final String falseValue; // The text value if false

  const SettingDetail(this.id, this.title, this.hint, this.path, this.detailType, this.fallback, this.desktopOnly, {this.trueValue = "", this.falseValue = ""});
}

class SettingControl {
  final SettingDetail detail;
  final String oldValue;
  final _controller = TextEditingController();
  SettingValidation validationState = SettingValidation.ok();

  SettingControl(this.detail, this.oldValue) {
    _controller.text = oldValue;
  }

  String getBoolString(bool set) {
    if (set) {
      return detail.trueValue;
    }
    return detail.falseValue;
  }

  dynamic get dynamicValue {
    if (detail.detailType == "BOOL") {
      return (getStringValue.toLowerCase() == "true");
    }
    if (detail.detailType == "INT") {
      return (num.parse(getStringValue));
    }
    return getStringValue;
  }

  String get getStringValue {
    return _controller.text.trim();
  }

  TextEditingController get getTextController {
    return _controller;
  }

  void setStringValue(String s) {
    _controller.text = s;
  }

  bool get changed {
    return oldValue.trim() != getStringValue;
  }

  @override
  String toString() {
    return "${validationState.name.toUpperCase()}: ${changed ? '*' : ''} Old:'$oldValue' New:'$getStringValue' Path:${detail.path} ";
  }
}

List<DropdownMenuItem<String>> _createDropDownColorList(AppThemeData appThemeData) {
  final List<DropdownMenuItem<String>> dll = List.empty(growable: true);
  for (var element in colourNames.keys) {
    dll.add(DropdownMenuItem<String>(
      value: element,
      child: Text(
        element,
        style: appThemeData.tsLarge,
      ),
    ));
  }
  return dll;
}

bool _stringToBool(String text) {
  final txt = text.trim().toLowerCase();
  if (txt == "true" || txt == "yes") {
    return true;
  }
  return false;
}

SettingValidation _initialValidate(String value, SettingDetail detail, SettingControlList controlList, SettingValidation Function(String, SettingDetail) onValidate) {
  final vt = value.trim();
  switch (detail.detailType) {
    case "INT":
      {
        try {
          final v = num.parse(value);
          if (v is! int) {
            return SettingValidation.error("Should be an integer");
          }
        } catch (e) {
          return SettingValidation.error("Invalid number");
        }
        break;
      }
    case "BOOL":
      {
        if (value != "true" && value != "false") {
          return SettingValidation.error("true or false");
        }
        break;
      }
    case "COLOUR":
      {
        if (!colourNames.containsKey(value)) {
          return SettingValidation.error("Invalid Colour Name");
        }
        break;
      }
    case "URL":
      {
        if (vt.isEmpty) {
          return SettingValidation.error("URL name cannot be empty");
        }
        try {
          Uri.parse(vt);
        } catch (e) {
          return SettingValidation.error("Could not parse URL");
        }
        if (!vt.toLowerCase().startsWith("http://") && !vt.toLowerCase().startsWith("https://")) {
          return SettingValidation.error("URL must start http:// or https://");
        }
        break;
      }
    case "DIR":
      {
        if (vt.isEmpty) {
          return SettingValidation.error("Directory name cannot be empty");
        }
        final exist = Directory(vt).existsSync();
        if (!exist) {
          return SettingValidation.error("Directory does not exist");
        }
        break;
      }
    case "FILE":
      {
        if (vt.isEmpty) {
          return SettingValidation.error("File name cannot be empty");
        }
        final pathSetting = controlList.getValueForId("path");
        if (pathSetting.isNotEmpty) {
          final fn = "$pathSetting${Platform.pathSeparator}$vt";
          if (!File(fn).existsSync()) {
            return SettingValidation.error("Local file not found");
          }
        }
        break;
      }
  }
  return onValidate(value, detail);
}
