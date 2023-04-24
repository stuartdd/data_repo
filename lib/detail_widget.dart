import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'path.dart';
import 'detail_buttons.dart';

const _styleLarge = TextStyle(fontFamily: 'Code128', fontWeight: FontWeight.w500, fontSize: 30.0, color: Colors.black);
const _styleSmall = TextStyle(fontFamily: 'Code128', fontWeight: FontWeight.w500, fontSize: 25.0, color: Colors.black);
const _styleSubTitle = TextStyle(fontFamily: 'Code128', fontSize: 17.0, color: Colors.black);

enum ActionType { none, editStart, renameStart, select, delete, link, clip }

class DetailAction {
  final ActionType action;
  final bool value;
  final Path path;
  final String oldValue;
  final Type oldValueType;
  final bool Function(String, String, String) onCompleteAction;
  DetailAction(this.action, this.value, this.path, this.oldValue, this.oldValueType, this.onCompleteAction);

  String getLastPathElement() {
    return path.getLast();
  }


  String get valueName {
    return value ? "Value" : "Group";
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
      case ActionType.select:
        {
          return "SELECT: $s";
        }
      case ActionType.delete:
        {
          return "DELETE: $s";
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
  final Type _type;
  final bool _isValue;
  final Path _path;
  final int _mapSize;

  DataValueDisplayRow(this._name, this._value, this._type, this._isValue, this._path, this._mapSize);

  String get name => _name;
  Type get type => _type;
  Path get path => _path;
  bool get isValue => _isValue;
  int get mapSize => _mapSize;

  String get value {
    if (_type == bool) {
      if (_value == "true") {
        return "Yes";
      }
      return "No";
    }
    return _value;
  }

  Path get pathString {
    return _path.cloneAppend([_name]);
  }

  bool get isLink {
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
      return "Name:$value ($_type) = $value";
    }
    return "Name:$value [$_mapSize]";
  }
}

class DetailWidget extends StatefulWidget {
  const DetailWidget({super.key, required this.dataValueRow, required this.loMaterialColor, required this.dataAction, required this.hiLightedPaths, required this.hiMaterialColor, required this.isEditDataDisplay});
  final DataValueDisplayRow dataValueRow;
  final MaterialColor loMaterialColor;
  final MaterialColor hiMaterialColor;
  final PathList hiLightedPaths;
  final bool isEditDataDisplay;
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
    final hiLight = widget.hiLightedPaths.contains(widget.dataValueRow.pathString);
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
                  show: widget.isEditDataDisplay,
                  text: 'Edit',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.editStart, true, widget.dataValueRow.pathString, widget.dataValueRow.value, widget.dataValueRow.type, _onCompleteAction));
                  },
                ),
                DetailButton(
                  show: widget.isEditDataDisplay,
                  text: 'Re-Name',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.renameStart, true, widget.dataValueRow.pathString, widget.dataValueRow.name, String, _onCompleteAction));
                  },
                ),
                DetailButton(
                  show: !widget.isEditDataDisplay,
                  timerMs: 500,
                  text: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.dataValueRow.value));
                    widget.dataAction(DetailAction(ActionType.clip, true, widget.dataValueRow.pathString, widget.dataValueRow.value, widget.dataValueRow.type, _onCompleteAction));
                  },
                ),
                DetailButton(
                  show: widget.dataValueRow.isLink && !widget.isEditDataDisplay,
                  timerMs: 500,
                  text: 'Link',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.link, true, widget.dataValueRow.pathString, widget.dataValueRow.value, widget.dataValueRow.type, _onCompleteAction));
                  },
                ),
                DetailButton(
                  show: widget.isEditDataDisplay,
                  timerMs: 500,
                  text: 'Remove',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.delete, true, widget.dataValueRow.pathString, widget.dataValueRow.value, widget.dataValueRow.type, _onCompleteAction));
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
                widget.dataAction(DetailAction(ActionType.select, false, widget.dataValueRow.pathString, widget.dataValueRow.name, String, _onCompleteAction));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                DetailButton(
                  show: widget.isEditDataDisplay,
                  text: 'Re-Name',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.renameStart, false, widget.dataValueRow.pathString, widget.dataValueRow.name, String, _onCompleteAction));
                  },
                ),
                DetailButton(
                  show: widget.isEditDataDisplay,
                  text: 'Remove',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.delete, false, widget.dataValueRow.pathString, widget.dataValueRow.value, widget.dataValueRow.type, _onCompleteAction));
                  },
                ),
              ],
            )
          ])),
    );
  }
}
