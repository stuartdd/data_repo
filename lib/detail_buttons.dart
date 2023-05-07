import 'package:flutter/material.dart';
import 'dart:async';
import 'data_types.dart';

const _buttonBorderStyle = BorderSide(color: Colors.black, width: 2);
const _buttonBorderStyleGrey = BorderSide(color: Colors.grey, width: 2);
const _styleSmall = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
const _styleSmallDisabled = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.grey);
const _inputTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 30.0, color: Colors.black);
const _trueStr = "true";
const _falseStr = "false";

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

class OptionListWidget extends StatefulWidget {
  late final List<OptionsTypeData> _optionList;
  late final OptionsTypeData _selectedOption;
  late final void Function(String, OptionsTypeData) _onSelect;

  OptionListWidget({super.key, required final List<OptionsTypeData> options, required final OptionsTypeData selectedOption, required final void Function(String, OptionsTypeData) onSelect}) {
    _optionList = options;
    _selectedOption = selectedOption;
    _onSelect = onSelect;
  }

  // Find the element type index for a given type name.
  //    -1 indicated not found
  int _findElementTypeIndex(String key) {
    if (_optionList.isNotEmpty) {
      for (int i = 0; i < _optionList.length; i++) {
        if (_optionList[i].key == key) {
          return i;
        }
      }
    }
    return -1;
  }

  @override
  State<OptionListWidget> createState() => _OptionListWidgetState();
}

class _OptionListWidgetState extends State<OptionListWidget> {
  OptionsTypeData _currentSelect = optionTypeDataNotFound;

  @override
  initState() {
    super.initState();
    _currentSelect = widget._selectedOption;
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
              widget._optionList[i].description,
              style: _styleSmall,
            ),
            value: widget._optionList[i].key,
            groupValue: _currentSelect.key,
            onChanged: (String? value) {
              setState(() {
                if (value != null) {
                  final i = widget._findElementTypeIndex(value);
                  if (i >= 0) {
                    _currentSelect = widget._optionList[i];
                    widget._onSelect(value, widget._optionList[i]);
                  }
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
  ValidatedInputField({super.key, required this.initialValue, required this.onClose, required this.onValidate, required this.prompt, required this.options, required this.initialOption});
  final String initialValue;
  final List<OptionsTypeData> options;
  final OptionsTypeData initialOption;
  final String prompt;
  final void Function(String, String, OptionsTypeData) onClose;
  final String Function(String, String, OptionsTypeData, OptionsTypeData) onValidate;
  final controller = TextEditingController();

  @override
  State<ValidatedInputField> createState() => _ValidatedInputFieldState();
}

class _ValidatedInputFieldState extends State<ValidatedInputField> {
  String help = "";
  String initial = "";
  String current = "";
  OptionsTypeData initialOption = optionTypeDataNotFound;
  OptionsTypeData currentOption = optionTypeDataNotFound;
  bool currentIsValid = false;

  @override
  initState() {
    super.initState();
    initial = widget.initialValue.trim();
    current = initial;
    initialOption = widget.initialOption;
    currentOption = initialOption;
    widget.controller.text = current;
    help = widget.onValidate(initial, current, initialOption, currentOption);
    currentIsValid = help.isEmpty;
  }

  void _validate() {
    setState(() {
      help = widget.onValidate(initial, current, initialOption, currentOption);
      currentIsValid = help.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showOkButton = (current != initial || currentOption.notEqual(initialOption));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OptionListWidget(
            options: widget.options,
            selectedOption: widget.initialOption,
            onSelect: (value, sel) {
              currentOption = sel;
              if (currentOption.elementType == bool) {
                current = _toTrueFalse(current);
              }
              debugPrint("currentOption $currentOption Value '$current'");
              _validate();
            }),
        Container(
          alignment: Alignment.centerLeft,
          child: Text(widget.prompt.replaceAll("\$", currentOption.description), style: _inputTextStyle),
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
        (currentOption.elementType == bool)
            ? OptionListWidget(
                options: optionsForYesNo,
                selectedOption: OptionsTypeData.toTrueFalse(current),
                onSelect: (value, option) {
                  current = option.key;
                  debugPrint("Current: $current Opt: ${currentOption.description}");
                  _validate();
                })
            : TextField(
                controller: widget.controller,
                style: _inputTextStyle,
                onChanged: (value) {
                  current = value;
                  _validate();
                },
                onSubmitted: (value) {
                  _validate();
                  if (currentIsValid) {
                    widget.onClose("OK", current, currentOption);
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
                widget.onClose("OK", current, currentOption);
              },
            ),
            DetailButton(
              text: 'Cancel',
              onPressed: () {
                widget.onClose("Cancel", current, currentOption);
              },
            )
          ],
        ),
      ],
    );
  }
}

String _toTrueFalse(String value) {
  final v = value.trim().toLowerCase();
  if (v.contains("tru") || v.contains("yes")) {
    return _trueStr;
  }
  try {
    final i = int.parse(v);
    if (i == 0) {
      return _falseStr;
    }
    return _trueStr;
  } catch(e) {
    return _falseStr;
  }
}


