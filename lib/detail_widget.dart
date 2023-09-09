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

  Path get fullPath {
    return _path.cloneAppendList([_name]);
  }

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
  const DetailWidget({super.key, required this.dataValueRow, required this.appThemeData, required this.dataAction, required this.onResolve, required this.pathPropertiesList, required this.isEditDataDisplay, required this.isHorizontal});
  final DataValueDisplayRow dataValueRow;
  final AppThemeData appThemeData;
  final PathPropertiesList pathPropertiesList;
  final bool isEditDataDisplay;
  final bool isHorizontal;
  final Path Function(DetailAction) dataAction;
  final String Function(String, Path) onResolve;

  @override
  State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {
  bool _onCompleteAction(String option, value1, value2) {
    if (value1 == value2) {
      return false;
    }
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

  List<Widget> _tableRowForString(final String value, final bool updated, final TextStyle ts, final Color bg, final Color fg, final int height) {
    List<Widget> l = [];
    for (int i = 0; i < value.length; i++) {
      l.add(Container(
        alignment: Alignment.center,
        height: height / 2,
        color: bg,
        child: Text(
          value[i],
          style: ts,
        ),
      ));
    }
    return l;
  }

  List<Widget> _tableRowForIndex(final int last, final bool updated, final TextStyle ts, final Color bg, final Color fg, final int height) {
    List<Widget> l = [];
    for (int i = 0; i < last; i++) {
      l.add(Container(
        alignment: Alignment.center,
        height: height / 2,
        color: bg,
        child: Text(
          "$i",
          style: ts,
        ),
      ));
    }
    return l;
  }

  Widget _tableForString(final String value, final bool updated, final TextStyle ts1, final TextStyle ts2, final Color bg, final Color fg, final int height) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder.all(color: fg),
      children: <TableRow>[
        TableRow(children: _tableRowForIndex(value.length, updated, ts1, bg, fg, height)),
        TableRow(children: _tableRowForString(value, updated, ts2, bg, fg, height)),
      ],
    );
  }

  Widget _containerForValue(final DataValueDisplayRow dataValueRow, final AppThemeData appThemeData, final PathProperties plp) {
    final bgColour = appThemeData.selectedAndHiLightColour(true, plp.updated);
    final fgColour = appThemeData.screenForegroundColour(true);

    if (dataValueRow.type.equal(optionTypeDataPositional)) {
      return Container(
        alignment: Alignment.center,
        child: _tableForString(dataValueRow.value, plp.updated, appThemeData.tsSmall, appThemeData.tsMediumBold, bgColour, fgColour, 70),
      );
    }
    if (dataValueRow.type.equal(optionTypeDataMarkDown)) {
      return Container(
        color: bgColour,
        alignment: Alignment.centerLeft,
        child: Markdown(
          data: dataValueRow.value,
          selectable: true,
          shrinkWrap: true,
          styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
          onTapLink: doOnTapLink,
        ),
      );
    }
    return Container(
      color: bgColour,
      alignment: Alignment.centerLeft,
      child: Padding(padding: const EdgeInsets.all(5.0), child: Text(widget.onResolve(dataValueRow.value, dataValueRow.fullPath), style: appThemeData.tsLarge)),
    );
  }

  Widget _detailForValue(final AppThemeData appThemeData, final PathProperties pathProperties, final bool horizontal) {
    final double rm = widget.dataValueRow.type.equal(optionTypeDataMarkDown) ? 15 : 5;
    return Card(
      color: appThemeData.detailBackgroundColor,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: groupButton(pathProperties, true, widget.dataValueRow.pathWithName, widget.appThemeData, widget.dataAction),
          title: Container(
            padding: const EdgeInsets.all(5),
            color: appThemeData.selectedAndHiLightColour(true, pathProperties.renamed),
            child: Text(widget.dataValueRow.getDisplayName(widget.isEditDataDisplay), style: appThemeData.tsMedium),
          ),
          subtitle: horizontal ? Text("Owned By:${widget.dataValueRow.path}. Is a ${widget.dataValueRow.type}", style: appThemeData.tsSmall) : null,
        ),
        SizedBox(
          child: Padding(
            padding: EdgeInsets.fromLTRB(5, 0, rm, 10),
            child: _containerForValue(widget.dataValueRow, appThemeData, pathProperties),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            DetailButton(
              appThemeData: widget.appThemeData,
              show: widget.isEditDataDisplay,
              text: 'Edit',
              onPressed: () {
                widget.dataAction(DetailAction(ActionType.editItemData, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
              },
            ),
            DetailButton(
              appThemeData: widget.appThemeData,
              show: widget.isEditDataDisplay,
              text: 'Change',
              onPressed: () {
                widget.dataAction(DetailAction(ActionType.renameItem, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.name, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction, additional: widget.dataValueRow.value));
              },
            ),
            DetailButton(
              appThemeData: widget.appThemeData,
              show: !widget.isEditDataDisplay && (widget.dataValueRow.displayTypeData.displayType != DisplayType.positionalString),
              timerMs: 500,
              text: 'Copy',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.onResolve(widget.dataValueRow.value, Path.empty())));
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
                widget.dataAction(DetailAction(ActionType.removeItem, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
              },
            ),
            widget.isEditDataDisplay ? IconButton(
              color: appThemeData.screenForegroundColour(true),
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Path',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.dataValueRow.fullPath.toString()));
              }
            ) : const SizedBox(width: 0,)
          ],
        ),
        const SizedBox(
          height: 10,
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
                    widget.dataAction(DetailAction(ActionType.renameItem, false, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.name, oldValueType: optionTypeDataGroup, onCompleteActionNullable: _onCompleteAction));
                  },
                ),
                DetailButton(
                  appThemeData: widget.appThemeData,
                  show: widget.isEditDataDisplay,
                  text: 'Remove',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.removeItem, false, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: optionTypeDataGroup, onCompleteActionNullable: _onCompleteAction));
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
      dataAction(DetailAction(ActionType.groupSelect, value, path));
    },
  );
}
