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
import 'package:data_repo/data_types.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'detail_buttons.dart';
import 'colour_pecker.dart';
import 'data_container.dart';
import 'path.dart';
import 'config.dart';

enum SettingDetailType { host, url, dir, file, int, double, bool, color, name }
enum SettingDetailId { host, get, put, test, path, data, rootNodeName, timeout, primaryColor, secondaryColor, helpColor, errorColor, ignore}

enum SettingState { ok, warning, error }

const List<String> _mustContainData = ["/", "%dataFileName%"];
const List<String> _mustContainTest = ["/", "%testFileName%"];
const List<String> _mustContainDefault = [];

final List<SettingDetail> _settingsData = [
  SettingDetail(SettingDetailId.host, "Server URL", "E.G. http://192.168.1.243:8080", getServerPathPath, SettingDetailType.host, defaultServerPath, true),
  SettingDetail(SettingDetailId.get, "Server URL (Download)", "Read Data URL", getDataUrlPath, SettingDetailType.url, defaultRemoteGetUrl, true, mustContain: _mustContainData),
  SettingDetail(SettingDetailId.put, "Server URL (Upload)", "Write Data URL", postDataUrlPath, SettingDetailType.url, defaultRemotePostUrl, true, mustContain: _mustContainData),
  SettingDetail(SettingDetailId.test, "Server URL (Test)", "Test Data URL. File:$defaultRemoteTestFileName", getTestFileUrlPath, SettingDetailType.url, defaultRemoteTestFileUrl, true, mustContain: _mustContainTest),
  SettingDetail(SettingDetailId.path, "Local Data file path", "GET List data URL", dataFileLocalDirPath, SettingDetailType.dir, defaultDataEmptyString, false),
  SettingDetail(SettingDetailId.data, "Data file Name", "Now set from the main screen!", dataFileLocalNamePath, SettingDetailType.file, defaultDataEmptyString, true, hide: true),
  SettingDetail(SettingDetailId.rootNodeName, "Root Node Name", "Replace the root node name with this", appRootNodeNamePathC, SettingDetailType.name, defaultDataEmptyString, true),
  SettingDetail(SettingDetailId.timeout, "Server Timeout Milliseconds", "The host server timeout 100..5000", dataFetchTimeoutMillisPath, SettingDetailType.int, defaultFetchTimeoutMillis.toString(), false, minValue: 100, maxValue: 5000),
  SettingDetail(SettingDetailId.ignore, "Screen Text & Icons", "Icons/Text White or Black. Click below to change", appDarkModePathC, SettingDetailType.bool, "$defaultDarkMode", true, trueValue: "Currently White", falseValue: "Currently Black"),
  SettingDetail(SettingDetailId.ignore, "Hide Data Info", "Compact mode. Hide 'Owned By'", hideDataPathPathC, SettingDetailType.bool, "$defaultHideDataPath", false, trueValue: "Currently Hide", falseValue: "Currently Show"),
  SettingDetail(SettingDetailId.ignore, "Screen Text Scale", "Text Scale. 0.5..2.0", appTextScalePath, SettingDetailType.double, "1.0", true, minValue: 0.5, maxValue: 2.0),
  SettingDetail(SettingDetailId.primaryColor, "Primary Colour", "The main colour theme", appColoursPrimaryPathC, SettingDetailType.color, defaultPrimaryColourName, true),
  SettingDetail(SettingDetailId.secondaryColor, "Preview Colour", "The Markdown 'Preview' colour", appColoursSecondaryPathC, SettingDetailType.color, defaultSecondaryColourName, true),
  SettingDetail(SettingDetailId.helpColor, "Help Colour", "The Markdown 'Help' colour", appColoursHiLightPathC, SettingDetailType.color, defaultHiLightColourName, true),
  SettingDetail(SettingDetailId.errorColor, "Error Colour", "The Error colour theme", appColoursErrorPathC, SettingDetailType.color, defaultErrorColourName, true),
];

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
  factory SettingValidation.mustContain(String m, List<String> mustContain) {
    for (int i = 0; i < mustContain.length; i++) {
      if (!m.contains(mustContain[i])) {
        return SettingValidation._(SettingState.error, "Must contain ${mustContain[i]}");
      }
    }
    return SettingValidation._(SettingState.ok, "");
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
        return appThemeData.tsMediumError;
      case SettingState.error:
        return appThemeData.tsLargeError;
      default:
        return appThemeData.tsMedium;
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
  final void Function(SettingControlList, String) onUpdateState;
  final String hint;
  final double width;
  final void Function(String) log;

  const ConfigInputPage({
    super.key,
    required this.appThemeData,
    required this.settingsControlList,
    required this.onValidate,
    required this.onUpdateState,
    required this.hint,
    required this.width,
    required this.log,
  });

  @override
  State<ConfigInputPage> createState() => _ConfigInputPageState();
}

