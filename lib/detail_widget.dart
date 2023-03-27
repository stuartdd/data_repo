import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_load.dart';
import 'path.dart';
import 'detail_buttons.dart';

const _styleLarge = TextStyle(fontFamily: 'Code128', fontWeight: FontWeight.w500, fontSize: 30.0, color: Colors.black);
const _styleLargeEdit = TextStyle(fontFamily: 'Code128', fontSize: 30.0, color: Colors.black);
const _styleSmall = TextStyle(fontFamily: 'Code128', fontWeight: FontWeight.w500, fontSize: 25.0, color: Colors.black);
const _styleSmallEdit = TextStyle(fontFamily: 'Code128', fontWeight: FontWeight.w500, fontSize: 25.0, color: Colors.black);
const _styleSubTitle = TextStyle(fontFamily: 'Code128', fontSize: 17.0, color: Colors.black);

enum ActionType { none, editStart, editCancel, editSubmit, renameStart, renameCancel, renameSubmit, addStart, addCancel, addSubmit, link, clip }

class DetailAction {
  final ActionType action;
  final bool value;
  final Path path;
  final String v1;
  final String v2;
  const DetailAction(this.action, this.value, this.path, this.v1, this.v2);

  bool isValueDifferent() {
    return v1.trim() != v2.trim();
  }

  String getLastPathElement() {
    return path.getLast();
  }

  @override
  String toString() {
    final s = "Type:'${value ? "Value" : "Map"}' Path:'$path' V1:'$v1' V2:'$v2'";
    switch (action) {
      case ActionType.none:
        {
          return "NONE: $s";
        }
      case ActionType.editStart:
        {
          return "EDIT-START: $s";
        }
      case ActionType.editSubmit:
        {
          return "EDIT-SUBMIT: $s";
        }
      case ActionType.editCancel:
        {
          return "EDIT-CANCEL: $s";
        }
      case ActionType.renameStart:
        {
          return "RENAME-START: $s";
        }
      case ActionType.renameCancel:
        {
          return "RENAME-CANCEL $s";
        }
      case ActionType.renameSubmit:
        {
          return "RENAME-SUBMIT: $s";
        }
      case ActionType.addStart:
        {
          return "ADD-START: $s";
        }
      case ActionType.addCancel:
        {
          return "ADD-CANCEL: $s";
        }
      case ActionType.addSubmit:
        {
          return "ADD-SUBMIT: $s";
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
  final Path _path;
  final String _type;
  final bool _isValue;
  final int _mapSize;

  DataValueDisplayRow(this._name, this._value, this._path, this._type, this._isValue, this._mapSize);

  Path getFullPath() {
    return _path.cloneAppend([_name]);
  }

  String get name => _name;
  String get value => _value;
  Path get path => _path;
  String get type => _type;
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
  bool edit = false;
  bool editName = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hiLight =  widget.hiLightedPaths.contains(widget.dataValueRow.getFullPath());
    final  materialColor = hiLight ? widget.hiMaterialColor : widget.loMaterialColor;
    if (widget.dataValueRow.isValue) {
      return detailForValue(materialColor,hiLight);
    }
    return dataForMap(materialColor,hiLight);
  }

  Widget detailForValue(MaterialColor materialColor, bool hiLight) {
    return SizedBox(
      child: Card(
          color: materialColor.shade600,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: hiLight ? const Icon(Icons.radio_button_checked) : const Icon(Icons.radio_button_unchecked),
              title: editName
                  ? Container(
                      color: materialColor.shade100,
                      child: TextField(
                        controller: _controller,
                        style: _styleSmallEdit,
                        onSubmitted: (value) {
                          if (widget.dataAction(DetailAction(ActionType.renameSubmit, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.name, _controller.text))) {
                            setState(() {
                              edit = false;
                            });
                          }
                        },
                      ))
                  : Text(widget.dataValueRow.name, style: _styleSmall),
              subtitle: Text("Owned By:${widget.dataValueRow.path}. Is a ${widget.dataValueRow.type}", style: _styleSubTitle),
            ),
            SizedBox(
              width: double.infinity,
              child: Card(
                margin: EdgeInsetsGeometry.lerp(null, null, 5),
                color: edit ? materialColor.shade100 : materialColor.shade200,
                child: Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: edit
                        ? TextField(
                            controller: _controller,
                            style: _styleLargeEdit,
                            onSubmitted: (value) {
                              if (widget.dataAction(DetailAction(ActionType.editSubmit, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, _controller.text))) {
                                setState(() {
                                  edit = false;
                                });
                              }
                            },
                          )
                        : Text(widget.dataValueRow.value, style: _styleLarge)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                DetailButton(
                  show: !edit && !editName,
                  text: 'Edit',
                  onPressed: () {
                    setState(() {
                      edit = true;
                      _controller.text = widget.dataValueRow.value;
                    });
                    widget.dataAction(DetailAction(ActionType.editStart, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
                  },
                ),
                DetailButton(
                  show: !edit && !editName,
                  text: 'Re-Name',
                  onPressed: () {
                    setState(() {
                      editName = true;
                      _controller.text = widget.dataValueRow.name;
                    });
                    widget.dataAction(DetailAction(ActionType.renameStart, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.name, ""));
                  },
                ),
                DetailButton(
                  show: edit || editName,
                  text: 'Done',
                  onPressed: () {
                    String v = "";
                    if (edit) {
                      v = widget.dataValueRow.value;
                    } else {
                      if (editName) {
                        v = widget.dataValueRow.name;
                      }
                    }
                    if (widget.dataAction(DetailAction(edit ? ActionType.editSubmit : ActionType.renameSubmit, true, widget.dataValueRow.getFullPath(), v, _controller.text))) {
                      setState(() {
                        edit = false;
                        editName = false;
                      });
                    }
                  },
                ),
                DetailButton(
                  show: edit || editName,
                  text: 'Cancel',
                  onPressed: () {
                    widget.dataAction(DetailAction(edit ? ActionType.editCancel : ActionType.renameCancel, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
                    setState(() {
                      edit = false;
                      editName = false;
                    });
                  },
                ),
                DetailButton(
                  show: !edit && !editName,
                  timerMs: 500,
                  text: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.dataValueRow.value));
                    widget.dataAction(DetailAction(ActionType.clip, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
                  },
                ),
                DetailButton(
                  show: widget.dataValueRow.isLink() && !edit && !editName,
                  timerMs: 500,
                  text: 'Link',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.link, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
                  },
                ),
              ],
            ),
          ])),
    );
  }

  Widget dataForMap(MaterialColor materialColor, bool hiLight) {
    return SizedBox(
      child: Card(
          color: materialColor.shade300,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: hiLight ? const Icon(Icons.radio_button_checked) : const Icon(Icons.radio_button_unchecked),
              title: Text(
                widget.dataValueRow.name,
                style: _styleSmall,
              ),
              subtitle: Text("Owned By:${widget.dataValueRow.path}. Has ${widget.dataValueRow.mapSize} sub elements", style: _styleSubTitle),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                DetailButton(
                  text: 'Add',
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.addStart, false, widget.dataValueRow.getFullPath(), widget.dataValueRow.name, ""));
                  },
                ),
                DetailButton(
                  text: "Re-Name",
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.editStart, false, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
                  },
                ),
              ],
            ),
          ])),
    );
  }
}

