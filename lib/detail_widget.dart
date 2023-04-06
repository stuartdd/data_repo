import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'path.dart';
import 'detail_buttons.dart';

const _styleLarge = TextStyle(fontFamily: 'Code128', fontWeight: FontWeight.w500, fontSize: 30.0, color: Colors.black);
const _styleSmall = TextStyle(fontFamily: 'Code128', fontWeight: FontWeight.w500, fontSize: 25.0, color: Colors.black);
const _styleSubTitle = TextStyle(fontFamily: 'Code128', fontSize: 17.0, color: Colors.black);
const inputTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 30.0, color: Colors.black);

enum ActionType { none, editStart, renameStart, addStart, select, link, clip }

class DetailAction {
  final ActionType action;
  final bool value;
  final Path path;
  final String oldValue;
  final String oldValueType;
  final bool Function(String, String, String) onCompleteAction;
  DetailAction(this.action, this.value, this.path, this.oldValue, this.oldValueType, this.onCompleteAction);

  String getLastPathElement() {
    return path.getLast();
  }

  @override
  String toString() {
    final s = "Type:'${value ? "Value" : "Map"}' Path:'$path' V1:'$oldValue' ";
    switch (action) {
      case ActionType.none:
        {
          return "NONE: $s";
        }
      case ActionType.editStart:
        {
          return "EDIT-START: $s";
        }
      case ActionType.renameStart:
        {
          return "RENAME-START: $s";
        }
      case ActionType.addStart:
        {
          return "ADD-START: $s";
        }
      case ActionType.select:
        {
          return "SELECT: $s";
        }
      case ActionType.link:
        {
          return "LINK: $s";
        }
      case ActionType.clip:
        {
          return "CLIP: $s";
        }
    }
  }
}

class DataValueDisplayRow {
  final String _name;
  final String _value;
  final String _type;
  final bool _isValue;
  final Path _path;
  final int _mapSize;

  DataValueDisplayRow(this._name, this._value, this._type, this._isValue, this._path, this._mapSize);

  Path getFullPath() {
    return _path.cloneAppend([_name]);
  }

  String get name => _name;
  String get value => _value;
  String get type => _type;
  Path get path => _path;
  bool get isValue => _isValue;
  int get mapSize => _mapSize;