class _ConfigInputPageState extends State<ConfigInputPage> {
  bool testErrorNotLogged = true;
  bool getErrorNotLogged = true;
  Timer? countdownTimer;

  @override
  void dispose() {
    if (countdownTimer != null) {
      countdownTimer!.cancel();
    }
    super.dispose();
  }

  void updateState() {
    if (mounted) {
      setState(() {
        widget.onUpdateState(widget.settingsControlList, widget.hint);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (countdownTimer != null) {
      countdownTimer!.cancel();
    }
    countdownTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      SettingValidation svTest = SettingValidation.ok();
      SettingValidation svGet = SettingValidation.ok();
      var dataError = "";
      final scHost = widget.settingsControlList.getSettingControlForId(SettingDetailId.host);
      if (scHost == null) {
        dataError = "${dataError}host, ";
      }
      final scTestGet = widget.settingsControlList.getSettingControlForId(SettingDetailId.test);
      if (scTestGet == null) {
        dataError = "${dataError}test, ";
      }
      final scGet = widget.settingsControlList.getSettingControlForId(SettingDetailId.get);
      if (scGet == null) {
        dataError = "${dataError}get, ";
      }
      final scFileName = widget.settingsControlList.getSettingControlForId(SettingDetailId.data);
      if (scFileName == null) {
        dataError = "${dataError}data, ";
      }
      if (dataError.isNotEmpty) {
        dataError = "__VALIDATE SETTINGS__ settings [${dataError.substring(0, dataError.length - 2)}] not found";
        widget.log(dataError);
        return;
      }

      final pathTest = widget.settingsControlList.substituteForUrl(scTestGet!.stringValue);
      final pathGet = widget.settingsControlList.substituteForUrl(scGet!.stringValue);

      await DataContainer.testHttpGet(pathTest, prefix: "Remote Test File: '$defaultRemoteTestFileName'  ", (resp) {
        if (resp.isNotEmpty) {
          if (testErrorNotLogged) {
            widget.log("__VALIDATE SETTINGS__ 'Test url' $resp");
            testErrorNotLogged = false;
          }
          svTest = SettingValidation.warning(resp);
        }
      });
      if (scTestGet.validationState.isNotEqual(svTest)) {
        scTestGet.validationState = svTest;
        updateState();
      }

      await DataContainer.testHttpGet(pathGet, prefix: "Remote File: '${scFileName!.stringValue}'  ", (resp) {
        if (resp.isNotEmpty) {
          if (getErrorNotLogged) {
            widget.log("__VALIDATE SETTINGS__ 'Get url' $resp");
            getErrorNotLogged = false;
          }
          svGet = SettingValidation.warning(resp);
        }
      });
      if (scGet.validationState.isNotEqual(svGet)) {
        scGet.validationState = svGet;
        updateState();
      }
    });

    final settingsWidgetsList = createSettingsWidgets(
      null,
      widget.appThemeData,
      widget.width,
      widget.settingsControlList,
      widget.hint,
      (newValue, settingDetail) {
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

  List<Widget> createSettingsWidgets(Key? key, AppThemeData appThemeData, final double width, SettingControlList settingsControlList, String hint, SettingValidation Function(dynamic, SettingDetail) onValidate) {
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
      if ((widget.appThemeData.desktop || scN.detail.desktopOnly) && !scN.detail.hide) {
        l.add(
          ConfigInputSection(
            key: key,
            settingsControl: scN,
            appThemeData: appThemeData,
            width: width,
            onValidation: (newValue, settingControl) {
              settingControl.stringValue = newValue;
              settingControl.validationState = _initialValidate(newValue, settingControl.detail, settingsControlList, onValidate);
              updateState();
            },
          ),
        );
      }
    }
    return l;
  }
}

class ConfigInputSection extends StatefulWidget {
  const ConfigInputSection({super.key, required this.settingsControl, required this.onValidation, required this.appThemeData, required this.width});
  final SettingControl settingsControl;
  final void Function(String, SettingControl) onValidation;
  final AppThemeData appThemeData;
  final double width;
  @override
  State<ConfigInputSection> createState() => _ConfigInputSectionState();
}

class _ConfigInputSectionState extends State<ConfigInputSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: widget.appThemeData.primary.light,
          child: ListTile(
            dense: true,
            title: Row(
              children: [
                (widget.settingsControl.changed) ? Icon(Icons.star, size: widget.appThemeData.iconSize, color: widget.appThemeData.screenForegroundColour(true)) : Icon(Icons.radio_button_unchecked, size: widget.appThemeData.iconSize, color: widget.appThemeData.screenForegroundColour(false)),
                widget.appThemeData.iconGapBox(1),
                Text(widget.settingsControl.detail.title, style: widget.appThemeData.tsLarge),
              ],
            ),
            subtitle: widget.settingsControl.validationState.hintText(widget.settingsControl.detail.hint, widget.appThemeData),
          ),
        ),
        _configInputField(widget.settingsControl.detail._detailType, (value) {
          widget.onValidation(value, widget.settingsControl);
        }),
        widget.appThemeData.horizontalLine
      ],
    );
  }

  Widget _configInputField(SettingDetailType type, void Function(String) onChanged) {
    
    if (type == SettingDetailType.bool) {
      final set = _stringToBool(widget.settingsControl.stringValue);
      final iconData = set ? Icon(Icons.circle_outlined, size: widget.appThemeData.iconSize, color: widget.appThemeData.screenForegroundColour(true)) : Icon(Icons.circle_rounded, size: widget.appThemeData.iconSize, color: widget.appThemeData.screenForegroundColour(true));
      return Container(
        color: widget.appThemeData.primary.med,
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
      final p = ColorPallet.forName(widget.settingsControl.stringValue, fallback: widget.settingsControl.detail.fallback);
      return Container(
        color: p.med,
        padding: const EdgeInsets.all(5.0),
        child: DetailTextButton(
          appThemeData: widget.appThemeData,
          text: "Select Colour Palette",
          onPressed: (button) {
            showColorPeckerDialog(context, widget.appThemeData, widget.settingsControl.detail.title, widget.width, ColorPallet.forName(widget.settingsControl.stringValue, fallback: widget.settingsControl.detail.fallback), (palette, index) {
              onChanged(palette.colorName);
            });
          },
        ),
      );
    }

    return Container(
      color: widget.appThemeData.primary.med,
      padding: const EdgeInsets.all(5.0),
      child: inputTextField(
        widget.appThemeData.tsMedium,
        widget.appThemeData.textSelectionThemeData,
        widget.appThemeData.darkMode,
        widget.settingsControl.getTextController,
        height: widget.appThemeData.textInputFieldHeight,
        onSubmit: (setValue) {
          onChanged(setValue);
        },
        onChange: (setValue) {
          onChanged(setValue);
        },
      ),
    );
  }
}

