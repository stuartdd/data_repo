import 'package:data_repo/data_types.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'detail_buttons.dart';
import 'colour_pecker.dart';
import 'data_container.dart';
import 'path.dart';
import 'config.dart';

enum SettingDetailType { url, dir, file, int, double, bool, color, name }

enum _SettingState { ok, warning, error }

final List<SettingDetail> _settingsData = [
  SettingDetail("get", "Server URL (Download)", "Download address of the host server", getDataUrlPath, SettingDetailType.url, defaultRemoteGetUrl, true),
  SettingDetail("put", "Server URL (Upload)", "Upload address of the host server", postDataUrlPath, SettingDetailType.url, defaultRemotePostUrl, true),
  SettingDetail("path", "Local Data file path", "The directory for the data file", dataFileLocalDirPath, SettingDetailType.dir, defaultDataEmptyString, false),
  SettingDetail("data", "Data file Name", "Now set from the main screen!", dataFileLocalNamePath, SettingDetailType.file, defaultDataEmptyString, true, hide: true),
  SettingDetail("rootNodeName", "Root Node Name", "Replace the root node name with this", appRootNodeNamePath, SettingDetailType.name, defaultDataEmptyString, true),
  SettingDetail("timeout", "Server Timeout Milliseconds", "The host server timeout 100..5000", dataFetchTimeoutMillisPath, SettingDetailType.int, defaultFetchTimeoutMillis.toString(), false, minValue: 100, maxValue: 5000),
  SettingDetail("", "Screen Text & Icons", "Icons/Text White or Black. Click below to change", appColoursDarkModePath, SettingDetailType.bool, defaultDarkMode, true, trueValue: "Currently White", falseValue: "Currently Black"),
  SettingDetail("", "Screen Text Scale", "Text Scale. 0.5..2.0", appTextScalePath, SettingDetailType.double, "1.0", true, minValue: 0.5, maxValue: 2.0),
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
        return appThemeData.tsMediumError;
      case _SettingState.error:
        return appThemeData.tsLargeError;
      default:
        return appThemeData.tsMedium;
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
        await DataContainer.testHttpGet("${scGet.stringValue}/$scDataValue", prefix: "File: $scDataValue.", (resp) {
          if (resp.isNotEmpty) {
            sv = SettingValidation.warning(resp);
          }
        });
      }
      if (scGet.validationState.isNotEqual(sv)) {
        scGet.validationState = sv;
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
                SizedBox(width: widget.appThemeData.iconGap),
                Text(widget.settingsControl.detail.title, style: widget.appThemeData.tsLarge),
              ],
            ),
            subtitle: widget.settingsControl.validationState.hintText(widget.settingsControl.detail.hint, widget.appThemeData),
          ),
        ),
        _configInputField(widget.settingsControl.detail.detailType, (value) {
          widget.onValidation(value, widget.settingsControl);
        }),
        Container(
          color: widget.appThemeData.screenForegroundColour(true),
          height: 2,
        ),
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
      final p = widget.appThemeData.getColorPalletForName(widget.settingsControl.stringValue);
      return Container(
        color: p.med,
        padding: const EdgeInsets.all(5.0),
        child: DetailButton(
          appThemeData: widget.appThemeData,
          text: "Select Colour Palette",
          onPressed: () {
            showColorPeckerDialog(context, widget.appThemeData, widget.settingsControl.detail.title, widget.width, colourNames[widget.settingsControl.stringValue], (palette, index) {
              onChanged(palette.colorName);
            });
          },
        ),
      );
    }

    return Container(
      color: widget.appThemeData.primary.med,
      padding: const EdgeInsets.all(10.0),
      child: inputTextField("",widget.appThemeData.tsMedium, widget.appThemeData.textSelectionThemeData, widget.appThemeData.darkMode, false,widget.settingsControl.getTextController, (changeValue) {
        // onChanged(changeValue);
      },(setValue) {
        onChanged(setValue);
      }, padding: const EdgeInsets.fromLTRB(5,0,0,0)),
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
  final bool hide; // Only applies to the desktop
  final String trueValue; // The text value if true
  final String falseValue; // The text value if false
  final double minValue; // The text value if true
  final double maxValue; // The text value if false
  const SettingDetail(this.id, this.title, this.hint, this.path, this.detailType, this.fallback, this.desktopOnly, {this.trueValue = "", this.falseValue = "", this.minValue = double.maxFinite, this.maxValue = double.maxFinite, this.hide = false});

  String range(String valueString) {
    final name = detailType == SettingDetailType.double ? 'Decimal' : 'Integer';
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
  SettingControlList(final bool isDeskTop, this.dataFileDir, final ConfigData configData) {
    list = List<SettingControl>.empty(growable: true);
    for (var settingDetail in _settingsData) {
      if (isDeskTop || settingDetail.desktopOnly) {
        switch (settingDetail.detailType) {
          case SettingDetailType.bool:
            list.add(SettingControl(settingDetail, configData.getBoolFromJson(settingDetail.path, fallback: _stringToBool(settingDetail.fallback)).toString()));
            break;
          case SettingDetailType.double:
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
    if (detail.detailType == SettingDetailType.double) {
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
  final okButton = DetailButton(
    key: okButtonKey,
    text: "OK",
    enabled: false,
    appThemeData: appThemeData,
    onPressed: () {
      onSelect(newPalette!, colorIndex!);
      Navigator.of(context).pop();
    },
  );

  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
          backgroundColor: appThemeData.dialogBackgroundColor,
          insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          title: Text('Select $name Palette', style: appThemeData.tsMedium),
          content: ColorPecker(width, colorList, currentIndex, 7, 18, appThemeData.primary.med, appThemeData.hiLight.med, (color, index) {
            newPalette = appThemeData.getColorPalletWithColourInIt(color);
            colorIndex = index;
            (okButtonKey.currentState as EnableAble).setEnabled(newPalette != null);
          }, rowSelect: true),
          actions: <Widget>[
            Row(
              children: [
                DetailButton(
                  appThemeData: appThemeData,
                  text: "Cancel",
                  onPressed: () {
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

Future<void> showConfigDialog(final BuildContext context, ConfigData configData, ScreenSize size, String dataFileDir, final SettingValidation Function(dynamic, SettingDetail) validate, final void Function(SettingControlList, bool) onCommit, final String Function() canChangeConfig, final Function(String) log) async {
  final settingsControlList = SettingControlList(configData.getAppThemeData().desktop, dataFileDir, configData);
  final appThemeData = configData.getAppThemeData();
  final applyButtonKey = GlobalKey();
  final applyButton = DetailButton(
    key: applyButtonKey,
    enabled: false,
    text: "Apply",
    appThemeData: appThemeData,
    onPressed: () {
      onCommit(settingsControlList, false);
      log("__CONFIG__ changes APPLIED");
      Navigator.of(context).pop();
    },
  );
  final saveButtonKey = GlobalKey();
  final saveButton = DetailButton(
    key: saveButtonKey,
    enabled: false,
    text: "Save",
    appThemeData: appThemeData,
    onPressed: () {
      onCommit(settingsControlList, true);
      log("__CONFIG__ changes SAVED");
      Navigator.of(context).pop();
    },
  );
  return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
              (applyButtonKey.currentState as EnableAble).setEnabled(enable);
              (saveButtonKey.currentState as EnableAble).setEnabled(enable);
            },
            hint: canChangeConfig(),
            width: size.width,
          ),
          actions: [
            Row(
              children: [
                DetailButton(
                  text: "Cancel",
                  appThemeData: appThemeData,
                  onPressed: () {
                    settingsControlList.clear();
                    Navigator.of(context).pop();
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
