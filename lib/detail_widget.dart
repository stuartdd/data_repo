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
  late final Path _pathWithName;
  DisplayTypeData _displayTypeData = simpleDisplayData;

  DataValueDisplayRow(this._name, this._value, this._type, this._isValue, this._path, this._mapSize) {
    _pathWithName = _path.cloneAppendList([_name]);
    final t = displayTypeMap[type.key];
    if (t != null) {
      _displayTypeData = t;
    }
  }

  String get name => _name;
  OptionsTypeData get type => _type;
  Path get path => _path;
  Path get pathWithName => _pathWithName;
  bool get isValue => _isValue;
  int get mapSize => _mapSize;
  DisplayTypeData get displayTypeData => _displayTypeData;

  String getDisplayName(bool editMode) {
    if (editMode) {
      return name;
    }
    return name.substring(0, (_name.length - displayTypeData.extensionLength));
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
  const DetailWidget({super.key, required this.dataValueRow, required this.appThemeData, required this.dataAction, required this.pathPropertiesList, required this.isEditDataDisplay, required this.isHorizontal});
  final DataValueDisplayRow dataValueRow;
  final AppThemeData appThemeData;
  final PathPropertiesList pathPropertiesList;
  final bool isEditDataDisplay;
  final bool isHorizontal;
  final Path Function(DetailAction) dataAction;

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
      widget.dataAction(DetailAction(ActionType.link, true, widget.dataValueRow.path, oldValue: href, oldValueType: widget.dataValueRow.type));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hiLight = widget.pathPropertiesList.propertiesForPath(widget.dataValueRow.pathWithName);
    if (widget.dataValueRow.isValue) {
      return _detailForValue(widget.appThemeData, hiLight, widget.isHorizontal);
    }
    return _detailForMap(widget.appThemeData, hiLight, widget.isHorizontal);
  }

  Widget _rowForString(final String value, final AppThemeData appThemeData, final bool updated, final TextStyle ts) {
    return Row(
      children: [
        for (int i = 0; i < value.length; i++) ...[
          Container(
            color: appThemeData.primaryOrSecondaryPallet(updated).light,
            width: (i < 9) ? 20 : 32,
            child: Text(
              (i < 9) ? value[i] : " ${value[i]}",
              style: ts,
            ),
          ),
          Container(
            color: appThemeData.screenForegroundColour(true),
            width: 2,
          ),
        ],
      ],
    );
  }

  Widget _rowForPosition(final int last, final AppThemeData appThemeData, final bool updated, final TextStyle ts) {
    return Row(
      children: [
        for (int i = 0; i < last; i++) ...[
          Container(
            color: (i % 2 == 0) ? appThemeData.primaryOrSecondaryPallet(updated).med : appThemeData.primaryOrSecondaryPallet(updated).medDark,
            width: (i < 9) ? 20 : 32,
            child: Text(
              "${i + 1}",
              style: ts,
            ),
          ),
          Container(
            color: appThemeData.screenForegroundColour(true),
            width: 2,
          ),
        ],
      ],
    );
  }

  Widget _cardForValue(final DataValueDisplayRow dataValueRow, final AppThemeData appThemeData, final PathProperties plp) {
    if (dataValueRow.type.equal(optionTypeDataPositional)) {
      return Card(
        margin: const EdgeInsets.all(5.0),
        color: appThemeData.selectedAndHiLightColour(true, plp.updated),
        child: Column(
          children: [
            _rowForPosition(dataValueRow.value.length, appThemeData, plp.updated, appThemeData.tsMedium),
            Container(
              color: Colors.black,
              height: 2,
            ),
            _rowForString(dataValueRow.value, appThemeData, plp.updated, appThemeData.tsMedium),
          ],
        ),
      );
    }
    if (dataValueRow.type.equal(optionTypeDataMarkDown)) {
      return Card(
        margin: const EdgeInsets.all(5.0),
        color: appThemeData.selectedAndHiLightColour(true, plp.updated),
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
      margin: const EdgeInsets.all(5.0),
      color: appThemeData.selectedAndHiLightColour(true, plp.updated),
      child: Padding(padding: const EdgeInsets.all(5.0), child: Text(dataValueRow.value, style: appThemeData.tsLarge)),
    );
  }

  Widget _detailForValue(final AppThemeData appThemeData, final PathProperties pathProperties, final bool horizontal) {
    return Card(
      color: appThemeData.detailBackgroundColor,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: groupButton(pathProperties, true, widget.dataValueRow.pathWithName, widget.appThemeData, widget.dataAction),
          title: Container(
            padding: const EdgeInsets.all(5.0),
            color: appThemeData.selectedAndHiLightColour(true, pathProperties.renamed),
            child: Text(widget.dataValueRow.getDisplayName(widget.isEditDataDisplay), style: appThemeData.tsMedium),
          ),
          subtitle: horizontal ? Text("Owned By:${widget.dataValueRow.path}. Is a ${widget.dataValueRow.type}", style: appThemeData.tsSmall) : null,
        ),
        SizedBox(
          width: double.infinity,
          child: _cardForValue(widget.dataValueRow, appThemeData, pathProperties),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            DetailButton(
              appThemeData: widget.appThemeData,
              show: widget.isEditDataDisplay,
              text: 'Edit',
              onPressed: () {
                widget.dataAction(DetailAction(ActionType.edit, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
              },
            ),
            DetailButton(
              appThemeData: widget.appThemeData,
              show: widget.isEditDataDisplay,
              text: 'Change',
              onPressed: () {
                widget.dataAction(DetailAction(ActionType.rename, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.name, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction, additional: widget.dataValueRow.value));
              },
            ),
            DetailButton(
              appThemeData: widget.appThemeData,
              show: !widget.isEditDataDisplay && (widget.dataValueRow.displayTypeData.displayType != DisplayType.positionalString),
              timerMs: 500,
              text: 'Copy',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.dataValueRow.value));
                widget.dataAction(DetailAction(ActionType.clip, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
              },
            ),
            DetailButton(
              appThemeData: widget.appThemeData,
              show: widget.dataValueRow.isLink && !widget.isEditDataDisplay && (widget.dataValueRow.displayTypeData.displayType != DisplayType.positionalString),
              timerMs: 500,
              text: 'Link',
              onPressed: () {
                widget.dataAction(DetailAction(ActionType.link, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
              },
            ),
            DetailButton(
              appThemeData: widget.appThemeData,
              show: widget.isEditDataDisplay,
              timerMs: 500,
              text: 'Remove',
              onPressed: () {
                widget.dataAction(DetailAction(ActionType.delete, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
              },
            ),
          ],
        ),
      ]),
    );
  }

  Widget _detailForMap(final AppThemeData appThemeData, final PathProperties plp, final bool horizontal) {
    return SizedBox(
      child: Card(
          color: appThemeData.detailBackgroundColor,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: groupButton(plp, false, widget.dataValueRow.pathWithName, widget.appThemeData, widget.dataAction),
              title: Container(
                padding: const EdgeInsets.all(5.0),
                color: appThemeData.selectedAndHiLightColour(true, plp.renamed),
                child: Text(widget.dataValueRow.name, style: appThemeData.tsMedium),
              ),
              subtitle: horizontal ? Text("Group is Owned By:${widget.dataValueRow.path}. Has ${widget.dataValueRow.mapSize} sub elements", style: appThemeData.tsSmall) : null,
              onTap: () {
                widget.dataAction(DetailAction(ActionType.select, false, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.name, oldValueType: optionTypeDataGroup, onCompleteActionNullable: _onCompleteAction));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                DetailButton(
                  appThemeData: widget.appThemeData,
                  show: widget.isEditDataDisplay,
                  text: 'Change',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.rename, false, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.name, oldValueType: optionTypeDataGroup, onCompleteActionNullable: _onCompleteAction));
                  },
                ),
                DetailButton(
                  appThemeData: widget.appThemeData,
                  show: widget.isEditDataDisplay,
                  text: 'Remove',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.delete, false, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: optionTypeDataGroup, onCompleteActionNullable: _onCompleteAction));
                  },
                ),
              ],
            )
          ])),
    );
  }
}

Widget groupButton(PathProperties plp, bool value, Path path, AppThemeData appThemeData, final Path Function(DetailAction) dataAction) {
  return IconButton(
    color: appThemeData.screenForegroundColour(true),
    icon: plp.groupSelect ? const Icon(Icons.radio_button_checked) : const Icon(Icons.radio_button_unchecked),
    tooltip: plp.groupSelect ? 'Remove from select' : 'Add to select',
    onPressed: () {
      dataAction(DetailAction(ActionType.group, value, path));
    },
  );
}
