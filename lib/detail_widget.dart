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
import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'path.dart';
import 'data_types.dart';
import 'detail_buttons.dart';

class DataValueDisplayRow {
  final String _name;
  final String _stringValue;
  final OptionsTypeData _type;
  final bool _isValue;
  final Path _path;
  final int _mapSize;
  final Path _pathWithName;
  const DataValueDisplayRow(this._name, this._stringValue, this._type, this._isValue, this._path, this._mapSize, this._pathWithName);

  String get name => _name;
  OptionsTypeData get type => _type;
  Path get path => _path;
  Path get pathWithName => _pathWithName;
  bool get isValue => _isValue;
  int get mapSize => _mapSize;

  String get displayName {
    if (isValue && type.hasSuffix) {
      return _name.substring(0, _name.length - _type.nameSuffix.length);
    }
    return _name;
  }

  Path get fullPath {
    return _path.cloneAppend(_name);
  }

  String getDisplayName(bool editMode) {
    if (editMode) {
      return name;
    }
    return name.substring(0, (_name.length - _type.nameSuffix.length));
  }

  String get value {
    if (_type.dataValueType == bool) {
      if (_stringValue == "true") {
        return "Yes";
      }
      return "No";
    }
    return _stringValue;
  }

  bool get isLink {
    if (_isValue) {
      return isLinkString(_stringValue);
    }
    return false;
  }

  bool get isRef {
    if (_isValue) {
      return type.isRef;
    }
    return false;
  }

  @override
  String toString() {
    if (_isValue) {
      return "Name:$name ($_type) = Value:$value";
    }
    return "Name:$name [$_mapSize]";
  }
}

class DetailWidget extends StatefulWidget {
  const DetailWidget({super.key, required this.dataValueRow, required this.appThemeData, required this.dataAction, required this.onResolve, required this.pathPropertiesList, required this.isEditDataDisplay, required this.isHorizontal});
  final DataValueDisplayRow dataValueRow; // Fixed data about the node to be displayed
  final AppThemeData appThemeData;
  final PathPropertiesList pathPropertiesList;
  final bool isEditDataDisplay;
  final bool isHorizontal;
  final Path Function(DetailAction) dataAction;
  final SuccessState Function(String) onResolve;

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

  @override
  Widget build(BuildContext context) {
    final hiLight = widget.pathPropertiesList.propertiesForPath(widget.dataValueRow.pathWithName);
    if (widget.dataValueRow.isValue) {
      return _detailForValue(widget.appThemeData, hiLight, widget.isHorizontal, widget.isEditDataDisplay);
    }
    return _detailForMap(widget.appThemeData, hiLight, widget.isHorizontal, widget.isEditDataDisplay);
  }

  List<Widget> _tableRowForString(final String value, final bool updated, final TextStyle ts, final Color bg, final Color fg, final double height) {
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

  List<Widget> _tableRowForIndex(final int last, final bool updated, final TextStyle ts, final Color bg, final Color fg, final double height) {
    List<Widget> l = [];
    for (int i = 0; i < last; i++) {
      l.add(Container(
        alignment: Alignment.center,
        height: height / 2,
        color: bg,
        child: Text(
          "${i + 1}",
          style: ts,
        ),
      ));
    }
    return l;
  }

  Widget _tableForString(final String value, final bool updated, final TextStyle ts1, final TextStyle ts2, final Color bg, final Color fg, final double height) {
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
        child: _tableForString(dataValueRow.value, plp.updated, appThemeData.tsMedium, appThemeData.tsMediumBold, bgColour, fgColour, appThemeData.buttonHeight * 2),
      );
    }

    if (dataValueRow.type.equal(optionTypeDataMarkDown)) {
      return markdownDisplayWidget(true, dataValueRow.value, bgColour, (text, href, title) {
        markdownOnTapLink(text, href, title, widget.dataAction);
      });
    }

