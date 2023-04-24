import 'package:flutter/material.dart';
import 'dart:async';

const _buttonBorderStyle = BorderSide(color: Colors.black, width: 2);
const _buttonBorderStyleGrey = BorderSide(color: Colors.grey, width: 2);
const _styleSmall = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
const _styleSmallDisabled = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.grey);
const _inputTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 30.0, color: Colors.black);

class DetailIconButton extends StatefulWidget {
  final bool show;
  final Function() onPressed;
  final int timerMs;
  final Icon icon;
  final String tooltip;
  final MaterialColor materialColor;
  const DetailIconButton({super.key, this.show = true, required this.onPressed, this.timerMs = 100, required this.icon, this.tooltip = "", required this.materialColor});
  @override
  State<DetailIconButton> createState() => _DetailIconButton();
}

class _DetailIconButton extends State<DetailIconButton> {
  bool grey = false;

  @override
  Widget build(BuildContext context) {
    if (widget.show) {
      return IconButton(
        padding: const EdgeInsets.fromLTRB(1, 12, 1, 0),
        color: grey ? widget.materialColor.shade900 : widget.materialColor.shade900,
        icon: widget.icon,
        tooltip: widget.tooltip,
        onPressed: () {
          if (grey) {
            return;
          }
          setState(() {
            grey = true;
          });
          Timer(const Duration(milliseconds: 5), () {
            widget.onPressed();
            Timer(Duration(milliseconds: 15 + widget.timerMs), () {
              setState(() {
                grey = false;
              });
            });
          });
        },
      );
    } else {
      return const SizedBox(width: 0);
    }
  }
}

class DetailButton extends StatefulWidget {
  const DetailButton({super.key, required this.onPressed, required this.text, this.timerMs = 100, this.show = true});
  final bool show;
  final Function() onPressed;
  final String text;
  final int timerMs;
  @override
  State<DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<DetailButton> {
  bool grey = false;

  @override
  Widget build(BuildContext context) {
    if (widget.show) {
      return Row(
        children: [
          OutlinedButton(
            onPressed: () {
              if (grey) {
                return;
              }
              widget.onPressed();
              setState(() {
                grey = true;
              });
              Timer(Duration(milliseconds: 15 + widget.timerMs), () {
                setState(() {
                  grey = false;
                });
              });
            },
            style: OutlinedButton.styleFrom(side: grey ? _buttonBorderStyleGrey : _buttonBorderStyle),
            child: Text(widget.text, style: grey ? _styleSmallDisabled : _styleSmall),
          ),
          const SizedBox(width: 8)
        ],
      );
    } else {
      return const SizedBox(width: 0);
    }
  }
}

class _OptionPair {
  final String display;
  final Type optionType;
  _OptionPair(
    this.optionType,
    this.display,
  );
}

class OptionList extends StatefulWidget {
  final List<_OptionPair> _optionList = List.empty(growable: true);
  final void Function(Type, String) onSelect;
  late final Type _initialSelect;

  OptionList({super.key, required final Map<Type, String> options, required final Type selectedOption, required this.onSelect}) {
    if (options.isEmpty) {
      _initialSelect = String;
    } else {
      bool notFound = true;
      options.forEach((typ, disp) {
        _optionList.add(_OptionPair(typ, disp));
        if (typ == selectedOption) {
          notFound = false;
          _initialSelect = typ;
        }
      });
      if (notFound) {
        _initialSelect = _optionList[0].optionType;
      }
    }
  }

  @override
  State<OptionList> createState() => _OptionListState();
}

class _OptionListState extends State<OptionList> {
  String _select = "";

  @override
  initState() {
    super.initState();
    _select = widget._initialSelect.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget._optionList.isEmpty) {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < widget._optionList.length; i++) ...[
          RadioListTile<String>(
            title: Text(
              widget._optionList[i].display,
              style: _styleSmall,
            ),
            value: widget._optionList[i].optionType.toString(),
            groupValue: _select,
            onChanged: (String? value) {
              setState(() {
                if (value != null) {
                  _select = value;
                  widget.onSelect(widget._optionList[i].optionType, widget._optionList[i].display);
                }
              });
            },
          ),
        ],
      ],
    );
  }
}

class ValidatedInputField extends StatefulWidget {
  ValidatedInputField({super.key, required this.initialValue, required this.onClose, required this.validate, required this.initialType, required this.prompt, required this.options, required this.currentOptionType});
  final String initialValue;
  final Type initialType;
  final String prompt;
  final Map<Type, String> options;
  final Type currentOptionType;
  final void Function(String, String, Type) onClose;
  final String Function(String, String, Type, String) validate;
  final controller = TextEditingController();

  @override
  State<ValidatedInputField> createState() => _ValidatedInputFieldState();
}

class _ValidatedInputFieldState extends State<ValidatedInputField> {
  String help = "";
  String initial = "";
  String current = "";
  Type inputType = String;
  String inputTypeName = "";
  bool currentIsValid = false;
  bool showOkButton = false;

  @override
  initState() {
    super.initState();
    initial = widget.initialValue.trim();
    current = initial;
    inputType = widget.initialType;
    if (widget.options.isNotEmpty && widget.options[inputType] != null) {
      inputTypeName = widget.options[inputType]!;
    } else {
      inputTypeName = "Name";
    }
    widget.controller.text = current;
    help = widget.validate(current, initial, inputType, inputTypeName);
    currentIsValid = help.isEmpty;
  }

  void _validate() {
    setState(() {
      help = widget.validate(current, initial, inputType, inputTypeName);
      currentIsValid = help.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OptionList(
            options: widget.options,
            selectedOption: widget.currentOptionType,
            onSelect: (selType, typeName) {
              inputType = selType;
              inputTypeName = typeName;
              showOkButton = (inputType != widget.initialType);
              if (inputType == bool) {
                current = _toYesNoString(_toTrueFalse(current));
              }
              _validate();
            }),
        Container(
          alignment: Alignment.centerLeft,
          child: Text(widget.prompt.replaceAll("\$", inputTypeName), style: _inputTextStyle),
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
                    style: _inputTextStyle,
                  ),
                ),
                const SizedBox(
                  height: 10,
                )
              ]),
        (inputType == bool)
            ? OptionList(
                options: const {bool: "Yes (true)", int:"No (false)"},
                selectedOption: (_toTrueFalse(current)?bool:int),
                onSelect: (selType, typeName) {
                  current = _toYesNoString(selType == bool);
                  showOkButton = (current != _toYesNoString(_toTrueFalse(widget.initialValue)));
                  _validate();
                })
            : TextField(
                controller: widget.controller,
                style: _inputTextStyle,
                onChanged: (value) {
                  current = value;
                  showOkButton = (current != widget.initialValue);
                  _validate();
                },
                onSubmitted: (value) {
                  _validate();
                  if (currentIsValid) {
                    widget.onClose("OK", current, inputType);
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
        Row(
          children: [
            DetailButton(
              show: currentIsValid && showOkButton,
              text: 'OK',
              onPressed: () {
                widget.onClose("OK", current, inputType);
              },
            ),
            DetailButton(
              text: 'Cancel',
              onPressed: () {
                widget.onClose("Cancel", current, inputType);
              },
            )
          ],
        ),
      ],
    );
  }
}

String _toYesNoString(bool value) {
  if (value) {
    return "Yes";
  }
  return "No";
}

bool _toTrueFalse(String value) {
  final vlc = value.trim().toLowerCase();
  if (vlc == "true" || vlc == "yes" || vlc == "1") {
    return true;
  }
  return false;
}
