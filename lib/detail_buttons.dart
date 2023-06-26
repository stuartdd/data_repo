import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'data_types.dart';
import 'path.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const _buttonBorderStyle = BorderSide(color: Colors.black, width: 2);
const _buttonBorderStyleGrey = BorderSide(color: Colors.grey, width: 2);
// const _styleSmall = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
// const _styleSmallDisabled = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.grey);
// const _inputTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 30.0, color: Colors.black);
const _trueStr = "true";
const _falseStr = "false";
const helpText = """# # Heading 1 (one more # for each sub heading)
## ## Heading 2  (Use blank lines before and after headings)
_\\_Italic\\__ \\_\\___Bold__\\_\\_ \\_\\_\\____BoldItalic___\\_\\_\\_. One Two or Three underscore.

Escape using '\\\\'. 

For a 'New Line': Use an empty line. Otherwise it is a paragraph. Don't have empty spaces at the start of a line.

> > Block Quotes. Note space after >

1. First list line (Ordered Lists)
    1. Sublist (4 spaces indent)
2. Second List Line

- Un-ordered list start line with a dash+space '- '

``Code Blocks surround with 'backtick'. Use 2 to include a backtick `
``

Code block Special chars use &code; where code = lt, gt, amp

Horizontal line use 3 '*' or 3 '-' or 3 '_'
___
To add an image, add an exclamation mark (!), followed by alt text in brackets, and the path or URL to the image asset in parentheses. You can optionally add a title in quotation marks after the path or URL.

mages ``![alt text](images/image.jpg "Comment")``

[Link](https://www.markdownguide.org/basic-syntax/#images-1) ``[Link](https://www.markdownguide.org/basic-syntax/#images-1)``
""";

class DetailIconButton extends StatefulWidget {
  final bool show;
  final Function() onPressed;
  final int timerMs;
  final Icon icon;
  final String tooltip;
  final AppThemeData appThemeData;
  final EdgeInsetsGeometry padding;
  const DetailIconButton({super.key, this.show = true, required this.onPressed, this.timerMs = 100, required this.icon, this.tooltip = "", required this.appThemeData, this.padding = const EdgeInsets.fromLTRB(1, 1, 1, 0)});
  @override
  State<DetailIconButton> createState() => _DetailIconButton();
}

class _DetailIconButton extends State<DetailIconButton> {
  bool grey = false;