    if (dataValueRow.type.equal(optionTypeDataReference)) {
      final r = widget.onResolve(dataValueRow.value);
      if (r.isSuccess) {
        return Container(
          color: bgColour,
          alignment: Alignment.centerLeft,
          child: Padding(padding: const EdgeInsets.all(5.0), child: Text(r.value, style: appThemeData.tsLargeItalic)),
        );
      } else {
        return Container(
          color: appThemeData.error.med,
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              Container(
                color: appThemeData.error.med,
                alignment: Alignment.centerLeft,
                child: Padding(padding: const EdgeInsets.all(5.0), child: Text(r.message, style: appThemeData.tsLarge)),
              ),
              Container(
                color: bgColour,
                alignment: Alignment.centerLeft,
                child: Padding(padding: const EdgeInsets.all(5.0), child: Text(r.value, style: appThemeData.tsLargeItalic)),
              ),
            ],
          ),
        );
      }
    }

    return Container(
      color: bgColour,
      alignment: Alignment.centerLeft,
      child: Padding(padding: const EdgeInsets.all(5.0), child: Text(dataValueRow.value, style: appThemeData.tsLarge)),
    );
  }

  Widget _detailForValue(final AppThemeData appThemeData, final PathProperties plp, final bool horizontal, final bool isEditDataDisplay) {
    final double rm = widget.dataValueRow.type.equal(optionTypeDataMarkDown) ? 15 : 5;
    final String resolvedValue;
    final bool resolvedValueIsLink;
    final bool refIsResolved;
    if (widget.dataValueRow.type.isRef) {
      final v = widget.onResolve(widget.dataValueRow.value);
      if (v.isSuccess) {
        refIsResolved = true;
        resolvedValue = v.value;
        resolvedValueIsLink = isLinkString(resolvedValue);
      } else {
        refIsResolved = false;
        resolvedValue = widget.dataValueRow.value;
        resolvedValueIsLink = false;
      }
    } else {
      refIsResolved = true;
      resolvedValue = widget.dataValueRow.value;
      resolvedValueIsLink = isLinkString(resolvedValue);
    }
    return Card(
      shape: appThemeData.rectangleBorderShape,
      key: UniqueKey(),
      color: appThemeData.detailBackgroundColor,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: Container(
            padding: const EdgeInsets.all(3),
            color: appThemeData.selectedAndHiLightColour(true, plp.renamed),
            child: Row(
              children: [
                groupButton(plp, false, isEditDataDisplay, widget.dataValueRow.pathWithName, widget.appThemeData, widget.dataAction),
                isEditDataDisplay ? widget.appThemeData.buttonGapBox(1) : const SizedBox(width: 0),
                Text(widget.dataValueRow.displayName, style: appThemeData.tsMediumBold),
              ],
            ),
          ),
          subtitle: horizontal && !appThemeData.hideDataPath
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [widget.appThemeData.verticalGapBox(1), Text("[${widget.dataValueRow.type.displayName}] Owned By:${widget.dataValueRow.path}", style: appThemeData.tsMediumBold)],
                )
              : null,
          onTap: () {
            widget.dataAction(DetailAction(ActionType.select, false, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.name, oldValueType: optionTypeDataGroup, onCompleteActionNullable: _onCompleteAction));
          },
        ),
        SizedBox(
          child: Padding(
            padding: EdgeInsets.fromLTRB(5, 0, rm, 5),
            child: _containerForValue(widget.dataValueRow, appThemeData, plp),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            widget.appThemeData.buttonGapBox(2),
            DetailTextButton(
              appThemeData: widget.appThemeData,
              visible: widget.isEditDataDisplay,
              text: 'Properties',
              onPressed: (button) {
                widget.dataAction(DetailAction(ActionType.renameItem, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.name, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction, additional: widget.dataValueRow.value));
              },
            ),
            DetailIconButton(
                appThemeData: appThemeData,
                visible: widget.isEditDataDisplay,
                iconData: Icons.edit,
                tooltip: "Edit value",
                onPressed: (p0) {
                  widget.dataAction(DetailAction(ActionType.editItemData, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
                }),
            DetailIconButton(
                appThemeData: appThemeData,
                visible: !widget.isEditDataDisplay && refIsResolved,
                iconData: Icons.copy,
                tooltip: "Copy value",
                onPressed: (p0) async {
                  await Clipboard.setData(ClipboardData(text: resolvedValue));
                  widget.dataAction(DetailAction(ActionType.clip, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
                }),
            DetailIconButton(
                appThemeData: appThemeData,
                visible: resolvedValueIsLink && !widget.isEditDataDisplay && (widget.dataValueRow.type != optionTypeDataPositional) && refIsResolved,
                iconData: Icons.launch_outlined,
                tooltip: "Open in browser",
                onPressed: (p0) {
                  widget.dataAction(DetailAction(ActionType.link, true, widget.dataValueRow.pathWithName, oldValue: resolvedValue, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
                }),
            DetailIconButton(
                appThemeData: appThemeData,
                visible: widget.isEditDataDisplay,
                iconData: Icons.delete,
                tooltip: "Delete item",
                onPressed: (p0) {
                  widget.dataAction(DetailAction(ActionType.removeItem, true, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
                }),
            DetailIconButton(
                appThemeData: appThemeData,
                visible: widget.isEditDataDisplay && widget.dataValueRow.type.hasNoSuffix,
                iconData: Icons.copy,
                tooltip: "Copy reference to item",
                onPressed: (p0) {
                  Clipboard.setData(ClipboardData(text: widget.dataValueRow.fullPath.toString()));
                }),
            DetailIconButton(
                appThemeData: appThemeData,
                visible: widget.isEditDataDisplay && widget.dataValueRow.type.isRef && refIsResolved,
                iconData: Icons.double_arrow,
                tooltip: "Go to Reference",
                onPressed: (p0) {
                  widget.dataAction(DetailAction(ActionType.select, true, Path.fromDotPath(widget.dataValueRow.value).cloneParentPath(), oldValue: widget.dataValueRow.value, oldValueType: widget.dataValueRow.type, onCompleteActionNullable: _onCompleteAction));
                })
          ],
        ),
        widget.appThemeData.verticalGapBox(1)
      ]),
    );
  }

  Widget _detailForMap(final AppThemeData appThemeData, final PathProperties plp, final bool horizontal, final bool isEditDataDisplay) {
    return SizedBox(
      child: Card(
          shape: appThemeData.rectangleBorderShape,
          elevation: 2,
          margin: const EdgeInsets.all(2),
          key: UniqueKey(),
          color: appThemeData.detailBackgroundColor,
          child: Column(children: [
            ListTile(
              title: Container(
                padding: const EdgeInsets.all(3),
                color: appThemeData.selectedAndHiLightColour(true, plp.renamed),
                child: Row(
                  children: [
                    groupButton(plp, false, isEditDataDisplay, widget.dataValueRow.pathWithName, widget.appThemeData, widget.dataAction),
                    isEditDataDisplay ? widget.appThemeData.buttonGapBox(1) : const SizedBox(width: 0),
                    Text(widget.dataValueRow.name, style: appThemeData.tsLargeBold),
                  ],
                ),
              ),
              subtitle: horizontal
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [widget.appThemeData.verticalGapBox(1), Text("Owned By:${widget.dataValueRow.path}. Has ${widget.dataValueRow.mapSize} sub elements", style: appThemeData.tsMediumBold)],
                    )
                  : null,
              onTap: () {
                widget.dataAction(DetailAction(ActionType.select, false, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.name, oldValueType: optionTypeDataGroup, onCompleteActionNullable: _onCompleteAction));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                widget.appThemeData.buttonGapBox(2),
                DetailTextButton(
                  appThemeData: widget.appThemeData,
                  visible: widget.isEditDataDisplay,
                  text: 'Properties',
                  onPressed: (button) {
                    widget.dataAction(DetailAction(ActionType.renameItem, false, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.name, oldValueType: optionTypeDataGroup, onCompleteActionNullable: _onCompleteAction));
                  },
                ),
                DetailIconButton(
                    appThemeData: appThemeData,
                    visible: widget.isEditDataDisplay,
                    iconData: Icons.delete,
                    tooltip: "Delete item",
                    onPressed: (p0) {
                      widget.dataAction(DetailAction(ActionType.removeItem, false, widget.dataValueRow.pathWithName, oldValue: widget.dataValueRow.value, oldValueType: optionTypeDataGroup, onCompleteActionNullable: _onCompleteAction));
                    }),
              ],
            ),
            widget.appThemeData.verticalGapBox(1)
          ])),
    );
  }
}

Widget groupButton(final PathProperties plp, final bool value, final bool isEditDataDisplay, final Path path, final AppThemeData appThemeData, final Path Function(DetailAction) dataAction) {
  final c = appThemeData.screenForegroundColour(true);
  final size = appThemeData.iconSize;
  if (isEditDataDisplay) {
    return InkWell(
      child: plp.groupSelect ? Icon(Icons.radio_button_checked, color: c, size: size) : Icon(Icons.radio_button_unchecked, color: c, size: size),
      onTap: () {
        dataAction(DetailAction(ActionType.groupSelect, value, path));
      },
    );
  }
  return const SizedBox(width: 0);
}

bool isLinkString(String test) {
  var t = test.toLowerCase();
  if (t.startsWith("http://") || t.startsWith("https://")) {
    return true;
  }
  return false;
}
