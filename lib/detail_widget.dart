import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_load.dart';
import 'detail_buttons.dart';

const _styleLarge = TextStyle(fontFamily: 'Code128', fontSize: 35.0);
const _styleLargeEdit = TextStyle(fontFamily: 'Code128', fontSize: 28.0);
const _styleSmall = TextStyle(fontFamily: 'Code128', fontSize: 25.0, color: Colors.black);
const _styleSubTitle = TextStyle(fontFamily: 'Code128', fontSize: 17.0, color: Colors.black);

enum ActionType { none, editStart, editCancel, editSubmit, addStart, addCancel, addSubmit, link, clip }

class DetailAction {
  final ActionType action;
  final bool value;
  final String path;
  final String v1;
  final String v2;
  const DetailAction(this.action, this.value, this.path, this.v1, this.v2);

  bool isValueDifferent() {
    return v1.trim() != v2.trim();
  }

  String getLastPathElement() {
    final l = path.split('.');
    if (l.isNotEmpty) {
      return l[l.length - 1];
    }
    return "";
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

class DetailWidget extends StatefulWidget {
  const DetailWidget({super.key, required this.dataValueRow, required this.materialColor, required this.dataAction});
  final DataValueRow dataValueRow;
  final MaterialColor materialColor;
  final bool Function(DetailAction) dataAction;
  @override
  State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {
  bool edit = false;
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
    if (widget.dataValueRow.isValue) {
      return detailForValue();
    }
    return dataForMap();
  }

  Widget detailForValue() {
    return SizedBox(
      child: Card(
          color: widget.materialColor.shade600,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.album),
              title: Text(
                widget.dataValueRow.name,
                style: _styleSmall,
              ),
              subtitle: Text("Owned By:${widget.dataValueRow.path}. Is a ${widget.dataValueRow.type}", style: _styleSubTitle),
            ),
            SizedBox(
              width: double.infinity,
              child: Card(
                margin: EdgeInsetsGeometry.lerp(null, null, 5),
                color: edit ? widget.materialColor.shade100 : widget.materialColor.shade200,
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
                  show: !edit,
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
                  show: edit,
                  text: 'Done',
                  onPressed: () {
                    if (widget.dataAction(DetailAction(ActionType.editSubmit, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, _controller.text))) {
                      setState(() {
                        edit = false;
                      });
                    }
                  },
                ),
                DetailButton(
                  show: edit,
                  text: 'Cancel',
                  onPressed: () {
                    setState(() {
                      edit = false;
                    });
                    widget.dataAction(DetailAction(ActionType.editCancel, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
                  },
                ),
                DetailButton(
                  show: !edit,
                  timerMs: 500,
                  text: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.dataValueRow.value));
                    widget.dataAction(DetailAction(ActionType.clip, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
                  },
                ),
                DetailButton(
                  show: widget.dataValueRow.isLink() && !edit,
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

  Widget dataForMap() {
    return SizedBox(
      child: Card(
          color: widget.materialColor.shade300,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.album),
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