class SettingDetail {
  final String title;
  final String hint;
  final Path path;
  final SettingDetailId _locator;
  final SettingDetailType _detailType; // BOOL, INT or other. Used for validation/conversion
  final String fallback; // The value if not defined in the config data.
  final bool desktopOnly; // Only applies to the desktop
  final bool hide; // Only applies to the desktop
  final String trueValue; // The text value if true
  final String falseValue; // The text value if false
  final double minValue; // The text value if true
  final double maxValue; // The text value if false
  final List<String> mustContain;

  const SettingDetail(this._locator, this.title, this.hint, this.path, this._detailType, this.fallback, this.desktopOnly, {this.trueValue = "", this.falseValue = "", this.minValue = double.maxFinite, this.maxValue = double.maxFinite, this.hide = false, this.mustContain = _mustContainDefault});

  String range(String valueString) {
    final name = _detailType == SettingDetailType.double ? 'Decimal' : 'Integer';
    final vs = valueString.trim();
    if (vs.isEmpty) {
      return "Requires $name number";
    }
    final double value;
    try {
      value = num.parse(vs).toDouble();
    } catch (e) {
      return "Invalid $name number";
    }
    if (minValue != double.maxFinite) {
      if (value < minValue) {
        return "$name number too low";
      }
    }
    if (maxValue != double.maxFinite) {
      if (value > maxValue) {
        return "$name number too high";
      }
    }
    return "";
  }
}

class SettingControlList {
  late final List<SettingControl> list;
  final String dataFileDir;

