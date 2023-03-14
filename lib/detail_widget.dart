import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'data_load.dart';

const _styleLarge = TextStyle(fontFamily: 'Code128', fontSize: 30.0);
const _styleLargeEdit = TextStyle(fontFamily: 'Code128', fontSize: 25.0);
const _styleSmall = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
const _styleSmallDisabled = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.grey);
const _buttonBorderStyle = BorderSide(color: Colors.black, width: 2);
const _buttonBorderStyleDisabled = BorderSide(color: Colors.grey, width: 2);

enum ActionType { none, editStart, editSubmit, addStart, addSubmit, link, clip }

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
      return l[l.length-1];
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
      case ActionType.addStart:
        {
          return "ADD-START: $s";
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
    return "";
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
  bool clipped = false;
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
                "Title:${widget.dataValueRow.name}",
                style: _styleSmall,
              ),
              subtitle: Text("Owned By:${widget.dataValueRow.path}"),
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
                widget.dataValueRow.isLink()
                    ? OutlinedButton(
                        style: OutlinedButton.styleFrom(side: _buttonBorderStyle),
                        child: const Text('Link', style: _styleSmall),
                        onPressed: () {
                          widget.dataAction(DetailAction(ActionType.link, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
                        },
                      )
                    : const SizedBox(),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(side: clipped ? _buttonBorderStyleDisabled : _buttonBorderStyle),
                  child: Text('Copy', style: clipped ? _styleSmallDisabled : _styleSmall),
                  onPressed: () async {
                    if (clipped) {
                      return;
                    }
                    await Clipboard.setData(ClipboardData(text: widget.dataValueRow.value));
                    widget.dataAction(DetailAction(ActionType.clip, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
                    setState(() {
                      clipped = true;
                    });
                    Timer(const Duration(seconds: 1), () {
                      setState(() {
                        clipped = false;
                      });
                    });
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(side: edit ? _buttonBorderStyleDisabled : _buttonBorderStyle),
                  child: Text('Edit', style: edit ? _styleSmallDisabled : _styleSmall),
                  onPressed: () {
                    if (edit) {
                      return;
                    }
                    setState(() {
                      edit = true;
                      _controller.text = widget.dataValueRow.value;
                    });
                    widget.dataAction(DetailAction(ActionType.editStart, true, widget.dataValueRow.getFullPath(), widget.dataValueRow.value, ""));
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
                "Title:${widget.dataValueRow.name} has ${widget.dataValueRow.mapSize} sub elements",
                style: _styleSmall,
              ),
              subtitle: Text("Owned By:${widget.dataValueRow.path}"),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(side: _buttonBorderStyle),
                  child: const Text('Add', style: _styleSmall),
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.addStart, false, widget.dataValueRow.getFullPath(), widget.dataValueRow.name, ""));
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(side: _buttonBorderStyle),
                  child: const Text('Edit', style: _styleSmall),
                  onPressed: () {
                    widget.dataAction(DetailAction(ActionType.editStart, false, widget.dataValueRow.getFullPath(), widget.dataValueRow.name, ""));
                  },
                ),
              ],
            ),
          ])),
    );
  }
}
