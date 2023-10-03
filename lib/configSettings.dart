import 'dart:async';
import 'dart:io';
import 'package:data_repo/detail_buttons.dart';
import 'package:flutter/material.dart';
import 'data_container.dart';
import 'path.dart';
import 'config.dart';

enum SettingDetailType { url, dir, file, int, bool, color, name }

enum _SettingState { ok, warning, error }

final List<SettingDetail> _settingsData = [
  SettingDetail("get", "Server URL (Download)", "Download address of the host server", getDataUrlPath, SettingDetailType.url, defaultRemoteGetUrl, true),
  SettingDetail("put", "Server URL (Upload)", "Upload address of the host server", postDataUrlPath, SettingDetailType.url, defaultRemotePostUrl, true),
  SettingDetail("path", "Local Data file path", "The directory for the data file", dataFileLocalDirPath, SettingDetailType.dir, defaultDataEmptyString, false),
  // SettingDetail("data", "Data file Name", "The name of the server file", dataFileLocalNamePath, SettingDetailType.file, defaultDataEmptyString, true),
  SettingDetail("rootNodeName", "Root Node Name", "Replace the root node name with this", rootNodeNamePath, SettingDetailType.name, defaultDataEmptyString, true),
  SettingDetail("timeout", "Server Timeout Milliseconds", "The host server timeout", dataFetchTimeoutMillisPath, SettingDetailType.int, defaultFetchTimeoutMillis.toString(), false),
  SettingDetail("", "Screen Text & Icons", "Icons/Text White or Black. Click below to change", appColoursDarkMode, SettingDetailType.bool, defaultDarkMode, true, trueValue: "Currently White", falseValue: "Currently Black"),
  SettingDetail("", "Primary Colour", "The main colour theme", appColoursPrimaryPath, SettingDetailType.color, defaultPrimaryColour, true),
  SettingDetail("", "Preview Colour", "The Markdown 'Preview' colour", appColoursSecondaryPath, SettingDetailType.color, defaultSecondaryColour, true),
  SettingDetail("", "Help Colour", "The Markdown 'Help' colour", appColoursHiLightPath, SettingDetailType.color, defaultHiLightColour, true),
  SettingDetail("", "Error Colour", "The Error colour theme", appColoursErrorPath, SettingDetailType.color, defaultErrorColour, true),
];

class SettingValidation {
  final _SettingState _state;
  final String _message;
  SettingValidation._(this._state, this._message);