  bool isLink() {
    if (_isValue) {
      var t = _value.toLowerCase();
      if (t.startsWith("http://") || t.startsWith("https://")) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() {
    if (_isValue) {
      return "Name:$_name ($_type) = $_value";
    }
    return "Name:$_name [$_mapSize]";
  }
}

class ValidatedInputField extends StatefulWidget {
  ValidatedInputField({super.key, required this.initialValue, required this.onClose, required this.validate, required this.inputType, required this.prompt});
  final String initialValue;
  final String inputType;
  final String prompt;
  final controller = TextEditingController();
  final Function(String, String, String) onClose;
  final String Function(String, String, String) validate;

  @override
  State<ValidatedInputField> createState() => _ValidatedInputFieldState();
}

const _inputTypeNames = {"double": "a 'decimal number'", "int": "an 'integer number'", "bool":"'true' or 'false'"};

class _ValidatedInputFieldState extends State<ValidatedInputField> {
  String help = "";
  String initial = "";
  bool showOk = false;
  String inputType = "";
  String inputTypeName = "";

  @override
  initState() {
    super.initState();
    initial = widget.initialValue.trim();
    widget.controller.text = initial;
    inputType = widget.inputType;
    if (_inputTypeNames.containsKey(inputType)) {
      inputTypeName = _inputTypeNames[inputType]!;
    } else {
      inputTypeName = inputType;
    }
    help = widget.validate(initial, inputType, inputTypeName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          alignment: Alignment.centerLeft,
          child: Text(widget.prompt.replaceAll("\$", inputTypeName), style: inputTextStyle),
        ),
        (help.isEmpty)
            ? const SizedBox(
                height: 0,
              )
            : Column(children: [
                Container(
                  alignment: Alignment.centerLeft,
                  color: Colors.brown,
                  child: Text(
                    " $help ",
                    style: inputTextStyle,
                  ),
                ),
                const SizedBox(
                  height: 10,
                )
              ]),
        TextField(
          controller: widget.controller,
          style: inputTextStyle,
          onChanged: (value) {
            setState(() {
              print("--- '$value' --- '${initial}'");
              if (value.trim() == initial) {
                showOk = false;
                help = "";
              } else {
                help = widget.validate(value.trim(), inputType, inputTypeName);
                showOk = help.isEmpty;
              }
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        Row(
          children: [
            DetailButton(
              show: showOk,
              text: 'OK',
              onPressed: () {
                widget.onClose("OK", widget.controller.text.trim(), inputType);
              },
            ),
            DetailButton(
              text: 'Cancel',
              onPressed: () {
                widget.onClose("Cancel", widget.controller.text.trim(), inputType);
              },
            )
          ],
        ),
      ],
    );
  }
}

class DetailWidget extends StatefulWidget {
  const DetailWidget({super.key, required this.dataValueRow, required this.loMaterialColor, required this.dataAction, required this.hiLightedPaths, required this.hiMaterialColor});
  final DataValueDisplayRow dataValueRow;
  final MaterialColor loMaterialColor;
  final MaterialColor hiMaterialColor;
  final PathList hiLightedPaths;
  final bool Function(DetailAction) dataAction;

  @override
  State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {
  bool _onCompleteAction(String option, value1, value2) {
    if (value1 == value2) {
      debugPrint("_onCompleteAction:FALSE: Action: $option, v1:$value1 v2:$value2");
      return false;
    }
    debugPrint("_onCompleteAction:TRUE: Action: $option, v1:$value1 v2:$value2");
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hiLight = widget.hiLightedPaths.contains(widget.dataValueRow.getFullPath());
    final materialColor = hiLight ? widget.hiMaterialColor : widget.loMaterialColor;
    if (widget.dataValueRow.isValue) {
      return _detailForValue(materialColor, hiLight);
    }
    return _dataForMap(materialColor, hiLight);
  }

  Widget _detailForValue(MaterialColor materialColor, bool hiLight) {
    return SizedBox(
      child: Card(
          color: materialColor.shade600,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: hiLight ? const Icon(Icons.radio_button_checked) : const Icon(Icons.radio_button_unchecked),
              title: Text(widget.dataValueRow.name, style: _styleSmall),
              subtitle: Text("Owned By:${widget.dataValueRow.path}. Is a ${widget.dataValueRow.type}", style: _styleSubTitle),
            ),
            SizedBox(
              width: double.infinity,
              child: Card(
                margin: EdgeInsetsGeometry.lerp(null, null, 5),
                color: materialColor.shade200,
                child: Padding(padding: const EdgeInsets.only(left: 20.0), child: Text(widget.dataValueRow.value, style: _styleLarge)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                DetailButton(
                  text: 'Edit',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.editStart, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, widget.dataValueRow.type, _onCompleteAction));
                  },
                ),
                DetailButton(
                  text: 'Re-Name',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.renameStart, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.name, "Name", _onCompleteAction));
                  },
                ),
                DetailButton(
                  timerMs: 500,
                  text: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.dataValueRow.value));
                    widget.dataAction(DetailAction(ActionType.clip, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, widget.dataValueRow.type, _onCompleteAction));
                  },
                ),
                DetailButton(
                  show: widget.dataValueRow.isLink(),
                  timerMs: 500,
                  text: 'Link',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.link, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, widget.dataValueRow.type, _onCompleteAction));
                  },
                ),
              ],
            ),
          ])),
    );
  }

  Widget _dataForMap(MaterialColor materialColor, bool hiLight) {
    return SizedBox(
      child: Card(
          color: materialColor.shade300,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: hiLight ? const Icon(Icons.radio_button_checked) : const Icon(Icons.radio_button_unchecked),
              title: Text(widget.dataValueRow.name, style: _styleSmall),
              subtitle: Text("Group is Owned By:${widget.dataValueRow.path}. Has ${widget.dataValueRow.mapSize} sub elements", style: _styleSubTitle),
              onTap: () {
                widget.dataAction(DetailAction(ActionType.select, false, widget.dataValueRow.getFullPath(), widget.dataValueRow.name, "String", _onCompleteAction));
              },
            ),
          ])),
    );
  }
}