  @override
  Widget build(BuildContext context) {
    if (widget.show) {
      return IconButton(
        padding: widget.padding,
        color: grey ? widget.appThemeData.primary.shade200 : widget.appThemeData.primary.shade900,
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
  const DetailButton({super.key, required this.onPressed, required this.text, this.timerMs = 100, this.show = true, required this.appThemeData});
  final bool show;
  final AppThemeData appThemeData;
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
          SizedBox(
            height: 40,
            child: OutlinedButton(
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
              child: Text(widget.text, style: grey ? widget.appThemeData.tsMediumDisabled : widget.appThemeData.tsMedium),
            ),
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
  final AppThemeData appThemeData;

  OptionListWidget({super.key, required final List<OptionsTypeData> options, required final OptionsTypeData selectedOption, required final void Function(String, OptionsTypeData) onSelect, required this.appThemeData}) {
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
              style: widget.appThemeData.tsMedium,
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

class MarkDownInputField extends StatefulWidget {
  final String initialText;
  final void Function(String, String, OptionsTypeData) onClose;
  final double height;
  final double width;
  final AppThemeData appThemeData;
  final bool Function(bool) shouldDisplayHelp;
  final bool Function(bool) shouldDisplayPreview;
  final bool Function(DetailAction) dataAction;

  const MarkDownInputField({super.key, required this.initialText, required this.onClose, required this.height, required this.width, required this.shouldDisplayHelp, required this.shouldDisplayPreview, required this.dataAction, required this.appThemeData});
  @override
  State<MarkDownInputField> createState() => _MarkDownInputField();
}

class _MarkDownInputField extends State<MarkDownInputField> {
  final controller = TextEditingController();
  @override
  initState() {
    super.initState();
    controller.text = widget.initialText;
  }

  void doOnTapLink(String text, String? href, String title) {
    if (href != null) {
      widget.dataAction(DetailAction(
        ActionType.link,
        true,
        Path.empty(),
        oldValue: href,
        oldValueType: optionTypeDataString,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Column(
        children: [
          widget.shouldDisplayPreview(false)
              ? Container(
                  color: widget.appThemeData.hiLight.shade300,
                  child: Markdown(
                    data: controller.text,
                    selectable: true,
                    shrinkWrap: true,
                    styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
                    onTapLink: doOnTapLink,
                  ))
              : const SizedBox(
                  height: 0,
                ),
          widget.shouldDisplayHelp(false)
              ? Container(
                  color: widget.appThemeData.secondary.shade300,
                  child: Markdown(
                    data: helpText,
                    selectable: true,
                    shrinkWrap: true,
                    styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
                    onTapLink: doOnTapLink,
                  ))
              : const SizedBox(
                  height: 0,
                ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.multiline,
              style: widget.appThemeData.tsMedium,
              maxLines: null,
              expands: true,
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Row(
            children: [
              DetailButton(
                show: controller.text != widget.initialText,
                appThemeData: widget.appThemeData,
                text: 'OK',
                onPressed: () {
                  widget.onClose("OK", controller.text, optionTypeDataMarkDown);
                },
              ),
              DetailButton(
                appThemeData: widget.appThemeData,
                text: 'Cancel',
                onPressed: () {
                  widget.onClose("Cancel", widget.initialText, optionTypeDataMarkDown);
                },
              ),
              DetailButton(
                appThemeData: widget.appThemeData,
                text: widget.shouldDisplayHelp(false) ? 'Hide Help' : "Show Help",
                onPressed: () {
                  setState(() {
                    widget.shouldDisplayHelp(true);
                  });
                },
              ),
              DetailButton(
                appThemeData: widget.appThemeData,
                text: widget.shouldDisplayPreview(false) ? 'Hide Preview' : "Show Preview",
                onPressed: () {
                  setState(() {
                    widget.shouldDisplayPreview(true);
                  });
                },
              )
            ],
          ),
        ],
      ),
    );
  }
}

class ValidatedInputField extends StatefulWidget {
  ValidatedInputField({super.key, required this.initialValue, required this.onClose, required this.onValidate, required this.prompt, required this.options, required this.initialOption, required this.appThemeData});
  final String initialValue;
  final List<OptionsTypeData> options;
  final OptionsTypeData initialOption;
  final String prompt;
  final void Function(String, String, OptionsTypeData) onClose;
  final String Function(String, String, OptionsTypeData, OptionsTypeData) onValidate;
  final controller = TextEditingController();
  final AppThemeData appThemeData;

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
            appThemeData: widget.appThemeData,
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
          child: Text(widget.prompt.replaceAll("[type]", currentOption.description), style: widget.appThemeData.tsMedium),
        ),
        (help.isEmpty)
            ? const SizedBox(
                height: 0,
              )
            : Column(children: [
                Container(
                  alignment: Alignment.centerLeft,
                  color:  widget.appThemeData.error.shade900,
                  child: Text(
                    " $help ",
                    style:  widget.appThemeData.tsMedium,
                  ),
                ),
                const SizedBox(
                  height: 10,
                )
              ]),
        (currentOption.elementType == bool)
            ? OptionListWidget(
          appThemeData:  widget.appThemeData,
                options: optionsForYesNo,
                selectedOption: OptionsTypeData.toTrueFalse(current),
                onSelect: (value, option) {
                  current = option.key;
                  debugPrint("Current: $current Opt: ${currentOption.description}");
                  _validate();
                })
            : TextField(
                controller: widget.controller,
                style:  widget.appThemeData.tsMedium,
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
              appThemeData:  widget.appThemeData,
              show: currentIsValid && showOkButton,
              text: 'OK',
              onPressed: () {
                widget.onClose("OK", current, currentOption);
              },
            ),
            DetailButton(
              appThemeData:  widget.appThemeData,
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
  } catch (e) {
    return _falseStr;
  }
}