  factory SettingValidation.ok() {
    return SettingValidation._(_SettingState.ok, "");
  }
  factory SettingValidation.error(String m) {
    return SettingValidation._(_SettingState.error, m);
  }
  factory SettingValidation.warning(String m) {
    return SettingValidation._(_SettingState.warning, m);
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
      case _SettingState.warning:
        return "Warning: $_message";
      case _SettingState.error:
        return "Error: $_message";
      default:
        return okMessage;
    }
  }

  bool get isError {
    return (_state == _SettingState.error);
  }

  bool get isNotError {
    return (_state != _SettingState.error);
  }

  bool isNotEqual(final SettingValidation other) {
    return (_state != other._state) || (_message != other._message);
  }

  bool get isNotOk {
    return (_state != _SettingState.ok);
  }

  TextStyle hintStyle(AppThemeData appThemeData) {
    switch (_state) {
      case _SettingState.warning:
        return appThemeData.tsSmallError;
      case _SettingState.error:
        return appThemeData.tsLargeError;
      default:
        return appThemeData.tsSmall;
    }
  }

  TextStyle textStyle(AppThemeData appThemeData) {
    switch (_state) {
      case _SettingState.error:
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
  final void Function(SettingControlList, String) onUpdateState;
  final String hint;
  final double width;

  const ConfigInputPage({
    super.key,
    required this.appThemeData,
    required this.settingsControlList,
    required this.onValidate,
    required this.onUpdateState,
    required this.hint,
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

  void updateState() {
    setState(() {
      widget.onUpdateState(widget.settingsControlList, widget.hint);
    });
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
      final String scDataValue;
      if (scData == null) {
        sv = SettingValidation.warning("Setting 'get' setting not found");
        scDataValue = "NUL";
      } else {
        scDataValue = scData.stringValue;
      }
      if (sv.isNotError) {
        final response = await DataContainer.testHttpGet("${scGet.stringValue}/$scDataValue", "File: $scDataValue.");
        if (response.isNotEmpty) {
          sv = SettingValidation.warning(response);
        }
      }
      if (scGet.validationState.isNotEqual(sv)) {
        scGet.validationState = sv;
        updateState();
      }
    });

    final settingsWidgetsList = createSettingsWidgets(
      null,
      widget.appThemeData,
      widget.settingsControlList,
      widget.hint,
      (newValue, settingDetail) {
        debugPrint("Page:OnValidate $newValue");
        return widget.onValidate(newValue, settingDetail);
      },
    );

    return SizedBox(
      width: widget.width,
      child: ListView(
        children: settingsWidgetsList,
      ),
    );
  }

  List<Widget> createSettingsWidgets(Key? key, AppThemeData appThemeData, SettingControlList settingsControlList, String hint, SettingValidation Function(dynamic, SettingDetail) onValidate) {
    final l = List<Widget>.empty(growable: true);
    if (hint.isNotEmpty) {
      l.add(
        Card(
          color: appThemeData.detailBackgroundColor,
          margin: EdgeInsetsGeometry.lerp(null, null, 5),
          child: Text(hint, style: appThemeData.tsLargeError),
        ),
      );
    }
    for (var scN in settingsControlList.list) {
      if (widget.appThemeData.desktop || scN.detail.desktopOnly) {
        l.add(
          Card(
            margin: EdgeInsetsGeometry.lerp(null, null, 5),
            child: ConfigInputSection(
              key: key,
              settingsControl: scN,
              appThemeData: appThemeData,
              onValidation: (newValue, settingControl) {
                settingControl.stringValue = newValue;
                settingControl.validationState = _initialValidate(newValue, settingControl.detail, settingsControlList, onValidate);
                updateState();
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
  const ConfigInputSection({super.key, required this.settingsControl, required this.onValidation, required this.appThemeData});
  final SettingControl settingsControl;
  final void Function(String, SettingControl) onValidation;
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
        _configInputField(widget.settingsControl.detail.detailType, (value) {
          widget.onValidation(value, widget.settingsControl);
        }),
        Container(
          color: widget.appThemeData.screenForegroundColour(true),
          height: 1,
        ),
      ],
    );
  }

  Widget _configInputField(SettingDetailType type, void Function(String) onChanged) {
    if (type == SettingDetailType.bool) {
      final set = _stringToBool(widget.settingsControl.stringValue);
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
                final newValue = (!set).toString();
                onChanged(newValue);
              },
            ),
          ],
        ),
      );
    }

    if (type == SettingDetailType.color) {
      final p = widget.appThemeData.getColorPalletForName(widget.settingsControl.stringValue);
      return Container(
        color: p.med,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(5.0),
        child: DetailButton(
          appThemeData: widget.appThemeData,
          text: "Select Colour",
          onPressed: () {
            onChanged(widget.settingsControl.detail.title);
          },
        ),
        // child: DropdownButton(
        //   items: _createDropDownColorList(widget.appThemeData),
        //   isDense: true,
        //   elevation: 16,
        //   dropdownColor: widget.appThemeData.dialogBackgroundColor,
        //   value: widget.settingsControl.stringValue,
        //   style: widget.appThemeData.tsLarge,
        //   underline: const SizedBox(
        //     height: 0,
        //   ),
        //   iconSize: widget.appThemeData.tsLarge.fontSize! * 1.5,
        //   iconEnabledColor: widget.appThemeData.screenForegroundColour(true),
        //   onChanged: (newValue) {
        //     onChanged(newValue!);
        //   },
        // ),
      );
    }

    return Container(
      color: widget.appThemeData.primary.med,
      padding: const EdgeInsets.all(5.0),
      child: TextField(
        controller: widget.settingsControl.getTextController,
        style: widget.settingsControl.validationState.textStyle(widget.appThemeData),
        onChanged: (newValue) {
          onChanged(newValue);
        },
        cursorColor: widget.appThemeData.cursorColor,
        decoration: const InputDecoration.collapsed(hintText: "Value"),
      ),
    );
  }
}