  SettingControlList(final bool isDeskTop, this.dataFileDir, ConfigData configData) {
    list = List<SettingControl>.empty(growable: true);
    for (var settingDetail in _settingsData) {
      if (isDeskTop || settingDetail.desktopOnly) {
        switch (settingDetail._detailType) {
          case SettingDetailType.bool:
            list.add(SettingControl(settingDetail, configData.getBoolFromJson(settingDetail.path, sub2: defaultThemeReplace, sub1: configData.themeContext, fallback: _stringToBool(settingDetail.fallback)).toString()));
            break;
          case SettingDetailType.double:
          case SettingDetailType.int:
            list.add(SettingControl(settingDetail, configData.getNumFromJson(settingDetail.path, sub2: defaultThemeReplace, sub1: configData.themeContext, fallback: num.parse(settingDetail.fallback)).toString()));
            break;
          default:
            list.add(SettingControl(settingDetail, configData.getStringFromJsonOptional(settingDetail.path, sub2: defaultThemeReplace, sub1: configData.themeContext)));
        }
      }
    }
  }

  String substituteForUrl(String value) {
    final dataFileName = getValueForId(SettingDetailId.data, fallback: "?");
    final serverPath = getValueForId(SettingDetailId.host, fallback: "?");
    var s = value.replaceAll("%dataFileName%", dataFileName);
    s = s.replaceAll("%testFileName%", defaultRemoteTestFileName);
    return "$serverPath/$s";
  }

  String getValueForId(SettingDetailId id, {final String fallback = ""}) {
    final e = getSettingControlForId(id);
    if (e != null) {
      return e.stringValue;
    }
    return fallback;
  }

