import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'path.dart';
import 'data_types.dart';
import 'detail_buttons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class DataValueDisplayRow {
  final String _name;
  final String _value;
  final OptionsTypeData _type;
  final bool _isValue;
  final Path _path;
  final int _mapSize;
  DisplayTypeData _displayTypeData = simpleDisplayData;

  DataValueDisplayRow(this._name, this._value, this._type, this._isValue, this._path, this._mapSize) {
    final t = displayTypeMap[type.key];
    if (t != null) {
      _displayTypeData = t;
    }
  }

  String get name => _name;
  OptionsTypeData get type => _type;
  Path get path => _path;
  bool get isValue => _isValue;
  int get mapSize => _mapSize;
  DisplayTypeData get displayTypeData => _displayTypeData;

  String getDisplayName(bool editMode) {
    if (editMode) {
      return name;
    }
    return name.substring(0, (_name.length - displayTypeData.markerLength));
  }
  
  String get value {
    if (_type.elementType == bool) {
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
  const DetailWidget({super.key, required this.dataValueRow, required this.appThemeData, required this.dataAction, required this.hiLightedPaths, required this.isEditDataDisplay, required this.isHorizontal});
  final DataValueDisplayRow dataValueRow;
  final AppThemeData appThemeData;
  final PathList hiLightedPaths;
  final bool isEditDataDisplay;
  final bool isHorizontal;
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

  void doOnTapLink(String text, String? href, String title) {
    if (href != null) {
      widget.dataAction(DetailAction(ActionType.link, true, widget.dataValueRow.path, oldValue:href, oldValueType:widget.dataValueRow.type));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hiLight = widget.hiLightedPaths.contains(widget.dataValueRow.pathString);
    if (widget.dataValueRow.isValue) {
      return _detailForValue(widget.appThemeData, hiLight, widget.isHorizontal);
    }
    return _detailForMap(widget.appThemeData, hiLight, widget.isHorizontal);
  }

  Widget _rowForString(final String value, final materialColor, final TextStyle ts) {
    return Row(
      children: [
        for (int i = 0; i < value.length; i++) ...[
          Container(
            color: (i % 2 == 0) ? materialColor.shade300 : materialColor.shade400,
            width: (i < 9) ? 20 : 32,
            child: Text(
              (i < 9) ? value[i] : " ${value[i]}",
              style: ts,
            ),
          ),
          Container(
            color: Colors.black,
            width: 2,
          ),
        ],
      ],
    );
  }

  Widget _rowForPosition(final int last, final MaterialColor materialColor, final TextStyle ts) {
    return Row(
      children: [
        for (int i = 0; i < last; i++) ...[
          Container(
            color: (i % 2 == 0) ? materialColor.shade300 : materialColor.shade400,
            width: (i < 9) ? 20 : 32,
            child: Text(
              "${i + 1}",
              style: ts,
            ),
          ),
          Container(
            color: Colors.black,
            width: 2,
          ),
        ],
      ],
    );
  }

  Widget _cardForValue(final DataValueDisplayRow dataValueRow, final AppThemeData appThemeData, final bool hiLight) {
    if (dataValueRow.type.equal(optionTypeDataPositional)) {
      return Card(
        margin: EdgeInsetsGeometry.lerp(null, null, 5),
        color: appThemeData.hiLowColor(hiLight).shade700,
        child: Column(
          children: [
            _rowForPosition(dataValueRow.value.length, appThemeData.hiLowColor(hiLight), appThemeData.tsMedium),
            Container(
              color: Colors.black,
              height: 2,
            ),
            _rowForString(dataValueRow.value, appThemeData.hiLowColor(hiLight), appThemeData.tsMedium),
          ],
        ),
      );
    }
    if (dataValueRow.type.equal(optionTypeDataMarkDown)) {
      return Card(
        margin: EdgeInsetsGeometry.lerp(null, null, 5),
        color: appThemeData.hiLowColor(hiLight).shade200,
        child: SizedBox(
          child: Markdown(
            data: dataValueRow.value,
            selectable: true,
            shrinkWrap: true,
            styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
            onTapLink: doOnTapLink,
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsetsGeometry.lerp(null, null, 5),
      color: appThemeData.hiLowColor(hiLight).shade200,
      child: Padding(padding: const EdgeInsets.only(left: 20.0), child: Text(dataValueRow.value, style: appThemeData.tsLarge)),
    );
  }

  Widget _detailForValue(final AppThemeData appThemeData, final bool hiLight, final bool horizontal) {
    return Card(
          color: appThemeData.primary.shade600,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: hiLight ? const Icon(Icons.radio_button_checked) : const Icon(Icons.radio_button_unchecked),
              title: Text(widget.dataValueRow.getDisplayName(widget.isEditDataDisplay), style: appThemeData.tsMedium),
              subtitle: horizontal ? Text("Owned By:${widget.dataValueRow.path}. Is a ${widget.dataValueRow.type}", style: appThemeData.tsSmall) : null,
            ),
            SizedBox(
              width: double.infinity,
              child: _cardForValue(widget.dataValueRow, appThemeData, hiLight),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                DetailButton(
                  appThemeData:  widget.appThemeData,
                  show: widget.isEditDataDisplay,
                  text: 'Edit',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.editStart, true, widget.dataValueRow.pathString, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
                  },
                ),
                DetailButton(
                  appThemeData:  widget.appThemeData,
                  show: widget.isEditDataDisplay,
                  text: 'Re-Name',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.renameStart, true, widget.dataValueRow.pathString, oldValue: widget.dataValueRow.name, oldValueType: widget.dataValueRow.type,  onCompleteActionNullable:_onCompleteAction, additional: widget.dataValueRow.value));
                  },
                ),
                DetailButton(
                  appThemeData:  widget.appThemeData,
                  show: !widget.isEditDataDisplay && (widget.dataValueRow.displayTypeData.displayType != DisplayType.positionalString),
                  timerMs: 500,
                  text: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.dataValueRow.value));
                    widget.dataAction(DetailAction(ActionType.clip, true, widget.dataValueRow.pathString, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type,  onCompleteActionNullable:_onCompleteAction));
                  },
                ),
                DetailButton(
                  appThemeData:  widget.appThemeData,
                  show: widget.dataValueRow.isLink && !widget.isEditDataDisplay && (widget.dataValueRow.displayTypeData.displayType != DisplayType.positionalString),
                  timerMs: 500,
                  text: 'Link',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.link, true, widget.dataValueRow.pathString, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type,  onCompleteActionNullable:_onCompleteAction));
                  },
                ),
                DetailButton(
                  appThemeData:  widget.appThemeData,
                  show: widget.isEditDataDisplay,
                  timerMs: 500,
                  text: 'Remove',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.delete, true, widget.dataValueRow.pathString, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type,  onCompleteActionNullable:_onCompleteAction));
                  },
                ),
              ],
            ),
          ]),
    );
  }

  Widget _detailForMap(AppThemeData appThemeData, bool hiLight, bool horizontal) {
    return SizedBox(
      child: Card(
          color: appThemeData.primary.shade300,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: hiLight ? const Icon(Icons.radio_button_checked) : const Icon(Icons.radio_button_unchecked),
              title: Text(widget.dataValueRow.name, style: appThemeData.tsMedium),
              subtitle: horizontal ? Text("Group is Owned By:${widget.dataValueRow.path}. Has ${widget.dataValueRow.mapSize} sub elements", style: appThemeData.tsSmall) : null,
              onTap: () {
                widget.dataAction(DetailAction(ActionType.select, false, widget.dataValueRow.pathString, oldValue: widget.dataValueRow.name, oldValueType: optionTypeDataGroup,  onCompleteActionNullable:_onCompleteAction));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                DetailButton(
                  appThemeData:  widget.appThemeData,
                  show: widget.isEditDataDisplay,
                  text: 'Re-Name',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.renameStart, false, widget.dataValueRow.pathString, oldValue: widget.dataValueRow.name,oldValueType:  optionTypeDataGroup,  onCompleteActionNullable:_onCompleteAction));
                  },
                ),
                DetailButton(
                  appThemeData:  widget.appThemeData,
                  show: widget.isEditDataDisplay,
                  text: 'Remove',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.delete, false, widget.dataValueRow.pathString, oldValue: widget.dataValueRow.value, oldValueType: optionTypeDataGroup,  onCompleteActionNullable:_onCompleteAction));
                  },
                ),
              ],
            )
          ])),
    );
  }
}