class SettingDetail {
  final String id;
  final String title;
  final String hint;
  final Path path;
  final SettingDetailType detailType; // BOOL, INT or other. Used for validation/conversion
  final String fallback; // The value if not defined in the config data.
  final bool desktopOnly; // Only applies to the desktop
  final String trueValue; // The text value if true
  final String falseValue; // The text value if false
  final Function(SettingDetail) onSet
  const SettingDetail(this.id, this.title, this.hint, this.path, this.detailType, this.fallback, this.desktopOnly, {this.trueValue = "", this.falseValue = ""});
}

class SettingControlList {
  late final List<SettingControl> list;
  final String dataFileDir;
  SettingControlList(final bool isDeskTop, this.dataFileDir, final ConfigData configData) {
    list = List<SettingControl>.empty(growable: true);
    for (var settingDetail in _settingsData) {
      if (isDeskTop || settingDetail.desktopOnly) {
        switch (settingDetail.detailType) {
          case SettingDetailType.bool:
            list.add(SettingControl(settingDetail, configData.getBoolFromJson(settingDetail.path, fallback: _stringToBool(settingDetail.fallback)).toString()));
            break;
          case SettingDetailType.int:
            list.add(SettingControl(settingDetail, configData.getNumFromJson(settingDetail.path, fallback: num.parse(settingDetail.fallback)).toString()));
            break;
          default:
            list.add(SettingControl(settingDetail, configData.getStringFromJsonOptional(settingDetail.path)));
        }
      }
    }
  }

  String getValueForId(String id) {
    final e = getSettingControlForId(id);
    if (e != null) {
      return e.stringValue;
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

  void commit(ConfigData configData, {void Function(String)? log}) {
    if (canSaveOrApply) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].changed) {
          final sc = list[i];
          if (log != null) {
            log("__CONFIG__ Changed:'${list[i].detail.title}' From:'${list[i].oldValue}' To:'${list[i].stringValue}'");
          }
          configData.setValueForJsonPath(sc.detail.path, sc.dynamicValue);
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

class SettingControl {
  final SettingDetail detail;
  final String oldValue;
  TextEditingController? _controller;
  SettingValidation validationState = SettingValidation.ok();
  String _currentValue = "";

  SettingControl(this.detail, this.oldValue) {
    _currentValue = oldValue;
  }

  String getBoolString(bool set) {
    if (set) {
      return detail.trueValue;
    }
    return detail.falseValue;
  }

  dynamic get dynamicValue {
    if (detail.detailType == SettingDetailType.bool) {
      return (stringValue.toLowerCase() == "true");
    }
    if (detail.detailType == SettingDetailType.int) {
      return (num.parse(stringValue));
    }
    return stringValue;
  }

  set stringValue(dynamic v) {
    _currentValue = v.toString();
  }

  String get stringValue {
    return _currentValue.trim();
  }

  TextEditingController get getTextController {
    if (_controller == null) {
      _controller = TextEditingController();
      _controller!.text = _currentValue;
    }
    return _controller!;
  }

  bool get changed {
    return oldValue.trim() != stringValue;
  }

  @override
  String toString() {
    return "id:${detail.id} ${validationState.name.toUpperCase()}: ${changed ? '*' : ''} Old:'$oldValue' New:'$stringValue' Path:${detail.path} ";
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
    case SettingDetailType.int:
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
    case SettingDetailType.bool:
      {
        if (value != "true" && value != "false") {
          return SettingValidation.error("true or false");
        }
        break;
      }
    case SettingDetailType.color:
      {
        if (!colourNames.containsKey(value)) {
          return SettingValidation.error("Invalid Colour Name");
        }
        break;
      }
    case SettingDetailType.url:
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
    case SettingDetailType.dir:
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
    case SettingDetailType.file:
      {
        if (vt.isEmpty) {
          return SettingValidation.error("File name cannot be empty");
        }
        var pathSetting = controlList.getValueForId("path");
        if (pathSetting.isEmpty) {
          pathSetting = controlList.dataFileDir;
        }
        final fn = "$pathSetting${Platform.pathSeparator}$vt";
        if (!File(fn).existsSync()) {
          return SettingValidation.error("Local file not found");
        }
        break;
      }
  }
  return onValidate(value, detail);
}