  SettingControl? getSettingControlForId(SettingDetailId locator) {
    for (var element in list) {
      if (element.detail._locator == locator) {
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
          configData.setValueForJsonPath(sc.detail.path.cloneSub(configData.themeContext), sc.dynamicValue);
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

  String getBoolString(bool trueValue) {
    if (trueValue) {
      return detail.trueValue;
    }
    return detail.falseValue;
  }

  dynamic get dynamicValue {
    if (detail._detailType == SettingDetailType.bool) {
      return (stringValue.toLowerCase() == "true");
    }
    if (detail._detailType == SettingDetailType.int) {
      return (num.parse(stringValue));
    }
    if (detail._detailType == SettingDetailType.double) {
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
    return "id:${detail._locator.toString()} ${validationState.name.toUpperCase()}: ${changed ? '*' : ''} Old:'$oldValue' New:'$stringValue' Path:${detail.path} ";
  }
}

bool _stringToBool(final String text) {
  final txt = text.trim().toLowerCase();
  if (txt == "true" || txt == "yes") {
    return true;
  }
  return false;
}

SettingValidation _initialValidate(final String value, final SettingDetail detail, final SettingControlList controlList, final SettingValidation Function(String, SettingDetail) onValidate) {
  final vt = value.trim();
  switch (detail._detailType) {
    case SettingDetailType.int:
    case SettingDetailType.double:
      {
        final msg = detail.range(value);
        if (msg.isNotEmpty) {
          return SettingValidation.error(msg);
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
        if (!ColorPallet.colorNameExists(value)) {
          return SettingValidation.error("Invalid Colour Name");
        }
        break;
      }
    case SettingDetailType.host:
      {
        if (vt.isEmpty) {
          return SettingValidation.error("Host path cannot be empty");
        }
        try {
          Uri.parse(vt);
        } catch (e) {
          return SettingValidation.error("Could not parse Host");
        }
        if (!vt.toLowerCase().startsWith("http://") && !vt.toLowerCase().startsWith("https://")) {
          return SettingValidation.error("Host must start http:// or https://");
        }
        break;
      }
    case SettingDetailType.url:
      {
        if (vt.isEmpty) {
          return SettingValidation.error("URL cannot be empty");
        }
        final mc = SettingValidation.mustContain(vt, detail.mustContain);
        if (mc.isError) {
          return mc;
        }
        final vs = controlList.substituteForUrl(vt);
        try {
          Uri.parse(vs);
        } catch (e) {
          return SettingValidation.error("Could not parse URL");
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
        var pathSetting = controlList.getValueForId(SettingDetailId.path);
        if (pathSetting.isEmpty) {
          pathSetting = controlList.dataFileDir;
        }
        final fn = "$pathSetting${Platform.pathSeparator}$vt";
        if (!File(fn).existsSync()) {
          return SettingValidation.error("Local file not found");
        }
        break;
      }
    case SettingDetailType.name:
      {
        break;
      }
  }
  return onValidate(value, detail);
}

Future<void> showColorPeckerDialog(final BuildContext context, final AppThemeData appThemeData, final String name, final double width, final ColorPallet? currentPalette, final Function(ColorPallet, int) onSelect) async {
  ColorPallet? newPalette;
  int? colorIndex;
  ColorPallet current = currentPalette ?? appThemeData.primary;
  int currentIndex = 0;
  final colorList = appThemeData.getColorsAsList(2);
  for (int i = 0; i < colorList.length; i++) {
    if (colorList[i].value == current.med.value) {
      currentIndex = i;
    }
  }

  final okButtonKey = GlobalKey();
  final okButton = DetailTextButton(
    key: okButtonKey,
    text: "OK",
    enabled: false,
    appThemeData: appThemeData,
    onPressed: (button) {
      onSelect(newPalette!, colorIndex!);
      Navigator.of(context).pop();
    },
  );

  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
          shape: appThemeData.rectangleBorderShape,
          backgroundColor: appThemeData.dialogBackgroundColor,
          insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          title: Text('Select $name Palette', style: appThemeData.tsMedium),
          content: ColorPecker(width, colorList, currentIndex, 7, 18, appThemeData.primary.med, appThemeData.hiLight.med, (color, index) {
            newPalette = appThemeData.getColorPalletWithColourInIt(color);
            colorIndex = index;
            (okButtonKey.currentState as ManageAble).setEnabled(newPalette != null);
          }, rowSelect: true),
          actions: <Widget>[
            Row(
              children: [
                DetailTextButton(
                  appThemeData: appThemeData,
                  text: "Cancel",
                  onPressed: (button) {
                    Navigator.of(context).pop();
                  },
                ),
                okButton
              ],
            )
          ]);
    },
  );
}

Future<void> showConfigDialog(final BuildContext context, ConfigData configData, ScreenSize size, String dataFileDir, final SettingValidation Function(dynamic, SettingDetail) validate, final void Function(SettingControlList, bool) onCommit, final String Function() canChangeConfig, final Function(String) log, final Function() onClose) async {
  final settingsControlList = SettingControlList(configData.getAppThemeData().desktop, dataFileDir, configData);
  final appThemeData = configData.getAppThemeData();
  final applyButtonKey = GlobalKey();
  final applyButton = DetailTextButton(
    key: applyButtonKey,
    enabled: false,
    text: "Apply",
    appThemeData: appThemeData,
    onPressed: (button) {
      onCommit(settingsControlList, false);
      log("__CONFIG__ changes APPLIED");
      Navigator.of(context).pop();
      onClose();
    },
  );
  final saveButtonKey = GlobalKey();
  final saveButton = DetailTextButton(
    key: saveButtonKey,
    enabled: false,
    text: "Save",
    appThemeData: appThemeData,
    onPressed: (button) {
      onCommit(settingsControlList, true);
      log("__CONFIG__ changes SAVED");
      Navigator.of(context).pop();
      onClose();
    },
  );
  return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: appThemeData.rectangleBorderShape,
          backgroundColor: appThemeData.dialogBackgroundColor,
          insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          title: Row(
            children: [
              Text("Settings: ", style: appThemeData.tsLarge),
              Icon(
                Icons.circle_rounded,
                size: appThemeData.iconSize,
                color: appThemeData.primary.lightest,
              ),
              Icon(
                Icons.circle_rounded,
                size: appThemeData.iconSize,
                color: appThemeData.primary.light,
              ),
              Icon(
                Icons.circle_rounded,
                size: appThemeData.iconSize,
                color: appThemeData.primary.med,
              ),
              Icon(
                Icons.circle_rounded,
                size: appThemeData.iconSize,
                color: appThemeData.primary.medLight,
              ),
              Icon(
                Icons.circle_rounded,
                size: appThemeData.iconSize,
                color: appThemeData.primary.medDark,
              ),
              Icon(
                Icons.circle_rounded,
                size: appThemeData.iconSize,
                color: appThemeData.primary.dark,
              ),
              Icon(
                Icons.circle_rounded,
                size: appThemeData.iconSize,
                color: appThemeData.primary.darkest,
              ),
            ],
          ),
          content: ConfigInputPage(
            appThemeData: appThemeData,
            settingsControlList: settingsControlList,
            onValidate: (dynamicValue, settingDetail) {
              return validate(dynamicValue, settingDetail);
            },
            onUpdateState: (settingsControlList, hint) {
              final enable = settingsControlList.canSaveOrApply & hint.isEmpty;
              (applyButtonKey.currentState as ManageAble).setEnabled(enable);
              (saveButtonKey.currentState as ManageAble).setEnabled(enable);
            },
            hint: canChangeConfig(),
            width: size.width,
            log: log,
          ),
          actions: [
            Row(
              children: [
                DetailTextButton(
                  text: "Cancel",
                  appThemeData: appThemeData,
                  onPressed: (button) {
                    settingsControlList.clear();
                    Navigator.of(context).pop();
                    onClose();
                  },
                ),
                saveButton,
                applyButton,
              ],
            )
          ],
        );
      });
}
